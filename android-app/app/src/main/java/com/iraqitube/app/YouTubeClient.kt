package com.iraqitube.app

import org.json.JSONObject
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.localization.Localization
import org.schabi.newpipe.extractor.stream.VideoStream

object YouTubeClient {
    @Volatile
    private var newPipeReady = false
    private val idRegex = Regex("""(?:youtu\.be/|v=|shorts/|embed/|live/|/v/)([A-Za-z0-9_-]{11})""")

    private val piped = listOf(
        "https://pipedapi.kavin.rocks",
        "https://pipedapi-libre.kavin.rocks",
        "https://api.piped.private.coffee",
        "https://pipedapi.adminforge.de",
        "https://pipedapi.leptons.xyz",
        "https://pipedapi.ducks.party",
        "https://pipedapi.reallyaweso.me",
        "https://pipedapi.r4fo.com",
    )

    private val invidious = listOf(
        "https://inv.nadeko.net",
        "https://yewtu.be",
        "https://invidious.nerdvpn.de",
        "https://invidious.f5.si",
        "https://invidious.tiekoetter.com",
        "https://yt.chocolatemoo53.com",
    )

    fun videoId(url: String): String? = idRegex.find(url)?.groupValues?.getOrNull(1)

    fun watchUrl(url: String): String {
        val id = videoId(url) ?: return url
        return "https://www.youtube.com/watch?v=$id"
    }

    fun fetch(url: String): VideoMeta {
        val id = videoId(url) ?: throw IllegalStateException("Could not read this YouTube link")
        val errors = mutableListOf<String>()
        val watch = watchUrl(url)
        try {
            return fromNewPipe(watch, id)
        } catch (error: Exception) {
            error.message?.let { errors += it }
        }
        for (base in piped) {
            try {
                return fromPiped(jsonGet("$base/streams/$id"), watch, id)
            } catch (error: Exception) {
                error.message?.let { errors += it }
            }
        }
        for (base in invidious) {
            try {
                return fromInvidious(jsonGet("$base/api/v1/videos/$id"), watch, id)
            } catch (error: Exception) {
                error.message?.let { errors += it }
            }
        }
        throw IllegalStateException(errors.firstOrNull() ?: "YouTube blocked this one. Try again.")
    }

    private fun ensureNewPipe() {
        if (newPipeReady) return
        synchronized(this) {
            if (newPipeReady) return
            NewPipe.init(NewPipeHttp(), Localization.DEFAULT)
            newPipeReady = true
        }
    }

    private fun fromNewPipe(watch: String, id: String): VideoMeta {
        ensureNewPipe()
        val extractor = ServiceList.YouTube.getStreamExtractor(watch)
        extractor.fetchPage()
        val muxed = extractor.videoStreams.orEmpty().mapNotNull { it.toVideoOption() }
        val videoOnly = extractor.videoOnlyStreams.orEmpty().mapNotNull { it.toVideoOption() }
        val audioUrl = extractor.audioStreams.orEmpty()
            .maxByOrNull { it.averageBitrate }
            ?.content
            ?.ifBlank { null }
        val hd = muxed.filter { (it.height ?: 0) >= 720 }.maxByOrNull { it.height ?: 0 }
            ?: videoOnly.filter { (it.height ?: 0) >= 720 }.maxByOrNull { it.height ?: 0 }
            ?: muxed.maxByOrNull { it.height ?: 0 }
            ?: videoOnly.maxByOrNull { it.height ?: 0 }
        val sd = muxed.filter { (it.height ?: 0) in 1..480 }.maxByOrNull { it.height ?: 0 }
            ?: muxed.filter { it.id != hd?.id }.minByOrNull { it.height ?: 9999 }
            ?: videoOnly.filter { (it.height ?: 0) in 1..480 }.maxByOrNull { it.height ?: 0 }
        val audio = audioUrl?.let {
            QualityOption("np-audio", "Audio", "m4a", null, true, it, MediaKind.AUDIO)
        } ?: QualityOption("bestaudio/ba", "Audio", "m4a", null, true, kind = MediaKind.AUDIO)
        if (hd == null) throw IllegalStateException("No video")
        val thumb = extractor.thumbnails.firstOrNull()?.url
        return VideoMeta(
            id = id,
            title = extractor.name.ifBlank { "YouTube video" },
            author = extractor.uploaderName.ifBlank { null },
            thumbnail = thumb,
            duration = extractor.length.takeIf { it > 0 },
            webpageUrl = watch,
            platform = "YouTube",
            options = listOfNotNull(hd.copy(label = "HD"), sd?.copy(label = "SD"), audio),
        )
    }

    private fun VideoStream.toVideoOption(): QualityOption? {
        val stream = content.ifBlank { return null }
        val height = height.takeIf { it > 0 }
        return QualityOption(
            id = "np-$height",
            label = if ((height ?: 0) >= 720) "HD" else "SD",
            ext = format?.suffix ?: "mp4",
            height = height,
            noWatermark = true,
            directUrl = stream,
            kind = MediaKind.VIDEO,
        )
    }

    private fun jsonGet(url: String): String {
        val body = DirectHttp.get(url)
        val trimmed = body.trimStart()
        if (!trimmed.startsWith("{") && !trimmed.startsWith("[")) {
            throw IllegalStateException("YouTube lookup returned a page, not video data")
        }
        return body
    }

    private fun fromPiped(body: String, url: String, id: String): VideoMeta {
        val json = JSONObject(body)
        if (json.has("error")) throw IllegalStateException(json.optString("error"))
        val title = json.optString("title").ifBlank { "YouTube video" }
        val author = json.optString("uploader").ifBlank { null }
        val thumb = json.optString("thumbnailUrl").ifBlank { null }
        val duration = json.optLong("duration").takeIf { it > 0 }
        val videos = json.optJSONArray("videoStreams") ?: throw IllegalStateException("No video")
        val audios = json.optJSONArray("audioStreams")
        val muxed = mutableListOf<QualityOption>()
        val videoOnly = mutableListOf<Pair<Int, String>>()
        for (i in 0 until videos.length()) {
            val item = videos.optJSONObject(i) ?: continue
            val stream = item.optString("url")
            if (stream.isBlank()) continue
            val height = item.optString("quality").filter(Char::isDigit).toIntOrNull()
                ?: item.optInt("height").takeIf { it > 0 }
            val videoOnlyStream = item.optBoolean("videoOnly")
            if (videoOnlyStream) {
                if (height != null) videoOnly += height to stream
                continue
            }
            muxed += QualityOption(
                id = "piped-$height",
                label = if ((height ?: 0) >= 720) "HD" else "SD",
                ext = "mp4",
                height = height,
                noWatermark = true,
                directUrl = stream,
                kind = MediaKind.VIDEO,
            )
        }
        val audioUrl = (0 until (audios?.length() ?: 0))
            .mapNotNull { audios?.optJSONObject(it) }
            .maxByOrNull { it.optLong("bitrate") }
            ?.optString("url")
            ?.ifBlank { null }
        val hd = muxed.filter { (it.height ?: 0) >= 720 }.maxByOrNull { it.height ?: 0 }
            ?: videoOnly.filter { it.first >= 720 }.maxByOrNull { it.first }?.let { (h, stream) ->
                QualityOption("piped-$h", "HD", "mp4", h, true, stream, MediaKind.VIDEO)
            }
            ?: muxed.maxByOrNull { it.height ?: 0 }
        val sd = muxed.filter { (it.height ?: 0) in 1..480 }.maxByOrNull { it.height ?: 0 }
            ?: muxed.filter { it.id != hd?.id }.minByOrNull { it.height ?: 9999 }
            ?: videoOnly.filter { it.first <= 480 }.maxByOrNull { it.first }?.let { (h, stream) ->
                QualityOption("piped-sd-$h", "SD", "mp4", h, true, stream, MediaKind.VIDEO)
            }
        val audio = audioUrl?.let {
            QualityOption("piped-audio", "Audio", "m4a", null, true, it, MediaKind.AUDIO)
        } ?: QualityOption("bestaudio/ba", "Audio", "m4a", null, true, kind = MediaKind.AUDIO)
        val options = listOfNotNull(hd?.copy(label = "HD"), sd?.copy(label = "SD"), audio)
        if (options.none { it.kind == MediaKind.VIDEO }) throw IllegalStateException("No video")
        return VideoMeta(id, title, author, thumb, duration, url, "YouTube", options)
    }

    private fun fromInvidious(body: String, url: String, id: String): VideoMeta {
        val json = JSONObject(body)
        val title = json.optString("title").ifBlank { "YouTube video" }
        val author = json.optString("author").ifBlank { null }
        val thumb = json.optJSONArray("videoThumbnails")?.optJSONObject(0)?.optString("url")
        val duration = json.optLong("lengthSeconds").takeIf { it > 0 }
        val formats = json.optJSONArray("formatStreams") ?: throw IllegalStateException("No video")
        val options = mutableListOf<QualityOption>()
        for (i in 0 until formats.length()) {
            val item = formats.optJSONObject(i) ?: continue
            val stream = item.optString("url")
            if (stream.isBlank()) continue
            val height = item.optString("qualityLabel").filter(Char::isDigit).toIntOrNull()
                ?: item.optInt("height").takeIf { it > 0 }
            options += QualityOption(
                id = "inv-$height",
                label = if ((height ?: 0) >= 720) "HD" else "SD",
                ext = item.optString("container").ifBlank { "mp4" },
                height = height,
                noWatermark = true,
                directUrl = stream,
                kind = MediaKind.VIDEO,
            )
        }
        val hd = options.filter { (it.height ?: 0) >= 720 }.maxByOrNull { it.height ?: 0 }
            ?: options.maxByOrNull { it.height ?: 0 }
        val sd = options.filter { (it.height ?: 0) in 1..480 }.maxByOrNull { it.height ?: 0 }
            ?: options.filter { it.id != hd?.id }.minByOrNull { it.height ?: 9999 }
        if (hd == null) throw IllegalStateException("No video")
        return VideoMeta(
            id, title, author, thumb, duration, url, "YouTube",
            listOfNotNull(hd.copy(label = "HD"), sd?.copy(label = "SD"), QualityOption("bestaudio/ba", "Audio", "m4a", null, true, kind = MediaKind.AUDIO)),
        )
    }
}
