package com.iraqitube.app

import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request
import org.schabi.newpipe.extractor.downloader.Response
import org.schabi.newpipe.extractor.exceptions.ReCaptchaException
import java.net.HttpURLConnection
import java.net.URL

class NewPipeHttp : Downloader() {
    override fun execute(request: Request): Response {
        val conn = (URL(request.url()).openConnection() as HttpURLConnection).apply {
            instanceFollowRedirects = true
            connectTimeout = 20_000
            readTimeout = 30_000
            requestMethod = request.httpMethod()
            setRequestProperty("User-Agent", UA)
            request.headers().forEach { (key, values) ->
                values.forEach { addRequestProperty(key, it) }
            }
            val body = request.dataToSend()
            if (body != null) {
                doOutput = true
                outputStream.use { it.write(body) }
            }
        }
        val code = conn.responseCode
        if (code == 429) throw ReCaptchaException("YouTube asked for a check", request.url())
        val stream = if (code in 200..399) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() }
        val headers = conn.headerFields
            .filterKeys { it != null }
            .mapKeys { it.key }
            .mapValues { it.value ?: emptyList() }
        return Response(code, conn.responseMessage, headers, text, conn.url.toString())
    }

    companion object {
        const val UA =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0"
    }
}
