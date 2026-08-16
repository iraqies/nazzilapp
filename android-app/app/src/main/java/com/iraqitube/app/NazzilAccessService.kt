package com.iraqitube.app

import android.accessibilityservice.AccessibilityService
import android.content.ClipboardManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class NazzilAccessService : AccessibilityService() {
    private val main = Handler(Looper.getMainLooper())
    private var listener: ClipboardManager.OnPrimaryClipChangedListener? = null
    private var lastTs = 0L
    private var lastUrl = ""
    private var lastAt = 0L

    private val poll = object : Runnable {
        override fun run() {
            onClip("poll")
            main.postDelayed(this, 500)
        }
    }

    override fun onServiceConnected() {
        lastTs = ClipWatch.clipTimestamp(this)
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
            main.post { onClip("listener") }
        }
        listener = clipListener
        clipboard.addPrimaryClipChangedListener(clipListener)
        main.post(poll)
        Log.e(TAG, "access connected overlay=${Settings.canDrawOverlays(this)}")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        main.removeCallbacks(poll)
        listener?.let { clipListener ->
            (getSystemService(CLIPBOARD_SERVICE) as ClipboardManager)
                .removePrimaryClipChangedListener(clipListener)
        }
        listener = null
        OverlayPrompt.hide(this)
        super.onDestroy()
    }

    private fun onClip(reason: String) {
        if (!SettingsStore(this).watchClipboard) return
        if (ClipWatch.appInFront) return
        val ts = ClipWatch.clipTimestamp(this)
        if (reason == "poll" && (ts == 0L || ts == lastTs)) return
        if (ts != 0L) lastTs = ts
        val link = ClipWatch.readSupportedLink(this)
        Log.e(TAG, "access $reason ts=$ts link='$link'")
        if (link.isBlank()) return
        if (!Settings.canDrawOverlays(this)) {
            ClipWatch.openCatcher(this)
            return
        }
        val now = System.currentTimeMillis()
        if (link == lastUrl && now - lastAt < 4_000) return
        if (!ClipWatch.shouldShow(this, link)) return
        lastUrl = link
        lastAt = now
        OverlayPrompt.show(this, link)
    }

    companion object {
        private const val TAG = "NazzilClip"
    }
}
