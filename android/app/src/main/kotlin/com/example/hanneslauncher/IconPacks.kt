package com.example.hanneslauncher

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Resources
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Xml
import org.xmlpull.v1.XmlPullParser
import java.io.File
import java.io.FileOutputStream

/**
 * Reads the icon packs installed on the phone and turns them into plain PNG
 * files the Flutter side can draw with `Image.file`.
 *
 * An icon pack is an ordinary app that ships a drawing per app plus an
 * `appfilter.xml` saying which drawing belongs to which component. There is
 * no Android API for that - every launcher reads the file itself - so this
 * does the same: find the packs, parse the file, render the drawable.
 *
 * Nothing here touches the apps themselves. The rendered icons are written
 * into this app's own cache directory, so clearing the cache (or switching
 * the pack off) simply brings the original icons back.
 */
object IconPacks {
    /**
     * How a pack announces itself. There is no standard for this: each
     * launcher invented its own declaration and pack authors add the ones
     * they care about, so a pack is recognised if it carries any of these -
     * which in practice is nearly all of them, since a pack that named none
     * would be invisible to every launcher, not just this one.
     *
     * Shown verbatim in the icon settings screen, so a pack that isn't
     * picked up can be checked against the list rather than guessed at.
     *
     * Every entry needs a matching pair of `<queries>` entries in
     * AndroidManifest.xml, otherwise Android 11+ hides the pack from
     * [installed] without an error. `test/icon_pack_queries_test.dart` is
     * what keeps the two in step.
     */
    val supportedActions = listOf(
        "org.adw.launcher.THEMES",
        "com.novalauncher.THEME",
        "com.teslacoilsw.launcher.THEME",
        "com.anddoes.launcher.THEME",
        "com.fede.launcher.THEME_ICONPACK",
        "com.gau.go.launcherex.theme",
        "com.dlto.atom.launcher.THEME",
        "ch.deletescape.lawnchair.ICONPACK",
        "net.oneplus.launcher.icons.ICONPACK",
        "com.sonymobile.home.ICON_PACK",
    )

    /** Where the rendered icons live, under this app's cache directory. */
    private const val CACHE_ROOT = "icon_packs"

    /**
     * Fallback edge length for an icon that does not say how big it is.
     * Between a phone's launcher density buckets - big enough not to blur on
     * a large icon setting, small enough that a few hundred of them stay a
     * few megabytes of cache.
     */
    private const val DEFAULT_SIZE = 192

    /** Every installed pack as `{package, label}`, sorted by label. */
    fun installed(context: Context): List<Map<String, String>> {
        val pm = context.packageManager
        val found = LinkedHashMap<String, String>()
        for (action in supportedActions) {
            // Two spellings of the same declaration: most packs put the name
            // on the action, some hang it off MAIN as a category.
            collect(pm, Intent(action), found)
            collect(pm, Intent(Intent.ACTION_MAIN).addCategory(action), found)
        }
        return found.entries
            .sortedBy { it.value.lowercase() }
            .map { mapOf("package" to it.key, "label" to it.value) }
    }

    private fun collect(
        pm: PackageManager,
        intent: Intent,
        into: MutableMap<String, String>,
    ) {
        val matches = try {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        } catch (_: Exception) {
            return
        }
        for (info in matches) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (into.containsKey(pkg)) continue
            into[pkg] = try {
                pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
            } catch (_: Exception) {
                pkg
            }
        }
    }

    /**
     * Renders [pack]'s icon for each of [packages] and answers with the file
     * each one landed in.
     *
     * A package is simply left out when the pack has nothing for it and no
     * frame to build one out of - the caller then keeps the app's own icon,
     * which is far better than a hole in the list. Packs cover a few hundred
     * popular apps at most, so that is the normal case, not the exception.
     *
     * Slow enough on a first run (a few hundred PNGs) to belong on a
     * background thread; every later run finds the files already there.
     */
    fun resolve(
        context: Context,
        pack: String,
        packages: List<String>,
    ): Map<String, String> {
        val pm = context.packageManager
        val res = try {
            pm.getResourcesForApplication(pack)
        } catch (_: Exception) {
            // Pack uninstalled since it was picked.
            return emptyMap()
        }

        val filter = readAppFilter(res, pack)
        val dir = File(context.cacheDir, CACHE_ROOT + "/" + pack + "-" + version(pm, pack))
        dir.mkdirs()
        dropOtherCaches(context, dir)

        val out = LinkedHashMap<String, String>()
        for (pkg in packages) {
            val file = File(dir, "$pkg.png")
            // Already rendered: the directory name carries the pack and its
            // version, so what is in there can only be this pack's answer.
            if (file.isFile && file.length() > 0) {
                out[pkg] = file.absolutePath
                continue
            }
            val bitmap = render(pm, res, pack, filter, pkg) ?: continue
            if (writePng(bitmap, file)) out[pkg] = file.absolutePath
        }
        return out
    }

    private fun render(
        pm: PackageManager,
        res: Resources,
        pack: String,
        filter: AppFilter,
        pkg: String,
    ): Bitmap? {
        val themed = filter.drawableFor(pm, pkg)
        if (themed != null) {
            val drawable = loadDrawable(res, pack, themed)
            if (drawable != null) return toBitmap(drawable, DEFAULT_SIZE)
        }
        // Not in the pack: dress the app's own icon in the pack's frame, so
        // the odd app out still belongs to the set instead of sitting in its
        // own square. A pack without a frame answers null and the app keeps
        // its icon untouched.
        val original = try {
            pm.getApplicationIcon(pkg)
        } catch (_: Exception) {
            return null
        }
        return dressed(res, pack, filter, original, pkg)
    }

    /**
     * The pack's own recipe for an app it does not know: draw its background
     * plate, put the app's icon on top shrunk by the pack's scale factor,
     * cut that to the pack's silhouette, and lay the pack's gloss over the
     * result. Every piece is optional; with none of them there is nothing to
     * do and the original icon stands.
     */
    private fun dressed(
        res: Resources,
        pack: String,
        filter: AppFilter,
        original: Drawable,
        pkg: String,
    ): Bitmap? {
        val back = filter.backFor(pkg)?.let { loadBitmap(res, pack, it) }
        val mask = filter.mask?.let { loadBitmap(res, pack, it) }
        val upon = filter.upon?.let { loadBitmap(res, pack, it) }
        if (back == null && mask == null && upon == null) return null

        val size = back?.width ?: mask?.width ?: upon?.width ?: DEFAULT_SIZE
        val icon = toBitmap(original, size) ?: return null

        val result = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val full = Rect(0, 0, size, size)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

        if (back != null) canvas.drawBitmap(back, null, full, paint)

        val scaled = (size * filter.scale).toInt().coerceIn(1, size)
        val inset = (size - scaled) / 2
        val iconRect = Rect(inset, inset, inset + scaled, inset + scaled)

        if (mask == null) {
            canvas.drawBitmap(icon, null, iconRect, paint)
        } else {
            // The icon is cut on a layer of its own: cutting it straight onto
            // the canvas would take the background plate away with it.
            val layer = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val layerCanvas = Canvas(layer)
            layerCanvas.drawBitmap(icon, null, iconRect, paint)
            val cut = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            cut.xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_OUT)
            layerCanvas.drawBitmap(mask, null, full, cut)
            canvas.drawBitmap(layer, 0f, 0f, paint)
        }

        if (upon != null) canvas.drawBitmap(upon, null, full, paint)
        return result
    }

    // --- appfilter.xml -----------------------------------------------------

    /**
     * What `appfilter.xml` says: which drawing belongs to which component,
     * plus the frame to build one out of for an app the pack never heard of.
     */
    private class AppFilter(
        val byComponent: Map<String, String>,
        val byPackage: Map<String, String>,
        val backs: List<String>,
        val mask: String?,
        val upon: String?,
        val scale: Float,
    ) {
        /**
         * The pack's drawing for [pkg], found by the app's launcher
         * component. Packs are written against a component name and apps
         * rename theirs between releases, so a package that does not match
         * exactly falls back to any entry for the same package - an outdated
         * pack still dressing the app is the whole point of the pack.
         */
        fun drawableFor(pm: PackageManager, pkg: String): String? {
            val component = try {
                pm.getLaunchIntentForPackage(pkg)?.component
            } catch (_: Exception) {
                null
            }
            if (component != null) {
                val key = component.packageName + "/" + component.className
                byComponent[key]?.let { return it }
            }
            return byPackage[pkg]
        }

        /**
         * Which background plate this app gets when a pack ships several.
         * Chosen from the package name rather than at random, so an app keeps
         * the same plate on every redraw and across restarts.
         */
        fun backFor(pkg: String): String? {
            if (backs.isEmpty()) return null
            val index = (pkg.hashCode().toLong() and 0xffffffffL) % backs.size
            return backs[index.toInt()]
        }
    }

    private fun readAppFilter(res: Resources, pack: String): AppFilter {
        val byComponent = LinkedHashMap<String, String>()
        val byPackage = LinkedHashMap<String, String>()
        val backs = mutableListOf<String>()
        var mask: String? = null
        var upon: String? = null
        var scale = 1f

        val parser = openAppFilter(res, pack)
        if (parser != null) {
            try {
                var event = parser.eventType
                while (event != XmlPullParser.END_DOCUMENT) {
                    if (event == XmlPullParser.START_TAG) {
                        when (parser.name) {
                            "item" -> {
                                val component =
                                    parser.getAttributeValue(null, "component")
                                val drawable =
                                    parser.getAttributeValue(null, "drawable")
                                val key = if (component == null) {
                                    null
                                } else {
                                    componentKey(component)
                                }
                                if (key != null && !drawable.isNullOrEmpty()) {
                                    byComponent.putIfAbsent(key, drawable)
                                    byPackage.putIfAbsent(
                                        key.substringBefore('/'),
                                        drawable,
                                    )
                                }
                            }
                            "iconback" -> backs += images(parser)
                            "iconmask" -> mask = images(parser).firstOrNull() ?: mask
                            "iconupon" -> upon = images(parser).firstOrNull() ?: upon
                            "scale" -> {
                                val factor = parser
                                    .getAttributeValue(null, "factor")
                                    ?.toFloatOrNull()
                                // Nonsense factors (zero, negative, a pack
                                // meaning percent) would erase the icon.
                                if (factor != null && factor > 0f && factor <= 2f) {
                                    scale = factor
                                }
                            }
                        }
                    }
                    event = parser.next()
                }
            } catch (_: Exception) {
                // A truncated or malformed file: keep whatever was read up to
                // that point rather than dropping the whole pack.
            }
        }

        return AppFilter(byComponent, byPackage, backs, mask, upon, scale)
    }

    /**
     * `appfilter.xml` sits in the pack's assets in nearly every pack, and in
     * the resource table in the rest.
     */
    private fun openAppFilter(res: Resources, pack: String): XmlPullParser? {
        try {
            val text = res.assets.open("appfilter.xml").use { it.readBytes() }
            val parser = Xml.newPullParser()
            parser.setInput(text.inputStream(), null)
            return parser
        } catch (_: Exception) {
            // Not in the assets - try the resource table below.
        }
        return try {
            val id = res.getIdentifier("appfilter", "xml", pack)
            if (id == 0) null else res.getXml(id)
        } catch (_: Exception) {
            null
        }
    }

    /** `ComponentInfo{pkg/cls}` to `pkg/cls`; anything else is not one. */
    private fun componentKey(raw: String): String? {
        val inner = raw.substringAfter("ComponentInfo{", "").substringBefore('}')
        if (inner.isEmpty() || !inner.contains('/')) return null
        return inner
    }

    /** `img`, `img1`, `img2`, ... on one tag, in order, skipping the gaps. */
    private fun images(parser: XmlPullParser): List<String> {
        val out = mutableListOf<String>()
        for (i in 0 until parser.attributeCount) {
            if (!parser.getAttributeName(i).startsWith("img")) continue
            val value = parser.getAttributeValue(i)
            if (!value.isNullOrEmpty()) out += value
        }
        return out
    }

    // --- bitmaps -----------------------------------------------------------

    private fun loadDrawable(res: Resources, pack: String, name: String): Drawable? {
        return try {
            val id = res.getIdentifier(name, "drawable", pack)
            if (id == 0) {
                null
            } else {
                @Suppress("DEPRECATION")
                res.getDrawable(id, null)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun loadBitmap(res: Resources, pack: String, name: String): Bitmap? {
        val drawable = loadDrawable(res, pack, name) ?: return null
        return toBitmap(drawable, DEFAULT_SIZE)
    }

    private fun toBitmap(drawable: Drawable, fallbackSize: Int): Bitmap? {
        if (drawable is BitmapDrawable) {
            drawable.bitmap?.let { return it }
        }
        val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: fallbackSize
        val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: fallbackSize
        return try {
            val out = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, width, height)
            drawable.draw(Canvas(out))
            out
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Written under a temporary name and moved into place, so a run killed
     * halfway can never leave a half-written PNG that the next run would take
     * for a finished icon.
     */
    private fun writePng(bitmap: Bitmap, file: File): Boolean {
        return try {
            val temp = File(file.parentFile, file.name + ".part")
            FileOutputStream(temp).use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            }
            if (file.exists()) file.delete()
            temp.renameTo(file)
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Throws away every other pack's rendered icons. A pack that is switched
     * away from (or updated) leaves a few hundred PNGs behind, and they would
     * otherwise sit in the cache until Android ran short of space.
     */
    private fun dropOtherCaches(context: Context, keep: File) {
        val children = File(context.cacheDir, CACHE_ROOT).listFiles() ?: return
        for (child in children) {
            if (child.absolutePath == keep.absolutePath) continue
            child.deleteRecursively()
        }
    }

    private fun version(pm: PackageManager, pack: String): Long {
        return try {
            val info = pm.getPackageInfo(pack, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        } catch (_: Exception) {
            0L
        }
    }
}
