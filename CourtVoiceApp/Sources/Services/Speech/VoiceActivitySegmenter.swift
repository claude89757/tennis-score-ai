import Foundation

struct VoiceActivitySegmenter {
  private let bytesPerSecond = 16_000 * MemoryLayout<Int16>.size
  private let voiceThreshold: Float
  private let silenceDuration: TimeInterval
  private let minimumDuration: TimeInterval
  private let maximumDuration: TimeInterval

  private var preRoll = Data()
  private var activeSegment = Data()
  private var silentBytes = 0
  private var isSpeaking = false

  init(
    voiceThreshold: Float = 0.035,
    silenceDuration: TimeInterval = 0.75,
    minimumDuration: TimeInterval = 0.35,
    maximumDuration: TimeInterval = 12
  ) {
    self.voiceThreshold = voiceThreshold
    self.silenceDuration = silenceDuration
    self.minimumDuration = minimumDuration
    self.maximumDuration = maximumDuration
  }

  mutating func append(frame: Data, level: Float) -> Data? {
    let voiced = level >= voiceThreshold

    if isSpeaking == false {
      preRoll.append(frame)
      let maximumPreRollBytes = Int(Double(bytesPerSecond) * 0.3)
      if preRoll.count > maximumPreRollBytes {
        preRoll.removeFirst(preRoll.count - maximumPreRollBytes)
      }
      guard voiced else { return nil }
      isSpeaking = true
      activeSegment.append(preRoll)
      preRoll.removeAll(keepingCapacity: true)
    }

    activeSegment.append(frame)
    silentBytes = voiced ? 0 : silentBytes + frame.count

    let activeDuration = TimeInterval(activeSegment.count) / TimeInterval(bytesPerSecond)
    let currentSilence = TimeInterval(silentBytes) / TimeInterval(bytesPerSecond)
    if (currentSilence >= silenceDuration && activeDuration >= minimumDuration)
      || activeDuration >= maximumDuration
    {
      return finish()
    }
    return nil
  }

  mutating func flush() -> Data? {
    guard activeSegment.isEmpty == false else { return nil }
    return finish()
  }

  private mutating func finish() -> Data {
    let result = activeSegment
    activeSegment.removeAll(keepingCapacity: true)
    silentBytes = 0
    isSpeaking = false
    return result
  }
}
