import CourtVoiceCore
import XCTest

@testable import CourtVoiceApp

@MainActor
final class SpeechScoringTests: XCTestCase {
  func testLegalReportedScoreAwardsServerPoint() async throws {
    let controller = try makeController()

    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 0)
    XCTAssertTrue(controller.lastActionDescription.contains("Agent scored"))
  }

  func testHypotheticalLanguageDoesNotMutateScore() async throws {
    let controller = try makeController()

    await controller.ingestFinalTranscriptForTesting("如果赢了就是三十比十五")
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints, SidePair(home: 0, away: 0))
  }

  func testLowConfidenceScoreDoesNotChangeOfficialScore() async throws {
    let controller = try makeController()

    await controller.ingestFinalTranscriptForTesting("15-0", confidence: 0.5)
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 0)
    XCTAssertTrue(controller.lastActionDescription.contains("Held"))
  }

  func testRepeatedCurrentScoreDoesNotDuplicatePoint() async throws {
    let controller = try makeController()

    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 0)
  }

  func testReasoningProposalCanScoreWhenParserDoesNot() async throws {
    let answer =
      #"{"intent":"reported_score","server":"fifteen","receiver":"love","confidence":0.96,"summary":"15-0"}"#
    let controller = try makeController(reasoningClient: StubScoreReasoningClient(answer: answer))

    await controller.ingestFinalTranscriptForTesting("xyzzy clean winner")
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(controller.reasoningPhase, .complete)
    XCTAssertTrue(controller.reasoningAnswer.contains("reported_score"))
  }

  func testReachableLaterScoreCatchesUpInTheSameGame() async throws {
    let controller = try makeController()

    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.ingestFinalTranscriptForTesting("30平")
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 2)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 2)
  }

  func testSpokenSentenceFifteenLoveScoresFromStablePartial() async throws {
    var configuration = SpeechConfiguration.standard
    configuration.utteranceCommitDelay = 0.05
    let controller = try makeController(configuration: configuration)

    await controller.ingestTranscriptForTesting(
      "现在比分是15比零",
      confidence: 0.31,
      isFinal: false
    )
    try await Task.sleep(for: .milliseconds(120))
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 0)
  }

  func testStablePartialTranscriptCommitsAfterPause() async throws {
    var configuration = SpeechConfiguration.standard
    configuration.utteranceCommitDelay = 0.05
    let controller = try makeController(configuration: configuration)

    await controller.ingestTranscriptForTesting("15-0", isFinal: false)
    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 0)

    try await Task.sleep(for: .milliseconds(120))
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertTrue(controller.lastTranscriptIsFinal)
  }

  func testStablePartialThenMatchingFinalDoesNotDoubleCount() async throws {
    var configuration = SpeechConfiguration.standard
    configuration.utteranceCommitDelay = 0.05
    let controller = try makeController(configuration: configuration)

    await controller.ingestTranscriptForTesting("15-0", isFinal: false)
    try await Task.sleep(for: .milliseconds(120))
    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 0)
  }

  func testReasoningDoesNotDoubleCountAfterParserScores() async throws {
    let answer =
      #"{"intent":"reported_score","server":"thirty","receiver":"love","confidence":0.96,"summary":"30-0"}"#
    let controller = try makeController(reasoningClient: StubScoreReasoningClient(answer: answer))

    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.waitForReasoningToSettleForTesting()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 0)
  }

  private func makeController(
    configuration: SpeechConfiguration = .standard,
    reasoningClient: (any ScoreReasoningClient)? = nil
  ) throws -> MatchSessionController {
    let repository = MatchRepository(baseDirectory: temporaryDirectory())
    let state = MatchState(
      teams: SidePair(
        home: Team(displayName: "Server"),
        away: Team(displayName: "Receiver")
      ),
      initialServer: .home
    )
    return try MatchSessionController(
      initialState: state,
      repository: repository,
      speechConfiguration: configuration,
      reasoningClient: reasoningClient
    )
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
  }
}

private struct StubScoreReasoningClient: ScoreReasoningClient {
  let answer: String

  func streamProposal(
    transcript: String,
    matchContext: String,
    onEvent: @escaping @Sendable (ScoreReasoningEvent) -> Void
  ) async throws -> String {
    onEvent(.thinkingDelta("checking the call"))
    onEvent(.answerDelta(answer))
    return answer
  }
}
