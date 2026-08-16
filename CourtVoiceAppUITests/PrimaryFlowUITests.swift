import XCTest

@MainActor
final class PrimaryFlowUITests: XCTestCase {
  private var screenshotDirectory: URL? {
    guard let path = ProcessInfo.processInfo.environment["COURTVOICE_SCREENSHOT_DIR"],
      path.isEmpty == false
    else {
      return nil
    }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  override func setUp() async throws {
    try await super.setUp()
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
  }

  func testOnboardingManualScoringPersistenceAndSettings() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-ui-testing-reset"]
    app.launch()

    XCTAssertTrue(app.staticTexts["Call the score naturally"].waitForExistence(timeout: 8))
    capture(app, name: "01-onboarding")

    app.buttons["onboarding.skip"].tap()

    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))
    capture(app, name: "02-home")

    app.buttons["home.startMatch"].tap()
    XCTAssertTrue(app.buttons["matchSetup.start"].waitForExistence(timeout: 5))
    capture(app, name: "03-match-setup")
    app.buttons["matchSetup.start"].tap()

    XCTAssertTrue(app.buttons["live.award.home"].waitForExistence(timeout: 8))
    capture(app, name: "04-live-match")

    for _ in 0..<3 {
      app.buttons["live.award.home"].tap()
      app.buttons["live.award.away"].tap()
    }
    let reachedDeuce =
      app.staticTexts["Deuce"].waitForExistence(timeout: 2)
      || app.staticTexts["平分"].exists
      || app.staticTexts["40"].exists
    XCTAssertTrue(reachedDeuce, "Manual scoring should reach deuce after three points each.")

    app.buttons["live.award.home"].tap()
    app.buttons["live.undo"].tap()
    app.buttons["live.correct"].tap()
    XCTAssertTrue(app.navigationBars["Correct score"].waitForExistence(timeout: 5))
    capture(app, name: "05-score-correction")
    app.buttons["Cancel"].tap()

    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.buttons["live.award.home"].waitForExistence(timeout: 3))
    capture(app, name: "06-live-landscape")
    XCUIDevice.shared.orientation = .portrait

    app.buttons["live.close"].tap()
    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))

    app.terminate()
    app.launchArguments = ["-ui-testing"]
    app.launch()

    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["Continue"].waitForExistence(timeout: 5))
    capture(app, name: "07-home-after-relaunch")

    app.tabBars.buttons["Matches"].tap()
    XCTAssertTrue(app.staticTexts["Player 1"].waitForExistence(timeout: 5))
    capture(app, name: "08-match-history")

    app.tabBars.buttons["Settings"].tap()
    XCTAssertTrue(app.staticTexts["Speech & AI models"].waitForExistence(timeout: 5))
    capture(app, name: "09-settings")

    let paywallEntry = app.buttons["Upgrade to CourtVoice Pro"].exists
      ? app.buttons["Upgrade to CourtVoice Pro"]
      : app.buttons["CourtVoice Pro active"]
    paywallEntry.tap()
    XCTAssertTrue(app.navigationBars["CourtVoice Pro"].waitForExistence(timeout: 5))
    capture(app, name: "10-paywall")
    app.buttons["Done"].tap()

    app.buttons["Speech & AI models"].tap()
    XCTAssertTrue(app.navigationBars["Speech & AI"].waitForExistence(timeout: 5))
    capture(app, name: "11-model-settings")
  }

  func testMediaImportSurfaceStaysReachableWithoutDisablingManualScoring() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-skip-onboarding"]
    app.launch()

    XCTAssertTrue(app.buttons["home.analyzeMedia"].waitForExistence(timeout: 8))
    app.buttons["home.analyzeMedia"].tap()
    XCTAssertTrue(app.navigationBars["Analyze match media"].waitForExistence(timeout: 5))
    capture(app, name: "12-media-analysis")
    app.buttons["Close"].tap()
    XCTAssertTrue(app.navigationBars["Analyze match media"].waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.buttons["home.startMatch"].isHittable)
    capture(app, name: "13-home-after-media")
  }

  private func capture(_ app: XCUIApplication, name: String) {
    let screenshot = app.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)

    guard let screenshotDirectory else { return }
    let url = screenshotDirectory.appendingPathComponent("\(name).png")
    do {
      try screenshot.pngRepresentation.write(to: url)
    } catch {
      XCTFail("Unable to write screenshot \(name): \(error.localizedDescription)")
    }
  }
}
