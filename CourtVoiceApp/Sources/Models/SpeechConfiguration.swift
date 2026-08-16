import Foundation

enum SpeechProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
  case automatic
  case appleOnDevice
  case openAICompatible
  case deepgram

  var id: String { rawValue }

  var title: String {
    switch self {
    case .automatic: "Automatic"
    case .appleOnDevice: "Apple on-device"
    case .openAICompatible: "OpenAI-compatible BYOK"
    case .deepgram: "Deepgram BYOK"
    }
  }

  var subtitle: String {
    switch self {
    case .automatic:
      "Prefer private on-device recognition, then fall back to a configured personal provider."
    case .appleOnDevice:
      "No provider bill and no raw audio uploaded by CourtVoice. Availability depends on device and language."
    case .openAICompatible:
      "Short voice segments are sent directly to your HTTPS transcription endpoint."
    case .deepgram:
      "16 kHz mono audio is streamed directly to Deepgram while listening is active."
    }
  }
}

struct SpeechConfiguration: Codable, Equatable, Sendable {
  var provider: SpeechProviderKind = .automatic
  var localeIdentifier = "zh-CN"
  var autoAcceptConfidence = 0.92
  var openAITranscriptionEndpoint = "https://api.openai.com/v1/audio/transcriptions"
  var openAITranscriptionModel = "gpt-4o-mini-transcribe"
  var deepgramModel = "nova-3"
  var deepgramLanguage = "multi"
  var scoreReasoningEnabled = true
  var scoreReasoningEndpoint = "https://api.deepseek.com/chat/completions"
  var scoreReasoningModel = "deepseek-v4-flash"
  var scoreReasoningEffort = "high"

  static let standard = SpeechConfiguration()

  var locale: Locale { Locale(identifier: localeIdentifier) }

  init(
    provider: SpeechProviderKind = .automatic,
    localeIdentifier: String = "zh-CN",
    autoAcceptConfidence: Double = 0.92,
    openAITranscriptionEndpoint: String = "https://api.openai.com/v1/audio/transcriptions",
    openAITranscriptionModel: String = "gpt-4o-mini-transcribe",
    deepgramModel: String = "nova-3",
    deepgramLanguage: String = "multi",
    scoreReasoningEnabled: Bool = true,
    scoreReasoningEndpoint: String = "https://api.deepseek.com/chat/completions",
    scoreReasoningModel: String = "deepseek-v4-flash",
    scoreReasoningEffort: String = "high"
  ) {
    self.provider = provider
    self.localeIdentifier = localeIdentifier
    self.autoAcceptConfidence = autoAcceptConfidence
    self.openAITranscriptionEndpoint = openAITranscriptionEndpoint
    self.openAITranscriptionModel = openAITranscriptionModel
    self.deepgramModel = deepgramModel
    self.deepgramLanguage = deepgramLanguage
    self.scoreReasoningEnabled = scoreReasoningEnabled
    self.scoreReasoningEndpoint = scoreReasoningEndpoint
    self.scoreReasoningModel = scoreReasoningModel
    self.scoreReasoningEffort = scoreReasoningEffort
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    provider = try container.decodeIfPresent(SpeechProviderKind.self, forKey: .provider) ?? .automatic
    localeIdentifier = try container.decodeIfPresent(String.self, forKey: .localeIdentifier) ?? "zh-CN"
    autoAcceptConfidence =
      try container.decodeIfPresent(Double.self, forKey: .autoAcceptConfidence) ?? 0.92
    openAITranscriptionEndpoint =
      try container.decodeIfPresent(String.self, forKey: .openAITranscriptionEndpoint)
      ?? "https://api.openai.com/v1/audio/transcriptions"
    openAITranscriptionModel =
      try container.decodeIfPresent(String.self, forKey: .openAITranscriptionModel)
      ?? "gpt-4o-mini-transcribe"
    deepgramModel = try container.decodeIfPresent(String.self, forKey: .deepgramModel) ?? "nova-3"
    deepgramLanguage = try container.decodeIfPresent(String.self, forKey: .deepgramLanguage) ?? "multi"
    scoreReasoningEnabled =
      try container.decodeIfPresent(Bool.self, forKey: .scoreReasoningEnabled) ?? true
    scoreReasoningEndpoint =
      try container.decodeIfPresent(String.self, forKey: .scoreReasoningEndpoint)
      ?? "https://api.deepseek.com/chat/completions"
    scoreReasoningModel =
      try container.decodeIfPresent(String.self, forKey: .scoreReasoningModel) ?? "deepseek-v4-flash"
    scoreReasoningEffort =
      try container.decodeIfPresent(String.self, forKey: .scoreReasoningEffort) ?? "high"
  }
}
