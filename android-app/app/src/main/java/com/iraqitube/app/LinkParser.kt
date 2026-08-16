package com.iraqitube.app

import java.net.HttpURLConnection
import java.net.URL

object LinkParser {
    private val urlRegex = Regex("""https?://[^\s<>"'\\]+""", RegexOption.IGNORE_CASE)
    private val shortHosts = setOf(
        "vm.tiktok.com",
        "vt.tiktok.com",
        "fb.watch",
        "fb.me",
        "l.instagram.com",
        "instagr.am",
        "ig.me",
        "youtu.be",
    )

    fun extract(text: String): String {
        val raw = text.trim()
        if (raw.isEmpty()) return ""
        val found = urlRegex.find(raw)?.value?.trimEnd('.', ',', ';', ')', ']', '"', '\'', '>', '\\')
        return found ?: raw.lineSequence().map { it.trim() }.firstOrNull { looksLikeUrl(it) }.orEmpty()
    }

    fun resolve(text: String): String {
        val url = extract(text)
        if (url.isEmpty()) return text.trim()
        val host = hostOf(url)
        val needsResolve = host in shortHosts ||
            "/share/" in url.lowercase() ||
            host.startsWith("lm.facebook") ||
            host == "m.facebook.com"
        if (!needsResolve) return url
        return follow(url) ?: url
    }

    fun looksLikeUrl(value: String): Boolean {
        val text = value.lowercase()
        return text.startsWith("http://") || text.startsWith("https://") ||
            "tiktok.com" in text || "instagram.com" in text || "instagr.am" in text ||
            "facebook.com" in text || "fb.watch" in text || "fb.com" in text ||
            "youtu.be" in text || "youtube.com" in text
    }

    private fun hostOf(url: String): String {
        return try {
            URL(url).host.lowercase().removePrefix("www.")
        } catch (_: Exception) {
            ""
        }
    }

    private fun follow(start: String): String? {
        var current = start
        repeat(8) {
            val conn = (URL(current).openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = false
                requestMethod = "GET"
                connectTimeout = 12_000
                readTimeout = 12_000
                setRequestProperty(
                    "User-Agent",
                    "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36",
                )
            }
            val code = try {
                conn.responseCode
            } catch (_: Exception) {
                conn.disconnect()
                return current
            }
            if (code !in 300..399) {
                conn.disconnect()
                return current
            }
            val location = conn.getHeaderField("Location")
            conn.disconnect()
            if (location.isNullOrBlank()) return current
            current = URL(URL(current), location).toString()
        }
        return current
    }
}
