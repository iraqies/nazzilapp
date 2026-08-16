package com.iraqitube.app

import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

object TikTokClient {
    private const val UA =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

    fun fetch(pageUrl: String): VideoMeta {
        var last: Exception? = null
        val attempts = if (isShortLink(pageUrl)) 4 else 3
        repeat(attempts) { index ->
            try {
                return parse(request(pageUrl), pageUrl)
            } catch (error: Exception) {
                last = error
                val limit = error.message?.contains("limit", ignoreCase = true) == true
                Thread.sleep(if (index == 0 && isShortLink(pageUrl)) 3500 else if (limit) 1500 else 800)
            }
        }
        throw last ?: IllegalStateException("Could not read this TikTok link")
    }

    fun download(
        pageUrl: String,
        option: QualityOption,
        dest: File,
        onProgress: (Float) -> Unit,
    ): File {
        val url = option.directUrl ?: refresh(pageUrl, option.id)
        return try {
            save(url, dest, refererFor(url), onProgress)
        } catch (_: Exception) {
            val fresh = refresh(pageUrl, option.id)
            save(fresh, dest, refererFor(fresh), onProgress)
        }
    }

    private fun refresh(pageUrl: String, optionId: String): String {
        val meta = fetch(pageUrl)
        val match = meta.options.firstOrNull { it.id == optionId && !it.directUrl.isNullOrBlank() }
            ?: meta.options.firstOrNull { it.noWatermark && !it.directUrl.isNullOrBlank() }
        return match?.directUrl ?: throw IllegalStateException("Could not get a no-watermark TikTok file")
    }

    private fun request(pageUrl: String): JSONObject {
        val encoded = URLEncoder.encode(pageUrl, "UTF-8")
        val endpoints = listOf(
            "https://www.tikwm.com/api/?url=$encoded&hd=1",
            "https://tikwm.com/api/?url=$encoded&hd=1",
        )
        var last: Exception? = null
        for (endpoint in endpoints) {
            try {
                return readJson(get(endpoint))
            } catch (error: Exception) {
                last = error
            }
        }
        try {
            return readJson(post("https://www.tikwm.com/api/", "url=$encoded&hd=1"))
        } catch (error: Exception) {
            throw last ?: error
        }
    }

    private fun readJson(body: String): JSONObject {
        val json = JSONObject(body)
        val code = json.opt("code")
        val ok = code == 0 || code == 0L || code == "0"
        if (!ok) {
            val message = json.optString("msg").ifBlank { "TikTok lookup failed" }
            throw IllegalStateException(message)
        }
        return json.optJSONObject("data")
            ?: throw IllegalStateException("TikTok returned no video data")
    }

    private fun parse(data: JSONObject, pageUrl: String): VideoMeta {
        val hd = absUrl(data.optString("hdplay"))
        val play = absUrl(data.optString("play"))
        val music = absUrl(data.optString("music"))
        if (hd == null && play == null) {
            throw IllegalStateException("No watermark-free TikTok file was returned")
        }

        val options = buildList {
            if (hd != null) {
                add(
                    QualityOption(
                        id = "tikwm-hd",
                        label = "HD",
                        ext = "mp4",
                        height = null,
                        noWatermark = true,
                        directUrl = hd,
                        kind = MediaKind.VIDEO,
                    ),
                )
            }
            if (play != null && play != hd) {
                add(
                    QualityOption(
                        id = "tikwm-play",
                        label = "SD",
                        ext = "mp4",
                        height = null,
                        noWatermark = true,
                        directUrl = play,
                        kind = MediaKind.VIDEO,
                    ),
                )
            }
            if (music != null) {
                add(
                    QualityOption(
                        id = "tikwm-audio",
                        label = "Audio",
                        ext = "mp3",
                        height = null,
                        noWatermark = true,
                        directUrl = music,
                        kind = MediaKind.AUDIO,
                    ),
                )
            }
        }

        val author = data.optJSONObject("author")
        return VideoMeta(
            id = data.optString("id").ifBlank { System.currentTimeMillis().toString() },
            title = data.optString("title").ifBlank { "TikTok video" },
            author = author?.optString("nickname")?.ifBlank { null }
                ?: author?.optString("unique_id")?.ifBlank { null },
            thumbnail = absUrl(data.optString("cover")) ?: absUrl(data.optString("origin_cover")),
            duration = data.optLong("duration").takeIf { it > 0 },
            webpageUrl = pageUrl,
            platform = "TikTok",
            options = options,
        )
    }

    private fun absUrl(raw: String): String? {
        val value = raw.trim()
        if (value.isEmpty() || value == "null") return null
        return when {
            value.startsWith("//") -> "https:$value"
            value.startsWith("/") -> "https://www.tikwm.com$value"
            value.startsWith("http://") || value.startsWith("https://") -> value
            else -> null
        }
    }

    private fun isShortLink(url: String): Boolean {
        val host = url.lowercase()
        return "vm.tiktok.com" in host || "vt.tiktok.com" in host
    }

    private fun refererFor(url: String): String {
        return if ("tikwm.com" in url.lowercase()) "https://www.tikwm.com/" else "https://www.tiktok.com/"
    }

    private fun get(url: String): String {
        val conn = open(url, mapOf("Accept" to "application/json"))
        return readBody(conn)
    }

    private fun post(url: String, body: String): String {
        val conn = open(url, mapOf(
            "Accept" to "application/json",
            "Content-Type" to "application/x-www-form-urlencoded",
        ), body)
        return readBody(conn)
    }

    fun save(url: String, dest: File, referer: String, onProgress: (Float) -> Unit): File {
        val conn = open(url, mapOf("Referer" to referer, "Accept" to "*/*"))
        val length = conn.contentLengthLong
        dest.outputStream().use { output ->
            conn.inputStream.use { input ->
                val buffer = ByteArray(64 * 1024)
                var read = 0L
                while (true) {
                    val n = input.read(buffer)
                    if (n <= 0) break
                    output.write(buffer, 0, n)
                    read += n
                    onProgress(if (length > 0) (read.toFloat() / length).coerceIn(0f, 0.99f) else 0.45f)
                }
            }
        }
        if (dest.length() < 2048) {
            dest.delete()
            throw IllegalStateException("TikTok download was empty")
        }
        onProgress(1f)
        return dest
    }

    private fun readBody(conn: HttpURLConnection): String {
        val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
        if (conn.responseCode !in 200..299) {
            throw IllegalStateException("HTTP ${conn.responseCode} ${text.take(120)}")
        }
        return text
    }

    private fun open(
        url: String,
        headers: Map<String, String>,
        body: String? = null,
    ): HttpURLConnection {
        var current = url
        repeat(8) { hop ->
            val postFirst = body != null && hop == 0 && current == url
            val conn = (URL(current).openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = false
                connectTimeout = 20_000
                readTimeout = 60_000
                requestMethod = if (postFirst) "POST" else "GET"
                setRequestProperty("User-Agent", UA)
                headers.forEach { (key, value) -> setRequestProperty(key, value) }
                if (postFirst) {
                    doOutput = true
                    outputStream.use { stream -> stream.write(body!!.toByteArray()) }
                }
            }
            val code = conn.responseCode
            if (code in 300..399) {
                val location = conn.getHeaderField("Location")
                    ?: throw IllegalStateException("Redirect without location")
                current = URL(URL(current), location).toString()
                conn.disconnect()
                return@repeat
            }
            return conn
        }
        throw IllegalStateException("Too many redirects")
    }
}
