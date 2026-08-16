package com.iraqitube.app

import android.content.Context
import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.mapper.VideoFormat
import com.yausername.youtubedl_android.mapper.VideoInfo
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
    private const val TIKTOK_NO_WM =
        "play_addr_h264/play_addr/play/best[format_note!*=watermarked]/best"

    private val tiktokHosts = listOf(
        "api16-normal-c-useast1a.tiktokv.com",
        "api16-normal-c-useast2a.tiktokv.com",
        "api19-normal-c-useast1a.tiktokv.com",
    )

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
            else -> threeChoices(fromInfo(fetchDefault(resolved), resolved))
        }
    }

    fun shortMessage(error: Exception): String {
        val lines = error.message.orEmpty().lineSequence()
            .map { it.trim() }
            .filter { it.isNotBlank() && !it.startsWith("File \"") && !it.startsWith("Traceback") }
            .toList()
        val useful = lines.lastOrNull { it.contains("ERROR", ignoreCase = true) } ?: lines.lastOrNull()
        return useful
            ?.replace(Regex("(?i)^ERROR:\\s*"), "")
            ?.take(120)
            ?.ifBlank { null }
            ?: "Could not load this link"
    }

    private fun fetchTikTok(url: String): VideoMeta {
        val errors = mutableListOf<String>()
        try {
            return TikTokClient.fetch(url)
        } catch (error: Exception) {
            error.message?.let { errors += it }
        }
        try {
            return fetchTikTokYtdlp(url)
        } catch (error: Exception) {
            error.message?.let { errors += it }
        }
        throw IllegalStateException(
            errors.firstOrNull { it.isNotBlank() } ?: "Could not read this TikTok link",
        )
    }

    fun download(
        context: Context,
        pageUrl: String,
        option: QualityOption,
        title: String,
        onProgress: (Float) -> Unit,
    ): File {
        val folder = File(context.getExternalFilesDir(null), "videos").apply { mkdirs() }
        val safe = title.replace(Regex("[\\\\/:*?\"<>|]"), "").take(60).ifBlank { "iraqi-tube" }
        val ext = option.ext.ifBlank { "mp4" }
        val dest = File(folder, "$safe-${System.currentTimeMillis()}.$ext")

        val platform = platformOf(pageUrl)
        if (option.directUrl != null && platform != "TikTok") {
            return SocialClient.download(option, dest, onProgress)
        }
        if (platform == "TikTok") {
            if (option.directUrl != null || option.id.startsWith("tikwm-")) {
                return TikTokClient.download(pageUrl, option, dest, onProgress)
            }
            return try {
                runYtdlp(pageUrl, option.id, dest, platform, onProgress)
            } catch (_: Exception) {
                val fresh = TikTokClient.fetch(pageUrl)
                val fallback = fresh.options.firstOrNull { it.noWatermark && it.directUrl != null }
                    ?: throw IllegalStateException("Could not download this TikTok")
                TikTokClient.download(pageUrl, fallback, dest, onProgress)
            }
        }

        return try {
            runYtdlp(pageUrl, option.id, dest, platform, onProgress)
        } catch (error: Exception) {
            if ("+" in option.id || "*" in option.id) {
                runYtdlp(pageUrl, "b", dest, platform, onProgress)
            } else {
                throw error
            }
        }
    }

    private fun fetchTikTokYtdlp(url: String): VideoMeta {
        var last: Exception? = null
        for (host in tiktokHosts) {
            try {
                val request = YoutubeDLRequest(url)
                applyCommon(request)
                applyTikTok(request, host)
                return threeChoices(fromTikTokInfo(YoutubeDL.getInstance().getInfo(request), url))
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Could not read this TikTok link")
    }

    private fun fetchInstagram(url: String): VideoMeta {
        try {
            val meta = SocialClient.fetchInstagram(url)
            return meta.copy(options = meta.options + audioChoice())
        } catch (error: Exception) {
            Log.e("IraqiTube", "instagram embed failed", error)
        }
        return try {
            threeChoices(fromInfo(fetchSocial(url, ::applyInstagram), url))
        } catch (error: Exception) {
            Log.e("IraqiTube", "instagram ytdlp failed", error)
            throw IllegalStateException(shortMessage(error))
        }
    }

    private fun fetchFacebook(url: String): VideoMeta {
        try {
            val meta = SocialClient.fetchFacebook(url)
            if (meta.options.any { it.kind == MediaKind.VIDEO }) {
                return meta.copy(options = meta.options + audioChoice())
            }
        } catch (error: Exception) {
            Log.e("IraqiTube", "facebook page failed", error)
        }
        return try {
            threeChoices(fromInfo(fetchSocial(url, ::applyFacebook), url))
        } catch (error: Exception) {
            Log.e("IraqiTube", "facebook ytdlp failed", error)
            throw IllegalStateException(shortMessage(error))
        }
    }

    private fun audioChoice() = QualityOption(
        id = "bestaudio/ba",
        label = "Audio",
        ext = "m4a",
        height = null,
        noWatermark = true,
        kind = MediaKind.AUDIO,
    )

    private fun threeChoices(meta: VideoMeta): VideoMeta {
        val videos = meta.options.filter { it.kind == MediaKind.VIDEO }
        val hd = videos.firstOrNull()?.copy(label = "HD")
        val sd = videos.drop(1).lastOrNull()?.copy(label = "SD")
        val audio = meta.options.firstOrNull { it.kind == MediaKind.AUDIO }?.copy(label = "Audio")
            ?: audioChoice()
        return meta.copy(options = listOfNotNull(hd, sd, audio))
    }

    private fun fromTikTokInfo(info: VideoInfo, url: String): VideoMeta {
        val formats = info.formats ?: emptyList()
        val options = linkedMapOf<String, QualityOption>()
        options[TIKTOK_NO_WM] = QualityOption(
            id = TIKTOK_NO_WM,
            label = "HD",
            ext = "mp4",
            height = info.height,
            noWatermark = true,
            kind = MediaKind.VIDEO,
        )
        formats
            .filter { usableVideo(it) && !watermarked(it) }
            .sortedByDescending { it.height ?: 0 }
            .forEach { format ->
                val id = format.formatId ?: return@forEach
                if (options.containsKey(id)) return@forEach
                val height = format.height
                if (height != null && options.values.any { it.height == height }) return@forEach
                options[id] = QualityOption(
                    id = id,
                    label = if (height != null) "${height}p" else "Video",
                    ext = format.ext ?: "mp4",
                    height = height,
                    noWatermark = true,
                    kind = MediaKind.VIDEO,
                )
            }
        addAudioOption(options, formats)
        return VideoMeta(
            id = info.id ?: System.currentTimeMillis().toString(),
            title = info.title?.ifBlank { null } ?: "TikTok video",
            author = info.uploader,
            thumbnail = info.thumbnail,
            duration = info.duration?.toLong(),
            webpageUrl = info.webpageUrl ?: url,
            platform = "TikTok",
            options = options.values.toList(),
        )
    }

    private fun fromInfo(info: VideoInfo, url: String): VideoMeta {
        val platform = platformOf(info.webpageUrl ?: url)
        val options = linkedMapOf<String, QualityOption>()
        options["hd"] = QualityOption(
            id = "bv*+ba/b",
            label = "HD",
            ext = "mp4",
            height = info.height,
            noWatermark = false,
            kind = MediaKind.VIDEO,
        )
        options["sd"] = QualityOption(
            id = "bv*[height<=480]+ba/b[height<=480]/worst",
            label = "SD",
            ext = "mp4",
            height = 480,
            noWatermark = false,
            kind = MediaKind.VIDEO,
        )
        val formats = info.formats ?: emptyList()
        addAudioOption(options, formats)
        return VideoMeta(
            id = info.id ?: System.currentTimeMillis().toString(),
            title = info.title?.ifBlank { null } ?: "Untitled",
            author = info.uploader,
            thumbnail = info.thumbnail,
            duration = info.duration?.toLong(),
            webpageUrl = info.webpageUrl ?: url,
            platform = platform,
            options = options.values.toList(),
        )
    }

    private fun addAudioOption(
        options: MutableMap<String, QualityOption>,
        formats: List<VideoFormat>,
    ) {
        val audio = formats
            .filter { it.vcodec == "none" && it.acodec != null && it.acodec != "none" }
            .maxByOrNull { it.fileSize ?: 0 }
        options["audio"] = QualityOption(
            id = audio?.formatId ?: "bestaudio/ba",
            label = "Audio",
            ext = audio?.ext ?: "m4a",
            height = null,
            noWatermark = true,
            kind = MediaKind.AUDIO,
        )
    }

    private fun runYtdlp(
        pageUrl: String,
        format: String,
        dest: File,
        platform: String,
        onProgress: (Float) -> Unit,
    ): File {
        val template = File(dest.parentFile, dest.nameWithoutExtension + ".%(ext)s")
        val request = YoutubeDLRequest(pageUrl)
        applyCommon(request)
        when (platform) {
            "TikTok" -> applyTikTok(request, tiktokHosts.first())
            "Instagram" -> applyInstagram(request)
            "Facebook" -> applyFacebook(request)
        }
        request.addOption("-f", format)
        request.addOption("-o", template.absolutePath)
        if ("+" in format) {
            request.addOption("--merge-output-format", "mp4")
        }
        YoutubeDL.getInstance().execute(request) { progress, _, _ ->
            onProgress((progress / 100f).coerceIn(0f, 1f))
        }
        val prefix = template.absolutePath.removeSuffix(".%(ext)s")
        return dest.parentFile?.listFiles()?.firstOrNull { it.absolutePath.startsWith(prefix) }
            ?: dest.parentFile?.listFiles()?.maxByOrNull { it.lastModified() }
            ?: throw IllegalStateException("Download finished but the file was not found")
    }

    private fun fetchDefault(url: String): VideoInfo {
        val request = YoutubeDLRequest(url)
        applyCommon(request)
        return YoutubeDL.getInstance().getInfo(request)
    }

    private fun fetchSocial(url: String, extra: (YoutubeDLRequest) -> Unit): VideoInfo {
        val request = YoutubeDLRequest(url)
        applyCommon(request)
        extra(request)
        return YoutubeDL.getInstance().getInfo(request)
    }

    private fun applyCommon(request: YoutubeDLRequest) {
        request.addOption("--no-playlist")
        request.addOption("--no-warnings")
        request.addOption(
            "--user-agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
        )
    }

    private fun applyTikTok(request: YoutubeDLRequest, host: String) {
        request.addOption("--extractor-args", "tiktok:api_hostname=$host")
        request.addOption("--referer", "https://www.tiktok.com/")
        request.addOption("--xff", "US")
    }

    private fun applyInstagram(request: YoutubeDLRequest) {
        request.addOption("--referer", "https://www.instagram.com/")
        request.addOption("--add-header", "Origin:https://www.instagram.com/")
        request.addOption(
            "--user-agent",
            "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36",
        )
    }

    private fun applyFacebook(request: YoutubeDLRequest) {
        request.addOption("--referer", "https://www.facebook.com/")
        request.addOption("--add-header", "Origin:https://www.facebook.com/")
        request.addOption(
            "--user-agent",
            "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36",
        )
    }

    private fun watermarked(format: VideoFormat): Boolean {
        val note = (format.formatNote ?: "").lowercase()
        val id = (format.formatId ?: "").lowercase()
        return "watermarked" in note || id == "download" || id == "download_addr"
    }

    private fun usableVideo(format: VideoFormat): Boolean {
        val ext = (format.ext ?: "").lowercase()
        if (ext in setOf("mhtml", "sbv", "srt", "vtt", "json", "jpg", "png", "webp")) return false
        val video = format.vcodec != null && format.vcodec != "none"
        return video || ext in setOf("mp4", "webm", "mov")
    }

}
