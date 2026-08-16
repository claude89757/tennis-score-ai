import AVFoundation
import Foundation
import Speech

struct SpeechTranscription: Identifiable, Equatable, Sendable {
  let id: UUID
  let text: String
  let confidence: Double?
  let isFinal: Bool
  let providerID: String
  let timestamp: Date

  init(
    id: UUID = UUID(),
    text: String,
    confidence: Double?,
    isFinal: Bool,
    providerID: String,
    timestamp: Date = Date()
  ) {
    self.id = id
    self.text = text
    self.confidence = confidence
    self.isFinal = isFinal
    self.providerID = providerID
    self.timestamp = timestamp
  }
}

enum SpeechSessionState: Equatable, Sendable {
  case idle
  case requestingPermission
  case preparing(providerName: String)
  case listening(providerName: String)
  case processing(providerName: String)
  case interrupted(String)
  case failed(String)

  var isActive: Bool {
    switch self {
    case .requestingPermission, .preparing, .listening, .processing:
      true
    case .idle, .interrupted, .failed:
      false
    }
  }

  var title: String {
    switch self {
    case .idle: "Voice off"
    case .requestingPermission: "Requesting permission"
    case .preparing(let provider): "Preparing \(provider)"
    case .listening(let provider): "Listening · \(provider)"
    case .processing(let provider): "Processing · \(provider)"
    case .interrupted(let reason): "Interrupted · \(reason)"
    case .failed(let reason): "Voice unavailable · \(reason)"
    }
  }
}

@MainActor
protocol LiveSpeechProvider: AnyObject {
  var providerID: String { get }
  var displayName: String { get }

  func start(
    locale: Locale,
    contextualPhrases: [String],
    onTranscription: @escaping @MainActor (SpeechTranscription) -> Void,
    onStateChange: @escaping @MainActor (SpeechSessionState) -> Void
  ) async throws

  func stop() async
}

enum SpeechProviderError: LocalizedError, Sendable {
  case permissionDenied
  case speechRecognitionDenied
  case providerUnavailable(String)
  case missingCredential(String)
  case invalidEndpoint
  case invalidResponse
  case network(String)

  var errorDescription: String? {
    switch self {
    case .permissionDenied:
      "Microphone permission is required for voice scoring."
    case .speechRecognitionDenied:
      "Speech-recognition permission is required for Apple on-device scoring."
    case .providerUnavailable(let reason):
      reason
    case .missingCredential(let provider):
      "Add a \(provider) API key in Settings before using this provider."
    case .invalidEndpoint:
      "The provider endpoint must be a valid HTTPS URL."
    case .invalidResponse:
      "The speech provider returned an invalid response."
    case .network(let message):
      message
    }
  }
}

enum SpeechPermissionCenter {
  static func requestMicrophone() async -> Bool {
    await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  static func requestSpeechRecognition() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
      SFSpeechRecognizer.requestAuthorization { status in
        continuation.resume(returning: status)
      }
    }
  }
}

enum TennisSpeechVocabulary {
  static let contextualPhrases = [
    "love", "fifteen", "thirty", "forty", "deuce", "advantage",
    "ad in", "ad out", "game", "set", "match", "tiebreak", "let",
    "零", "十五", "三十", "四十", "平分", "占先", "发球方", "接发方",
    "重打", "撤销上一分", "暂停", "继续比赛",
  ]
}
