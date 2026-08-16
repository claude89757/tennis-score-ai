import AVFoundation
import Foundation

final class PCM16AudioCapture: @unchecked Sendable {
  typealias FrameHandler = @Sendable (_ pcm16Data: Data, _ normalizedLevel: Float) -> Void

  private let audioEngine = AVAudioEngine()
  private let lock = NSLock()
  private var converter: AVAudioConverter?
  private var outputFormat: AVAudioFormat?
  private var frameHandler: FrameHandler?

  func start(frameHandler: @escaping FrameHandler) throws {
    lock.lock()
    self.frameHandler = frameHandler
    lock.unlock()

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    guard
      let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
      ),
      let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
    else {
      throw SpeechProviderError.providerUnavailable(
        "Unable to convert microphone audio to 16 kHz PCM.")
    }

    self.outputFormat = outputFormat
    self.converter = converter

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) {
      [weak self] buffer, _ in
      self?.process(buffer, inputFormat: inputFormat)
    }

    audioEngine.prepare()
    try audioEngine.start()
  }

  func stop() {
    if audioEngine.isRunning {
      audioEngine.stop()
    }
    audioEngine.inputNode.removeTap(onBus: 0)
    converter = nil
    outputFormat = nil

    lock.lock()
    frameHandler = nil
    lock.unlock()

    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func process(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
    guard let converter, let outputFormat else { return }

    let ratio = outputFormat.sampleRate / inputFormat.sampleRate
    let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
    guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCapacity)
    else {
      return
    }

    var suppliedInput = false
    var conversionError: NSError?
    let status = converter.convert(to: converted, error: &conversionError) { _, outputStatus in
      if suppliedInput {
        outputStatus.pointee = .noDataNow
        return nil
      }
      suppliedInput = true
      outputStatus.pointee = .haveData
      return buffer
    }

    guard
      status != .error,
      conversionError == nil,
      let samples = converted.int16ChannelData?[0]
    else {
      return
    }

    let sampleCount = Int(converted.frameLength)
    guard sampleCount > 0 else { return }

    let data = Data(bytes: samples, count: sampleCount * MemoryLayout<Int16>.size)
    var sum: Double = 0
    for index in 0..<sampleCount {
      let normalized = Double(samples[index]) / Double(Int16.max)
      sum += normalized * normalized
    }
    let level = Float(min(sqrt(sum / Double(sampleCount)) * 8, 1))

    lock.lock()
    let handler = frameHandler
    lock.unlock()
    handler?(data, level)
  }
}
