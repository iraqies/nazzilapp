package com.iraqitube.app

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

object GallerySaver {
    fun save(context: Context, file: File, title: String): Uri {
        val isAudio = file.extension.lowercase() in setOf("m4a", "mp3", "aac", "opus")
        val mime = when (file.extension.lowercase()) {
            "m4a", "aac" -> "audio/mp4"
            "mp3" -> "audio/mpeg"
            "webm" -> "video/webm"
            else -> "video/mp4"
        }
        val name = file.name.ifBlank { "${title.take(40)}.${file.extension.ifBlank { "mp4" }}" }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (isAudio) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            }
            val folder = if (isAudio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.TITLE, title)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$folder/Nazzil")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("Could not create a gallery item")
            resolver.openOutputStream(uri)?.use { output ->
                file.inputStream().use { input -> input.copyTo(output) }
            } ?: throw IllegalStateException("Could not write the video into Gallery")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri
        }

        val publicDir = File(
            Environment.getExternalStoragePublicDirectory(
                if (isAudio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES,
            ),
            "Nazzil",
        ).apply { mkdirs() }
        val dest = File(publicDir, name)
        file.copyTo(dest, overwrite = true)
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DATA, dest.absolutePath)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.TITLE, title)
        }
        val collection = if (isAudio) MediaStore.Audio.Media.EXTERNAL_CONTENT_URI else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        return context.contentResolver.insert(collection, values) ?: Uri.fromFile(dest)
    }
}
