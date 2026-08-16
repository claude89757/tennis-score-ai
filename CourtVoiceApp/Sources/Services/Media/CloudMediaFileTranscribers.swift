import Foundation

@MainActor
final class OpenAIMediaFileTranscriber: MediaFileTranscriber {
  let providerID = "openai-compatible.file.byok"
  let displayName = "OpenAI-compatible"

  private let apiKey: String
  private let endpoint: URL
  private let model: String

  init(apiKey: String, endpoint: URL, model: String) {
    self.apiKey = apiKey
    self.endpoint = endpoint
    self.model = model
  }

  func transcribe(audioURL: URL, locale: Locale) async throws -> [MediaUtterance] {
    guard endpoint.scheme?.lowercased() == "https" else {
      throw SpeechProviderError.invalidEndpoint
    }

    let boundary = "CourtVoice-Media-\(UUID().uuidString)"
    let bodyURL = try buildMultipartBody(
      audioURL: audioURL,
      boundary: boundary,
      language: locale.language.languageCode?.identifier ?? "en"
    )
    defer { try? FileManager.default.removeItem(at: bodyURL) }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 300
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue(
      "multipart/form-data; boundary=\(boundary)",
      forHTTPHeaderField: "Content-Type"
    )

    let (data, response) = try await URLSession.shared.upload(for: request, fromFile: bodyURL)
    guard let http = response as? HTTPURLResponse else {
      throw SpeechProviderError.invalidResponse
    }
    guard (200..<300).contains(http.statusCode) else {
      let message = String(decoding: data.prefix(768), as: UTF8.self)
      throw SpeechProviderError.network(
        "Media transcription failed (\(http.statusCode)): \(message)"
      )
    }

    let payload = try JSONDecoder().decode(OpenAIVerboseTranscription.self, from: data)
    let rows =
      payload.segments?.compactMap { segment -> MediaUtterance? in
        let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return nil }
        return MediaUtterance(
          startTime: segment.start,
          endTime: segment.end,
          text: text,
          confidence: nil,
          providerID: providerID
        )
      } ?? []

    if rows.isEmpty == false { return rows }
    let text = payload.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.isEmpty == false else { throw MediaAnalysisError.emptyTranscription }
    return [
      MediaUtterance(
        startTime: 0,
        endTime: 0,
        text: text,
        confidence: nil,
        providerID: providerID
      )
    ]
  }

  private func buildMultipartBody(
    audioURL: URL,
    boundary: String,
    language: String
  ) throws -> URL {
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("courtvoice-upload-\(UUID().uuidString).body")
    _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    let output = try FileHandle(forWritingTo: outputURL)
    defer { try? output.close() }

    func write(_ string: String) throws {
      try output.write(contentsOf: Data(string.utf8))
    }

    try write("--\(boundary)\r\n")
    try write("Content-Disposition: form-data; name=\"model\"\r\n\r\n\(model)\r\n")
    try write("--\(boundary)\r\n")
    try write("Content-Disposition: form-data; name=\"language\"\r\n\r\n\(language)\r\n")
    try write("--\(boundary)\r\n")
    try write("Content-Disposition: form-data; name=\"response_format\"\r\n\r\nverbose_json\r\n")
    try write("--\(boundary)\r\n")
    try write("Content-Disposition: form-data; name=\"file\"; filename=\"match.m4a\"\r\n")
    try write("Content-Type: audio/mp4\r\n\r\n")

    let input = try FileHandle(forReadingFrom: audioURL)
    defer { try? input.close() }
    while let chunk = try input.read(upToCount: 1_048_576), chunk.isEmpty == false {
      try output.write(contentsOf: chunk)
    }
    try write("\r\n--\(boundary)--\r\n")
    return outputURL
  }
}

@MainActor
final class DeepgramMediaFileTranscriber: MediaFileTranscriber {
  let providerID = "deepgram.file.byok"
  let displayName = "Deepgram"

  private let apiKey: String
  private let model: String
  private let language: String

  init(apiKey: String, model: String, language: String) {
    self.apiKey = apiKey
    self.model = model
    self.language = language
  }

  func transcribe(audioURL: URL, locale: Locale) async throws -> [MediaUtterance] {
    var components = URLComponents(string: "https://api.deepgram.com/v1/listen")
    components?.queryItems = [
      URLQueryItem(name: "model", value: model),
      URLQueryItem(name: "language", value: resolvedLanguage(locale)),
      URLQueryItem(name: "smart_format", value: "true"),
      URLQueryItem(name: "utterances", value: "true"),
      URLQueryItem(name: "punctuate", value: "true"),
    ]
    guard let url = components?.url else { throw SpeechProviderError.invalidEndpoint }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 300
    request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")

    let (data, response) = try await URLSession.shared.upload(for: request, fromFile: audioURL)
    guard let http = response as? HTTPURLResponse else {
      throw SpeechProviderError.invalidResponse
    }
    guard (200..<300).contains(http.statusCode) else {
      let message = String(decoding: data.prefix(768), as: UTF8.self)
      throw SpeechProviderError.network(
        "Deepgram media transcription failed (\(http.statusCode)): \(message)"
      )
    }

    let payload = try JSONDecoder().decode(DeepgramFileResponse.self, from: data)
    let utterances =
      payload.results.utterances?.compactMap { value -> MediaUtterance? in
        let text = value.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return nil }
        return MediaUtterance(
          startTime: value.start,
          endTime: value.end,
          text: text,
          confidence: value.confidence,
          providerID: providerID
        )
      } ?? []
    if utterances.isEmpty == false { return utterances }

    guard let alternative = payload.results.channels.first?.alternatives.first else {
      throw MediaAnalysisError.emptyTranscription
    }
    let text = alternative.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.isEmpty == false else { throw MediaAnalysisError.emptyTranscription }
    return [
      MediaUtterance(
        startTime: 0,
        endTime: 0,
        text: text,
        confidence: alternative.confidence,
        providerID: providerID
      )
    ]
  }

  private func resolvedLanguage(_ locale: Locale) -> String {
    language == "auto" ? locale.language.languageCode?.identifier ?? "multi" : language
  }
}

private struct OpenAIVerboseTranscription: Decodable {
  struct Segment: Decodable {
    let start: Double
    let end: Double
    let text: String
  }

  let text: String
  let segments: [Segment]?
}

private struct DeepgramFileResponse: Decodable {
  struct Results: Decodable {
    struct Utterance: Decodable {
      let start: Double
      let end: Double
      let confidence: Double?
      let transcript: String
    }

    struct Channel: Decodable {
      struct Alternative: Decodable {
        let transcript: String
        let confidence: Double?
      }

      let alternatives: [Alternative]
    }

    let utterances: [Utterance]?
    let channels: [Channel]
  }

  let results: Results
}
