package com.iraqitube.app

import android.content.Context
import android.util.Log
import java.io.File

object AudioCover {
    fun apply(
        context: Context,
        audio: File,
        thumbnail: String?,
        title: String,
        author: String?,
        pageUrl: String,
    ): File {
        val cover = File(audio.parentFile, "${audio.nameWithoutExtension}-cover.jpg")
        return try {
            if (!saveCover(cover, thumbnail, pageUrl)) return audio
            val ffmpeg = File(context.applicationInfo.nativeLibraryDir, "libffmpeg.so")
            if (!ffmpeg.canExecute() && !ffmpeg.exists()) return audio
            taggedMp3(context, ffmpeg, audio, cover, title, author)
                ?: taggedSameFormat(context, ffmpeg, audio, cover, title, author)
                ?: audio
        } catch (error: Exception) {
            Log.w("Nazzil", "audio cover failed", error)
            audio
        } finally {
            cover.delete()
        }
    }

    private fun saveCover(dest: File, thumbnail: String?, pageUrl: String): Boolean {
        for (url in coverUrls(thumbnail, pageUrl)) {
            try {
                val referer = when {
                    "ytimg" in url || "youtu" in url -> "https://www.youtube.com/"
                    "tiktok" in url -> "https://www.tiktok.com/"
                    "instagram" in url || "cdninstagram" in url -> "https://www.instagram.com/"
                    else -> "https://www.youtube.com/"
                }
                val conn = DirectHttp.open(
                    url,
                    mapOf("Referer" to referer, "Accept" to "image/*"),
                    userAgent = NewPipeHttp.UA,
                )
                dest.outputStream().use { output ->
                    val stream = if (conn.responseCode in 200..299) conn.inputStream else conn.errorStream
                    stream?.use { it.copyTo(output) }
                }
                if (dest.length() >= 400) return true
            } catch (error: Exception) {
                Log.w("Nazzil", "cover download failed $url", error)
            }
        }
        return false
    }

    private fun coverUrls(thumbnail: String?, pageUrl: String): List<String> {
        val id = YouTubeClient.videoId(pageUrl)
        val youtube = if (id != null) {
            listOf(
                "https://i.ytimg.com/vi/$id/maxresdefault.jpg",
                "https://i.ytimg.com/vi/$id/sddefault.jpg",
                "https://i.ytimg.com/vi/$id/hqdefault.jpg",
            )
        } else {
            emptyList()
        }
        return (listOfNotNull(thumbnail?.ifBlank { null }) + youtube).distinct()
    }

    private fun taggedMp3(
        context: Context,
        ffmpeg: File,
        audio: File,
        cover: File,
        title: String,
        author: String?,
    ): File? {
        val out = File(audio.parentFile, "${audio.nameWithoutExtension}.mp3")
        val ok = run(
            context,
            ffmpeg,
            listOf(
                "-y",
                "-i", audio.absolutePath,
                "-i", cover.absolutePath,
                "-map", "0:a",
                "-map", "1",
                "-c:a", "libmp3lame",
                "-q:a", "3",
                "-id3v2_version", "3",
                "-metadata", "title=$title",
                "-metadata", "artist=${author.orEmpty()}",
                "-metadata:s:v", "title=Album cover",
                "-metadata:s:v", "comment=Cover (front)",
                "-disposition:v", "attached_pic",
                out.absolutePath,
            ),
        )
        return out.takeIf { ok && it.length() > 1000 }
    }

    private fun taggedSameFormat(
        context: Context,
        ffmpeg: File,
        audio: File,
        cover: File,
        title: String,
        author: String?,
    ): File? {
        val ext = audio.extension.ifBlank { "m4a" }
        val out = File(audio.parentFile, "${audio.nameWithoutExtension}-art.$ext")
        val args = mutableListOf(
            "-y",
            "-i", audio.absolutePath,
            "-i", cover.absolutePath,
            "-map", "0:a",
            "-map", "1",
            "-c", "copy",
            "-metadata", "title=$title",
            "-metadata", "artist=${author.orEmpty()}",
            "-disposition:v", "attached_pic",
        )
        if (ext == "mp3") args += listOf("-id3v2_version", "3")
        args += out.absolutePath
        val ok = run(context, ffmpeg, args)
        if (!ok || out.length() < 1000) return null
        audio.delete()
        val final = File(audio.parentFile, "${audio.nameWithoutExtension}.$ext")
        return if (out.renameTo(final)) final else out
    }

    private fun run(context: Context, ffmpeg: File, args: List<String>): Boolean {
        val ffmpegDir = File(context.noBackupFilesDir, "youtubedl-android/packages/ffmpeg")
        val process = ProcessBuilder(listOf(ffmpeg.absolutePath) + args)
            .redirectErrorStream(true)
            .apply {
                environment()["LD_LIBRARY_PATH"] =
                    "${ffmpegDir.absolutePath}/usr/lib:${context.applicationInfo.nativeLibraryDir}"
            }
            .start()
        val log = process.inputStream.bufferedReader().use { it.readText() }
        val code = process.waitFor()
        if (code != 0) Log.w("Nazzil", "ffmpeg cover exit $code $log")
        return code == 0
    }
}
