package com.nazzil.nazzil

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import java.io.File

object DownloadNotifier {
    const val CHANNEL = "nazzil_download"
    const val ID = 41
    const val ACTION_OPEN = "com.nazzil.app.OPEN_DOWNLOAD"
    const val EXTRA_OPEN_LIBRARY = "open_library"
    const val EXTRA_RESUME = "resume_download"
    const val EXTRA_CANCEL = "cancel_download"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                "Downloads",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                setShowBadge(false)
                enableVibration(false)
            },
        )
    }

    fun progressNotification(context: Context, title: String, percent: Int): Notification {
        ensureChannel(context)
        val shown = percent.coerceIn(0, 100)
        return NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Downloading…")
            .setContentText("$shown%  ·  $title")
            .setProgress(100, shown, shown <= 1)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(openApp(context, library = false))
            .addAction(
                android.R.drawable.ic_media_pause,
                "Pause",
                serviceAction(context, DownloadService.ACTION_PAUSE, 11),
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancel",
                serviceAction(context, DownloadService.ACTION_CANCEL, 12),
            )
            .build()
    }

    fun updateProgress(context: Context, title: String, percent: Int) {
        notify(context, progressNotification(context, title, percent))
    }

    fun paused(context: Context, title: String, percent: Int) {
        ensureChannel(context)
        val shown = percent.coerceIn(0, 100)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Paused")
            .setContentText("$shown%  ·  $title")
            .setProgress(100, shown, false)
            .setOngoing(false)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(openApp(context, library = true))
            .addAction(
                android.R.drawable.ic_media_play,
                "Resume",
                resumeApp(context),
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancel",
                openApp(context, library = true, cancel = true),
            )
            .build()
        notify(context, notification)
    }

    fun done(context: Context, title: String, path: String?) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Saved")
            .setContentText(title)
            .setAutoCancel(true)
            .setOngoing(false)
            .setProgress(0, 0, false)
            .setContentIntent(openFileOrApp(context, path, library = true))
            .build()
        notify(context, notification)
    }

    fun failed(context: Context, message: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Download failed")
            .setContentText(message)
            .setAutoCancel(true)
            .setOngoing(false)
            .setProgress(0, 0, false)
            .setContentIntent(openApp(context, library = true))
            .build()
        notify(context, notification)
    }

    fun cancel(context: Context) {
        NotificationManagerCompat.from(context).cancel(ID)
    }

    private fun serviceAction(context: Context, action: String, code: Int): PendingIntent {
        val intent = Intent(context, DownloadService::class.java).setAction(action)
        return PendingIntent.getService(
            context,
            code,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openApp(context: Context, library: Boolean, cancel: Boolean = false): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = if (cancel) DownloadService.ACTION_CANCEL else ACTION_OPEN
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_OPEN_LIBRARY, library)
            putExtra(EXTRA_CANCEL, cancel)
        }
        return PendingIntent.getActivity(
            context,
            when {
                cancel -> 14
                library -> 3
                else -> 1
            },
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun resumeApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = DownloadService.ACTION_RESUME
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_OPEN_LIBRARY, true)
            putExtra(EXTRA_RESUME, true)
        }
        return PendingIntent.getActivity(
            context,
            13,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openFileOrApp(context: Context, path: String?, library: Boolean): PendingIntent {
        val file = path?.let(::File)
        if (file != null && file.exists()) {
            val uri = runCatching {
                FileProvider.getUriForFile(context, "${context.packageName}.files", file)
            }.getOrNull()
            if (uri != null) {
                val view = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mimeOf(file))
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                val chooser = Intent.createChooser(view, "Open")
                chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                return PendingIntent.getActivity(
                    context,
                    4,
                    chooser,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
        }
        return openApp(context, library)
    }

    fun viewUri(context: Context, path: String): Uri? {
        val file = File(path)
        if (!file.exists()) return null
        return FileProvider.getUriForFile(context, "${context.packageName}.files", file)
    }

    fun mimeOf(file: File): String {
        return when (file.extension.lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "mp3" -> "audio/mpeg"
            "m4a", "aac" -> "audio/mp4"
            "mp4" -> "video/mp4"
            "webm" -> "video/webm"
            else -> "*/*"
        }
    }

    private fun notify(context: Context, notification: Notification) {
        runCatching { NotificationManagerCompat.from(context).notify(ID, notification) }
    }
}
