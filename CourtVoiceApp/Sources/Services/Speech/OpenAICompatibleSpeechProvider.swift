import Foundation

@MainActor
final class OpenAICompatibleSpeechProvider: LiveSpeechProvider {
  let providerID = "openai-compatible.byok"
  let displayName = "OpenAI-compatible"

  private let apiKey: String
  private let endpoint: URL
  private let model: String
  private let capture = PCM16AudioCapture()
  private var segmenter = VoiceActivitySegmenter()
  private var pendingSegments: [Data] = []
  private var processingTask: Task<Void, Never>?
  private var onTranscription: (@MainActor (SpeechTranscription) -> Void)?
  private var onStateChange: (@MainActor (SpeechSessionState) -> Void)?
  private var locale = Locale(identifier: "en-US")
  private var isRunning = false

  init(apiKey: String, endpoint: URL, model: String) {
    self.apiKey = apiKey
    self.endpoint = endpoint
    self.model = model
  }

  func start(
    locale: Locale,
    contextualPhrases: [String],
    onTranscription: @escaping @MainActor (SpeechTranscription) -> Void,
    onStateChange: @escaping @MainActor (SpeechSessionState) -> Void
  ) async throws {
    guard apiKey.isEmpty == false else {
      throw SpeechProviderError.missingCredential(displayName)
    }
    guard endpoint.scheme?.lowercased() == "https" else {
      throw SpeechProviderError.invalidEndpoint
    }

    onStateChange(.requestingPermission)
    guard await SpeechPermissionCenter.requestMicrophone() else {
      throw SpeechProviderError.permissionDenied
    }

    self.locale = locale
    self.onTranscription = onTranscription
    self.onStateChange = onStateChange
    segmenter = VoiceActivitySegmenter()
    pendingSegments = []
    isRunning = true

    onStateChange(.preparing(providerName: displayName))
    try capture.start { [weak self] frame, level in
      Task { @MainActor [weak self] in
        self?.consume(frame: frame, level: level)
      }
    }
    onStateChange(.listening(providerName: displayName))
  }

  func stop() async {
    isRunning = false
    capture.stop()
    if let finalSegment = segmenter.flush() {
      pendingSegments.append(finalSegment)
      startProcessingIfNeeded()
    }
    onStateChange?(.idle)
  }

  private func consume(frame: Data, level: Float) {
    guard isRunning else { return }
    if let segment = segmenter.append(frame: frame, level: level) {
      pendingSegments.append(segment)
      startProcessingIfNeeded()
    }
  }

  private func startProcessingIfNeeded() {
    guard processingTask == nil, pendingSegments.isEmpty == false else { return }
    processingTask = Task { [weak self] in
      guard let self else { return }
      while self.pendingSegments.isEmpty == false, Task.isCancelled == false {
        let pcm = self.pendingSegments.removeFirst()
        self.onStateChange?(.processing(providerName: self.displayName))
        do {
          let text = try await self.transcribe(pcm: pcm)
          let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
          if normalized.isEmpty == false {
            self.onTranscription?(
              SpeechTranscription(
                text: normalized,
                confidence: nil,
                isFinal: true,
                providerID: self.providerID
              )
            )
          }
        } catch {
          self.onStateChange?(.failed(error.localizedDescription))
        }
      }
      self.processingTask = nil
      if self.isRunning {
        self.onStateChange?(.listening(providerName: self.displayName))
      }
    }
  }

  private func transcribe(pcm: Data) async throws -> String {
    let wav = WAVEncoder.encodePCM16Mono(pcm)
    let boundary = "CourtVoice-\(UUID().uuidString)"
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 45
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = multipartBody(wav: wav, boundary: boundary)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw SpeechProviderError.invalidResponse
    }
    guard (200..<300).contains(httpResponse.statusCode) else {
      let message = String(decoding: data.prefix(512), as: UTF8.self)
      throw SpeechProviderError.network(
        "Transcription request failed (\(httpResponse.statusCode)): \(message)")
    }

    guard let payload = try? JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
    else {
      throw SpeechProviderError.invalidResponse
    }
    return payload.text
  }

  private func multipartBody(wav: Data, boundary: String) -> Data {
    var body = Data()
    func append(_ string: String) { body.append(Data(string.utf8)) }

    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    append("\(model)\r\n")
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
    let languageCode = locale.language.languageCode?.identifier ?? "en"
    append("\(languageCode)\r\n")
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
    append(
      "Tennis score calls: love, fifteen, thirty, forty, deuce, advantage, 零, 十五, 三十, 四十, 平分, 占先.\r\n"
    )
    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"file\"; filename=\"score.wav\"\r\n")
    append("Content-Type: audio/wav\r\n\r\n")
    body.append(wav)
    append("\r\n--\(boundary)--\r\n")
    return body
  }
}

private struct OpenAITranscriptionResponse: Decodable {
  let text: String
}
