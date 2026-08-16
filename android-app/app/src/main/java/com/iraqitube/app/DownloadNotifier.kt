package com.iraqitube.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object DownloadNotifier {
    const val CHANNEL = "nazzil_download"
    const val ID = 41
    const val ACTION_OPEN = "com.nazzil.app.OPEN_DOWNLOAD"
    const val EXTRA_FOCUS = "focus_download"
    const val EXTRA_DONE_ID = "done_id"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                context.getString(R.string.download),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setShowBadge(false)
                enableVibration(false)
            },
        )
    }

    fun progressNotification(context: Context, title: String, percent: Int): Notification {
        ensureChannel(context)
        return NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(context.getString(R.string.downloading))
            .setContentText("$percent%  ·  $title")
            .setProgress(100, percent.coerceIn(0, 100), false)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(openIntent(context, focus = true))
            .build()
    }

    fun updateProgress(context: Context, title: String, percent: Int) {
        notify(context, progressNotification(context, title, percent))
    }

    fun done(context: Context, item: SavedVideo) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(context.getString(R.string.downloaded))
            .setContentText(item.title)
            .setSubText(context.getString(R.string.download_ready))
            .setAutoCancel(true)
            .setOngoing(false)
            .setProgress(0, 0, false)
            .setContentIntent(openIntent(context, focus = false, doneId = item.id))
            .build()
        notify(context, notification)
    }

    fun failed(context: Context, message: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(context.getString(R.string.download_failed))
            .setContentText(message)
            .setAutoCancel(true)
            .setOngoing(false)
            .setProgress(0, 0, false)
            .setContentIntent(openIntent(context, focus = true))
            .build()
        notify(context, notification)
    }

    private fun openIntent(context: Context, focus: Boolean, doneId: String? = null): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_FOCUS, focus)
            if (!doneId.isNullOrBlank()) putExtra(EXTRA_DONE_ID, doneId)
        }
        return PendingIntent.getActivity(
            context,
            if (doneId.isNullOrBlank()) 1 else 2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun notify(context: Context, notification: Notification) {
        runCatching { NotificationManagerCompat.from(context).notify(ID, notification) }
    }
}
