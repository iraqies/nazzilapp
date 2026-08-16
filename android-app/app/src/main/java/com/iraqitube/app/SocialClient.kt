package com.iraqitube.app

import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.math.BigInteger

object SocialClient {
    private val igCode = Regex("""instagram\.com/(?:reel|reels|p|tv)/([A-Za-z0-9_-]+)""", RegexOption.IGNORE_CASE)
    private val videoMeta = Regex("""(?:og:video(?::secure_url)?["'\s]+content=["']|["']video_url["']\s*:\s*["']|["']playback_url["']\s*:\s*["']|contentUrl["']\s*:\s*["'])([^"']+)""")
    private val versionUrl = Regex("""["']url["']\s*:\s*["'](https:[^"']+)["']""")
    private val titleRx = Regex("""(?:og:title["'\s]+content=["']|["']title["']\s*:\s*["'])([^"']+)""")
    private val thumbRx = Regex("""(?:og:image["'\s]+content=["']|["']display_url["']\s*:\s*["'])([^"']+)""")
    private val hdSrc = Regex("""["']hd_src["']\s*:\s*["']([^"']+)""")
    private val sdSrc = Regex("""["']sd_src["']\s*:\s*["']([^"']+)""")

    private const val IG_WEB_APP = "936619743392459"
    private const val IG_ANDROID_UA =
        "Instagram 192.168.1.2.117 Android (33/13; 420dpi; 1080x2400; Google; Pixel 7; panther; gs201; en_US; 458229237)"

    fun fetchInstagram(pageUrl: String): VideoMeta {
        val resolved = LinkParser.resolve(pageUrl)
        val code = igCode.find(resolved)?.groupValues?.get(1)
            ?: throw IllegalStateException("Could not read this Instagram link")
        val pk = shortcodeToId(code)
        val igHeaders = mapOf(
            "Referer" to "https://www.instagram.com/",
            "Origin" to "https://www.instagram.com",
            "X-IG-App-ID" to IG_WEB_APP,
            "X-ASBD-ID" to "129477",
            "X-IG-WWW-Claim" to "0",
        )

        try {
            DirectHttp.get("https://www.instagram.com/reel/$code/", igHeaders)
        } catch (_: Exception) {
        }

        val attempts = listOf(
            {
                DirectHttp.get(
                    "https://www.instagram.com/reel/$code/",
                    igHeaders,
                    "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
                )
            },
            { DirectHttp.get("https://i.instagram.com/api/v1/media/$pk/info/", igHeaders, IG_ANDROID_UA) },
            { DirectHttp.get("https://www.instagram.com/api/v1/media/$pk/info/", igHeaders) },
            { DirectHttp.get("https://www.instagram.com/p/$code/?__a=1&__d=dis", igHeaders) },
            { DirectHttp.get("https://www.instagram.com/reel/$code/?__a=1&__d=dis", igHeaders) },
            { DirectHttp.get("https://www.instagram.com/p/$code/embed/captioned/", igHeaders) },
            { DirectHttp.get("https://www.instagram.com/reel/$code/embed/", igHeaders) },
        )
        var last: Exception? = null
        for (attempt in attempts) {
            try {
                val body = attempt()
                val meta = if (body.trimStart().startsWith("{")) {
                    parseJson(body, resolved, code)
                } else {
                    parseHtml(body, resolved, "Instagram", code)
                }
                if (meta.options.any { it.kind == MediaKind.VIDEO }) return meta
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Could not load this Instagram link")
    }

    fun fetchFacebook(pageUrl: String): VideoMeta {
        val resolved = LinkParser.resolve(pageUrl)
        val encoded = java.net.URLEncoder.encode(resolved, "UTF-8")
        val pages = listOf(
            resolved,
            resolved.replace("www.facebook.com", "m.facebook.com").replace("web.facebook.com", "m.facebook.com"),
            resolved.replace("www.facebook.com", "mbasic.facebook.com").replace("web.facebook.com", "mbasic.facebook.com"),
            "https://www.facebook.com/plugins/video.php?href=$encoded",
        ).distinct()
        var last: Exception? = null
        for (page in pages) {
            try {
                val html = DirectHttp.get(page, mapOf("Referer" to "https://www.facebook.com/"))
                val meta = parseHtml(html, resolved, "Facebook", System.currentTimeMillis().toString())
                if (meta.options.any { it.kind == MediaKind.VIDEO }) return meta
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Could not load this Facebook link")
    }

    fun download(option: QualityOption, dest: File, onProgress: (Float) -> Unit): File {
        val url = option.directUrl ?: throw IllegalStateException("Missing download link")
        val youtube = "googlevideo" in url || "youtube" in url || "ytimg" in url
        val referer = when {
            "instagram7" in url -> "https://www.instagram7.com/"
            "instagram" in url || "cdninstagram" in url || "fbcdn" in url -> "https://www.instagram.com/"
            youtube -> "https://www.youtube.com/"
            else -> "https://www.facebook.com/"
        }
        val agents = if (youtube) {
            listOf(NewPipeHttp.UA)
        } else if ("instagram" in url || "cdninstagram" in url || "fbcdn" in url) {
            listOf(
                DirectHttp.UA,
                InstagramDownloader.FB_UA,
                InstagramDownloader.GOOGLE_UA,
                InstagramDownloader.BOT_UA,
            )
        } else {
            listOf(DirectHttp.UA)
        }
        var last: Exception? = null
        for (ua in agents) {
            try {
                return DirectHttp.save(url, dest, referer, onProgress, ua)
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Could not download this video")
    }

    private fun parseJson(body: String, pageUrl: String, id: String): VideoMeta {
        val root = JSONObject(body)
        val videos = mutableListOf<Pair<Int, String>>()
        val thumbs = mutableListOf<String>()
        val titles = mutableListOf<String>()
        val music = mutableListOf<String>()
        walk(root, videos, thumbs, titles, music, 0)
        val unique = videos
            .map { it.first to clean(it.second) }
            .filter { looksLikeVideo(it.second) }
            .distinctBy { it.second }
            .sortedByDescending { it.first }
        if (unique.isEmpty()) {
            throw IllegalStateException("Could not load this Instagram link")
        }
        val hd = unique.first().second
        val sd = unique.last().second
        val options = buildList {
            add(option("HD", hd, MediaKind.VIDEO))
            if (sd != hd) add(option("SD", sd, MediaKind.VIDEO))
            music.firstOrNull { it.startsWith("http") }?.let { add(option("Audio", clean(it), MediaKind.AUDIO)) }
        }
        val (igTitle, igAuthor) = HtmlText.instagram(titles.firstOrNull())
        return VideoMeta(
            id = id,
            title = igTitle,
            author = igAuthor,
            thumbnail = thumbs.firstOrNull()?.let { clean(it) },
            duration = null,
            webpageUrl = pageUrl,
            platform = "Instagram",
            options = options,
        )
    }

    private fun walk(
        node: Any?,
        videos: MutableList<Pair<Int, String>>,
        thumbs: MutableList<String>,
        titles: MutableList<String>,
        music: MutableList<String>,
        depth: Int,
    ) {
        if (node == null || depth > 14) return
        when (node) {
            is JSONObject -> {
                val versions = node.optJSONArray("video_versions")
                if (versions != null) {
                    for (i in 0 until versions.length()) {
                        val item = versions.optJSONObject(i) ?: continue
                        val url = item.optString("url")
                        if (url.startsWith("http")) {
                            videos += item.optInt("width") to url
                        }
                    }
                }
                val videoUrl = node.optString("video_url")
                if (videoUrl.startsWith("http")) videos += node.optInt("original_width", 1080) to videoUrl
                val play = node.optString("playback_url")
                if (play.startsWith("http")) videos += 720 to play
                val sound = node.optString("progressive_download_url")
                if (sound.startsWith("http")) music += sound
                val display = node.optString("display_url")
                if (display.startsWith("http")) thumbs += display
                val caption = node.optJSONObject("caption")?.optString("text")
                if (!caption.isNullOrBlank()) titles += caption
                val text = node.optString("title")
                if (text.isNotBlank() && text != "null") titles += text
                val keys = node.keys()
                while (keys.hasNext()) {
                    walk(node.opt(keys.next()), videos, thumbs, titles, music, depth + 1)
                }
            }
            is JSONArray -> {
                for (i in 0 until node.length()) {
                    walk(node.opt(i), videos, thumbs, titles, music, depth + 1)
                }
            }
        }
    }

    private fun parseHtml(html: String, pageUrl: String, platform: String, id: String): VideoMeta {
        val decoded = html
            .replace("\\u0026", "&")
            .replace("\\/", "/")
            .replace("\\\"", "\"")
        val urls = linkedSetOf<String>()
        hdSrc.find(decoded)?.groupValues?.get(1)?.let { urls += clean(it) }
        videoMeta.findAll(decoded).forEach { urls += clean(it.groupValues[1]) }
        versionUrl.findAll(decoded).forEach { match ->
            val url = clean(match.groupValues[1])
            if (looksLikeVideo(url)) urls += url
        }
        sdSrc.find(decoded)?.groupValues?.get(1)?.let { urls += clean(it) }
        Regex("""https://[^\s"'<>\\]+?\.mp4[^\s"'<>\\]*""").findAll(decoded).forEach { match ->
            urls += clean(match.value)
        }
        val videos = urls.filter { looksLikeVideo(it) }.distinct()
        if (videos.isEmpty()) {
            throw IllegalStateException("Could not load this $platform link")
        }
        val hd = videos.first()
        val sd = videos.last()
        val options = buildList {
            add(option("HD", hd, MediaKind.VIDEO))
            if (sd != hd) add(option("SD", sd, MediaKind.VIDEO))
        }
        val rawTitle = titleRx.find(decoded)?.groupValues?.get(1)
        val (igTitle, igAuthor) = HtmlText.instagram(rawTitle)
        return VideoMeta(
            id = id,
            title = if (platform == "Instagram") igTitle else HtmlText.decode(rawTitle).ifBlank { "$platform video" },
            author = if (platform == "Instagram") igAuthor else null,
            thumbnail = thumbRx.find(decoded)?.groupValues?.get(1)?.let { clean(it) },
            duration = null,
            webpageUrl = pageUrl,
            platform = platform,
            options = options,
        )
    }

    private fun option(label: String, url: String, kind: MediaKind) = QualityOption(
        id = "direct-$label",
        label = label,
        ext = if (kind == MediaKind.AUDIO) "m4a" else "mp4",
        height = null,
        noWatermark = true,
        directUrl = url,
        kind = kind,
    )

    private fun looksLikeVideo(url: String): Boolean {
        val value = url.lowercase()
        if (!value.startsWith("http")) return false
        if (listOf(".jpg", ".jpeg", ".png", ".webp", ".heic", ".gif").any { value.contains(it) }) return false
        return ".mp4" in value || "/v/t" in value || "video" in value ||
            "cdninstagram" in value || "fbcdn.net" in value
    }

    private fun shortcodeToId(code: String): String {
        val alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        var id = BigInteger.ZERO
        val base = BigInteger.valueOf(64)
        for (char in code) {
            val index = alphabet.indexOf(char)
            if (index < 0) continue
            id = id.multiply(base).add(BigInteger.valueOf(index.toLong()))
        }
        return id.toString()
    }

    private fun clean(raw: String): String {
        return raw.trim()
            .replace("\\u0026", "&")
            .replace("\\/", "/")
            .replace("&amp;", "&")
    }

}
