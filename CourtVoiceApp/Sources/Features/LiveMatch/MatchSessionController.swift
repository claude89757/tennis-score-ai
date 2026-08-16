import CourtVoiceCore
import Foundation
import Observation

@MainActor
@Observable
final class MatchSessionController: Identifiable {
  let id: UUID

  private(set) var timeline: MatchTimeline
  private let repository: MatchRepository

  var lastErrorMessage: String?
  var lastActionDescription = "Match ready"
  var isShowingCorrection = false

  var state: MatchState { timeline.currentState }

  init(initialState: MatchState, repository: MatchRepository) throws {
    id = initialState.id
    self.repository = repository

    var newTimeline = MatchTimeline(initialState: initialState)
    try newTimeline.append(
      MatchEvent(
        kind: .matchStarted,
        evidence: ScoreEvidence(source: .manual),
        idempotencyKey: "match-start-\(initialState.id.uuidString)"
      )
    )
    timeline = newTimeline
  }

  init(savedMatch: SavedMatch, repository: MatchRepository) {
    id = savedMatch.id
    timeline = savedMatch.timeline
    self.repository = repository
    lastActionDescription = "Match restored"
  }

  func awardPoint(
    to side: TeamSide,
    source: MatchSource = .manual,
    transcript: String? = nil,
    confidence: Double? = nil,
    providerID: String? = nil,
    idempotencyKey: String? = nil
  ) async {
    await apply(
      .pointAwarded(side),
      evidence: ScoreEvidence(
        transcript: transcript,
        confidence: confidence,
        providerID: providerID,
        source: source
      ),
      idempotencyKey: idempotencyKey,
      successDescription: "Point to \(state.teams[side].displayName)"
    )
  }

  func undo() async {
    do {
      _ = try timeline.revokeLastMutableEvent()
      lastActionDescription = "Last scoring action undone"
      try await persist()
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }

  func togglePause() async {
    let kind: MatchEventKind
    let description: String

    switch state.status {
    case .inProgress:
      kind = .matchPaused
      description = "Match paused"
    case .paused:
      kind = .matchResumed
      description = "Match resumed"
    default:
      return
    }

    await apply(
      kind,
      evidence: ScoreEvidence(source: .manual),
      successDescription: description
    )
  }

  func changeServer(to side: TeamSide) async {
    await apply(
      .serverChanged(side),
      evidence: ScoreEvidence(source: .manual),
      successDescription: "Server changed to \(state.teams[side].displayName)"
    )
  }

  func applyCorrection(_ correction: ScoreCorrection) async {
    await apply(
      .scoreCorrected(correction),
      evidence: ScoreEvidence(source: .manual),
      successDescription: "Score corrected"
    )
  }

  func endMatch(winner: TeamSide) async {
    await apply(
      .matchEnded(winner: winner),
      evidence: ScoreEvidence(source: .manual),
      successDescription: "Match ended"
    )
  }

  func persist() async throws {
    try await repository.save(timeline)
  }

  private func apply(
    _ kind: MatchEventKind,
    evidence: ScoreEvidence,
    idempotencyKey: String? = nil,
    successDescription: String
  ) async {
    do {
      try timeline.append(
        MatchEvent(
          kind: kind,
          evidence: evidence,
          idempotencyKey: idempotencyKey
        )
      )
      lastActionDescription = successDescription
      try await persist()
    } catch {
      lastErrorMessage = error.localizedDescription
    }
  }
}
