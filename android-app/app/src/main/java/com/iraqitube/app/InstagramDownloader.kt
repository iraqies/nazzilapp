package com.iraqitube.app

import android.util.Log
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import java.net.URL
import java.net.URLEncoder
import org.json.JSONObject

object InstagramDownloader {
    const val BOT_UA =
        "Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)"
    const val FB_UA =
        "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"
    const val GOOGLE_UA =
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

    private val igCode = Regex("""instagram\.com/(?:reel|reels|p|tv)/([A-Za-z0-9_-]+)""", RegexOption.IGNORE_CASE)
    private val mp4Rx = Regex("""https://[^\s"'<>\\]+?\.mp4[^\s"'<>\\]*""")
    private val hrefRx = Regex("""href=["'](https?://[^"']+)["']""", RegexOption.IGNORE_CASE)
    private val ogVideo = Regex(
        """(?:og:video(?::secure_url)?|twitter:player:stream)["'\s]+content=["']([^"']+)""",
        RegexOption.IGNORE_CASE,
    )
    private val ogImage = Regex(
        """(?:og:image(?::secure_url)?|twitter:image)["'\s]+content=["']([^"']+)""",
        RegexOption.IGNORE_CASE,
    )
    private val ogTitle = Regex("""(?:og:title|twitter:title)["'\s]+content=["']([^"']+)""", RegexOption.IGNORE_CASE)

    fun fetch(pageUrl: String): VideoMeta {
        val resolved = LinkParser.resolve(pageUrl)
        val code = igCode.find(resolved)?.groupValues?.get(1)
            ?: throw IllegalStateException("Could not read this Instagram link")
        val canonical = "https://www.instagram.com/reel/$code/"
        val errors = mutableListOf<String>()

        try {
            return fromOfficialPage(code, canonical)
        } catch (error: Exception) {
            Log.w(TAG, "instagram page failed", error)
            error.message?.let { errors += it }
        }
        try {
            return fromInstaFix(code, canonical)
        } catch (error: Exception) {
            Log.w(TAG, "instafix failed", error)
            error.message?.let { errors += it }
        }
        try {
            return fromSaveIg(canonical, code)
        } catch (error: Exception) {
            Log.w(TAG, "saveig failed", error)
            error.message?.let { errors += it }
        }
        throw IllegalStateException(errors.firstOrNull { it.isNotBlank() } ?: "Could not load this Instagram link")
    }

    fun download(option: QualityOption, dest: File, onProgress: (Float) -> Unit): File {
        val url = option.directUrl ?: throw IllegalStateException("Missing download link")
        if (option.kind == MediaKind.AUDIO) {
            return extractAudio(url, dest, onProgress)
        }
        val referer = refererFor(url)
        val agents = listOf(userAgentFor(url), FB_UA, GOOGLE_UA, BOT_UA, DirectHttp.UA).distinct()
        var last: Exception? = null
        for (ua in agents) {
            try {
                return DirectHttp.save(url, dest, referer, onProgress, ua)
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Could not download this Instagram video")
    }

    private fun fromOfficialPage(code: String, pageUrl: String): VideoMeta {
        var last: Exception? = null
        for (ua in listOf(FB_UA, GOOGLE_UA)) {
            try {
                val html = DirectHttp.get(
                    "https://www.instagram.com/reel/$code/",
                    mapOf("Accept" to "text/html"),
                    ua,
                )
                val videos = extractMp4s(html)
                    .take(6)
                    .filter { isPlayable(it, ua, "https://www.instagram.com/") }
                if (videos.isEmpty()) {
                    last = IllegalStateException("Instagram page had no video")
                    continue
                }
                val title = ogTitle.find(html)?.groupValues?.get(1)
                val thumb = ogImage.find(html)?.groupValues?.get(1)?.let { clean(it) }
                Log.i(TAG, "instagram via official page")
                return meta(code, pageUrl, Found(videos, thumb, title))
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Instagram page had no video")
    }

    private fun fromInstaFix(code: String, pageUrl: String): VideoMeta {
        val hosts = listOf("www.instagram7.com", "instagram7.com")
        var last: Exception? = null
        for (host in hosts) {
            try {
                val html = DirectHttp.get(
                    "https://$host/reel/$code",
                    mapOf("Accept" to "text/html"),
                    BOT_UA,
                )
                if ("preview unavailable" in html || "/fallback/" in html && "og:video" !in html) {
                    last = IllegalStateException("This Instagram post is not public")
                    continue
                }
                val video = ogVideo.find(html)?.groupValues?.get(1)?.let { abs(it, host) }
                    ?: "https://$host/offload/$code/1.mp4"
                val thumb = ogImage.find(html)?.groupValues?.get(1)?.let { abs(it, host) }
                    ?: "https://$host/offload/$code/1?thumbnail=1"
                val title = ogTitle.find(html)?.groupValues?.get(1)
                if (!looksLikeVideo(video) || !isPlayable(video, BOT_UA, "https://$host/")) {
                    last = IllegalStateException("InstaFix had no video")
                    continue
                }
                Log.i(TAG, "instagram via instafix $host")
                return meta(code, pageUrl, Found(listOf(video), thumb, title))
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("InstaFix had no video")
    }

    private fun fromSaveIg(pageUrl: String, code: String): VideoMeta {
        val encoded = URLEncoder.encode(pageUrl, "UTF-8")
        val body = DirectHttp.post(
            "https://saveig.app/api/ajaxSearch",
            "q=$encoded&t=media&lang=en",
            mapOf(
                "Origin" to "https://saveig.app",
                "Referer" to "https://saveig.app/en/instagram-video-downloader",
                "X-Requested-With" to "XMLHttpRequest",
            ),
        )
        val html = try {
            JSONObject(body).optString("data").ifBlank { body }
        } catch (_: Exception) {
            body
        }
        val videos = hrefRx.findAll(html).map { clean(it.groupValues[1]) }.filter { looksLikeVideo(it) }.distinct().toList()
        if (videos.isEmpty()) throw IllegalStateException("SaveIG had no video")
        val thumb = ogImage.find(html)?.groupValues?.get(1)?.let { clean(it) }
            ?: Regex("""src=["'](https?://[^"']+)["']""", RegexOption.IGNORE_CASE)
                .findAll(html)
                .map { clean(it.groupValues[1]) }
                .firstOrNull { it.contains("thumb", ignoreCase = true) || it.contains("cdninstagram") }
        Log.i(TAG, "instagram via saveig")
        return meta(code, pageUrl, Found(videos, thumb, null))
    }

    private fun extractAudio(url: String, dest: File, onProgress: (Float) -> Unit): File {
        val template = File(dest.parentFile, dest.nameWithoutExtension + ".%(ext)s")
        return try {
            val request = YoutubeDLRequest(url)
            request.addOption("-x")
            request.addOption("--audio-format", "m4a")
            request.addOption("--no-playlist")
            request.addOption("-o", template.absolutePath)
            YoutubeDL.getInstance().execute(request) { progress, _, _ ->
                onProgress((progress / 100f).coerceIn(0f, 1f))
            }
            dest.parentFile?.listFiles()?.firstOrNull { it.absolutePath.startsWith(dest.absolutePath.removeSuffix(".${dest.extension}")) }
                ?: dest.parentFile?.listFiles()?.maxByOrNull { it.lastModified() }
                ?: throw IllegalStateException("Audio file was not found")
        } catch (error: Exception) {
            Log.w(TAG, "instagram audio extract failed, saving video", error)
            DirectHttp.save(url, dest, refererFor(url), onProgress, userAgentFor(url))
        }
    }

    private fun meta(id: String, pageUrl: String, found: Found): VideoMeta {
        val hd = found.videos.first()
        val sd = found.videos.last()
        val options = buildList {
            add(choice("HD", hd, MediaKind.VIDEO))
            if (sd != hd) add(choice("SD", sd, MediaKind.VIDEO))
            add(choice("Audio", hd, MediaKind.AUDIO).copy(ext = "m4a"))
        }
        val (title, author) = HtmlText.instagram(found.title)
        return VideoMeta(
            id = id,
            title = title,
            author = author,
            thumbnail = found.thumb,
            duration = null,
            webpageUrl = pageUrl,
            platform = "Instagram",
            options = options,
        )
    }

    private fun choice(label: String, url: String, kind: MediaKind) = QualityOption(
        id = "ig-$label",
        label = label,
        ext = if (kind == MediaKind.AUDIO) "m4a" else "mp4",
        height = null,
        noWatermark = true,
        directUrl = url,
        kind = kind,
    )

    private fun extractMp4s(html: String): List<String> {
        val unescaped = html.replace("\\/", "/").replace("\\u0026", "&")
        return mp4Rx.findAll(unescaped)
            .map { clean(it.value) }
            .filter { looksLikeVideo(it) && ("fbcdn" in it || "cdninstagram" in it) }
            .distinct()
            .sortedByDescending { it.length }
            .toList()
    }

    private fun isPlayable(url: String, userAgent: String, referer: String): Boolean {
        return try {
            val conn = DirectHttp.open(
                url,
                mapOf("Referer" to referer, "Range" to "bytes=0-64", "Accept" to "*/*"),
                userAgent = userAgent,
            )
            val code = conn.responseCode
            val type = conn.contentType.orEmpty()
            conn.disconnect()
            (code in 200..299 || code == 206) &&
                (type.startsWith("video") || type.startsWith("application/octet-stream") || type.isBlank())
        } catch (_: Exception) {
            false
        }
    }

    private fun looksLikeVideo(url: String): Boolean {
        val value = url.lowercase()
        if (!value.startsWith("http")) return false
        if (listOf(".jpg", ".jpeg", ".png", ".webp", ".gif", ".heic").any { it in value && ".mp4" !in value }) {
            return false
        }
        return ".mp4" in value || "/offload/" in value || "/videos/" in value ||
            "/v/t" in value || "cdninstagram" in value || "fbcdn.net" in value ||
            "saveig" in value || "ig-13-data" in value || "download" in value
    }

    private fun abs(raw: String, host: String): String {
        val value = clean(raw)
        return when {
            value.startsWith("http") -> value
            value.startsWith("//") -> "https:$value"
            value.startsWith("/") -> "https://$host$value"
            else -> try {
                URL(URL("https://$host/"), value).toString()
            } catch (_: Exception) {
                value
            }
        }
    }

    private fun userAgentFor(url: String): String {
        return if ("instagram7" in url || "toinstagram" in url || "ddinstagram" in url) BOT_UA else DirectHttp.UA
    }

    private fun refererFor(url: String): String {
        return when {
            "instagram7" in url -> "https://www.instagram7.com/"
            "saveig" in url || "ig-13" in url -> "https://saveig.app/"
            else -> "https://www.instagram.com/"
        }
    }

    private fun clean(raw: String) = raw.trim()
        .replace("\\u0026", "&")
        .replace("\\/", "/")
        .replace("&amp;", "&")

    private data class Found(val videos: List<String>, val thumb: String?, val title: String?)

    private const val TAG = "IraqiTube"
}
