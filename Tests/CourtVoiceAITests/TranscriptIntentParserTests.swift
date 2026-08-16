import XCTest
import CourtVoiceCore
@testable import CourtVoiceAI

final class TranscriptIntentParserTests: XCTestCase {
    private let parser = TranscriptIntentParser()

    func testParsesScoreEmbeddedInSpokenSentence() {
        let result = parser.parse("现在比分是15比零")
        XCTAssertEqual(result.intent, .reportedScore(server: .fifteen, receiver: .love))
        XCTAssertFalse(result.requiresConfirmation)
        XCTAssertGreaterThanOrEqual(result.confidence, 0.92)
    }

    func testIgnoresNonTennisNumericScore() {
        let result = parser.parse("现在比分是一比一")
        XCTAssertEqual(result.intent, .unknown)
    }

    func testParsesChineseScore() {
        let result = parser.parse("三十比十五")
        XCTAssertEqual(result.intent, .reportedScore(server: .thirty, receiver: .fifteen))
        XCTAssertGreaterThan(result.confidence, 0.95)
    }

    func testParsesEnglishScore() {
        let result = parser.parse("thirty fifteen")
        XCTAssertEqual(result.intent, .reportedScore(server: .thirty, receiver: .fifteen))
    }

    func testParsesCorrectionSentenceByExtractingFinalScore() {
        let result = parser.parse("不是三十比十五，是三十平")
        XCTAssertEqual(result.intent, .reportedScore(server: .thirty, receiver: .thirty))
        XCTAssertTrue(result.requiresConfirmation)
    }

    func testHypotheticalLanguageCannotMutateScore() {
        let result = parser.parse("如果我赢了就是四十比十五")
        XCTAssertEqual(result.intent, .discussion)
    }

    func testUndoAndReplay() {
        XCTAssertEqual(parser.parse("撤销上一分").intent, .undo)
        XCTAssertEqual(parser.parse("刚才那分重打").intent, .replayPoint)
    }

    func testResolverAcceptsSingleLegalTransition() {
        var state = MatchState(
            teams: SidePair(
                home: Team(displayName: "A"),
                away: Team(displayName: "B")
            )
        )
        state.status = .inProgress
        state.currentGame.rawPoints = SidePair(home: 1, away: 1)
        state.server = .home

        let candidate = parser.parse("三十比十五")
        XCTAssertEqual(
            ScoreIntentResolver().resolve(candidate, state: state),
            .event(.pointAwarded(.home))
        )
    }

    func testResolverCatchesUpToReachableInGameScore() {
        var state = MatchState(
            teams: SidePair(
                home: Team(displayName: "A"),
                away: Team(displayName: "B")
            )
        )
        state.status = .inProgress
        state.currentGame.rawPoints = SidePair(home: 1, away: 0)
        state.server = .home

        let candidate = parser.parse("30平")
        XCTAssertEqual(candidate.intent, .reportedScore(server: .thirty, receiver: .thirty))
        guard case .events(let kinds) = ScoreIntentResolver().resolve(candidate, state: state) else {
            return XCTFail("A reachable 30-all from 15-0 should catch up")
        }
        XCTAssertEqual(kinds.count, 3)
    }

    func testResolverRequiresConfirmationForBackwardsScore() {
        var state = MatchState(
            teams: SidePair(
                home: Team(displayName: "A"),
                away: Team(displayName: "B")
            )
        )
        state.status = .inProgress
        state.currentGame.rawPoints = SidePair(home: 3, away: 0)
        let candidate = parser.parse("十五比零")
        guard case .confirmationRequired = ScoreIntentResolver().resolve(candidate, state: state) else {
            return XCTFail("A backwards score must not auto-commit")
        }
    }
}
