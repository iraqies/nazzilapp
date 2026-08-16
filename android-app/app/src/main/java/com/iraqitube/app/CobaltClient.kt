package com.iraqitube.app

import org.json.JSONObject

object CobaltClient {
    private val hosts = listOf(
        "https://api.cobalt.tools",
        "https://cobalt.api.timelessnesses.me",
        "https://co.eepy.today",
        "https://cobalt-api.kwiatekmiki.com",
    )

    fun fetch(pageUrl: String, platform: String): VideoMeta {
        var last: Exception? = null
        for (host in hosts) {
            try {
                return request(host, pageUrl, platform)
            } catch (error: Exception) {
                last = error
            }
        }
        throw last ?: IllegalStateException("Could not load this link")
    }

    private fun request(host: String, pageUrl: String, platform: String): VideoMeta {
        val payload = JSONObject()
            .put("url", pageUrl)
            .put("videoQuality", "1080")
            .put("downloadMode", "auto")
            .toString()
        val raw = DirectHttp.postJson("$host/", payload)
        val json = JSONObject(raw)
        val status = json.optString("status")
        if (status == "error" || json.has("error")) {
            val message = json.optJSONObject("error")?.optString("code")
                ?: json.optString("text").ifBlank { "Lookup failed" }
            throw IllegalStateException(message)
        }
        val url = json.optString("url")
        if (!url.startsWith("http")) throw IllegalStateException("No video")
        val title = json.optString("filename").substringBeforeLast('.').ifBlank { "$platform video" }
        return VideoMeta(
            id = System.currentTimeMillis().toString(),
            title = HtmlText.decode(title).ifBlank { "$platform video" },
            author = null,
            thumbnail = json.optString("thumbnail").ifBlank { null },
            duration = null,
            webpageUrl = pageUrl,
            platform = platform,
            options = listOf(
                QualityOption("cobalt-hd", "HD", "mp4", null, true, url, MediaKind.VIDEO),
                QualityOption("bestaudio/ba", "Audio", "m4a", null, true, kind = MediaKind.AUDIO),
            ),
        )
    }
}
