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

  func testResumeRestoresPersistedTimeline() async throws {
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
    await controller.awardPoint(to: .away)

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

  func testCorrectionUpdatesCurrentGamePoints() async throws {
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

    await controller.applyCorrection(
      ScoreCorrection(
        completedSets: [],
        currentGames: SidePair(home: 3, away: 2),
        currentGame: GameState(rawPoints: SidePair(home: 2, away: 1)),
        server: .away
      )
    )

    XCTAssertEqual(controller.state.currentGames.home, 3)
    XCTAssertEqual(controller.state.currentGames.away, 2)
    XCTAssertEqual(controller.state.currentGame.rawPoints.home, 2)
    XCTAssertEqual(controller.state.currentGame.rawPoints.away, 1)
    XCTAssertEqual(controller.state.server, .away)
  }
}
