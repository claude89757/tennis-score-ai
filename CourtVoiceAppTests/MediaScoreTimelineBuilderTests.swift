import CourtVoiceCore
import XCTest

@testable import CourtVoiceApp

final class MediaScoreTimelineBuilderTests: XCTestCase {
  func testBuildAcceptsSequentialLegalScores() {
    let initialState = MatchState(
      teams: SidePair(
        home: Team(displayName: "A"),
        away: Team(displayName: "B")
      ),
      initialServer: .home
    )
    let utterances = [
      MediaUtterance(
        startTime: 3,
        endTime: 4,
        text: "15-0",
        confidence: 0.99,
        providerID: "test"
      ),
      MediaUtterance(
        startTime: 9,
        endTime: 10,
        text: "30-0",
        confidence: 0.99,
        providerID: "test"
      ),
    ]

    let result = MediaScoreTimelineBuilder().build(
      initialState: initialState,
      utterances: utterances,
      automaticAcceptanceThreshold: 0.92
    )

    XCTAssertEqual(result.acceptedCount, 2)
    XCTAssertEqual(result.timeline.currentState.currentGame.rawPoints.home, 2)
  }

  func testBuildFlagsLowConfidenceScoreForReview() {
    let initialState = MatchState(
      teams: SidePair(
        home: Team(displayName: "A"),
        away: Team(displayName: "B")
      )
    )
    let utterance = MediaUtterance(
      startTime: 1,
      endTime: 2,
      text: "15-0",
      confidence: 0.4,
      providerID: "test"
    )

    let result = MediaScoreTimelineBuilder().build(
      initialState: initialState,
      utterances: [utterance],
      automaticAcceptanceThreshold: 0.92
    )

    XCTAssertEqual(result.reviewCount, 1)
    XCTAssertEqual(result.timeline.currentState.currentGame.rawPoints.home, 0)
  }

  func testBuildAppliesExplicitUndoAsAuditableEvent() {
    let initialState = MatchState(
      teams: SidePair(
        home: Team(displayName: "A"),
        away: Team(displayName: "B")
      )
    )
    let utterances = [
      MediaUtterance(
        startTime: 1,
        endTime: 2,
        text: "15-0",
        confidence: 0.99,
        providerID: "test"
      ),
      MediaUtterance(
        startTime: 4,
        endTime: 5,
        text: "撤销",
        confidence: 0.99,
        providerID: "test"
      ),
    ]

    let result = MediaScoreTimelineBuilder().build(
      initialState: initialState,
      utterances: utterances,
      automaticAcceptanceThreshold: 0.92
    )

    XCTAssertEqual(result.acceptedCount, 2)
    XCTAssertEqual(result.timeline.currentState.currentGame.rawPoints.home, 0)
    XCTAssertTrue(
      result.timeline.events.contains { event in
        if case .eventRevoked = event.kind { return true }
        return false
      }
    )
  }
}
