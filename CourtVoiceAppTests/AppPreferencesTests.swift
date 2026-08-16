import XCTest

@testable import CourtVoiceApp

final class AppPreferencesTests: XCTestCase {
  func testOlderPreferencesDecodeWithSpeechDefaults() throws {
    let data = Data(#"{"hasCompletedOnboarding":true}"#.utf8)

    let preferences = try JSONDecoder().decode(AppPreferences.self, from: data)

    XCTAssertTrue(preferences.hasCompletedOnboarding)
    XCTAssertEqual(preferences.speechConfiguration, .standard)
  }
}
