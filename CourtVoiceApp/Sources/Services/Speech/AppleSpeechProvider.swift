import AVFoundation
import Foundation
import Speech

/// Holds the live recognition request so the AVAudioEngine tap can append
/// buffers on the realtime audio thread without hopping to the MainActor.
private final class SpeechAudioRequestSlot: @unchecked Sendable {
  var request: SFSpeechAudioBufferRecognitionRequest?
}

private enum SpeechAudioTapInstaller {
  static func install(
    on inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    requestSlot: SpeechAudioRequestSlot
  ) {
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
      requestSlot.request?.append(buffer)
    }
  }
}

@MainActor
final class AppleSpeechProvider: LiveSpeechProvider {
  let providerID = "apple.on-device"
  let displayName = "Apple on-device"

  private let audioEngine = AVAudioEngine()
  private let requestSlot = SpeechAudioRequestSlot()
  private var recognizer: SFSpeechRecognizer?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var restartTask: Task<Void, Never>?
  private var finalizeTask: Task<Void, Never>?
  private var lastHeardText = ""
  private var shouldContinue = false
  private var locale = Locale(identifier: "zh-CN")
  private var contextualPhrases: [String] = []
  private var onTranscription: (@MainActor (SpeechTranscription) -> Void)?
  private var onStateChange: (@MainActor (SpeechSessionState) -> Void)?

  func start(
    locale: Locale,
    contextualPhrases: [String],
    onTranscription: @escaping @MainActor (SpeechTranscription) -> Void,
    onStateChange: @escaping @MainActor (SpeechSessionState) -> Void
  ) async throws {
    guard shouldContinue == false else { return }
    onStateChange(.requestingPermission)

    guard await SpeechPermissionCenter.requestMicrophone() else {
      throw SpeechProviderError.permissionDenied
    }
    guard await SpeechPermissionCenter.requestSpeechRecognition() == .authorized else {
      throw SpeechProviderError.speechRecognitionDenied
    }
    guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
      throw SpeechProviderError.providerUnavailable(
        "Apple Speech is unavailable for \(locale.identifier)."
      )
    }
    guard recognizer.supportsOnDeviceRecognition else {
      throw SpeechProviderError.providerUnavailable(
        "On-device recognition is not installed for \(locale.identifier)."
      )
    }

    self.locale = locale
    self.contextualPhrases = contextualPhrases
    self.onTranscription = onTranscription
    self.onStateChange = onStateChange
    self.recognizer = recognizer
    shouldContinue = true

    onStateChange(.preparing(providerName: displayName))
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let inputNode = audioEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    SpeechAudioTapInstaller.install(
      on: inputNode,
      format: format,
      requestSlot: requestSlot
    )

    audioEngine.prepare()
    try audioEngine.start()
    beginRecognitionTask()
    onStateChange(.listening(providerName: displayName))
  }

  func stop() async {
    shouldContinue = false
    finalizeTask?.cancel()
    finalizeTask = nil
    restartTask?.cancel()
    restartTask = nil
    lastHeardText = ""
    recognitionTask?.cancel()
    recognitionTask = nil
    requestSlot.request?.endAudio()
    requestSlot.request = nil

    if audioEngine.isRunning {
      audioEngine.stop()
    }
    audioEngine.inputNode.removeTap(onBus: 0)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    onStateChange?(.idle)
  }

  private func beginRecognitionTask() {
    guard shouldContinue, let recognizer else { return }

    recognitionTask?.cancel()
    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.taskHint = .dictation
    request.contextualStrings = contextualPhrases
    request.requiresOnDeviceRecognition = true
    requestSlot.request = request

    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      Task { @MainActor [weak self] in
        guard let self else { return }

        if let result {
          let text = result.bestTranscription.formattedString
          let segments = result.bestTranscription.segments
          let confidence: Double? =
            segments.isEmpty
            ? nil
            : Double(segments.reduce(0) { $0 + $1.confidence }) / Double(segments.count)
          self.onTranscription?(
            SpeechTranscription(
              text: text,
              confidence: confidence,
              isFinal: result.isFinal,
              providerID: self.providerID
            )
          )

          if result.isFinal {
            self.finalizeTask?.cancel()
            self.lastHeardText = ""
            self.scheduleRestart()
            return
          }
          self.scheduleForcedFinal(for: text)
        }

        if error != nil {
          self.finalizeTask?.cancel()
          self.scheduleRestart()
        }
      }
    }
  }

  private func scheduleForcedFinal(for text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return }
    lastHeardText = trimmed
    finalizeTask?.cancel()
    finalizeTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(900))
      guard let self, Task.isCancelled == false, self.shouldContinue else { return }
      guard self.lastHeardText == trimmed else { return }
      self.requestSlot.request?.endAudio()
      self.requestSlot.request = nil
      try? await Task.sleep(for: .milliseconds(450))
      guard Task.isCancelled == false, self.shouldContinue else { return }
      if self.requestSlot.request == nil {
        self.scheduleRestart()
      }
    }
  }

  private func scheduleRestart() {
    guard shouldContinue else { return }
    requestSlot.request?.endAudio()
    recognitionTask?.cancel()
    restartTask?.cancel()
    restartTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(180))
      guard Task.isCancelled == false else { return }
      self?.beginRecognitionTask()
      if let displayName = self?.displayName {
        self?.onStateChange?(.listening(providerName: displayName))
      }
    }
  }
}
