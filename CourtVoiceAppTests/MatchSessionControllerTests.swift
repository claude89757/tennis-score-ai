import CourtVoiceCore
import XCTest

@testable import CourtVoiceApp

@MainActor
final class MatchSessionControllerTests: XCTestCase {
  func testAwardPointPersistsTimeline() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repository = MatchRepository(baseDirectory: directory)
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

    await controller.awardPoint(to: .home)

    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 1)
    let stored = try await repository.loadAll()
    XCTAssertEqual(stored.count, 1)
    XCTAssertEqual(stored[0].state.currentGame.rawPoints.home, 1)
  }

  func testUndoRestoresPreviousScore() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let repository = MatchRepository(baseDirectory: directory)
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

    await controller.awardPoint(to: .away)
    await controller.undo()

    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 0)
  }
}
