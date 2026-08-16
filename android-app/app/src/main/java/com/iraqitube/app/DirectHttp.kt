package com.iraqitube.app

import java.io.File
import java.net.HttpURLConnection
import java.net.URL

object DirectHttp {
    const val UA =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36"

    fun get(url: String, extra: Map<String, String> = emptyMap()): String {
        val conn = open(url, extra + mapOf("Accept" to "text/html,application/json,*/*"))
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

    fun open(url: String, headers: Map<String, String>, body: String? = null): HttpURLConnection {
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
