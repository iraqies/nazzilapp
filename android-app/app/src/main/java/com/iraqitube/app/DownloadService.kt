package com.iraqitube.app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat

class DownloadService : Service() {
    @Volatile
    private var lastNotifyAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || DownloadBus.busy.value) {
            if (intent == null) stopSelf()
            return START_NOT_STICKY
        }
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank { getString(R.string.app_name) }
        val pageUrl = intent.getStringExtra(EXTRA_URL).orEmpty()
        val option = optionFrom(intent)
        if (pageUrl.isBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }
        DownloadNotifier.ensureChannel(this)
        val start = DownloadNotifier.progressNotification(this, title, 2)
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(
                this,
                DownloadNotifier.ID,
                start,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(DownloadNotifier.ID, start)
        }
        Thread {
            try {
                DownloadBus.begin(title)
                val file = Downloader.download(
                    this,
                    pageUrl,
                    option,
                    title,
                    { value ->
                        val progress = value.coerceAtMost(0.9f)
                        DownloadBus.progress(progress)
                        maybeNotify(title, (progress * 100).toInt())
                    },
                    intent.getStringExtra(EXTRA_THUMB),
                    intent.getStringExtra(EXTRA_AUTHOR),
                )
                DownloadBus.progress(0.92f)
                DownloadNotifier.updateProgress(this, title, 92)
                val gallery = GallerySaver.save(this, file, title, intent.getStringExtra(EXTRA_AUTHOR))
                val item = SavedVideo(
                    id = "${intent.getStringExtra(EXTRA_VIDEO_ID) ?: System.currentTimeMillis()}-${file.name}",
                    title = title,
                    author = intent.getStringExtra(EXTRA_AUTHOR),
                    platform = intent.getStringExtra(EXTRA_PLATFORM) ?: Downloader.platformOf(pageUrl),
                    path = file.absolutePath,
                    galleryUri = gallery.toString(),
                    quality = option.label,
                    createdAt = System.currentTimeMillis(),
                    thumbnail = intent.getStringExtra(EXTRA_THUMB),
                )
                LibraryStore(this).add(item)
                Analytics.videoSaved(item.platform, option.label)
                DownloadBus.finish(item)
                DownloadNotifier.done(this, item)
            } catch (error: Exception) {
                val message = Downloader.shortMessage(error)
                DownloadBus.fail(message)
                DownloadNotifier.failed(this, message)
            } finally {
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_DETACH)
                stopSelf()
            }
        }.start()
        return START_NOT_STICKY
    }

    private fun maybeNotify(title: String, percent: Int) {
        val now = System.currentTimeMillis()
        if (now - lastNotifyAt < 350) return
        lastNotifyAt = now
        DownloadNotifier.updateProgress(this, title, percent)
    }

    companion object {
        private const val EXTRA_URL = "url"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_AUTHOR = "author"
        private const val EXTRA_THUMB = "thumb"
        private const val EXTRA_PLATFORM = "platform"
        private const val EXTRA_VIDEO_ID = "video_id"
        private const val EXTRA_OPTION_ID = "option_id"
        private const val EXTRA_OPTION_LABEL = "option_label"
        private const val EXTRA_OPTION_EXT = "option_ext"
        private const val EXTRA_OPTION_HEIGHT = "option_height"
        private const val EXTRA_OPTION_NO_WM = "option_no_wm"
        private const val EXTRA_OPTION_URL = "option_url"
        private const val EXTRA_OPTION_KIND = "option_kind"

        fun start(context: Context, meta: VideoMeta, option: QualityOption) {
            val app = context.applicationContext
            val intent = Intent(app, DownloadService::class.java)
                .putExtra(EXTRA_URL, meta.webpageUrl)
                .putExtra(EXTRA_TITLE, meta.title)
                .putExtra(EXTRA_AUTHOR, meta.author)
                .putExtra(EXTRA_THUMB, meta.thumbnail)
                .putExtra(EXTRA_PLATFORM, meta.platform)
                .putExtra(EXTRA_VIDEO_ID, meta.id)
                .putExtra(EXTRA_OPTION_ID, option.id)
                .putExtra(EXTRA_OPTION_LABEL, option.label)
                .putExtra(EXTRA_OPTION_EXT, option.ext)
                .putExtra(EXTRA_OPTION_HEIGHT, option.height ?: -1)
                .putExtra(EXTRA_OPTION_NO_WM, option.noWatermark)
                .putExtra(EXTRA_OPTION_URL, option.directUrl)
                .putExtra(EXTRA_OPTION_KIND, option.kind.name)
            ContextCompat.startForegroundService(app, intent)
        }

        private fun optionFrom(intent: Intent): QualityOption {
            val height = intent.getIntExtra(EXTRA_OPTION_HEIGHT, -1)
            return QualityOption(
                id = intent.getStringExtra(EXTRA_OPTION_ID) ?: "b",
                label = intent.getStringExtra(EXTRA_OPTION_LABEL) ?: "HD",
                ext = intent.getStringExtra(EXTRA_OPTION_EXT) ?: "mp4",
                height = height.takeIf { it > 0 },
                noWatermark = intent.getBooleanExtra(EXTRA_OPTION_NO_WM, true),
                directUrl = intent.getStringExtra(EXTRA_OPTION_URL),
                kind = runCatching {
                    MediaKind.valueOf(intent.getStringExtra(EXTRA_OPTION_KIND) ?: "VIDEO")
                }.getOrDefault(MediaKind.VIDEO),
            )
        }
    }
}
