package com.nazzil.nazzil

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

class DownloadService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PAUSE -> {
                HostBridge.emit("pause")
                return START_NOT_STICKY
            }
            ACTION_RESUME -> {
                startForegroundNow("Nazzil", 1)
                HostBridge.emit("resume")
                return START_NOT_STICKY
            }
            ACTION_CANCEL -> {
                startForegroundNow("Nazzil", 1)
                HostBridge.emit("cancel")
                return START_NOT_STICKY
            }
        }
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Nazzil"
        val percent = intent?.getIntExtra(EXTRA_PERCENT, 1) ?: 1
        startForegroundNow(title, percent)
        acquireWakeLock()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
        releaseWakeLock()
        super.onDestroy()
    }

    private fun startForegroundNow(title: String, percent: Int) {
        DownloadNotifier.ensureChannel(this)
        val notification = DownloadNotifier.progressNotification(this, title, percent)
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(
                this,
                DownloadNotifier.ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(DownloadNotifier.ID, notification)
        }
        acquireWakeLock()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val manager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = manager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "nazzil:download").apply {
            setReferenceCounted(false)
            acquire(3 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        runCatching { if (wakeLock?.isHeld == true) wakeLock?.release() }
        wakeLock = null
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_PERCENT = "percent"
        const val ACTION_PAUSE = "com.nazzil.app.PAUSE"
        const val ACTION_RESUME = "com.nazzil.app.RESUME"
        const val ACTION_CANCEL = "com.nazzil.app.CANCEL"

        fun start(context: Context, title: String = "Nazzil", percent: Int = 1) {
            val intent = Intent(context.applicationContext, DownloadService::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_PERCENT, percent)
            }
            ContextCompat.startForegroundService(context.applicationContext, intent)
        }

        fun stop(context: Context) {
            context.applicationContext.stopService(
                Intent(context.applicationContext, DownloadService::class.java),
            )
        }
    }
}
