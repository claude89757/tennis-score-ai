import XCTest

@testable import CourtVoiceApp

final class L10nTests: XCTestCase {
  func testChineseIsTheDefaultCopy() {
    let copy = L10n(language: .chinese)
    XCTAssertEqual(copy.startMatch, "开始比赛")
    XCTAssertEqual(copy.tabSettings, "设置")
    XCTAssertEqual(copy.liveAction(.matchReady), "比赛已就绪")
  }

  func testEnglishSwitchChangesVisibleCopy() {
    let copy = L10n(language: .english)
    XCTAssertEqual(copy.startMatch, "Start match")
    XCTAssertEqual(copy.tabSettings, "Settings")
    XCTAssertEqual(copy.liveAction(.matchReady), "Match ready")
  }

  func testLanguageSwitchUpdatesSpeechLocale() {
    XCTAssertEqual(AppLanguage.chinese.speechLocaleIdentifier, "zh-CN")
    XCTAssertEqual(AppLanguage.english.speechLocaleIdentifier, "en-US")
  }
}
