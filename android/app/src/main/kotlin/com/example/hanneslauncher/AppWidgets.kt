package com.example.hanneslauncher

import android.app.Activity
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.SizeF
import android.view.ContextThemeWrapper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.RemoteViews
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Real Android app widgets on the panel - the clock, the weather, the music
 * player another app ships - hosted the way any launcher hosts them.
 *
 * Getting one onto the panel takes up to three steps, and each can be
 * refused: an id is allocated, the provider is bound to it (silently when
 * Android already allows it, otherwise through the system's own "allow
 * this launcher to create widgets" dialog), and then the widget's own setup
 * screen runs, if it has one. A refusal at any step gives the id back, so a
 * cancelled pick never leaves a half-made widget registered to this app.
 *
 * Drawing happens in a platform view ([Factory]), one per panel card. The
 * card always spans the panel's width; only its height is chosen, and the
 * widget is told both so it can pick the layout that fits.
 */
object AppWidgets {
    /** Any constant works; it only has to stay the same across releases. */
    private const val HOST_ID = 4711

    const val BIND_REQUEST_CODE = 4207
    const val CONFIGURE_REQUEST_CODE = 4208

    const val VIEW_TYPE = "hanneslauncher/app_widget"

    private var host: AppWidgetHost? = null

    /** The bind or configure step waiting for its activity result. */
    private var pending: Pending? = null

    private class Pending(val id: Int, val result: MethodChannel.Result)

    fun host(context: Context): AppWidgetHost =
        host ?: AppWidgetHost(context.applicationContext, HOST_ID).also { host = it }

    private fun manager(context: Context): AppWidgetManager =
        AppWidgetManager.getInstance(context)

    /** Updates only reach the views while this runs, see MainActivity. */
    fun startListening(context: Context) {
        try {
            host(context).startListening()
        } catch (_: Exception) {
            // Thrown while the user is still locked; the next start retries.
        }
    }

    fun stopListening(context: Context) {
        try {
            host(context).stopListening()
        } catch (_: Exception) {
            // Never started.
        }
    }

    /**
     * The picker's previews render one at a time, here. A thread per tile
     * had every visible tile fetch at once, and together they overran the
     * binder buffer - whichever tiles lost that race came back empty.
     */
    val previewExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    /**
     * What the last [providers] call read, for the previews to look things
     * up in. The full list is one large binder transaction; reading it again
     * for every tile was the other half of the overflow.
     */
    @Volatile
    private var cachedProviders: Map<ComponentName, AppWidgetProviderInfo> = emptyMap()

    private fun providerInfo(context: Context, component: ComponentName): AppWidgetProviderInfo? {
        cachedProviders[component]?.let { return it }
        // Not in the picker's list (yet) - asked once, and remembered.
        cachedProviders = manager(context).installedProviders.associateBy { it.provider }
        return cachedProviders[component]
    }

    /** Every widget installed for this user, with what the picker shows. */
    fun providers(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val density = context.resources.displayMetrics.density
        val installed = manager(context).installedProviders
        cachedProviders = installed.associateBy { it.provider }
        return installed.map { info ->
            val pkg = info.provider.packageName
            val appLabel = try {
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (_: Exception) {
                pkg
            }
            mapOf(
                "provider" to info.provider.flattenToString(),
                "package" to pkg,
                "label" to (info.loadLabel(pm) ?: appLabel),
                "appLabel" to appLabel,
                "height" to defaultHeightDp(info, density),
            )
        }
    }

    /**
     * How tall a new card starts out, in dp. The provider's minimum is what
     * the widget can live with; on Android 12+ it may also say how many grid
     * rows it would like, which is the better hint where it exists.
     */
    private fun defaultHeightDp(info: AppWidgetProviderInfo, density: Float): Double {
        var height = info.minHeight / density
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && info.targetCellHeight > 0) {
            height = maxOf(height, info.targetCellHeight * 88f - 16f)
        }
        return height.coerceIn(48f, 640f).toDouble()
    }

    /**
     * A small picture of the widget as PNG, for the picker. Called off the
     * main thread.
     *
     * Best first: the preview layout most widgets since Android 12 ship
     * instead of a picture, rendered the way the system's own picker does -
     * a miniature of the real thing. Then the old preview picture, then the
     * widget's icon, then its app's. Each step is tried on its own, so one
     * that throws still leaves the next.
     */
    fun preview(context: Context, provider: String): ByteArray? {
        val component = ComponentName.unflattenFromString(provider) ?: return null
        val info = providerInfo(context, component) ?: return null
        renderPreviewLayout(context, info)?.let { return it }
        val density = context.resources.displayMetrics.densityDpi
        val drawable = attempt { info.loadPreviewImage(context, density) }
            ?: attempt { info.loadIcon(context, density) }
            ?: attempt { context.packageManager.getApplicationIcon(component.packageName) }
            ?: return null
        return toPng(drawable, 360)
    }

    private fun <T> attempt(block: () -> T?): T? = try {
        block()
    } catch (_: Exception) {
        null
    }

    /**
     * Inflates the provider's preview layout at the size a new card would
     * get and draws it into a bitmap. Views belong on the main thread, so
     * the work is posted there and waited for - one tile at a time, which
     * the picker asks for only as tiles scroll into view.
     */
    private fun renderPreviewLayout(context: Context, info: AppWidgetProviderInfo): ByteArray? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || info.previewLayout == 0) {
            return null
        }
        val metrics = context.resources.displayMetrics
        val density = metrics.density
        var widthDp = info.minWidth / density
        if (info.targetCellWidth > 0) {
            widthDp = maxOf(widthDp, info.targetCellWidth * 80f - 16f)
        }
        widthDp = widthDp.coerceIn(120f, metrics.widthPixels / density)
        val heightDp = defaultHeightDp(info, density).toFloat()
        val w = (widthDp * density).toInt()
        val h = (heightDp * density).toInt()

        val latch = CountDownLatch(1)
        var bitmap: Bitmap? = null
        Handler(Looper.getMainLooper()).post {
            try {
                // The theme decides the dynamic colors a preview reads, and
                // without one it draws in the bare framework defaults.
                val themed = ContextThemeWrapper(
                    context,
                    android.R.style.Theme_DeviceDefault_DayNight,
                )
                val parent = FrameLayout(themed)
                val view = RemoteViews(info.provider.packageName, info.previewLayout)
                    .apply(themed, parent)
                parent.addView(view, FrameLayout.LayoutParams(w, h))
                parent.measure(
                    View.MeasureSpec.makeMeasureSpec(w, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY),
                )
                parent.layout(0, 0, w, h)
                bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also {
                    parent.draw(Canvas(it))
                }
            } catch (_: Exception) {
                // A layout this launcher cannot inflate; the picture is next.
            } finally {
                latch.countDown()
            }
        }
        if (!latch.await(3, TimeUnit.SECONDS)) return null
        val rendered = bitmap ?: return null
        return toPng(BitmapDrawable(context.resources, rendered), 360).also {
            rendered.recycle()
        }
    }

    private fun toPng(drawable: Drawable, maxSide: Int): ByteArray? {
        val w = drawable.intrinsicWidth.takeIf { it > 0 } ?: maxSide
        val h = drawable.intrinsicHeight.takeIf { it > 0 } ?: maxSide
        val scale = minOf(1f, maxSide.toFloat() / maxOf(w, h))
        val bw = maxOf(1, (w * scale).toInt())
        val bh = maxOf(1, (h * scale).toInt())
        return try {
            val bitmap = Bitmap.createBitmap(bw, bh, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, bw, bh)
            drawable.draw(Canvas(bitmap))
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                bitmap.recycle()
                out.toByteArray()
            }
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Allocates and binds an id for [provider], then runs its setup screen.
     * Answers the id once the widget is ready, or null when any step was
     * refused or cancelled.
     */
    fun create(activity: Activity, provider: String, result: MethodChannel.Result) {
        val component = ComponentName.unflattenFromString(provider)
        if (component == null) {
            result.success(null)
            return
        }
        // A stale request must not hang forever - it loses, the new one
        // takes over.
        pending?.let {
            host(activity).deleteAppWidgetId(it.id)
            it.result.success(null)
        }
        pending = null

        val id = host(activity).allocateAppWidgetId()
        val bound = try {
            manager(activity).bindAppWidgetIdIfAllowed(id, component)
        } catch (_: Exception) {
            false
        }
        if (bound) {
            configure(activity, id, result)
            return
        }
        pending = Pending(id, result)
        val intent = Intent(AppWidgetManager.ACTION_APPWIDGET_BIND).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_PROVIDER, component)
        }
        try {
            activity.startActivityForResult(intent, BIND_REQUEST_CODE)
        } catch (_: Exception) {
            finish(activity, null)
        }
    }

    private fun configure(activity: Activity, id: Int, result: MethodChannel.Result) {
        val info = manager(activity).getAppWidgetInfo(id)
        if (info == null) {
            host(activity).deleteAppWidgetId(id)
            result.success(null)
            return
        }
        val optional = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            (info.widgetFeatures and AppWidgetProviderInfo.WIDGET_FEATURE_CONFIGURATION_OPTIONAL) != 0
        if (info.configure == null || optional) {
            result.success(id)
            return
        }
        pending = Pending(id, result)
        try {
            host(activity).startAppWidgetConfigureActivityForResult(
                activity, id, 0, CONFIGURE_REQUEST_CODE, null,
            )
        } catch (_: Exception) {
            // A setup screen the launcher may not start (not exported, gone).
            // The widget is bound and usually works with its defaults, so
            // keep it rather than refusing over a screen nobody could open.
            pending = null
            result.success(id)
        }
    }

    /** Routed here from MainActivity.onActivityResult. */
    fun onActivityResult(activity: Activity, requestCode: Int, resultCode: Int): Boolean {
        val waiting = pending ?: return false
        when (requestCode) {
            BIND_REQUEST_CODE -> {
                pending = null
                if (resultCode == Activity.RESULT_OK) {
                    configure(activity, waiting.id, waiting.result)
                } else {
                    host(activity).deleteAppWidgetId(waiting.id)
                    waiting.result.success(null)
                }
            }
            CONFIGURE_REQUEST_CODE -> {
                finish(activity, if (resultCode == Activity.RESULT_OK) waiting.id else null)
            }
            else -> return false
        }
        return true
    }

    private fun finish(activity: Activity, id: Int?) {
        val waiting = pending ?: return
        pending = null
        if (id == null) host(activity).deleteAppWidgetId(waiting.id)
        waiting.result.success(id)
    }

    fun delete(context: Context, id: Int) {
        try {
            host(context).deleteAppWidgetId(id)
        } catch (_: Exception) {
            // Already gone.
        }
    }

    /**
     * Which provider [id] is bound to, or null when it is not bound to
     * anything any more - a restored backup from another phone, an
     * uninstalled app, a reinstall of this one.
     */
    fun providerOf(context: Context, id: Int): String? =
        manager(context).getAppWidgetInfo(id)?.provider?.flattenToString()

    class Factory(private val activity: Activity) :
        PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
            val id = ((args as? Map<*, *>)?.get("id") as? Number)?.toInt() ?: -1
            return WidgetView(activity, id)
        }
    }

    private class WidgetView(activity: Activity, id: Int) : PlatformView {
        private var hostView: AppWidgetHostView? = null

        // Tells the widget how much room it really got whenever the card
        // changes size, so it can switch to the layout that fits.
        private val container = object : FrameLayout(activity) {
            override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
                super.onSizeChanged(w, h, oldw, oldh)
                reportSize(w, h)
            }
        }

        init {
            val info = AppWidgetManager.getInstance(activity).getAppWidgetInfo(id)
            if (info != null) {
                try {
                    val view = host(activity).createView(activity, id, info)
                    container.addView(
                        view,
                        FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT,
                        ),
                    )
                    hostView = view
                } catch (_: Exception) {
                    // The provider's app crashed inflating it - an empty
                    // card is the most this can show.
                }
            }
        }

        private fun reportSize(w: Int, h: Int) {
            val view = hostView ?: return
            if (w <= 0 || h <= 0) return
            val density = container.resources.displayMetrics.density
            val wDp = w / density
            val hDp = h / density
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    view.updateAppWidgetSize(Bundle(), listOf(SizeF(wDp, hDp)))
                } else {
                    @Suppress("DEPRECATION")
                    view.updateAppWidgetSize(
                        null, wDp.toInt(), hDp.toInt(), wDp.toInt(), hDp.toInt(),
                    )
                }
            } catch (_: Exception) {
                // The widget is gone; nothing to resize.
            }
        }

        override fun getView() = container

        override fun dispose() {
            container.removeAllViews()
            hostView = null
        }
    }
}
