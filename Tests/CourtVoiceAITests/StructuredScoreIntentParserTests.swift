import XCTest
import CourtVoiceCore
@testable import CourtVoiceAI

final class StructuredScoreIntentParserTests: XCTestCase {
  private let parser = StructuredScoreIntentParser()

  func testParsesReportedScoreFromFencedJSON() {
    let text = """
      The caller announced a legal next score.
      ```json
      {"intent":"reported_score","server":"thirty","receiver":"fifteen","confidence":0.94,"summary":"30-15"}
      ```
      """

    let candidate = parser.parse(jsonText: text)
    XCTAssertEqual(candidate?.intent, .reportedScore(server: .thirty, receiver: .fifteen))
    XCTAssertEqual(candidate?.normalizedText, "30-15")
    XCTAssertEqual(candidate?.parserID, "deepseek.structured.v1")
    XCTAssertEqual(candidate?.requiresConfirmation, false)
  }

  func testParsesAwardPointAndUnknown() {
    XCTAssertEqual(
      parser.parse(jsonText: #"{"intent":"award_point","side":"away","confidence":0.8}"#)?.intent,
      .awardPoint(.away)
    )
    XCTAssertEqual(
      parser.parse(jsonText: #"{"intent":"discussion","summary":"hypothetical"}"#)?.intent,
      .discussion
    )
    XCTAssertNil(parser.parse(jsonText: "not json"))
  }
}
