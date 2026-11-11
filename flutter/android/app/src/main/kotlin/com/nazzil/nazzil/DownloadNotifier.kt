package com.nazzil.nazzil

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.FileProvider
import java.io.File

object DownloadNotifier {
    const val CHANNEL = "nazzil_download"
    const val ID = 41

    /**
     * What a download ended on (saved, paused, failed) is a notification of its own. A service
     * that stops takes the one it holds away with it, so under [ID] the ending was gone a
     * moment after it was shown.
     */
    private const val ENDING_ID = 42
    const val ACTION_OPEN = "com.nazzil.app.OPEN_DOWNLOAD"
    const val EXTRA_OPEN_LIBRARY = "open_library"
    const val EXTRA_RESUME = "resume_download"
    const val EXTRA_CANCEL = "cancel_download"
    private const val EXTRA_IS_PAUSED = "nazzil.paused"

    private const val WORDS = "nazzil_words"

    // The app sends its words in its own language, which can differ from the phone's.
    // They are kept, because the service can start before the app has sent them again.
    fun setWords(context: Context, words: Map<*, *>?) {
        if (words == null) return
        val edit = context.getSharedPreferences(WORDS, Context.MODE_PRIVATE).edit()
        for ((key, value) in words) {
            if (key is String && value is String && value.isNotBlank()) edit.putString(key, value)
        }
        edit.apply()
        ensureChannel(context)
    }

    private fun word(context: Context, key: String, fallback: String): String =
        context.getSharedPreferences(WORDS, Context.MODE_PRIVATE).getString(key, null) ?: fallback

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                word(context, "channel", "Downloads"),
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
            .setContentTitle(word(context, "downloading", "Downloading…"))
            .setContentText("$shown%  ·  $title")
            .setProgress(100, shown, shown <= 1)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(openApp(context, library = false))
            .addAction(
                android.R.drawable.ic_media_pause,
                word(context, "pause", "Pause"),
                serviceAction(context, DownloadService.ACTION_PAUSE, 11),
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                word(context, "cancel", "Cancel"),
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
            .setContentTitle(word(context, "paused", "Paused"))
            .setContentText("$shown%  ·  $title")
            .setProgress(100, shown, false)
            .setOngoing(false)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(openApp(context, library = true))
            .addAction(
                android.R.drawable.ic_media_play,
                word(context, "resume", "Resume"),
                resumeApp(context),
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                word(context, "cancel", "Cancel"),
                openApp(context, library = true, cancel = true),
            )
            .addExtras(Bundle().apply { putBoolean(EXTRA_IS_PAUSED, true) })
            .build()
        ending(context, notification)
    }

    /**
     * Takes the notification of a paused download away, once nothing is paused any more:
     * its Resume would resume nothing. An ending that says something else is left.
     */
    fun clearPaused(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val paused = runCatching {
            manager.activeNotifications.any {
                it.id == ENDING_ID && it.notification.extras.getBoolean(EXTRA_IS_PAUSED)
            }
        }.getOrDefault(false)
        if (paused) clearEnding(context)
    }

    /** A download that starts or carries on makes the last ending old news. */
    fun clearEnding(context: Context) {
        runCatching { NotificationManagerCompat.from(context).cancel(ENDING_ID) }
    }

    fun done(context: Context, title: String, path: String?) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(word(context, "saved", "Saved"))
            .setContentText(title)
            .setAutoCancel(true)
            .setOngoing(false)
            .setProgress(0, 0, false)
            .setContentIntent(openFileOrApp(context, path, library = true))
            .build()
        ending(context, notification)
    }

    fun failed(context: Context, message: String) {
        ensureChannel(context)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(word(context, "failed", "Download failed"))
            .setContentText(message)
            .setAutoCancel(true)
            .setOngoing(false)
            .setProgress(0, 0, false)
            .setContentIntent(openApp(context, library = true))
            .build()
        ending(context, notification)
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
                val chooser = Intent.createChooser(view, word(context, "open", "Open"))
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

    private fun ending(context: Context, notification: Notification) {
        runCatching { NotificationManagerCompat.from(context).notify(ENDING_ID, notification) }
    }
}
