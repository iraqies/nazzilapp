import AVFoundation
import UIKit

enum NazzilKeepAlive {
  private static var player: AVAudioPlayer?
  private static var task = UIBackgroundTaskIdentifier.invalid
  private static var active = false

  static func start() {
    DispatchQueue.main.async {
      guard !active else {
        beginTask()
        return
      }
      active = true
      beginTask()
      startAudio()
    }
  }

  static func stop() {
    DispatchQueue.main.async {
      active = false
      player?.stop()
      player = nil
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      endTask()
    }
  }

  private static func beginTask() {
    if task != .invalid { return }
    task = UIApplication.shared.beginBackgroundTask(withName: "nazzil-download") {
      endTask()
    }
  }

  private static func endTask() {
    if task != .invalid {
      UIApplication.shared.endBackgroundTask(task)
      task = .invalid
    }
  }

  private static func startAudio() {
    if player?.isPlaying == true { return }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      let wav = silentWav()
      player = try AVAudioPlayer(data: wav)
      player?.numberOfLoops = -1
      player?.volume = 0.01
      player?.prepareToPlay()
      player?.play()
    } catch {
      player = nil
    }
  }

  private static func silentWav() -> Data {
    let sampleRate: UInt32 = 8_000
    let samples: UInt32 = 8_000
    let dataSize = samples * 2
    var data = Data()
    func ascii(_ text: String) { data.append(contentsOf: text.utf8) }
    func le32(_ value: UInt32) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    func le16(_ value: UInt16) {
      var little = value.littleEndian
      withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }
    ascii("RIFF")
    le32(36 + dataSize)
    ascii("WAVE")
    ascii("fmt ")
    le32(16)
    le16(1)
    le16(1)
    le32(sampleRate)
    le32(sampleRate * 2)
    le16(2)
    le16(16)
    ascii("data")
    le32(dataSize)
    data.append(Data(count: Int(dataSize)))
    return data
  }
}
