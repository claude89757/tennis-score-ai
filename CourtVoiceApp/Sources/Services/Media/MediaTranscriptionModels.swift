import CourtVoiceCore
import Foundation

struct MediaUtterance: Identifiable, Equatable, Sendable {
  let id: UUID
  let startTime: TimeInterval
  let endTime: TimeInterval
  let text: String
  let confidence: Double?
  let providerID: String

  init(
    id: UUID = UUID(),
    startTime: TimeInterval,
    endTime: TimeInterval,
    text: String,
    confidence: Double?,
    providerID: String
  ) {
    self.id = id
    self.startTime = startTime
    self.endTime = endTime
    self.text = text
    self.confidence = confidence
    self.providerID = providerID
  }
}

enum MediaAnalysisOutcome: String, Equatable, Sendable {
  case accepted
  case needsReview
  case ignored
  case rejected
}

struct MediaAnalysisRow: Identifiable, Equatable, Sendable {
  let id: UUID
  let utterance: MediaUtterance
  let outcome: MediaAnalysisOutcome
  let detail: String

  init(
    id: UUID = UUID(),
    utterance: MediaUtterance,
    outcome: MediaAnalysisOutcome,
    detail: String
  ) {
    self.id = id
    self.utterance = utterance
    self.outcome = outcome
    self.detail = detail
  }
}

struct MediaScoreAnalysis: Equatable, Sendable {
  let timeline: MatchTimeline
  let rows: [MediaAnalysisRow]

  var acceptedCount: Int {
    rows.filter { $0.outcome == .accepted }.count
  }

  var reviewCount: Int {
    rows.filter { $0.outcome == .needsReview }.count
  }
}

@MainActor
protocol MediaFileTranscriber: AnyObject {
  var providerID: String { get }
  var displayName: String { get }
  func transcribe(audioURL: URL, locale: Locale) async throws -> [MediaUtterance]
}

enum MediaAnalysisError: LocalizedError {
  case noAudioTrack
  case cannotCreateExporter
  case unsupportedExportType
  case emptyTranscription
  case providerUnavailable(String)

  var errorDescription: String? {
    switch self {
    case .noAudioTrack:
      "The selected file does not contain an audio track."
    case .cannotCreateExporter:
      "CourtVoice could not create an audio export session for this file."
    case .unsupportedExportType:
      "The device cannot export this media file as M4A audio."
    case .emptyTranscription:
      "The provider completed without returning any recognizable speech."
    case .providerUnavailable(let reason):
      reason
    }
  }
}
