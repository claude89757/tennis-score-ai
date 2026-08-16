import Foundation

@MainActor
final class DeepgramSpeechProvider: LiveSpeechProvider {
  let providerID = "deepgram.byok"
  let displayName = "Deepgram"

  private let apiKey: String
  private let model: String
  private let language: String
  private let capture = PCM16AudioCapture()
  private var socket: URLSessionWebSocketTask?
  private var receiveTask: Task<Void, Never>?
  private var onTranscription: (@MainActor (SpeechTranscription) -> Void)?
  private var onStateChange: (@MainActor (SpeechSessionState) -> Void)?
  private var isStopping = false

  init(apiKey: String, model: String, language: String) {
    self.apiKey = apiKey
    self.model = model
    self.language = language
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

    onStateChange(.requestingPermission)
    guard await SpeechPermissionCenter.requestMicrophone() else {
      throw SpeechProviderError.permissionDenied
    }

    self.onTranscription = onTranscription
    self.onStateChange = onStateChange
    isStopping = false
    onStateChange(.preparing(providerName: displayName))

    var components = URLComponents(string: "wss://api.deepgram.com/v1/listen")
    components?.queryItems = [
      URLQueryItem(name: "model", value: model),
      URLQueryItem(name: "language", value: resolvedLanguage(for: locale)),
      URLQueryItem(name: "encoding", value: "linear16"),
      URLQueryItem(name: "sample_rate", value: "16000"),
      URLQueryItem(name: "channels", value: "1"),
      URLQueryItem(name: "interim_results", value: "true"),
      URLQueryItem(name: "smart_format", value: "true"),
      URLQueryItem(name: "endpointing", value: "500"),
      URLQueryItem(name: "utterance_end_ms", value: "900"),
    ]
    guard let url = components?.url else { throw SpeechProviderError.invalidEndpoint }

    var request = URLRequest(url: url)
    request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
    let socket = URLSession.shared.webSocketTask(with: request)
    self.socket = socket
    socket.resume()

    receiveTask = Task { [weak self] in
      await self?.receiveLoop()
    }

    try capture.start { [weak self] frame, _ in
      Task { @MainActor [weak self] in
        guard let self, let socket = self.socket else { return }
        do {
          try await socket.send(.data(frame))
        } catch {
          if self.isStopping == false {
            self.onStateChange?(.failed(error.localizedDescription))
          }
        }
      }
    }

    onStateChange(.listening(providerName: displayName))
  }

  func stop() async {
    isStopping = true
    capture.stop()
    receiveTask?.cancel()
    receiveTask = nil

    if let socket {
      try? await socket.send(.string("{\"type\":\"CloseStream\"}"))
      socket.cancel(with: .normalClosure, reason: nil)
    }
    socket = nil
    onStateChange?(.idle)
  }

  private func receiveLoop() async {
    while Task.isCancelled == false, let socket {
      do {
        let message = try await socket.receive()
        let data: Data
        switch message {
        case .data(let value): data = value
        case .string(let value): data = Data(value.utf8)
        @unknown default: continue
        }

        guard
          let payload = try? JSONDecoder().decode(DeepgramResponse.self, from: data),
          let alternative = payload.channel?.alternatives.first,
          alternative.transcript.isEmpty == false
        else {
          continue
        }

        onTranscription?(
          SpeechTranscription(
            text: alternative.transcript,
            confidence: alternative.confidence,
            isFinal: payload.isFinal ?? false,
            providerID: providerID
          )
        )
      } catch {
        guard isStopping == false, Task.isCancelled == false else { return }
        onStateChange?(.failed(error.localizedDescription))
        return
      }
    }
  }

  private func resolvedLanguage(for locale: Locale) -> String {
    guard language != "auto" else {
      return locale.language.languageCode?.identifier ?? "multi"
    }
    return language
  }
}

private struct DeepgramResponse: Decodable {
  struct Channel: Decodable {
    struct Alternative: Decodable {
      let transcript: String
      let confidence: Double?
    }

    let alternatives: [Alternative]
  }

  let channel: Channel?
  let isFinal: Bool?

  enum CodingKeys: String, CodingKey {
    case channel
    case isFinal = "is_final"
  }
}
