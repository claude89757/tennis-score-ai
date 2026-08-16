import CourtVoiceAI
import CourtVoiceCore
import Foundation

struct MediaScoreTimelineBuilder {
  private let parser = TranscriptIntentParser()
  private let resolver = ScoreIntentResolver()

  func build(
    initialState: MatchState,
    utterances: [MediaUtterance],
    automaticAcceptanceThreshold: Double
  ) -> MediaScoreAnalysis {
    let startedAt = Date()
    var timeline = MatchTimeline(initialState: initialState)
    try? timeline.append(
      MatchEvent(
        occurredAt: startedAt,
        kind: .matchStarted,
        evidence: ScoreEvidence(source: .importedMedia),
        idempotencyKey: "media-start-\(initialState.id.uuidString)"
      )
    )

    var rows: [MediaAnalysisRow] = []
    for utterance in utterances {
      let candidate = parser.parse(utterance.text)
      let providerConfidence = utterance.confidence ?? candidate.confidence
      let combinedConfidence = min(candidate.confidence, providerConfidence)
      if candidate.intent == .undo {
        if candidate.requiresConfirmation || combinedConfidence < automaticAcceptanceThreshold {
          rows.append(
            MediaAnalysisRow(
              utterance: utterance,
              outcome: .needsReview,
              detail: "Undo requires confirmation before changing the imported timeline"
            )
          )
        } else {
          do {
            _ = try timeline.revokeLastMutableEvent(
              evidence: ScoreEvidence(
                transcript: utterance.text,
                confidence: combinedConfidence,
                providerID: utterance.providerID,
                source: .importedMedia
              )
            )
            rows.append(
              MediaAnalysisRow(
                utterance: utterance,
                outcome: .accepted,
                detail: "Accepted as an auditable undo event"
              )
            )
          } catch {
            rows.append(
              MediaAnalysisRow(
                utterance: utterance,
                outcome: .rejected,
                detail: error.localizedDescription
              )
            )
          }
        }
        continue
      }

      let resolution = resolver.resolve(candidate, state: timeline.currentState)

      switch resolution {
      case .event(let kind)
      where candidate.requiresConfirmation == false
        && combinedConfidence >= automaticAcceptanceThreshold:
        do {
          try timeline.append(
            MatchEvent(
              occurredAt: startedAt.addingTimeInterval(max(0, utterance.startTime)),
              kind: kind,
              evidence: ScoreEvidence(
                transcript: utterance.text,
                confidence: combinedConfidence,
                providerID: utterance.providerID,
                source: .importedMedia
              ),
              idempotencyKey: "media-\(utterance.providerID)-\(utterance.id.uuidString)"
            )
          )
          rows.append(
            MediaAnalysisRow(
              utterance: utterance,
              outcome: .accepted,
              detail: "Accepted as a legal score transition"
            )
          )
        } catch {
          rows.append(
            MediaAnalysisRow(
              utterance: utterance,
              outcome: .rejected,
              detail: error.localizedDescription
            )
          )
        }

      case .events(let kinds)
      where candidate.requiresConfirmation == false
        && combinedConfidence >= automaticAcceptanceThreshold:
        do {
          for (offset, kind) in kinds.enumerated() {
            try timeline.append(
              MatchEvent(
                occurredAt: startedAt.addingTimeInterval(max(0, utterance.startTime)),
                kind: kind,
                evidence: ScoreEvidence(
                  transcript: utterance.text,
                  confidence: combinedConfidence,
                  providerID: utterance.providerID,
                  source: .importedMedia
                ),
                idempotencyKey: "media-\(utterance.providerID)-\(utterance.id.uuidString)-\(offset)"
              )
            )
          }
          rows.append(
            MediaAnalysisRow(
              utterance: utterance,
              outcome: .accepted,
              detail: "Accepted as a reachable in-game score"
            )
          )
        } catch {
          rows.append(
            MediaAnalysisRow(
              utterance: utterance,
              outcome: .rejected,
              detail: error.localizedDescription
            )
          )
        }

      case .event, .events:
        rows.append(
          MediaAnalysisRow(
            utterance: utterance,
            outcome: .needsReview,
            detail: "Recognized score action requires confirmation"
          )
        )

      case .alreadyCurrent:
        rows.append(
          MediaAnalysisRow(
            utterance: utterance,
            outcome: .ignored,
            detail: "Reported score already matches the timeline"
          )
        )

      case .confirmationRequired(let reason):
        rows.append(
          MediaAnalysisRow(
            utterance: utterance,
            outcome: .needsReview,
            detail: reason
          )
        )

      case .ignored(let reason):
        rows.append(
          MediaAnalysisRow(
            utterance: utterance,
            outcome: .ignored,
            detail: reason
          )
        )
      }
    }

    return MediaScoreAnalysis(timeline: timeline, rows: rows)
  }
}
