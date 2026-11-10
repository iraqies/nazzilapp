import UIKit

enum NazzilAudioTagger {
  static func apply(
    path: String,
    title: String,
    author: String?,
    coverPath: String?,
    lyricsPlain: String?,
    lyricsSynced: String?
  ) -> String {
    let original = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else { return path }
    do {
      let file = namedForFormat(original)
      let jpeg = loadJpeg(coverPath)
      let lyrics = Lyrics(plain: lyricsPlain?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", synced: {
        let value = lyricsSynced?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
      }())
      if jpeg == nil && lyrics.forTag.isEmpty { return file.path }
      let meta = TagMeta(title: title, author: author, jpeg: jpeg, lyrics: lyrics.forTag.isEmpty ? nil : lyrics)
      let tagged: URL
      switch sniff(file) {
      case .mp4:
        tagged = embedM4a(file, meta) ?? file
      case .mp3, .adts:
        tagged = embedMp3(file, meta)
      case .unknown:
        switch file.pathExtension.lowercased() {
        case "mp3":
          tagged = embedMp3(file, meta)
        case "m4a", "mp4", "aac":
          tagged = embedM4a(file, meta) ?? file
        default:
          tagged = file
        }
      }
      if let jpeg {
        try? jpeg.write(to: tagged.appendingPathExtension("cover"), options: .atomic)
      }
      if let synced = lyrics.synced {
        let lrc = tagged.deletingPathExtension().appendingPathExtension("lrc")
        try? synced.write(to: lrc, atomically: true, encoding: .utf8)
      }
      return tagged.path
    } catch {
      return path
    }
  }

  private struct Lyrics {
    let plain: String
    let synced: String?
    var forTag: String { synced?.isEmpty == false ? synced! : plain }
  }

  private struct TagMeta {
    let title: String
    let author: String?
    let jpeg: Data?
    let lyrics: Lyrics?
  }

  private enum Format { case mp3, mp4, adts, unknown }

  private static func loadJpeg(_ coverPath: String?) -> Data? {
    guard let coverPath, !coverPath.isEmpty else { return nil }
    let url = URL(fileURLWithPath: coverPath)
    guard let data = try? Data(contentsOf: url), data.count >= 32 else { return nil }
    guard let image = UIImage(data: data) else { return data.count >= 400 ? data : nil }
    let longest = max(image.size.width, image.size.height)
    let scale = longest > 720 ? 720 / longest : 1
    let size = CGSize(width: max(image.size.width * scale, 1), height: max(image.size.height * scale, 1))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let jpeg = renderer.jpegData(withCompressionQuality: 0.9) { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }
    return jpeg.count >= 400 ? jpeg : (data.count >= 400 ? data : nil)
  }

  private static func sniff(_ file: URL) -> Format {
    guard let handle = try? FileHandle(forReadingFrom: file) else { return .unknown }
    defer { try? handle.close() }
    var head = handle.readData(ofLength: 16)
    if head.count < 4 { return .unknown }
    let bytes = Array(head)
    if bytes[0] == 0x49, bytes[1] == 0x44, bytes[2] == 0x33 {
      let skip = max(synchsafe(bytes, 6) - max(head.count - 10, 0), 0)
      if skip > 0 { _ = try? handle.read(upToCount: skip) }
      let body = Array(handle.readData(ofLength: 12))
      return kindOf(body)
    }
    return kindOf(bytes)
  }

  private static func kindOf(_ bytes: [UInt8]) -> Format {
    if bytes.count >= 8, bytes[4] == 0x66, bytes[5] == 0x74, bytes[6] == 0x79, bytes[7] == 0x70 {
      return .mp4
    }
    if bytes.count >= 2, bytes[0] == 0xFF, (bytes[1] & 0xE0) == 0xE0 {
      let layer = (Int(bytes[1]) >> 1) & 3
      return layer == 1 ? .mp3 : .adts
    }
    return .unknown
  }

  private static func namedForFormat(_ file: URL) -> URL {
    let ext: String
    switch sniff(file) {
    case .mp4: ext = "m4a"
    case .mp3, .adts: ext = "mp3"
    case .unknown: return file
    }
    if file.pathExtension.lowercased() == ext { return file }
    var index = 0
    var dest: URL
    repeat {
      let name = index == 0
        ? "\(file.deletingPathExtension().lastPathComponent).\(ext)"
        : "\(file.deletingPathExtension().lastPathComponent)-\(index).\(ext)"
      dest = file.deletingLastPathComponent().appendingPathComponent(name)
      index += 1
    } while FileManager.default.fileExists(atPath: dest.path)
    do {
      try FileManager.default.moveItem(at: file, to: dest)
      return dest
    } catch {
      return file
    }
  }

  private static func embedMp3(_ audio: URL, _ meta: TagMeta) -> URL {
    guard let data = try? Data(contentsOf: audio) else { return audio }
    let body = stripId3(Array(data))
    let tagged = Data(id3Tag(meta) + body)
    try? tagged.write(to: audio, options: .atomic)
    return audio
  }

  private static func stripId3(_ data: [UInt8]) -> [UInt8] {
    if data.count < 10 || data[0] != 0x49 || data[1] != 0x44 || data[2] != 0x33 { return data }
    let end = 10 + synchsafe(data, 6)
    if end >= 10 && end <= data.count { return Array(data[end...]) }
    return data
  }

  private static func id3Tag(_ meta: TagMeta) -> [UInt8] {
    var parts: [[UInt8]] = []
    if let jpeg = meta.jpeg { parts.append(apicFrame(jpeg)) }
    parts.append(textFrame("TIT2", meta.title))
    parts.append(textFrame("TPE1", meta.author?.isEmpty == false ? meta.author! : "Nazzil"))
    parts.append(textFrame("TALB", meta.title))
    if let lyrics = meta.lyrics?.forTag, !lyrics.isEmpty { parts.append(usltFrame(lyrics)) }
    if let synced = meta.lyrics?.synced {
      let lines = parseLrc(synced)
      if !lines.isEmpty { parts.append(syltFrame(lines)) }
    }
    parts.append(Array(repeating: 0, count: 2048))
    let frames = concat(parts)
    var header = [UInt8](repeating: 0, count: 10)
    header[0] = 0x49
    header[1] = 0x44
    header[2] = 0x33
    header[3] = 3
    putSynchsafe(&header, 6, frames.count)
    return header + frames
  }

  private static func textFrame(_ id: String, _ text: String) -> [UInt8] {
    id3Frame(id, [1, 0xFF, 0xFE] + utf16le(text) + [0, 0])
  }

  private static func usltFrame(_ text: String) -> [UInt8] {
    var body: [UInt8] = [1]
    body += latin("eng")
    body += [0xFF, 0xFE, 0, 0, 0xFF, 0xFE]
    body += utf16le(text)
    body += [0, 0]
    return id3Frame("USLT", body)
  }

  private static func syltFrame(_ lines: [(Int, String)]) -> [UInt8] {
    var body: [UInt8] = [1]
    body += latin("eng")
    body += [2, 1, 0xFF, 0xFE, 0, 0]
    for (stamp, text) in lines {
      body += [0xFF, 0xFE]
      body += utf16le(text)
      body += [0, 0]
      var time = [UInt8](repeating: 0, count: 4)
      putU32(&time, 0, stamp)
      body += time
    }
    return id3Frame("SYLT", body)
  }

  private static func apicFrame(_ jpeg: Data) -> [UInt8] {
    var body: [UInt8] = [0]
    body += latin("image/jpeg")
    body += [0, 3, 0]
    body += Array(jpeg)
    return id3Frame("APIC", body)
  }

  private static func id3Frame(_ id: String, _ body: [UInt8]) -> [UInt8] {
    var frame = [UInt8](repeating: 0, count: 10 + body.count)
    let name = latin(id)
    for i in 0..<min(4, name.count) { frame[i] = name[i] }
    putU32(&frame, 4, body.count)
    for i in 0..<body.count { frame[10 + i] = body[i] }
    return frame
  }

  private static func embedM4a(_ audio: URL, _ tags: TagMeta) -> URL? {
    guard let data = try? Data(contentsOf: audio) else { return nil }
    let bytes = Array(data)
    let boxes = parseBoxes(bytes, 0, bytes.count)
    guard let moov = boxes.first(where: { $0.type == "moov" }) else { return nil }
    let mdat = boxes.first(where: { $0.type == "mdat" })
    let oldMoov = Array(bytes[moov.start..<(moov.start + moov.size)])
    var newMoov = addItunesTags(oldMoov, tags)
    let delta = newMoov.count - oldMoov.count
    if let mdat, moov.start < mdat.start, delta != 0 {
      newMoov = patchChunkOffsets(newMoov, delta)
    }
    var out: [UInt8] = []
    var pos = 0
    for box in boxes {
      if box.start > pos { out += bytes[pos..<box.start] }
      if box.type == "moov" {
        out += newMoov
      } else {
        out += bytes[box.start..<(box.start + box.size)]
      }
      pos = box.start + box.size
    }
    if pos < bytes.count { out += bytes[pos...] }
    try? Data(out).write(to: audio, options: .atomic)
    return audio
  }

  private static func addItunesTags(_ moov: [UInt8], _ tags: TagMeta) -> [UInt8] {
    let children = parseBoxes(moov, 8, moov.count)
    var pieces: [[UInt8]] = []
    var foundUdta = false
    for child in children {
      let bytes = Array(moov[child.start..<(child.start + child.size)])
      if child.type == "udta" {
        foundUdta = true
        pieces.append(mergeUdta(bytes, tags))
      } else {
        pieces.append(bytes)
      }
    }
    if !foundUdta { pieces.append(makeUdta(tags)) }
    return box("moov", concat(pieces))
  }

  private static func mergeUdta(_ udta: [UInt8], _ tags: TagMeta) -> [UInt8] {
    let children = parseBoxes(udta, 8, udta.count)
    var pieces: [[UInt8]] = []
    var foundMeta = false
    for child in children {
      let bytes = Array(udta[child.start..<(child.start + child.size)])
      if child.type == "meta" {
        foundMeta = true
        pieces.append(mergeMeta(bytes, tags))
      } else {
        pieces.append(bytes)
      }
    }
    if !foundMeta { pieces.append(makeMeta(makeIlst(tags))) }
    return box("udta", concat(pieces))
  }

  private static func mergeMeta(_ meta: [UInt8], _ tags: TagMeta) -> [UInt8] {
    let version = Array(meta[8..<min(12, meta.count)])
    let children = parseBoxes(meta, 12, meta.count)
    var pieces: [[UInt8]] = []
    var foundIlst = false
    var foundHdlr = false
    for child in children {
      let bytes = Array(meta[child.start..<(child.start + child.size)])
      switch child.type {
      case "ilst":
        foundIlst = true
        pieces.append(mergeIlst(bytes, tags))
      case "hdlr":
        foundHdlr = true
        pieces.append(bytes)
      default:
        pieces.append(bytes)
      }
    }
    if !foundHdlr { pieces.insert(hdlrMdir(), at: 0) }
    if !foundIlst { pieces.append(makeIlst(tags)) }
    return box("meta", (version.count == 4 ? version : [UInt8](repeating: 0, count: 4)) + concat(pieces))
  }

  private static func mergeIlst(_ ilst: [UInt8], _ tags: TagMeta) -> [UInt8] {
    var skip: Set<String> = ["©nam", "©ART", "©alb"]
    if tags.jpeg != nil { skip.insert("covr") }
    if tags.lyrics != nil { skip.insert("©lyr") }
    let children = parseBoxes(ilst, 8, ilst.count)
    var pieces: [[UInt8]] = []
    for child in children {
      if skip.contains(child.type) { continue }
      pieces.append(Array(ilst[child.start..<(child.start + child.size)]))
    }
    pieces.append(contentsOf: ilstAtoms(tags))
    return box("ilst", concat(pieces))
  }

  private static func makeUdta(_ tags: TagMeta) -> [UInt8] { box("udta", makeMeta(makeIlst(tags))) }
  private static func makeMeta(_ ilst: [UInt8]) -> [UInt8] { box("meta", [0, 0, 0, 0] + hdlrMdir() + ilst) }
  private static func makeIlst(_ tags: TagMeta) -> [UInt8] { box("ilst", concat(ilstAtoms(tags))) }

  private static func ilstAtoms(_ tags: TagMeta) -> [[UInt8]] {
    var parts: [[UInt8]] = []
    parts.append(tag("©nam", dataAtom(Array(tags.title.utf8), 1)))
    parts.append(tag("©ART", dataAtom(Array((tags.author?.isEmpty == false ? tags.author! : "Nazzil").utf8), 1)))
    parts.append(tag("©alb", dataAtom(Array(tags.title.utf8), 1)))
    if let jpeg = tags.jpeg { parts.append(tag("covr", dataAtom(Array(jpeg), 13))) }
    if let lyrics = tags.lyrics?.forTag, !lyrics.isEmpty {
      parts.append(tag("©lyr", dataAtom(Array(lyrics.utf8), 1)))
    }
    return parts
  }

  private static func hdlrMdir() -> [UInt8] {
    var payload = [UInt8](repeating: 0, count: 26)
    let mdir = latin("mdir")
    let appl = latin("appl")
    for i in 0..<4 { payload[8 + i] = mdir[i]; payload[12 + i] = appl[i] }
    return box("hdlr", payload)
  }

  private static func tag(_ name: String, _ child: [UInt8]) -> [UInt8] { box(name, child) }

  private static func dataAtom(_ payload: [UInt8], _ typeFlag: Int) -> [UInt8] {
    var body = [UInt8](repeating: 0, count: 8 + payload.count)
    putU32(&body, 0, typeFlag)
    for i in 0..<payload.count { body[8 + i] = payload[i] }
    return box("data", body)
  }

  private static func box(_ type: String, _ payload: [UInt8]) -> [UInt8] {
    var out = [UInt8](repeating: 0, count: 8 + payload.count)
    putU32(&out, 0, out.count)
    let name = latin(type)
    for i in 0..<min(4, name.count) { out[4 + i] = name[i] }
    for i in 0..<payload.count { out[8 + i] = payload[i] }
    return out
  }

  private static func patchChunkOffsets(_ moov: [UInt8], _ delta: Int) -> [UInt8] {
    var out = moov
    let containers: Set<String> = ["moov", "trak", "mdia", "minf", "dinf", "stbl", "udta", "edts", "mvex"]
    func walk(_ from: Int, _ to: Int, _ headerSkip: Int) {
      var pos = from + headerSkip
      while pos + 8 <= to {
        let size = u32(out, pos)
        let type = latin(out, pos + 4, 4)
        if size < 8 || pos + size > to { break }
        switch type {
        case "stco": patchStco(&out, pos, size, delta)
        case "co64": patchCo64(&out, pos, size, delta)
        case "meta": walk(pos, pos + size, 12)
        default:
          if containers.contains(type) { walk(pos, pos + size, 8) }
        }
        pos += size
      }
    }
    walk(0, out.count, 8)
    return out
  }

  private static func patchStco(_ buf: inout [UInt8], _ pos: Int, _ size: Int, _ delta: Int) {
    let count = u32(buf, pos + 12)
    var p = pos + 16
    for _ in 0..<count {
      if p + 4 > pos + size { return }
      putU32(&buf, p, u32(buf, p) + delta)
      p += 4
    }
  }

  private static func patchCo64(_ buf: inout [UInt8], _ pos: Int, _ size: Int, _ delta: Int) {
    let count = u32(buf, pos + 12)
    var p = pos + 16
    for _ in 0..<count {
      if p + 8 > pos + size { return }
      let value = u64(buf, p) + UInt64(delta)
      putU64(&buf, p, value)
      p += 8
    }
  }

  private struct Box {
    let type: String
    let start: Int
    let size: Int
  }

  private static func parseBoxes(_ data: [UInt8], _ from: Int, _ to: Int) -> [Box] {
    var list: [Box] = []
    var pos = from
    while pos + 8 <= to {
      var size = u32(data, pos)
      let type = latin(data, pos + 4, 4)
      if size == 1 && pos + 16 <= to {
        let large = u64(data, pos + 8)
        if large < 16 || large > UInt64(Int.max) { break }
        size = Int(large)
      } else if size == 0 {
        size = to - pos
      }
      if size < 8 || pos + size > to { break }
      list.append(Box(type: type, start: pos, size: size))
      pos += size
    }
    return list
  }

  private static func concat(_ parts: [[UInt8]]) -> [UInt8] { Array(parts.joined()) }

  private static func latin(_ text: String) -> [UInt8] {
    Array(text.data(using: .isoLatin1) ?? Data(text.utf8))
  }

  private static func latin(_ data: [UInt8], _ at: Int, _ n: Int) -> String {
    String(bytes: data[at..<(at + n)], encoding: .isoLatin1) ?? ""
  }

  private static func utf16le(_ text: String) -> [UInt8] {
    var out: [UInt8] = []
    for unit in text.utf16 {
      out.append(UInt8(unit & 0xFF))
      out.append(UInt8(unit >> 8))
    }
    return out
  }

  private static func u32(_ data: [UInt8], _ at: Int) -> Int {
    (Int(data[at]) << 24) | (Int(data[at + 1]) << 16) | (Int(data[at + 2]) << 8) | Int(data[at + 3])
  }

  private static func u64(_ data: [UInt8], _ at: Int) -> UInt64 {
    var value: UInt64 = 0
    for i in 0..<8 { value = (value << 8) | UInt64(data[at + i]) }
    return value
  }

  private static func putU32(_ data: inout [UInt8], _ at: Int, _ value: Int) {
    data[at] = UInt8((value >> 24) & 0xFF)
    data[at + 1] = UInt8((value >> 16) & 0xFF)
    data[at + 2] = UInt8((value >> 8) & 0xFF)
    data[at + 3] = UInt8(value & 0xFF)
  }

  private static func putU64(_ data: inout [UInt8], _ at: Int, _ value: UInt64) {
    for i in 0..<8 { data[at + i] = UInt8((value >> (8 * (7 - i))) & 0xFF) }
  }

  private static func synchsafe(_ data: [UInt8], _ at: Int) -> Int {
    (Int(data[at] & 0x7F) << 21) |
      (Int(data[at + 1] & 0x7F) << 14) |
      (Int(data[at + 2] & 0x7F) << 7) |
      Int(data[at + 3] & 0x7F)
  }

  private static func putSynchsafe(_ data: inout [UInt8], _ at: Int, _ value: Int) {
    data[at] = UInt8((value >> 21) & 0x7F)
    data[at + 1] = UInt8((value >> 14) & 0x7F)
    data[at + 2] = UInt8((value >> 7) & 0x7F)
    data[at + 3] = UInt8(value & 0x7F)
  }

  private static func parseLrc(_ text: String) -> [(Int, String)] {
    let rx = try? NSRegularExpression(pattern: #"\[(\d+):(\d+)(?:[.:](\d+))?\]\s*(.*)"#)
    return text.split(whereSeparator: \.isNewline).compactMap { line in
      let raw = String(line).trimmingCharacters(in: .whitespaces)
      guard let rx else { return nil }
      let range = NSRange(raw.startIndex..., in: raw)
      guard let match = rx.firstMatch(in: raw, range: range) else { return nil }
      func group(_ i: Int) -> String {
        let r = match.range(at: i)
        guard r.location != NSNotFound, let swift = Range(r, in: raw) else { return "" }
        return String(raw[swift])
      }
      guard let min = Int(group(1)), let sec = Int(group(2)) else { return nil }
      let frac = group(3)
      let millis: Int
      if frac.isEmpty {
        millis = 0
      } else if frac.count <= 3 {
        millis = Int(frac.padding(toLength: 3, withPad: "0", startingAt: 0)) ?? 0
      } else {
        millis = Int(frac.prefix(3)) ?? 0
      }
      let words = group(4).trimmingCharacters(in: .whitespaces)
      if words.isEmpty { return nil }
      return (min * 60_000 + sec * 1000 + millis, words)
    }
  }
}
