package com.iraqitube.app

import java.io.File
import java.net.CookieHandler
import java.net.CookieManager
import java.net.CookiePolicy
import java.net.HttpURLConnection
import java.net.URL

object DirectHttp {
    const val UA =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36"

    init {
        if (CookieHandler.getDefault() == null) {
            CookieHandler.setDefault(CookieManager(null, CookiePolicy.ACCEPT_ALL))
        }
    }

    data class Located(val url: String, val type: String, val body: String)

    fun get(url: String, extra: Map<String, String> = emptyMap(), userAgent: String = UA): String {
        val conn = open(url, extra + mapOf("Accept" to "text/html,application/json,*/*"), userAgent = userAgent)
        return readBody(conn)
    }

    fun post(url: String, body: String, extra: Map<String, String> = emptyMap(), userAgent: String = UA): String {
        val conn = open(
            url,
            extra + mapOf(
                "Accept" to "application/json,text/html,*/*",
                "Content-Type" to "application/x-www-form-urlencoded; charset=UTF-8",
            ),
            body,
            userAgent,
        )
        return readBody(conn)
    }

    fun postJson(url: String, body: String, extra: Map<String, String> = emptyMap(), userAgent: String = UA): String {
        val conn = open(
            url,
            extra + mapOf(
                "Accept" to "application/json",
                "Content-Type" to "application/json",
            ),
            body,
            userAgent,
        )
        return readBody(conn)
    }

    fun locate(url: String, extra: Map<String, String> = emptyMap(), userAgent: String = UA): Located {
        var current = url
        repeat(8) { hop ->
            val conn = open(current, extra + mapOf("Accept" to "*/*"), userAgent = userAgent)
            val code = conn.responseCode
            if (code in 300..399) {
                val location = conn.getHeaderField("Location")
                    ?: throw IllegalStateException("Redirect without location")
                current = URL(URL(current), location).toString()
                conn.disconnect()
                return@repeat
            }
            val type = conn.contentType.orEmpty()
            if (type.startsWith("video") || type.startsWith("audio")) {
                conn.disconnect()
                return Located(current, type, "")
            }
            return Located(current, type, readBody(conn))
        }
        throw IllegalStateException("Too many redirects")
    }

    fun save(
        url: String,
        dest: File,
        referer: String,
        onProgress: (Float) -> Unit,
        userAgent: String = UA,
    ): File {
        val conn = open(url, mapOf("Referer" to referer, "Accept" to "*/*"), userAgent = userAgent)
        val code = conn.responseCode
        val type = conn.contentType.orEmpty()
        if (code !in 200..299 && code != 206) {
            runCatching { conn.errorStream?.close() }
            conn.disconnect()
            throw IllegalStateException(
                when (code) {
                    401, 403 -> "This video blocked the download. Try again."
                    404 -> "This video is gone."
                    else -> "Download failed ($code)"
                },
            )
        }
        if (type.startsWith("text/html") || type.startsWith("application/json")) {
            runCatching { conn.inputStream?.close() }
            conn.disconnect()
            throw IllegalStateException("This video blocked the download. Try again.")
        }
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
            throw IllegalStateException("Download was empty")
        }
        onProgress(1f)
        return dest
    }

    private fun readBody(conn: HttpURLConnection): String {
        val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
        if (conn.responseCode !in 200..299) {
            throw IllegalStateException("HTTP ${conn.responseCode}")
        }
        return text
    }

    fun open(
        url: String,
        headers: Map<String, String>,
        body: String? = null,
        userAgent: String = UA,
    ): HttpURLConnection {
        var current = url
        repeat(8) { hop ->
            val postFirst = body != null && hop == 0 && current == url
            val conn = (URL(current).openConnection() as HttpURLConnection).apply {
                instanceFollowRedirects = false
                connectTimeout = 20_000
                readTimeout = 60_000
                requestMethod = if (postFirst) "POST" else "GET"
                setRequestProperty("User-Agent", userAgent)
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
