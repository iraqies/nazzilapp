package com.iraqitube.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class SavedVideo(
    val id: String,
    val title: String,
    val author: String?,
    val platform: String,
    val path: String,
    val galleryUri: String?,
    val quality: String,
    val createdAt: Long,
    val thumbnail: String?,
)

class LibraryStore(context: Context) {
    private val prefs = context.getSharedPreferences("iraqitube.library", Context.MODE_PRIVATE)

    fun all(): List<SavedVideo> {
        val raw = prefs.getString("items", "[]") ?: "[]"
        val array = JSONArray(raw)
        return buildList {
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val path = obj.optString("path")
                if (!File(path).exists()) continue
                add(
                    SavedVideo(
                        id = obj.optString("id"),
                        title = obj.optString("title"),
                        author = obj.optString("author").ifBlank { null },
                        platform = obj.optString("platform"),
                        path = path,
                        galleryUri = obj.optString("galleryUri").ifBlank { null },
                        quality = obj.optString("quality"),
                        createdAt = obj.optLong("createdAt"),
                        thumbnail = obj.optString("thumbnail").ifBlank { null },
                    ),
                )
            }
        }
    }

    fun add(item: SavedVideo) {
        val next = listOf(item) + all().filter { it.id != item.id }
        save(next.take(200))
    }

    fun remove(id: String) {
        val current = all()
        current.find { it.id == id }?.let { File(it.path).delete() }
        save(current.filter { it.id != id })
    }

    private fun save(items: List<SavedVideo>) {
        val array = JSONArray()
        items.forEach { item ->
            array.put(
                JSONObject()
                    .put("id", item.id)
                    .put("title", item.title)
                    .put("author", item.author ?: "")
                    .put("platform", item.platform)
                    .put("path", item.path)
                    .put("galleryUri", item.galleryUri ?: "")
                    .put("quality", item.quality)
                    .put("createdAt", item.createdAt)
                    .put("thumbnail", item.thumbnail ?: ""),
            )
        }
        prefs.edit().putString("items", array.toString()).apply()
    }
}
