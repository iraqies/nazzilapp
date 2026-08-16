package com.iraqitube.app

import android.content.Context
import android.util.Log
import java.io.File

enum class MediaKind { VIDEO, AUDIO }

data class QualityOption(
    val id: String,
    val label: String,
    val ext: String,
    val height: Int?,
    val noWatermark: Boolean,
    val directUrl: String? = null,
    val kind: MediaKind = MediaKind.VIDEO,
)

data class VideoMeta(
    val id: String,
    val title: String,
    val author: String?,
    val thumbnail: String?,
    val duration: Long?,
    val webpageUrl: String,
    val platform: String,
    val options: List<QualityOption>,
)

object Downloader {
    fun platformOf(url: String): String {
        val host = url.lowercase()
        return when {
            "youtu" in host -> "YouTube"
            "tiktok" in host -> "TikTok"
            "instagram" in host || "instagr.am" in host || "ig.me" in host -> "Instagram"
            "facebook" in host || "fb.watch" in host || "fb.com" in host || "fb.me" in host -> "Facebook"
            else -> "Video"
        }
    }

    fun looksSupported(url: String): Boolean = platformOf(url) != "Video"

    fun fetch(url: String): VideoMeta {
        val resolved = LinkParser.resolve(url)
        return when (platformOf(resolved)) {
            "TikTok" -> fetchTikTok(resolved)
            "Instagram" -> fetchInstagram(resolved)
            "Facebook" -> fetchFacebook(resolved)
            "YouTube" -> fetchYouTube(resolved)
            else -> CobaltClient.fetch(resolved, "Video")
        }
    }

    fun shortMessage(error: Exception): String {
        val lines = error.message.orEmpty().lineSequence()
            .map { it.trim() }
            .filter { it.isNotBlank() && !it.startsWith("File \"") && !it.startsWith("Traceback") }
            .toList()
        val useful = lines.lastOrNull { it.contains("ERROR", ignoreCase = true) } ?: lines.lastOrNull()
        val text = useful
            ?.replace(Regex("(?i)^ERROR:\\s*"), "")
            .orEmpty()
        val lower = text.lowercase()
        val dump = lower.contains("[youtube]") ||
            "yt-dlp" in lower ||
            "player response" in lower ||
            "failed to extract" in lower ||
            "not a bot" in lower ||
            "sign in" in lower ||
            "cookies" in lower
        val looksUrl = text.startsWith("http") ||
            "://" in text && (
                "cdn" in lower ||
                    "fbcdn" in lower ||
                    "scontent" in lower ||
                    "instagram" in lower ||
                    "googlevideo" in lower
                )
        return when {
            dump -> "This video blocked the download. Try again."
            looksUrl || error is java.io.FileNotFoundException ->
                "Could not download this video. Try again."
            else -> text.take(120).ifBlank { "Could not load this link" }
        }
    }

    private fun fetchYouTube(url: String): VideoMeta {
        val watch = YouTubeClient.watchUrl(url)
        try {
            return YouTubeClient.fetch(watch)
        } catch (error: Exception) {
            Log.e("Nazzil", "youtube api failed", error)
        }
        return CobaltClient.fetch(watch, "YouTube")
    }

    private fun fetchTikTok(url: String): VideoMeta {
        try {
            return TikTokClient.fetch(url)
        } catch (error: Exception) {
            Log.e("Nazzil", "tiktok api failed", error)
        }
        return CobaltClient.fetch(url, "TikTok")
    }

    private fun fetchInstagram(url: String): VideoMeta {
        try {
            return InstagramDownloader.fetch(url)
        } catch (error: Exception) {
            Log.e("Nazzil", "instagram downloader failed", error)
        }
        try {
            val meta = SocialClient.fetchInstagram(url)
            return if (meta.options.any { it.kind == MediaKind.AUDIO }) meta
            else meta.copy(options = meta.options + audioChoice())
        } catch (error: Exception) {
            Log.e("Nazzil", "instagram embed failed", error)
        }
        return CobaltClient.fetch(url, "Instagram")
    }

    private fun fetchFacebook(url: String): VideoMeta {
        try {
            val meta = SocialClient.fetchFacebook(url)
            if (meta.options.any { it.kind == MediaKind.VIDEO }) {
                return meta.copy(options = meta.options + audioChoice())
            }
        } catch (error: Exception) {
            Log.e("Nazzil", "facebook page failed", error)
        }
        return CobaltClient.fetch(url, "Facebook")
    }

    fun download(
        context: Context,
        pageUrl: String,
        option: QualityOption,
        title: String,
        onProgress: (Float) -> Unit,
        thumbnail: String? = null,
        author: String? = null,
    ): File {
        val folder = File(context.getExternalFilesDir(null), "videos").apply { mkdirs() }
        val safe = title.replace(Regex("[\\\\/:*?\"<>|]"), "").take(60).ifBlank { "nazzil" }
        val ext = option.ext.ifBlank { "mp4" }
        val dest = File(folder, "$safe-${System.currentTimeMillis()}.$ext")
        val file = downloadFile(pageUrl, option, dest, onProgress)
        if (option.kind != MediaKind.AUDIO) return file
        onProgress(0.94f)
        return AudioCover.apply(context, file, thumbnail, title, author, pageUrl)
    }

    private fun downloadFile(
        pageUrl: String,
        option: QualityOption,
        dest: File,
        onProgress: (Float) -> Unit,
    ): File {
        val platform = platformOf(pageUrl)
        if (platform == "YouTube") {
            return downloadDirect(pageUrl, option, dest, onProgress) { YouTubeClient.fetch(YouTubeClient.watchUrl(pageUrl)) }
        }
        if (platform == "TikTok") {
            return try {
                TikTokClient.download(pageUrl, option, dest, onProgress)
            } catch (error: Exception) {
                Log.e("Nazzil", "tiktok download failed", error)
                downloadDirect(pageUrl, option, dest, onProgress) { TikTokClient.fetch(pageUrl) }
            }
        }
        if (platform == "Instagram") {
            return try {
                InstagramDownloader.download(option, dest, onProgress)
            } catch (error: Exception) {
                Log.e("Nazzil", "instagram download failed", error)
                downloadDirect(pageUrl, option, dest, onProgress) { InstagramDownloader.fetch(pageUrl) }
            }
        }
        return downloadDirect(pageUrl, option, dest, onProgress) { fetch(pageUrl) }
    }

    private fun downloadDirect(
        pageUrl: String,
        option: QualityOption,
        dest: File,
        onProgress: (Float) -> Unit,
        refresh: () -> VideoMeta,
    ): File {
        if (option.directUrl != null) {
            try {
                return SocialClient.download(option, dest, onProgress)
            } catch (error: Exception) {
                Log.e("Nazzil", "direct download failed", error)
            }
        }
        val fresh = refresh()
        val match = fresh.options.firstOrNull {
            it.kind == option.kind && it.directUrl != null &&
                (it.label == option.label || it.id == option.id)
        } ?: fresh.options.firstOrNull { it.kind == option.kind && it.directUrl != null }
            ?: throw IllegalStateException("Could not download this video. Try again.")
        return SocialClient.download(match, dest, onProgress)
    }

    private fun audioChoice() = QualityOption(
        id = "bestaudio/ba",
        label = "Audio",
        ext = "m4a",
        height = null,
        noWatermark = true,
        kind = MediaKind.AUDIO,
    )
}
