import Foundation
import CourtVoiceCore

public enum ScoreIntentResolution: Equatable, Sendable {
    case event(MatchEventKind)
    case events([MatchEventKind])
    case alreadyCurrent
    case confirmationRequired(String)
    case ignored(String)
}

public struct ScoreIntentResolver: Sendable {
    public init() {}

    public func resolve(
        _ candidate: IntentCandidate,
        state: MatchState
    ) -> ScoreIntentResolution {
        guard candidate.intent != .discussion else {
            return .ignored("Hypothetical or conversational score language must not mutate the match.")
        }
        guard candidate.intent != .unknown else {
            return .ignored("No supported tennis scoring intent was detected.")
        }

        if candidate.requiresConfirmation {
            return .confirmationRequired(candidate.normalizedText)
        }

        switch candidate.intent {
        case let .awardPoint(side):
            return .event(.pointAwarded(side))
        case .undo:
            return .ignored("Undo is handled by the event timeline so the revoked event remains auditable.")
        case .replayPoint:
            return .event(.letCalled)
        case .pause:
            return .event(.matchPaused)
        case .resume:
            return .event(.matchResumed)
        case .deuce:
            return resolveReportedRawPoints(
                SidePair(home: 3, away: 3),
                state: state
            )
        case .advantageServer:
            var points = SidePair(home: 3, away: 3)
            points[state.server] = 4
            return resolveReportedRawPoints(points, state: state)
        case .advantageReceiver:
            var points = SidePair(home: 3, away: 3)
            points[state.receiver] = 4
            return resolveReportedRawPoints(points, state: state)
        case let .reportedScore(serverPoint, receiverPoint):
            var points = SidePair(home: 0, away: 0)
            points[state.server] = serverPoint.rawPointCount
            points[state.receiver] = receiverPoint.rawPointCount
            return resolveReportedRawPoints(points, state: state)
        case .discussion, .unknown:
            return .ignored("The candidate is not a score mutation.")
        }
    }

    private func resolveReportedRawPoints(
        _ reported: SidePair<Int>,
        state: MatchState
    ) -> ScoreIntentResolution {
        if state.currentGame.isTiebreak {
            return .confirmationRequired("A regular point score was heard during a tiebreak.")
        }
        if state.currentGame.rawPoints == reported {
            return .alreadyCurrent
        }

        let current = state.currentGame.rawPoints
        let possibleHomePoint = nextPoints(afterAwarding: .home, current: current, format: state.format)
        let possibleAwayPoint = nextPoints(afterAwarding: .away, current: current, format: state.format)

        if reported == possibleHomePoint {
            return .event(.pointAwarded(.home))
        }
        if reported == possibleAwayPoint {
            return .event(.pointAwarded(.away))
        }

        if let path = catchUpPath(from: current, to: reported, format: state.format) {
            return .events(path.map { .pointAwarded($0) })
        }

        return .confirmationRequired("The reported score is not a reachable score in the current game.")
    }

    private func catchUpPath(
        from current: SidePair<Int>,
        to target: SidePair<Int>,
        format: MatchFormat
    ) -> [TeamSide]? {
        var queue: [(SidePair<Int>, [TeamSide])] = [(current, [])]
        var seen: Set<String> = [pointKey(current)]
        var index = 0

        while index < queue.count {
            let (points, path) = queue[index]
            index += 1
            guard path.count < 7 else { continue }

            for side in [TeamSide.home, TeamSide.away] {
                let next = nextPoints(afterAwarding: side, current: points, format: format)
                let key = pointKey(next)
                guard seen.contains(key) == false else { continue }
                seen.insert(key)
                let nextPath = path + [side]
                if next == target {
                    return nextPath
                }
                queue.append((next, nextPath))
            }
        }

        return nil
    }

    private func pointKey(_ points: SidePair<Int>) -> String {
        "\(points.home)-\(points.away)"
    }

    private func nextPoints(
        afterAwarding side: TeamSide,
        current: SidePair<Int>,
        format: MatchFormat
    ) -> SidePair<Int> {
        var next = current
        next[side] += 1

        if format.gameScoring == .advantage,
           next.home >= 3,
           next.away >= 3,
           next.home == next.away {
            return SidePair(home: 3, away: 3)
        }
        return next
    }
}
