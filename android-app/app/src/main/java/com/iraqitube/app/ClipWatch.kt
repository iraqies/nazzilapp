package com.iraqitube.app

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat

object ClipWatch {
    @Volatile
    var appInFront: Boolean = false

    @Volatile
    private var lastShownUrl: String = ""

    @Volatile
    private var lastShownAt: Long = 0

    fun setEnabled(context: Context, enabled: Boolean) {
        val app = context.applicationContext
        val intent = Intent(app, ClipWatchService::class.java)
        if (!enabled) {
            OverlayPrompt.hide(app)
            app.stopService(intent)
            return
        }
        ContextCompat.startForegroundService(app, intent)
    }

    fun sync(context: Context) {
        val app = context.applicationContext
        if (SettingsStore(app).watchClipboard) {
            ContextCompat.startForegroundService(app, Intent(app, ClipWatchService::class.java))
        } else {
            OverlayPrompt.hide(app)
            app.stopService(Intent(app, ClipWatchService::class.java))
        }
    }

    fun clipTimestamp(context: Context): Long {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        return try {
            clipboard.primaryClipDescription?.timestamp ?: 0L
        } catch (_: Exception) {
            0L
        }
    }

    fun readSupportedLink(context: Context): String {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = try {
            clipboard.primaryClip
        } catch (_: Exception) {
            null
        } ?: return ""
        for (index in 0 until clip.itemCount) {
            val item = clip.getItemAt(index)
            val texts = listOfNotNull(
                item.text?.toString(),
                item.coerceToText(context)?.toString(),
                item.htmlText,
                item.uri?.toString(),
            )
            for (raw in texts) {
                val link = LinkParser.extract(raw)
                if (link.isNotBlank() && Downloader.looksSupported(link)) return link
            }
        }
        return ""
    }

    fun shouldShow(context: Context, link: String): Boolean {
        if (link.isBlank()) return false
        val now = System.currentTimeMillis()
        if (link == lastShownUrl && now - lastShownAt < 4_000) return false
        lastShownUrl = link
        lastShownAt = now
        SettingsStore(context).lastClipUrl = link
        return true
    }

    fun openCatcher(context: Context) {
        val app = context.applicationContext
        val intent = Intent(app, ClipCatchActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_NO_ANIMATION or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                Intent.FLAG_ACTIVITY_CLEAR_TOP,
        )
        val started = runCatching {
            if (Build.VERSION.SDK_INT >= 34) {
                val options = android.app.ActivityOptions.makeBasic()
                options.pendingIntentBackgroundActivityStartMode =
                    android.app.ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                app.startActivity(intent, options.toBundle())
            } else {
                app.startActivity(intent)
            }
        }
        if (started.isFailure) {
            ClipLog.write(app, "catcher failed ${started.exceptionOrNull()?.message}")
            runCatching { app.startActivity(intent) }
        } else {
            ClipLog.write(app, "catcher started")
        }
    }
}
