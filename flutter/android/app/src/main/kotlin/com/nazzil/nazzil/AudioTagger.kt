package com.nazzil.nazzil

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

object AudioTagger {
    fun apply(
        audio: File,
        title: String,
        author: String?,
        coverPath: String?,
        lyricsPlain: String?,
        lyricsSynced: String?,
    ): File {
        return try {
            val file = namedForFormat(audio)
            val jpeg = loadJpeg(coverPath)
            val lyrics = Lyrics(lyricsPlain?.trim().orEmpty(), lyricsSynced?.trim()?.ifBlank { null })
            if (jpeg == null && lyrics.forTag.isBlank()) return file
            val meta = TagMeta(title, author, jpeg, lyrics.takeIf { it.forTag.isNotBlank() })
            val tagged = when (sniff(file)) {
                Format.MP4 -> embedM4a(file, meta) ?: file
                Format.MP3, Format.ADTS -> embedMp3(file, meta)
                Format.UNKNOWN -> when (file.extension.lowercase()) {
                    "mp3" -> embedMp3(file, meta)
                    "m4a", "mp4", "aac" -> embedM4a(file, meta) ?: file
                    else -> file
                }
            }
            jpeg?.let { File(tagged.parentFile, "${tagged.name}.cover").writeBytes(it) }
            lyrics.synced?.let { File(tagged.parentFile, "${tagged.nameWithoutExtension}.lrc").writeText(it) }
            tagged
        } catch (error: Exception) {
            Log.w("Nazzil", "audio tag failed", error)
            audio
        }
    }

    private data class Lyrics(val plain: String, val synced: String?) {
        val forTag: String get() = synced?.ifBlank { null } ?: plain
    }

    private fun loadJpeg(coverPath: String?): ByteArray? {
        if (coverPath.isNullOrBlank()) return null
        val file = File(coverPath)
        if (!file.exists() || file.length() < 32) return null
        val raw = file.readBytes()
        val bitmap = BitmapFactory.decodeByteArray(raw, 0, raw.size) ?: return raw.takeIf { it.size >= 400 }
        return toJpeg(bitmap) ?: raw.takeIf { it.size >= 400 }
    }

    private fun toJpeg(bitmap: Bitmap): ByteArray? {
        val longest = maxOf(bitmap.width, bitmap.height)
        val scaled = if (longest > 720) {
            val scale = 720f / longest
            Bitmap.createScaledBitmap(
                bitmap,
                (bitmap.width * scale).toInt().coerceAtLeast(1),
                (bitmap.height * scale).toInt().coerceAtLeast(1),
                true,
            )
        } else {
            bitmap
        }
        val out = ByteArrayOutputStream()
        val ok = scaled.compress(Bitmap.CompressFormat.JPEG, 90, out)
        if (scaled !== bitmap) scaled.recycle()
        bitmap.recycle()
        return out.toByteArray().takeIf { ok && it.size >= 400 }
    }

    private enum class Format { MP3, MP4, ADTS, UNKNOWN }

    private fun sniff(file: File): Format {
        return file.inputStream().use { stream ->
            val head = ByteArray(16)
            val n = stream.read(head)
            if (n < 4) return@use Format.UNKNOWN
            if (head[0] == 'I'.code.toByte() && head[1] == 'D'.code.toByte() && head[2] == '3'.code.toByte()) {
                val skip = synchsafe(head, 6) - (n - 10).coerceAtLeast(0)
                var left = skip.toLong().coerceAtLeast(0L)
                while (left > 0) {
                    val gone = stream.skip(left)
                    if (gone <= 0) break
                    left -= gone
                }
                val body = ByteArray(12)
                stream.read(body)
                kindOf(body)
            } else {
                kindOf(head)
            }
        }
    }

    private fun kindOf(bytes: ByteArray): Format {
        if (bytes.size >= 8 &&
            bytes[4] == 'f'.code.toByte() &&
            bytes[5] == 't'.code.toByte() &&
            bytes[6] == 'y'.code.toByte() &&
            bytes[7] == 'p'.code.toByte()
        ) {
            return Format.MP4
        }
        if (bytes.size >= 2 && bytes[0] == 0xFF.toByte() && (bytes[1].toInt() and 0xE0) == 0xE0) {
            val layer = (bytes[1].toInt() shr 1) and 3
            return if (layer == 1) Format.MP3 else Format.ADTS
        }
        return Format.UNKNOWN
    }

    private fun namedForFormat(file: File): File {
        val ext = when (sniff(file)) {
            Format.MP4 -> "m4a"
            Format.MP3, Format.ADTS -> "mp3"
            Format.UNKNOWN -> return file
        }
        if (file.extension.equals(ext, ignoreCase = true)) return file
        var index = 0
        var dest: File
        while (true) {
            dest = File(
                file.parentFile,
                if (index == 0) "${file.nameWithoutExtension}.$ext" else "${file.nameWithoutExtension}-$index.$ext",
            )
            if (!dest.exists()) break
            index += 1
        }
        return if (file.renameTo(dest)) dest else file
    }

    private data class TagMeta(
        val title: String,
        val author: String?,
        val jpeg: ByteArray?,
        val lyrics: Lyrics?,
    )

    private fun embedMp3(audio: File, meta: TagMeta): File {
        val body = stripId3(audio.readBytes())
        val tag = id3Tag(meta)
        audio.writeBytes(tag + body)
        return audio
    }

    private fun stripId3(data: ByteArray): ByteArray {
        if (data.size < 10 || data[0] != 'I'.code.toByte() || data[1] != 'D'.code.toByte() || data[2] != '3'.code.toByte()) {
            return data
        }
        val size = synchsafe(data, 6)
        val end = 10 + size
        return if (end in 10..data.size) data.copyOfRange(end, data.size) else data
    }

    private fun id3Tag(meta: TagMeta): ByteArray {
        val parts = ArrayList<ByteArray>()
        meta.jpeg?.let { parts += apicFrame(it) }
        parts += textFrame("TIT2", meta.title)
        parts += textFrame("TPE1", meta.author?.ifBlank { null } ?: "Nazzil")
        parts += textFrame("TALB", meta.title)
        meta.lyrics?.forTag?.takeIf { it.isNotBlank() }?.let { parts += usltFrame(it) }
        meta.lyrics?.synced?.let { lrc ->
            val lines = parseLrc(lrc)
            if (lines.isNotEmpty()) parts += syltFrame(lines)
        }
        parts += ByteArray(2048)
        val frames = concat(*parts.toTypedArray())
        val header = ByteArray(10)
        header[0] = 'I'.code.toByte()
        header[1] = 'D'.code.toByte()
        header[2] = '3'.code.toByte()
        header[3] = 3
        putSynchsafe(header, 6, frames.size)
        return header + frames
    }

    private fun textFrame(id: String, text: String): ByteArray {
        val encoded = byteArrayOf(1, 0xFF.toByte(), 0xFE.toByte()) +
            text.toByteArray(Charsets.UTF_16LE) +
            byteArrayOf(0, 0)
        return id3Frame(id, encoded)
    }

    private fun usltFrame(text: String): ByteArray {
        val body = ByteArrayOutputStream()
        body.write(1)
        body.write("eng".toByteArray(Charsets.ISO_8859_1))
        body.write(byteArrayOf(0xFF.toByte(), 0xFE.toByte(), 0, 0))
        body.write(byteArrayOf(0xFF.toByte(), 0xFE.toByte()))
        body.write(text.toByteArray(Charsets.UTF_16LE))
        body.write(byteArrayOf(0, 0))
        return id3Frame("USLT", body.toByteArray())
    }

    private fun syltFrame(lines: List<Pair<Int, String>>): ByteArray {
        val body = ByteArrayOutputStream()
        body.write(1)
        body.write("eng".toByteArray(Charsets.ISO_8859_1))
        body.write(2)
        body.write(1)
        body.write(byteArrayOf(0xFF.toByte(), 0xFE.toByte(), 0, 0))
        for ((stamp, text) in lines) {
            body.write(text.toByteArray(Charsets.UTF_16LE))
            body.write(byteArrayOf(0, 0))
            val time = ByteArray(4)
            putU32(time, 0, stamp)
            body.write(time)
        }
        return id3Frame("SYLT", body.toByteArray())
    }

    private fun apicFrame(jpeg: ByteArray): ByteArray {
        val mime = "image/jpeg".toByteArray(Charsets.ISO_8859_1)
        val body = ByteArrayOutputStream()
        body.write(0)
        body.write(mime)
        body.write(0)
        body.write(3)
        body.write(0)
        body.write(jpeg)
        return id3Frame("APIC", body.toByteArray())
    }

    private fun id3Frame(id: String, body: ByteArray): ByteArray {
        val frame = ByteArray(10 + body.size)
        val name = id.toByteArray(Charsets.ISO_8859_1)
        System.arraycopy(name, 0, frame, 0, 4)
        putU32(frame, 4, body.size)
        System.arraycopy(body, 0, frame, 10, body.size)
        return frame
    }

    private fun embedM4a(audio: File, tags: TagMeta): File? {
        val data = audio.readBytes()
        val boxes = parseBoxes(data, 0, data.size)
        val moov = boxes.firstOrNull { it.type == "moov" } ?: return null
        val mdat = boxes.firstOrNull { it.type == "mdat" }
        val oldMoov = data.copyOfRange(moov.start, moov.start + moov.size)
        val newMoov = addItunesTags(oldMoov, tags)
        val delta = newMoov.size - oldMoov.size
        val patched = if (mdat != null && moov.start < mdat.start && delta != 0) {
            patchChunkOffsets(newMoov, delta)
        } else {
            newMoov
        }
        val out = ByteArrayOutputStream(data.size + delta.coerceAtLeast(0) + 1024)
        var pos = 0
        for (box in boxes) {
            if (box.start > pos) out.write(data, pos, box.start - pos)
            if (box.type == "moov") out.write(patched) else out.write(data, box.start, box.size)
            pos = box.start + box.size
        }
        if (pos < data.size) out.write(data, pos, data.size - pos)
        audio.writeBytes(out.toByteArray())
        return audio
    }

    private fun addItunesTags(moov: ByteArray, tags: TagMeta): ByteArray {
        val children = parseBoxes(moov, 8, moov.size)
        val pieces = ArrayList<ByteArray>()
        var foundUdta = false
        for (child in children) {
            val bytes = moov.copyOfRange(child.start, child.start + child.size)
            if (child.type == "udta") {
                foundUdta = true
                pieces.add(mergeUdta(bytes, tags))
            } else {
                pieces.add(bytes)
            }
        }
        if (!foundUdta) pieces.add(makeUdta(tags))
        return box("moov", concat(*pieces.toTypedArray()))
    }

    private fun mergeUdta(udta: ByteArray, tags: TagMeta): ByteArray {
        val children = parseBoxes(udta, 8, udta.size)
        val pieces = ArrayList<ByteArray>()
        var foundMeta = false
        for (child in children) {
            val bytes = udta.copyOfRange(child.start, child.start + child.size)
            if (child.type == "meta") {
                foundMeta = true
                pieces.add(mergeMeta(bytes, tags))
            } else {
                pieces.add(bytes)
            }
        }
        if (!foundMeta) pieces.add(makeMeta(makeIlst(tags)))
        return box("udta", concat(*pieces.toTypedArray()))
    }

    private fun mergeMeta(meta: ByteArray, tags: TagMeta): ByteArray {
        val version = meta.copyOfRange(8, minOf(12, meta.size))
        val children = parseBoxes(meta, 12, meta.size)
        val pieces = ArrayList<ByteArray>()
        var foundIlst = false
        var foundHdlr = false
        for (child in children) {
            val bytes = meta.copyOfRange(child.start, child.start + child.size)
            when (child.type) {
                "ilst" -> {
                    foundIlst = true
                    pieces.add(mergeIlst(bytes, tags))
                }
                "hdlr" -> {
                    foundHdlr = true
                    pieces.add(bytes)
                }
                else -> pieces.add(bytes)
            }
        }
        if (!foundHdlr) pieces.add(0, hdlrMdir())
        if (!foundIlst) pieces.add(makeIlst(tags))
        val payload = ByteArrayOutputStream()
        payload.write(if (version.size == 4) version else ByteArray(4))
        payload.write(concat(*pieces.toTypedArray()))
        return box("meta", payload.toByteArray())
    }

    private fun mergeIlst(ilst: ByteArray, tags: TagMeta): ByteArray {
        val children = parseBoxes(ilst, 8, ilst.size)
        val skip = buildSet {
            add("©nam")
            add("©ART")
            add("©alb")
            if (tags.jpeg != null) add("covr")
            if (tags.lyrics != null) add("©lyr")
        }
        val pieces = ArrayList<ByteArray>()
        for (child in children) {
            if (child.type in skip) continue
            pieces.add(ilst.copyOfRange(child.start, child.start + child.size))
        }
        pieces.addAll(ilstAtoms(tags))
        return box("ilst", concat(*pieces.toTypedArray()))
    }

    private fun makeUdta(tags: TagMeta): ByteArray {
        return box("udta", makeMeta(makeIlst(tags)))
    }

    private fun makeMeta(ilst: ByteArray): ByteArray {
        return box("meta", ByteArray(4) + hdlrMdir() + ilst)
    }

    private fun makeIlst(tags: TagMeta): ByteArray {
        return box("ilst", concat(*ilstAtoms(tags).toTypedArray()))
    }

    private fun ilstAtoms(tags: TagMeta): List<ByteArray> {
        val parts = ArrayList<ByteArray>()
        parts += tag("©nam", dataAtom(tags.title.toByteArray(Charsets.UTF_8), 1))
        parts += tag("©ART", dataAtom((tags.author?.ifBlank { null } ?: "Nazzil").toByteArray(Charsets.UTF_8), 1))
        parts += tag("©alb", dataAtom(tags.title.toByteArray(Charsets.UTF_8), 1))
        tags.jpeg?.let { parts += tag("covr", dataAtom(it, 13)) }
        tags.lyrics?.forTag?.takeIf { it.isNotBlank() }?.let {
            parts += tag("©lyr", dataAtom(it.toByteArray(Charsets.UTF_8), 1))
        }
        return parts
    }

    private fun hdlrMdir(): ByteArray {
        val payload = ByteArray(26)
        "mdir".toByteArray(Charsets.ISO_8859_1).copyInto(payload, 8)
        "appl".toByteArray(Charsets.ISO_8859_1).copyInto(payload, 12)
        return box("hdlr", payload)
    }

    private fun tag(name: String, child: ByteArray): ByteArray = box(name, child)

    private fun dataAtom(payload: ByteArray, typeFlag: Int): ByteArray {
        val body = ByteArray(8 + payload.size)
        putU32(body, 0, typeFlag)
        System.arraycopy(payload, 0, body, 8, payload.size)
        return box("data", body)
    }

    private fun box(type: String, payload: ByteArray): ByteArray {
        val out = ByteArray(8 + payload.size)
        putU32(out, 0, out.size)
        val name = type.toByteArray(Charsets.ISO_8859_1)
        System.arraycopy(name, 0, out, 4, minOf(4, name.size))
        System.arraycopy(payload, 0, out, 8, payload.size)
        return out
    }

    private fun patchChunkOffsets(moov: ByteArray, delta: Int): ByteArray {
        val out = moov.copyOf()
        val containers = setOf("moov", "trak", "mdia", "minf", "dinf", "stbl", "udta", "edts", "mvex")
        fun walk(from: Int, to: Int, headerSkip: Int) {
            var pos = from + headerSkip
            while (pos + 8 <= to) {
                val size = u32(out, pos)
                val type = latin(out, pos + 4, 4)
                if (size < 8 || pos + size > to) break
                when (type) {
                    "stco" -> patchStco(out, pos, size, delta)
                    "co64" -> patchCo64(out, pos, size, delta)
                    "meta" -> walk(pos, pos + size, 12)
                    in containers -> walk(pos, pos + size, 8)
                }
                pos += size
            }
        }
        walk(0, out.size, 8)
        return out
    }

    private fun patchStco(buf: ByteArray, pos: Int, size: Int, delta: Int) {
        val count = u32(buf, pos + 12)
        var p = pos + 16
        repeat(count) {
            if (p + 4 > pos + size) return
            putU32(buf, p, u32(buf, p) + delta)
            p += 4
        }
    }

    private fun patchCo64(buf: ByteArray, pos: Int, size: Int, delta: Int) {
        val count = u32(buf, pos + 12)
        var p = pos + 16
        repeat(count) {
            if (p + 8 > pos + size) return
            val value = ByteBuffer.wrap(buf, p, 8).order(ByteOrder.BIG_ENDIAN).long + delta
            ByteBuffer.wrap(buf, p, 8).order(ByteOrder.BIG_ENDIAN).putLong(value)
            p += 8
        }
    }

    private data class Box(val type: String, val start: Int, val size: Int)

    private fun parseBoxes(data: ByteArray, from: Int, to: Int): List<Box> {
        val list = ArrayList<Box>()
        var pos = from
        while (pos + 8 <= to) {
            var size = u32(data, pos)
            val type = latin(data, pos + 4, 4)
            if (size == 1 && pos + 16 <= to) {
                val large = ByteBuffer.wrap(data, pos + 8, 8).order(ByteOrder.BIG_ENDIAN).long
                if (large < 16 || large > Int.MAX_VALUE) break
                size = large.toInt()
            } else if (size == 0) {
                size = to - pos
            }
            if (size < 8 || pos + size > to) break
            list.add(Box(type, pos, size))
            pos += size
        }
        return list
    }

    private fun concat(vararg parts: ByteArray): ByteArray {
        val out = ByteArray(parts.sumOf { it.size })
        var at = 0
        for (part in parts) {
            System.arraycopy(part, 0, out, at, part.size)
            at += part.size
        }
        return out
    }

    private fun latin(data: ByteArray, at: Int, n: Int): String {
        return String(data, at, n, Charsets.ISO_8859_1)
    }

    private fun u32(data: ByteArray, at: Int): Int {
        return ((data[at].toInt() and 0xFF) shl 24) or
            ((data[at + 1].toInt() and 0xFF) shl 16) or
            ((data[at + 2].toInt() and 0xFF) shl 8) or
            (data[at + 3].toInt() and 0xFF)
    }

    private fun putU32(data: ByteArray, at: Int, value: Int) {
        data[at] = (value ushr 24).toByte()
        data[at + 1] = (value ushr 16).toByte()
        data[at + 2] = (value ushr 8).toByte()
        data[at + 3] = value.toByte()
    }

    private fun synchsafe(data: ByteArray, at: Int): Int {
        return ((data[at].toInt() and 0x7F) shl 21) or
            ((data[at + 1].toInt() and 0x7F) shl 14) or
            ((data[at + 2].toInt() and 0x7F) shl 7) or
            (data[at + 3].toInt() and 0x7F)
    }

    private fun putSynchsafe(data: ByteArray, at: Int, value: Int) {
        data[at] = ((value ushr 21) and 0x7F).toByte()
        data[at + 1] = ((value ushr 14) and 0x7F).toByte()
        data[at + 2] = ((value ushr 7) and 0x7F).toByte()
        data[at + 3] = (value and 0x7F).toByte()
    }

    private fun parseLrc(text: String): List<Pair<Int, String>> {
        val rx = Regex("""\[(\d+):(\d+)(?:[.:](\d+))?\]\s*(.*)""")
        return text.lineSequence().mapNotNull { line ->
            val match = rx.find(line.trim()) ?: return@mapNotNull null
            val min = match.groupValues[1].toIntOrNull() ?: return@mapNotNull null
            val sec = match.groupValues[2].toIntOrNull() ?: return@mapNotNull null
            val frac = match.groupValues[3]
            val millis = when {
                frac.isEmpty() -> 0
                frac.length <= 3 -> frac.padEnd(3, '0').toIntOrNull() ?: 0
                else -> frac.take(3).toIntOrNull() ?: 0
            }
            val words = match.groupValues[4].trim()
            if (words.isEmpty()) null else (min * 60_000 + sec * 1000 + millis) to words
        }.toList()
    }
}
