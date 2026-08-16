import Foundation

struct LiveTranscriptLine: Identifiable, Equatable, Sendable {
  let id: UUID
  var text: String
  var isFinal: Bool
}

enum ScoreReasoningPhase: Equatable, Sendable {
  case idle
  case thinking
  case answering
  case complete
  case failed(String)

  var title: String {
    switch self {
    case .idle: "Model idle"
    case .thinking: "Model thinking"
    case .answering: "Model answering"
    case .complete: "Model proposal"
    case .failed: "Model unavailable"
    }
  }
}
