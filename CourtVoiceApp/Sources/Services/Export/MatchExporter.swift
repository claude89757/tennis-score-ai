import CourtVoiceCore
import Foundation

struct MatchExporter {
  static func makeJSONFile(_ timeline: MatchTimeline) throws -> URL {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    let data = try encoder.encode(timeline)
    let filename = "courtvoice-match-\(timeline.initialState.id.uuidString.lowercased()).json"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    try data.write(to: url, options: [.atomic, .completeFileProtection])
    return url
  }
}
