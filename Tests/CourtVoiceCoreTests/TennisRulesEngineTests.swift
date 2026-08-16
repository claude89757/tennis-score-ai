import XCTest
@testable import CourtVoiceCore

final class TennisRulesEngineTests: XCTestCase {
    private let evidence = ScoreEvidence(source: .manual)

    func testAdvantageGameRequiresTwoPointLead() throws {
        var timeline = startedTimeline()
        try award([.home, .home, .home, .away, .away, .away], to: &timeline)
        XCTAssertEqual(timeline.currentState.currentGame.rawPoints, SidePair(home: 3, away: 3))

        try timeline.append(MatchEvent(kind: .pointAwarded(.home), evidence: evidence))
        XCTAssertEqual(ScoreFormatter.pointDisplay(for: timeline.currentState), .advantage(.home))

        try timeline.append(MatchEvent(kind: .pointAwarded(.away), evidence: evidence))
        XCTAssertEqual(ScoreFormatter.pointDisplay(for: timeline.currentState), .deuce)

        try award([.home, .home], to: &timeline)
        XCTAssertEqual(timeline.currentState.currentGames.home, 1)
        XCTAssertEqual(timeline.currentState.currentGame.rawPoints, SidePair(home: 0, away: 0))
        XCTAssertEqual(timeline.currentState.server, .away)
    }

    func testNoAdGameEndsOnNextPointAtDeuce() throws {
        var state = makeState(format: MatchFormat(gameScoring: .noAd))
        var timeline = MatchTimeline(initialState: state)
        try timeline.append(MatchEvent(kind: .matchStarted, evidence: evidence))
        try award([.home, .home, .home, .away, .away, .away, .away], to: &timeline)
        state = timeline.currentState
        XCTAssertEqual(state.currentGames, SidePair(home: 0, away: 1))
    }

    func testSevenPointTiebreakCompletesSetAndAlternatesServer() throws {
        var timeline = startedTimeline()
        for _ in 0..<6 {
            try winGame(.home, timeline: &timeline)
            try winGame(.away, timeline: &timeline)
        }

        var state = timeline.currentState
        XCTAssertTrue(state.currentGame.isTiebreak)
        let startingServer = state.currentGame.tiebreakStartingServer
        XCTAssertEqual(startingServer, state.server)

        try timeline.append(MatchEvent(kind: .pointAwarded(.home), evidence: evidence))
        state = timeline.currentState
        XCTAssertEqual(state.server, startingServer?.opponent)

        try award([.home, .home, .away, .home, .away, .home, .home, .home], to: &timeline)
        state = timeline.currentState
        XCTAssertEqual(state.completedSets.count, 1)
        XCTAssertEqual(state.completedSets[0].games, SidePair(home: 7, away: 6))
        XCTAssertEqual(state.completedSets[0].tiebreakPoints, SidePair(home: 7, away: 2))
    }

    func testMatchTiebreakCompletesBestOfThreeMatch() throws {
        let format = MatchFormat(decidingSetRule: .matchTiebreak(target: 10))
        var timeline = MatchTimeline(initialState: makeState(format: format))
        try timeline.append(MatchEvent(kind: .matchStarted, evidence: evidence))

        for _ in 0..<6 { try winGame(.home, timeline: &timeline) }
        for _ in 0..<6 { try winGame(.away, timeline: &timeline) }

        XCTAssertTrue(timeline.currentState.currentGame.isTiebreak)
        XCTAssertEqual(timeline.currentState.currentGame.tiebreakTarget, 10)

        try award(Array(repeating: .home, count: 10), to: &timeline)
        guard case let .completed(winner) = timeline.currentState.status else {
            return XCTFail("Expected a completed match")
        }
        XCTAssertEqual(winner, .home)
        XCTAssertTrue(timeline.currentState.completedSets.last?.isMatchTiebreak == true)
    }

    func testEventRevocationRebuildsStateWithoutDeletingAuditHistory() throws {
        var timeline = startedTimeline()
        let point = MatchEvent(kind: .pointAwarded(.home), evidence: evidence)
        try timeline.append(point)
        XCTAssertEqual(timeline.currentState.currentGame.rawPoints.home, 1)

        let undo = try timeline.revokeLastMutableEvent()
        XCTAssertEqual(timeline.currentState.currentGame.rawPoints.home, 0)
        XCTAssertEqual(timeline.events.count, 3)
        guard case let .eventRevoked(eventID) = undo.kind else {
            return XCTFail("Expected an audit revocation event")
        }
        XCTAssertEqual(eventID, point.id)
    }

    func testIdempotencyKeyPreventsDuplicatePoint() throws {
        var timeline = startedTimeline()
        let event = MatchEvent(
            kind: .pointAwarded(.home),
            evidence: evidence,
            idempotencyKey: "speech-segment-42"
        )
        try timeline.append(event)
        XCTAssertThrowsError(try timeline.append(event)) { error in
            XCTAssertEqual(error as? MatchRulesError, .duplicateIdempotencyKey("speech-segment-42"))
        }
    }

    private func startedTimeline() -> MatchTimeline {
        var timeline = MatchTimeline(initialState: makeState())
        try! timeline.append(MatchEvent(kind: .matchStarted, evidence: evidence))
        return timeline
    }

    private func makeState(format: MatchFormat = .standardSingles) -> MatchState {
        MatchState(
            teams: SidePair(
                home: Team(displayName: "Home"),
                away: Team(displayName: "Away")
            ),
            format: format
        )
    }

    private func award(_ sequence: [TeamSide], to timeline: inout MatchTimeline) throws {
        for side in sequence {
            try timeline.append(MatchEvent(kind: .pointAwarded(side), evidence: evidence))
        }
    }

    private func winGame(_ side: TeamSide, timeline: inout MatchTimeline) throws {
        try award(Array(repeating: side, count: 4), to: &timeline)
    }
}
