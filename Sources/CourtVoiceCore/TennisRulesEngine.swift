import Foundation

public enum MatchRulesError: Error, Equatable, LocalizedError, Sendable {
    case matchAlreadyStarted
    case matchNotInProgress
    case matchAlreadyCompleted
    case invalidCorrection(String)
    case invalidEvent(String)
    case duplicateIdempotencyKey(String)
    case nothingToUndo

    public var errorDescription: String? {
        switch self {
        case .matchAlreadyStarted:
            return "The match has already started."
        case .matchNotInProgress:
            return "The match is not currently in progress."
        case .matchAlreadyCompleted:
            return "The match has already completed."
        case let .invalidCorrection(reason):
            return "Invalid score correction: \(reason)"
        case let .invalidEvent(reason):
            return "Invalid match event: \(reason)"
        case let .duplicateIdempotencyKey(key):
            return "Duplicate idempotency key: \(key)"
        case .nothingToUndo:
            return "There is no mutable scoring event to undo."
        }
    }
}

public enum MatchReducer {
    public static func replay(initialState: MatchState, events: [MatchEvent]) -> MatchState {
        let revokedIDs = Set(events.compactMap { event -> UUID? in
            guard case let .eventRevoked(eventID) = event.kind else { return nil }
            return eventID
        })

        return events.reduce(initialState) { state, event in
            guard revokedIDs.contains(event.id) == false else { return state }
            guard case .eventRevoked = event.kind else {
                return (try? apply(event, to: state)) ?? state
            }
            return state
        }
    }

    public static func apply(_ event: MatchEvent, to state: MatchState) throws -> MatchState {
        var next = state

        switch event.kind {
        case .matchStarted:
            guard state.status == .notStarted else { throw MatchRulesError.matchAlreadyStarted }
            next.status = .inProgress
            next.startedAt = event.occurredAt
            next.currentGame = initialGame(for: next)

        case let .pointAwarded(side):
            guard state.status == .inProgress else {
                if state.isComplete { throw MatchRulesError.matchAlreadyCompleted }
                throw MatchRulesError.matchNotInProgress
            }
            try awardPoint(to: side, state: &next, occurredAt: event.occurredAt)

        case .letCalled:
            guard state.status == .inProgress else { throw MatchRulesError.matchNotInProgress }

        case let .scoreCorrected(correction):
            guard state.isComplete == false else { throw MatchRulesError.matchAlreadyCompleted }
            try validate(correction: correction, format: state.format)
            next.completedSets = correction.completedSets
            next.currentGames = correction.currentGames
            next.currentGame = correction.currentGame
            next.server = correction.server
            next.status = state.status == .notStarted ? .inProgress : state.status
            if next.startedAt == nil { next.startedAt = event.occurredAt }

        case let .serverChanged(server):
            guard state.isComplete == false else { throw MatchRulesError.matchAlreadyCompleted }
            next.server = server

        case .matchPaused:
            guard state.status == .inProgress else { throw MatchRulesError.matchNotInProgress }
            next.status = .paused

        case .matchResumed:
            guard state.status == .paused else {
                throw MatchRulesError.invalidEvent("Only a paused match can be resumed.")
            }
            next.status = .inProgress

        case let .matchEnded(winner):
            guard state.isComplete == false else { throw MatchRulesError.matchAlreadyCompleted }
            next.status = .completed(winner: winner)
            next.endedAt = event.occurredAt

        case .eventRevoked:
            break
        }

        return next
    }

    public static func validate(correction: ScoreCorrection, format: MatchFormat) throws {
        guard correction.currentGames.home >= 0, correction.currentGames.away >= 0 else {
            throw MatchRulesError.invalidCorrection("Games cannot be negative.")
        }
        guard correction.currentGames.home <= 7, correction.currentGames.away <= 7 else {
            throw MatchRulesError.invalidCorrection("A current set cannot exceed seven games per side.")
        }
        guard correction.currentGame.rawPoints.home >= 0,
              correction.currentGame.rawPoints.away >= 0 else {
            throw MatchRulesError.invalidCorrection("Points cannot be negative.")
        }

        if correction.currentGame.isTiebreak {
            guard let target = correction.currentGame.tiebreakTarget, target >= 2 else {
                throw MatchRulesError.invalidCorrection("A tiebreak requires a valid target.")
            }
            guard correction.currentGame.tiebreakStartingServer != nil else {
                throw MatchRulesError.invalidCorrection("A tiebreak requires its starting server.")
            }
        } else {
            let maximumUnfinishedPoint = format.gameScoring == .noAd ? 3 : 4
            let home = correction.currentGame.rawPoints.home
            let away = correction.currentGame.rawPoints.away
            guard home <= maximumUnfinishedPoint, away <= maximumUnfinishedPoint else {
                throw MatchRulesError.invalidCorrection("The unfinished game has an impossible point count.")
            }
            if format.gameScoring == .advantage, home == 4, away == 4 {
                throw MatchRulesError.invalidCorrection("Both teams cannot hold advantage simultaneously.")
            }
        }

        let completedWins = correction.completedSets.reduce(into: SidePair(home: 0, away: 0)) { result, set in
            if let winner = set.winner { result[winner] += 1 }
        }
        guard completedWins.home < format.setsRequiredToWin,
              completedWins.away < format.setsRequiredToWin else {
            throw MatchRulesError.invalidCorrection("A completed match cannot have an active current set.")
        }
    }

    private static func awardPoint(to winner: TeamSide, state: inout MatchState, occurredAt: Date) throws {
        state.totalPointsWon[winner] += 1
        state.currentGame.rawPoints[winner] += 1

        if state.currentGame.isTiebreak {
            try resolveTiebreakPoint(winner: winner, state: &state, occurredAt: occurredAt)
        } else {
            resolveStandardGamePoint(winner: winner, state: &state, occurredAt: occurredAt)
        }
    }

    private static func resolveStandardGamePoint(
        winner: TeamSide,
        state: inout MatchState,
        occurredAt: Date
    ) {
        let points = state.currentGame.rawPoints
        let winnerPoints = points[winner]
        let loserPoints = points[winner.opponent]

        let gameWon: Bool
        switch state.format.gameScoring {
        case .advantage:
            gameWon = winnerPoints >= 4 && winnerPoints - loserPoints >= 2
        case .noAd:
            gameWon = winnerPoints >= 4
        }

        guard gameWon else {
            if state.format.gameScoring == .advantage,
               points.home >= 3,
               points.away >= 3,
               abs(points.home - points.away) == 0 {
                state.currentGame.rawPoints = SidePair(home: 3, away: 3)
            }
            return
        }

        state.currentGames[winner] += 1
        state.server = state.server.opponent
        state.currentGame = initialGame(for: state)
        resolveSetIfNeeded(gameWinner: winner, state: &state, occurredAt: occurredAt)
    }

    private static func resolveTiebreakPoint(
        winner: TeamSide,
        state: inout MatchState,
        occurredAt: Date
    ) throws {
        guard let target = state.currentGame.tiebreakTarget,
              let startingServer = state.currentGame.tiebreakStartingServer else {
            throw MatchRulesError.invalidEvent("Tiebreak metadata is missing.")
        }

        let points = state.currentGame.rawPoints
        let winnerPoints = points[winner]
        let loserPoints = points[winner.opponent]
        let tiebreakWon = winnerPoints >= target && winnerPoints - loserPoints >= 2

        if tiebreakWon {
            let isMatchTiebreak = isDecidingMatchTiebreak(state)
            if isMatchTiebreak {
                state.completedSets.append(
                    CompletedSet(
                        games: SidePair(home: 0, away: 0),
                        tiebreakPoints: points,
                        isMatchTiebreak: true
                    )
                )
            } else {
                var finalGames = state.currentGames
                finalGames[winner] += 1
                state.completedSets.append(
                    CompletedSet(games: finalGames, tiebreakPoints: points)
                )
            }

            state.currentGames = SidePair(home: 0, away: 0)
            state.server = startingServer.opponent
            state.currentGame = GameState()
            resolveMatchOrPrepareNextSet(state: &state, occurredAt: occurredAt)
            return
        }

        let pointsPlayed = points.home + points.away
        state.server = nextTiebreakServer(
            startingServer: startingServer,
            nextPointIndex: pointsPlayed
        )
    }

    private static func resolveSetIfNeeded(
        gameWinner: TeamSide,
        state: inout MatchState,
        occurredAt: Date
    ) {
        let games = state.currentGames
        let winnerGames = games[gameWinner]
        let loserGames = games[gameWinner.opponent]

        if winnerGames >= 6 && winnerGames - loserGames >= 2 {
            state.completedSets.append(CompletedSet(games: games))
            state.currentGames = SidePair(home: 0, away: 0)
            resolveMatchOrPrepareNextSet(state: &state, occurredAt: occurredAt)
            return
        }

        if games.home == 6 && games.away == 6 {
            state.currentGame = GameState(
                isTiebreak: true,
                tiebreakTarget: state.format.tiebreakTarget,
                tiebreakStartingServer: state.server
            )
        }
    }

    private static func resolveMatchOrPrepareNextSet(state: inout MatchState, occurredAt: Date) {
        let setsWon = state.setsWon
        if setsWon.home >= state.format.setsRequiredToWin {
            state.status = .completed(winner: .home)
            state.endedAt = occurredAt
            return
        }
        if setsWon.away >= state.format.setsRequiredToWin {
            state.status = .completed(winner: .away)
            state.endedAt = occurredAt
            return
        }

        state.currentGame = initialGame(for: state)
    }

    private static func initialGame(for state: MatchState) -> GameState {
        if isDecidingMatchTiebreak(state) {
            let target: Int
            if case let .matchTiebreak(configuredTarget) = state.format.decidingSetRule {
                target = configuredTarget
            } else {
                target = 10
            }
            return GameState(
                isTiebreak: true,
                tiebreakTarget: target,
                tiebreakStartingServer: state.server
            )
        }
        return GameState()
    }

    private static func isDecidingMatchTiebreak(_ state: MatchState) -> Bool {
        guard case .matchTiebreak = state.format.decidingSetRule else { return false }
        let setsWon = state.setsWon
        let decidingSetIndex = state.format.bestOfSets - 1
        return state.completedSets.count == decidingSetIndex &&
            setsWon.home == setsWon.away
    }

    private static func nextTiebreakServer(
        startingServer: TeamSide,
        nextPointIndex: Int
    ) -> TeamSide {
        guard nextPointIndex > 0 else { return startingServer }
        let twoPointBlock = (nextPointIndex - 1) / 2
        return twoPointBlock.isMultiple(of: 2) ? startingServer.opponent : startingServer
    }
}
