import AVFoundation
import Foundation
import Speech

@MainActor
final class AppleSpeechProvider: LiveSpeechProvider {
  let providerID = "apple.on-device"
  let displayName = "Apple on-device"

  private let audioEngine = AVAudioEngine()
  private var recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var restartTask: Task<Void, Never>?
  private var shouldContinue = false
  private var locale = Locale(identifier: "en-US")
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
    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak self] buffer, _ in
      self?.request?.append(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()
    beginRecognitionTask()
    onStateChange(.listening(providerName: displayName))
  }

  func stop() async {
    shouldContinue = false
    restartTask?.cancel()
    restartTask = nil
    recognitionTask?.cancel()
    recognitionTask = nil
    request?.endAudio()
    request = nil

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
    self.request = request

    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      Task { @MainActor [weak self] in
        guard let self else { return }

        if let result {
          let segments = result.bestTranscription.segments
          let confidence: Double? =
            segments.isEmpty
            ? nil
            : Double(segments.reduce(0) { $0 + $1.confidence }) / Double(segments.count)
          self.onTranscription?(
            SpeechTranscription(
              text: result.bestTranscription.formattedString,
              confidence: confidence,
              isFinal: result.isFinal,
              providerID: self.providerID
            )
          )
        }

        if error != nil || result?.isFinal == true {
          self.scheduleRestart()
        }
      }
    }
  }

  private func scheduleRestart() {
    guard shouldContinue else { return }
    request?.endAudio()
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
