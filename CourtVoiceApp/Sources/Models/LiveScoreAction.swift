import Foundation

enum LiveScoreAction: Equatable, Sendable {
  case matchReady
  case matchRestored
  case agentScored(String)
  case heldUnclear
  case held(String)
  case heardCurrent
  case undone
  case ignored(String)

  var description: String {
    switch self {
    case .matchReady:
      "Match ready"
    case .matchRestored:
      "Match restored"
    case .agentScored(let text):
      "Agent scored: \(text)"
    case .heldUnclear:
      "Held: the agent needs a clearer call before changing the score."
    case .held(let reason):
      "Held: \(reason)"
    case .heardCurrent:
      "Heard the current score; no change"
    case .undone:
      "Last scoring action undone"
    case .ignored(let reason):
      reason
    }
  }
}
