import Foundation
import CourtVoiceCore

public enum ReportedPoint: String, Codable, CaseIterable, Sendable {
    case love
    case fifteen
    case thirty
    case forty

    public var rawPointCount: Int {
        switch self {
        case .love: 0
        case .fifteen: 1
        case .thirty: 2
        case .forty: 3
        }
    }
}

public enum ScoreIntent: Codable, Equatable, Sendable {
    case reportedScore(server: ReportedPoint, receiver: ReportedPoint)
    case deuce
    case advantageServer
    case advantageReceiver
    case awardPoint(TeamSide)
    case undo
    case replayPoint
    case pause
    case resume
    case discussion
    case unknown
}

public struct IntentCandidate: Codable, Equatable, Sendable {
    public var intent: ScoreIntent
    public var normalizedText: String
    public var confidence: Double
    public var requiresConfirmation: Bool
    public var parserID: String

    public init(
        intent: ScoreIntent,
        normalizedText: String,
        confidence: Double,
        requiresConfirmation: Bool,
        parserID: String
    ) {
        self.intent = intent
        self.normalizedText = normalizedText
        self.confidence = min(max(confidence, 0), 1)
        self.requiresConfirmation = requiresConfirmation
        self.parserID = parserID
    }
}
