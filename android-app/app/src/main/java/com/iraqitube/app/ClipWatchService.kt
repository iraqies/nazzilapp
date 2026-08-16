package com.iraqitube.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ClipboardManager
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class ClipWatchService : Service() {
    private val main = Handler(Looper.getMainLooper())
    private var listener: ClipboardManager.OnPrimaryClipChangedListener? = null
    private var keepView: View? = null
    private var lastTs = 0L
    private var busy = false

    private val poll = object : Runnable {
        override fun run() {
            checkClipboard("poll")
            main.postDelayed(this, 400)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        startQuiet()
        lastTs = ClipWatch.clipTimestamp(this)
        attachKeepWindow()
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
            main.post { checkClipboard("listener") }
        }
        listener = clipListener
        clipboard.addPrimaryClipChangedListener(clipListener)
        SamsungClip.listen(this) { main.post { checkClipboard("samsung") } }
        main.post(poll)
        ClipLog.write(this, "watching ts=$lastTs overlay=${Settings.canDrawOverlays(this)}")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startQuiet()
        if (!SettingsStore(this).watchClipboard) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (keepView == null) attachKeepWindow()
        return START_STICKY
    }

    override fun onDestroy() {
        main.removeCallbacks(poll)
        listener?.let { clipListener ->
            (getSystemService(CLIPBOARD_SERVICE) as ClipboardManager)
                .removePrimaryClipChangedListener(clipListener)
        }
        listener = null
        detachKeepWindow()
        super.onDestroy()
    }

    private fun checkClipboard(reason: String) {
        if (!SettingsStore(this).watchClipboard) return
        if (ClipWatch.appInFront) return
        val ts = ClipWatch.clipTimestamp(this)
        if (reason == "poll" && (ts == 0L || ts == lastTs)) return
        if (ts != 0L && ts == lastTs && reason != "listener") return
        if (ts != 0L) lastTs = ts
        if (busy) return
        busy = true
        val samsung = SamsungClip.readLatest(this)
        val normal = ClipWatch.readSupportedLink(this)
        ClipLog.write(this, "new clip via $reason ts=$ts samsung='$samsung' normal='$normal'")
        val link = samsung.ifBlank { normal }
        if (link.isNotBlank() && ClipWatch.shouldShow(this, link)) {
            OverlayPrompt.show(this, link)
        } else {
            ClipWatch.openCatcher(this)
        }
        main.postDelayed({ busy = false }, 800)
    }

    private fun attachKeepWindow() {
        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "no overlay permission")
            return
        }
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val view = View(this)
        val type = if (Build.VERSION.SDK_INT >= 26) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            1,
            1,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 0
            y = 0
            title = "nazzil-keep"
        }
        val added = runCatching { windowManager.addView(view, params) }
        if (added.isSuccess) {
            keepView = view
            Log.i(TAG, "keep window attached")
        } else {
            Log.e(TAG, "keep window failed", added.exceptionOrNull())
        }
    }

    private fun detachKeepWindow() {
        val view = keepView ?: return
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        if (view.isAttachedToWindow) runCatching { windowManager.removeView(view) }
        keepView = null
    }

    private fun startQuiet() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Nazzil", NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                    enableLights(false)
                    enableVibration(false)
                    lockscreenVisibility = Notification.VISIBILITY_SECRET
                },
            )
        }
        val notification = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(R.string.watch_clipboard))
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(
                this,
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    companion object {
        private const val TAG = "NazzilClip"
        private const val CHANNEL = "nazzil_clip"
        private const val NOTIF_ID = 17
    }
}
