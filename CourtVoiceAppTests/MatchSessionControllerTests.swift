import CourtVoiceCore
import XCTest

@testable import CourtVoiceApp

@MainActor
final class MatchSessionControllerTests: XCTestCase {
  func testVoicePointPersistsTimeline() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repository = MatchRepository(baseDirectory: directory)
    let controller = try MatchSessionController(
      initialState: MatchState(
        teams: SidePair(
          home: Team(displayName: "A"),
          away: Team(displayName: "B")
        )
      ),
      repository: repository
    )

    await controller.ingestFinalTranscriptForTesting("15-0")

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    let stored = try await repository.loadAll()
    XCTAssertEqual(stored.count, 1)
    XCTAssertEqual(stored[0].state.currentGame.rawPoints.home, 1)
  }

  func testVoiceUndoRestoresPreviousScore() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repository = MatchRepository(baseDirectory: directory)
    let controller = try MatchSessionController(
      initialState: MatchState(
        teams: SidePair(
          home: Team(displayName: "A"),
          away: Team(displayName: "B")
        )
      ),
      repository: repository
    )

    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.ingestFinalTranscriptForTesting("undo")

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 0)
  }

  func testResumeRestoresPersistedTimeline() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repository = MatchRepository(baseDirectory: directory)
    let controller = try MatchSessionController(
      initialState: MatchState(
        teams: SidePair(
          home: Team(displayName: "A"),
          away: Team(displayName: "B")
        )
      ),
      repository: repository
    )
    await controller.ingestFinalTranscriptForTesting("15-0")
    await controller.ingestFinalTranscriptForTesting("15-15")

    let stored = try await repository.loadAll()
    XCTAssertEqual(stored.count, 1)
    let resumed = MatchSessionController(
      savedMatch: stored[0],
      repository: repository
    )

    XCTAssertEqual(resumed.state.currentGame.rawPoints.home, 1)
    XCTAssertEqual(resumed.state.currentGame.rawPoints.away, 1)
    XCTAssertEqual(resumed.state.status, .inProgress)
  }
}
