import Foundation

enum ScoreReasoningEvent: Sendable {
  case thinkingDelta(String)
  case answerDelta(String)
}

protocol ScoreReasoningClient: Sendable {
  func streamProposal(
    transcript: String,
    matchContext: String,
    onEvent: @escaping @Sendable (ScoreReasoningEvent) -> Void
  ) async throws -> String
}

enum ScoreReasoningError: LocalizedError, Sendable {
  case invalidEndpoint
  case httpStatus(Int)
  case emptyAnswer

  var errorDescription: String? {
    switch self {
    case .invalidEndpoint:
      "The score-reasoning endpoint must be a valid HTTPS URL."
    case .httpStatus(let code):
      "Score reasoning failed with HTTP \(code)."
    case .emptyAnswer:
      "The model returned no structured score intent."
    }
  }
}
