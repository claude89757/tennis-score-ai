import CourtVoiceCore
import XCTest

@testable import CourtVoiceApp

@MainActor
final class SpeechScoringTests: XCTestCase {
  func testLegalReportedScoreAwardsServerPoint() async throws {
    let repository = MatchRepository(baseDirectory: temporaryDirectory())
    let state = MatchState(
      teams: SidePair(
        home: Team(displayName: "Server"),
        away: Team(displayName: "Receiver")
      ),
      initialServer: .home
    )
    let controller = try MatchSessionController(
      initialState: state,
      repository: repository
    )

    await controller.ingestFinalTranscriptForTesting("15-0")

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 0)
    XCTAssertNil(controller.pendingSpeechAction)
  }

  func testHypotheticalLanguageDoesNotMutateScore() async throws {
    let repository = MatchRepository(baseDirectory: temporaryDirectory())
    let state = MatchState(
      teams: SidePair(
        home: Team(displayName: "A"),
        away: Team(displayName: "B")
      )
    )
    let controller = try MatchSessionController(
      initialState: state,
      repository: repository
    )

    await controller.ingestFinalTranscriptForTesting("如果赢了就是三十比十五")

    XCTAssertEqual(controller.state.currentGame.rawPoints, SidePair(home: 0, away: 0))
    XCTAssertNil(controller.pendingSpeechAction)
  }

  func testLowConfidenceScoreRequiresConfirmation() async throws {
    let repository = MatchRepository(baseDirectory: temporaryDirectory())
    let state = MatchState(
      teams: SidePair(
        home: Team(displayName: "A"),
        away: Team(displayName: "B")
      )
    )
    let controller = try MatchSessionController(
      initialState: state,
      repository: repository
    )

    await controller.ingestFinalTranscriptForTesting("15-0", confidence: 0.5)

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 0)
    XCTAssertNotNil(controller.pendingSpeechAction)

    await controller.confirmPendingSpeechAction()

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertNil(controller.pendingSpeechAction)
  }

  func testRepeatedCurrentScoreDoesNotDuplicatePoint() async throws {
    let repository = MatchRepository(baseDirectory: temporaryDirectory())
    let state = MatchState(
      teams: SidePair(
        home: Team(displayName: "Server"),
        away: Team(displayName: "Receiver")
      ),
      initialServer: .home
    )
    let controller = try MatchSessionController(
      initialState: state,
      repository: repository
    )

    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.ingestFinalTranscriptForTesting("15-0")

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 0)
    XCTAssertNil(controller.pendingSpeechAction)
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
  }
}
