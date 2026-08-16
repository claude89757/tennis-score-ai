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

  static let standard = SpeechConfiguration()

  var locale: Locale { Locale(identifier: localeIdentifier) }
}
