import XCTest

@MainActor
final class LiveObservationUITests: XCTestCase {
  override func setUp() async throws {
    try await super.setUp()
    continueAfterFailure = true
    XCUIDevice.shared.orientation = .portrait
  }

  func testLiveCourtObservation() throws {
    guard ProcessInfo.processInfo.environment["COURTVOICE_LIVE_OBSERVE"] == "1" else {
      throw XCTSkip("Set COURTVOICE_LIVE_OBSERVE=1 to run a live on-device court session.")
    }

    let app = XCUIApplication()
    if let key = ProcessInfo.processInfo.environment["COURTVOICE_DEEPSEEK_API_KEY"],
      key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    {
      app.launchEnvironment["COURTVOICE_DEEPSEEK_API_KEY"] = key
    }
    app.launch()

    if app.buttons["onboarding.skip"].waitForExistence(timeout: 3) {
      app.buttons["onboarding.skip"].tap()
    }

    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 10))
    app.buttons["home.startMatch"].tap()
    XCTAssertTrue(app.buttons["matchSetup.start"].waitForExistence(timeout: 6))
    app.buttons["matchSetup.start"].tap()

    XCTAssertTrue(app.staticTexts["live.speechState"].waitForExistence(timeout: 10))
    resolveVoicePermission(in: app)

    let seconds = Int(ProcessInfo.processInfo.environment["COURTVOICE_LIVE_OBSERVE_SECONDS"] ?? "") ?? 180
    NSLog("COURTVOICE_OBSERVE_READY seconds=\(seconds)")
    observe(app, step: 0)

    let interval: TimeInterval = 5
    let steps = max(1, seconds / 5)
    for step in 1...steps {
      Thread.sleep(forTimeInterval: interval)
      observe(app, step: step)
    }

    NSLog("COURTVOICE_OBSERVE_DONE")
  }

  private func observe(_ app: XCUIApplication, step: Int) {
    let state = label(app.staticTexts["live.speechState"])
    let action = label(app.staticTexts["live.lastAction"])
    let score = label(app.staticTexts["live.spokenScore"])
    let phase = label(app.staticTexts["live.reasoning"])
    let latest = label(app.staticTexts["live.transcript.latest"])
    let thinking = label(app.staticTexts["live.reasoning.thinking"])
    let answer = label(app.staticTexts["live.reasoning.answer"])
    NSLog(
      "COURTVOICE_OBSERVE step=\(step) state=\(state) score=\(score) action=\(action) transcript=\(latest) phase=\(phase) thinking=\(thinking) answer=\(answer)"
    )

    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = String(format: "live-observe-%02d", step)
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func label(_ element: XCUIElement) -> String {
    element.exists ? element.label.replacingOccurrences(of: "\n", with: " ") : ""
  }

  private func resolveVoicePermission(in app: XCUIApplication) {
    let speechState = app.staticTexts["live.speechState"]
    let deadline = Date().addingTimeInterval(20)
    while Date() < deadline {
      tapAllowIfPresent(in: XCUIApplication(bundleIdentifier: "com.apple.springboard"))
      tapAllowIfPresent(in: app)
      if speechState.exists {
        let value = speechState.label
        if value.contains("Listening")
          || value.contains("Preparing")
          || value.contains("Processing")
          || value.contains("unavailable")
        {
          return
        }
      }
      Thread.sleep(forTimeInterval: 0.5)
    }
  }

  @discardableResult
  private func tapAllowIfPresent(in element: XCUIElement) -> Bool {
    let predicate = NSPredicate(
      format: "label CONTAINS[c] 'Allow' OR label CONTAINS[c] '允许' OR label == 'OK' OR label == '好'"
    )
    let button = element.buttons.matching(predicate).firstMatch
    if button.exists {
      button.tap()
      return true
    }
    return false
  }
}
