package com.iraqitube.app

import java.io.File

object SocialClient {
    private val igCode = Regex("""instagram\.com/(?:reel|reels|p|tv)/([A-Za-z0-9_-]+)""", RegexOption.IGNORE_CASE)
    private val videoUrl = Regex("""(?:og:video(?::secure_url)?["'\s]+content=["']|["']video_url["']\s*:\s*["']|["']playback_url["']\s*:\s*["'])([^"']+)""")
    private val versionUrl = Regex("""["']url["']\s*:\s*["'](https:[^"']+\.mp4[^"']*)["']""")
    private val titleRx = Regex("""(?:og:title["'\s]+content=["']|["']title["']\s*:\s*["'])([^"']+)""")
    private val thumbRx = Regex("""(?:og:image["'\s]+content=["']|["']display_url["']\s*:\s*["'])([^"']+)""")
    private val hdSrc = Regex("""["']hd_src["']\s*:\s*["']([^"']+)""")
    private val sdSrc = Regex("""["']sd_src["']\s*:\s*["']([^"']+)""")

    fun fetchInstagram(pageUrl: String): VideoMeta {
        val resolved = LinkParser.resolve(pageUrl)
        val code = igCode.find(resolved)?.groupValues?.get(1)
            ?: throw IllegalStateException("Could not read this Instagram link")
        val pages = listOf(
            "https://www.instagram.com/reel/$code/embed/",
            "https://www.instagram.com/p/$code/embed/",
            "https://www.instagram.com/p/$code/embed/captioned/",
        )
        var last: Exception? = null
        for (page in pages) {
            try {
                val html = DirectHttp.get(
                    page,
                    mapOf("Referer" to "https://www.instagram.com/"),
                )
                val meta = parse(html, resolved, "Instagram", code)
                if (meta.options.any { it.kind == MediaKind.VIDEO }) return meta
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Could not load this Instagram link")
    }

    fun fetchFacebook(pageUrl: String): VideoMeta {
        val resolved = LinkParser.resolve(pageUrl)
        val html = DirectHttp.get(
            resolved,
            mapOf("Referer" to "https://www.facebook.com/"),
        )
        return parse(html, resolved, "Facebook", System.currentTimeMillis().toString())
    }

    fun download(option: QualityOption, dest: File, onProgress: (Float) -> Unit): File {
        val url = option.directUrl ?: throw IllegalStateException("Missing download link")
        val referer = if ("instagram" in url || "cdninstagram" in url || "fbcdn" in url) {
            "https://www.instagram.com/"
        } else {
            "https://www.facebook.com/"
        }
        return DirectHttp.save(url, dest, referer, onProgress)
    }

    private fun parse(html: String, pageUrl: String, platform: String, id: String): VideoMeta {
        val decoded = html
            .replace("\\u0026", "&")
            .replace("\\/", "/")
            .replace("\\\"", "\"")
        val urls = linkedSetOf<String>()
        hdSrc.find(decoded)?.groupValues?.get(1)?.let { urls += clean(it) }
        videoUrl.findAll(decoded).forEach { urls += clean(it.groupValues[1]) }
        versionUrl.findAll(decoded).forEach { urls += clean(it.groupValues[1]) }
        sdSrc.find(decoded)?.groupValues?.get(1)?.let { urls += clean(it) }
        val videos = urls.filter { it.startsWith("http") && "mp4" in it.lowercase() }.distinct()
        if (videos.isEmpty()) {
            throw IllegalStateException("Could not load this $platform link")
        }
        val hd = videos.first()
        val sd = videos.last()
        val options = buildList {
            add(option("HD", hd, MediaKind.VIDEO))
            if (sd != hd) add(option("SD", sd, MediaKind.VIDEO))
        }
        return VideoMeta(
            id = id,
            title = decode(titleRx.find(decoded)?.groupValues?.get(1)).ifBlank { "$platform video" },
            author = null,
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

    private fun clean(raw: String): String {
        return raw.trim()
            .replace("\\u0026", "&")
            .replace("\\/", "/")
            .replace("&amp;", "&")
    }

    private fun decode(raw: String?): String {
        return raw.orEmpty()
            .replace("&amp;", "&")
            .replace("&#039;", "'")
            .replace("&quot;", "\"")
    }
}
