import Foundation
import CourtVoiceCore

public struct StructuredScoreIntentParser: Sendable {
  public init() {}

  public func parse(jsonText: String) -> IntentCandidate? {
    guard let payload = decodePayload(from: jsonText) else { return nil }
    guard let intent = intent(from: payload) else { return nil }

    let confidence = min(max(payload.confidence ?? 0.7, 0), 1)
    let requiresConfirmation =
      payload.requiresConfirmation
      ?? (confidence < 0.92 || intent == .unknown || intent == .discussion)

    return IntentCandidate(
      intent: intent,
      normalizedText: payload.summary?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        ?? payload.intent,
      confidence: confidence,
      requiresConfirmation: requiresConfirmation,
      parserID: "deepseek.structured.v1"
    )
  }

  private func decodePayload(from text: String) -> Payload? {
    let candidates = [extractJSONObject(from: text), text]
    for candidate in candidates {
      guard let data = candidate.data(using: .utf8) else { continue }
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      if let payload = try? decoder.decode(Payload.self, from: data) {
        return payload
      }
    }
    return nil
  }

  private func intent(from payload: Payload) -> ScoreIntent? {
    switch payload.intent.replacingOccurrences(of: "-", with: "_").lowercased() {
    case "reported_score", "reportedscore", "score":
      guard
        let server = point(from: payload.server),
        let receiver = point(from: payload.receiver)
      else {
        return nil
      }
      return .reportedScore(server: server, receiver: receiver)
    case "award_point", "awardpoint", "point":
      guard let side = side(from: payload.side) else { return nil }
      return .awardPoint(side)
    case "undo":
      return .undo
    case "deuce":
      return .deuce
    case "advantage_server", "advantageserver", "ad_in", "adin":
      return .advantageServer
    case "advantage_receiver", "advantagereceiver", "ad_out", "adout":
      return .advantageReceiver
    case "replay_point", "replaypoint", "let":
      return .replayPoint
    case "pause":
      return .pause
    case "resume":
      return .resume
    case "discussion":
      return .discussion
    case "unknown":
      return .unknown
    default:
      return nil
    }
  }

  private func point(from raw: String?) -> ReportedPoint? {
    switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "love", "0", "零": return .love
    case "fifteen", "15", "十五": return .fifteen
    case "thirty", "30", "三十": return .thirty
    case "forty", "40", "四十": return .forty
    default: return nil
    }
  }

  private func side(from raw: String?) -> TeamSide? {
    switch raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "home", "left", "server", "p1": return .home
    case "away", "right", "receiver", "p2": return .away
    default: return nil
    }
  }

  private func extractJSONObject(from text: String) -> String {
    let stripped = text
      .replacingOccurrences(of: "```json", with: "")
      .replacingOccurrences(of: "```", with: "")
    guard let start = stripped.firstIndex(of: "{"),
      let end = stripped.lastIndex(of: "}"),
      start < end
    else {
      return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return String(stripped[start...end])
  }
}

private struct Payload: Decodable {
  var intent: String
  var server: String?
  var receiver: String?
  var side: String?
  var confidence: Double?
  var summary: String?
  var requiresConfirmation: Bool?
}

extension String {
  fileprivate var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
