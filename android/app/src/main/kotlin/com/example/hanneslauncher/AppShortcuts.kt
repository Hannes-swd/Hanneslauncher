package com.example.hanneslauncher

import android.content.Context
import android.content.pm.LauncherApps
import android.content.pm.ShortcutInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Process
import java.io.File
import java.io.FileOutputStream

/**
 * The shortcuts an app publishes for itself - a chat in a messenger, "new
 * tab" in a browser, a playlist. Android hands them out through
 * [LauncherApps], but only to whichever app is currently the home app, which
 * is why every call here can legitimately come back empty: an installed but
 * not yet activated launcher is exactly the state this app spends its first
 * minutes in.
 *
 * Three kinds exist and this treats them as one list, in the order a user
 * reads them: the ones declared in the app's manifest (fixed, "New message"),
 * then the dynamic ones it publishes while running (the four most recent
 * chats), then anything only still alive because this launcher pinned it.
 * Android ranks each kind separately, so the rank is only ever compared
 * within its own kind.
 *
 * Pinning goes through Android rather than being a private list: a dynamic
 * shortcut drops off as soon as the app publishes a newer one, and a saved
 * chat would quietly stop working a day later. [pin] asks the system to keep
 * the named ones alive for this launcher, which is the whole difference
 * between a shortcut that survives and one that doesn't.
 */
object AppShortcuts {
    /** Where a rendered shortcut icon is cached. Cleared with the cache. */
    private const val ICON_DIR = "shortcut_icons"

    /** Only what a drawable with no size of its own is drawn at. */
    private const val FALLBACK_ICON_SIZE = 192

    /**
     * Whether shortcuts can be read at all: the API exists from 25 on, and
     * the permission to use it comes from being the home app.
     *
     * Deliberately one answer rather than two. The launcher already has a
     * screen that explains not being the default home app and offers to fix
     * it ([MainActivity.chooseDefaultLauncher]), so a second, subtly
     * different wording of the same problem would only compete with it.
     */
    fun available(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return false
        val launcherApps = launcherApps(context) ?: return false
        return try {
            launcherApps.hasShortcutHostPermission()
        } catch (_: Exception) {
            // Thrown while the user is still locked, among others. "No
            // shortcuts right now" is the honest answer either way.
            false
        }
    }

    /**
     * Every shortcut [pkg] currently offers, each already rendered to a PNG
     * so the Dart side only ever deals in file paths - the same shape
     * IconPacks.resolve answers in.
     *
     * Disabled ones are left out: Android refuses to start them, so a row
     * that cannot do anything would be worse than no row.
     */
    fun list(context: Context, pkg: String): List<Map<String, Any?>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return emptyList()
        val launcherApps = launcherApps(context) ?: return emptyList()
        val shortcuts = query(launcherApps, pkg) ?: return emptyList()

        val ordered = shortcuts
            .filter { it.isEnabled }
            .sortedWith(compareBy({ kindOrder(it) }, { it.rank }))

        return ordered.map { info ->
            mapOf(
                "id" to info.id,
                "package" to pkg,
                "label" to label(info),
                "iconPath" to renderIcon(context, launcherApps, info)?.absolutePath,
            )
        }
    }

    /**
     * Starts one shortcut. False when it is gone, disabled or the launcher
     * lost the host permission since the list was drawn - all three of which
     * a saved shortcut on the home screen can hit, and none of which should
     * look like a tap that simply did nothing.
     */
    fun launch(context: Context, pkg: String, id: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return false
        val launcherApps = launcherApps(context) ?: return false
        return try {
            launcherApps.startShortcut(pkg, id, null, null, Process.myUserHandle())
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Tells Android which of [pkg]'s shortcuts this launcher wants kept
     * alive. The list replaces whatever was pinned before, so the caller
     * passes everything it still holds for that package, not just the new
     * one - which is also why unpinning is the same call with one id fewer.
     */
    fun pin(context: Context, pkg: String, ids: List<String>): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return false
        val launcherApps = launcherApps(context) ?: return false
        return try {
            launcherApps.pinShortcuts(pkg, ids, Process.myUserHandle())
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * Re-renders one shortcut's icon, for a saved shortcut whose picture the
     * cache has since dropped. Null when the shortcut no longer exists.
     */
    fun icon(context: Context, pkg: String, id: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return null
        val launcherApps = launcherApps(context) ?: return null
        val info = query(launcherApps, pkg)?.firstOrNull { it.id == id } ?: return null
        return renderIcon(context, launcherApps, info)?.absolutePath
    }

    /**
     * The label a saved shortcut should carry now - apps do rename them (a
     * contact changes their name) - or null when it is gone.
     */
    fun label(context: Context, pkg: String, id: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return null
        val launcherApps = launcherApps(context) ?: return null
        val info = query(launcherApps, pkg)?.firstOrNull { it.id == id } ?: return null
        return label(info)
    }

    private fun launcherApps(context: Context): LauncherApps? {
        return context.getSystemService(Context.LAUNCHER_APPS_SERVICE) as? LauncherApps
    }

    /**
     * All three kinds in one query. Null rather than an empty list when the
     * call itself failed, so a missing permission is not confused with an
     * app that simply has no shortcuts.
     */
    private fun query(launcherApps: LauncherApps, pkg: String): List<ShortcutInfo>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return null
        val query = LauncherApps.ShortcutQuery()
            .setPackage(pkg)
            .setQueryFlags(
                LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST or
                    LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                    LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED,
            )
        return try {
            launcherApps.getShortcuts(query, Process.myUserHandle())
        } catch (_: Exception) {
            // SecurityException while not the home app, IllegalStateException
            // while the user is locked.
            null
        }
    }

    private fun kindOrder(info: ShortcutInfo): Int = when {
        info.isDeclaredInManifest -> 0
        info.isDynamic -> 1
        else -> 2
    }

    /**
     * The short label is what a launcher is meant to show; the long one is
     * the fallback, and the id is the last resort so a row is never blank.
     */
    private fun label(info: ShortcutInfo): String {
        val short = info.shortLabel?.toString()?.trim()
        if (!short.isNullOrEmpty()) return short
        val long = info.longLabel?.toString()?.trim()
        if (!long.isNullOrEmpty()) return long
        return info.id
    }

    /**
     * Writes the shortcut's icon out as a PNG and answers with the file.
     *
     * Rendered fresh every time rather than cached by id: these pictures are
     * contact photos and album covers, which change under a stable id, and a
     * handful of small bitmaps per long press is not worth a staleness bug.
     */
    private fun renderIcon(
        context: Context,
        launcherApps: LauncherApps,
        info: ShortcutInfo,
    ): File? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return null
        val density = context.resources.displayMetrics.densityDpi
        val drawable = try {
            launcherApps.getShortcutIconDrawable(info, density)
        } catch (_: Exception) {
            null
        } ?: return null

        val bitmap = toBitmap(drawable) ?: return null
        val dir = File(context.cacheDir, ICON_DIR)
        dir.mkdirs()
        val file = File(dir, "${safeName(info.`package`)}-${safeName(info.id)}.png")
        return if (writePng(bitmap, file)) file else null
    }

    /** Ids are free-form app strings, so they cannot go into a path as-is. */
    private fun safeName(raw: String): String =
        raw.replace(Regex("[^A-Za-z0-9._-]"), "_").take(64)

    private fun toBitmap(drawable: Drawable): Bitmap? {
        if (drawable is BitmapDrawable) {
            drawable.bitmap?.let { return it }
        }
        val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: FALLBACK_ICON_SIZE
        val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: FALLBACK_ICON_SIZE
        return try {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, width, height)
            drawable.draw(canvas)
            bitmap
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Through a temporary file, so a write interrupted halfway can never
     * leave a half-written PNG behind for the next run to hand out.
     */
    private fun writePng(bitmap: Bitmap, file: File): Boolean {
        val temp = File(file.parentFile, file.name + ".part")
        return try {
            FileOutputStream(temp).use {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
            }
            file.delete()
            temp.renameTo(file)
        } catch (_: Exception) {
            temp.delete()
            false
        }
    }
}
