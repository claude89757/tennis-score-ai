import Foundation

public enum TeamSide: String, CaseIterable, Codable, Sendable {
    case home
    case away

    public var opponent: TeamSide {
        self == .home ? .away : .home
    }
}

public struct SidePair<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var home: Value
    public var away: Value

    public init(home: Value, away: Value) {
        self.home = home
        self.away = away
    }

    public subscript(_ side: TeamSide) -> Value {
        get { side == .home ? home : away }
        set {
            if side == .home {
                home = newValue
            } else {
                away = newValue
            }
        }
    }
}

public enum MatchDiscipline: String, Codable, CaseIterable, Sendable {
    case singles
    case doubles
}

public enum GameScoringRule: String, Codable, CaseIterable, Sendable {
    case advantage
    case noAd
}

public enum DecidingSetRule: Codable, Equatable, Sendable {
    case standardSet
    case matchTiebreak(target: Int)
}

public struct MatchFormat: Codable, Equatable, Sendable {
    public var discipline: MatchDiscipline
    public var bestOfSets: Int
    public var gameScoring: GameScoringRule
    public var tiebreakTarget: Int
    public var decidingSetRule: DecidingSetRule

    public init(
        discipline: MatchDiscipline = .singles,
        bestOfSets: Int = 3,
        gameScoring: GameScoringRule = .advantage,
        tiebreakTarget: Int = 7,
        decidingSetRule: DecidingSetRule = .standardSet
    ) {
        precondition(bestOfSets > 0 && bestOfSets.isMultiple(of: 2) == false)
        precondition(tiebreakTarget >= 2)
        if case let .matchTiebreak(target) = decidingSetRule {
            precondition(target >= 2)
        }

        self.discipline = discipline
        self.bestOfSets = bestOfSets
        self.gameScoring = gameScoring
        self.tiebreakTarget = tiebreakTarget
        self.decidingSetRule = decidingSetRule
    }

    public var setsRequiredToWin: Int {
        (bestOfSets / 2) + 1
    }

    public static let standardSingles = MatchFormat()
}

public struct Team: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var displayName: String
    public var memberNames: [String]

    public init(id: UUID = UUID(), displayName: String, memberNames: [String] = []) {
        self.id = id
        self.displayName = displayName
        self.memberNames = memberNames
    }
}

public struct CompletedSet: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var games: SidePair<Int>
    public var tiebreakPoints: SidePair<Int>?
    public var isMatchTiebreak: Bool

    public init(
        id: UUID = UUID(),
        games: SidePair<Int>,
        tiebreakPoints: SidePair<Int>? = nil,
        isMatchTiebreak: Bool = false
    ) {
        self.id = id
        self.games = games
        self.tiebreakPoints = tiebreakPoints
        self.isMatchTiebreak = isMatchTiebreak
    }

    public var winner: TeamSide? {
        if isMatchTiebreak, let tiebreakPoints {
            guard tiebreakPoints.home != tiebreakPoints.away else { return nil }
            return tiebreakPoints.home > tiebreakPoints.away ? .home : .away
        }

        guard games.home != games.away else { return nil }
        return games.home > games.away ? .home : .away
    }
}

public struct GameState: Codable, Equatable, Sendable {
    public var rawPoints: SidePair<Int>
    public var isTiebreak: Bool
    public var tiebreakTarget: Int?
    public var tiebreakStartingServer: TeamSide?

    public init(
        rawPoints: SidePair<Int> = SidePair(home: 0, away: 0),
        isTiebreak: Bool = false,
        tiebreakTarget: Int? = nil,
        tiebreakStartingServer: TeamSide? = nil
    ) {
        self.rawPoints = rawPoints
        self.isTiebreak = isTiebreak
        self.tiebreakTarget = tiebreakTarget
        self.tiebreakStartingServer = tiebreakStartingServer
    }
}

public enum MatchStatus: Codable, Equatable, Sendable {
    case notStarted
    case inProgress
    case paused
    case completed(winner: TeamSide)
}

public struct MatchState: Codable, Equatable, Sendable {
    public var id: UUID
    public var teams: SidePair<Team>
    public var format: MatchFormat
    public var completedSets: [CompletedSet]
    public var currentGames: SidePair<Int>
    public var currentGame: GameState
    public var server: TeamSide
    public var initialServer: TeamSide
    public var totalPointsWon: SidePair<Int>
    public var status: MatchStatus
    public var startedAt: Date?
    public var endedAt: Date?

    public init(
        id: UUID = UUID(),
        teams: SidePair<Team>,
        format: MatchFormat = .standardSingles,
        initialServer: TeamSide = .home
    ) {
        self.id = id
        self.teams = teams
        self.format = format
        self.completedSets = []
        self.currentGames = SidePair(home: 0, away: 0)
        self.currentGame = GameState()
        self.server = initialServer
        self.initialServer = initialServer
        self.totalPointsWon = SidePair(home: 0, away: 0)
        self.status = .notStarted
        self.startedAt = nil
        self.endedAt = nil
    }

    public var setsWon: SidePair<Int> {
        completedSets.reduce(into: SidePair(home: 0, away: 0)) { result, set in
            if let winner = set.winner {
                result[winner] += 1
            }
        }
    }

    public var receiver: TeamSide { server.opponent }

    public var isComplete: Bool {
        if case .completed = status { return true }
        return false
    }
}

public enum MatchSource: String, Codable, Sendable {
    case manual
    case speechLocal
    case speechCloud
    case importedMedia
    case system
}

public struct ScoreEvidence: Codable, Equatable, Sendable {
    public var transcript: String?
    public var confidence: Double?
    public var providerID: String?
    public var source: MatchSource

    public init(
        transcript: String? = nil,
        confidence: Double? = nil,
        providerID: String? = nil,
        source: MatchSource
    ) {
        self.transcript = transcript
        self.confidence = confidence
        self.providerID = providerID
        self.source = source
    }
}

public struct ScoreCorrection: Codable, Equatable, Sendable {
    public var completedSets: [CompletedSet]
    public var currentGames: SidePair<Int>
    public var currentGame: GameState
    public var server: TeamSide

    public init(
        completedSets: [CompletedSet],
        currentGames: SidePair<Int>,
        currentGame: GameState,
        server: TeamSide
    ) {
        self.completedSets = completedSets
        self.currentGames = currentGames
        self.currentGame = currentGame
        self.server = server
    }
}
