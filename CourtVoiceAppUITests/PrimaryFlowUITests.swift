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

  func testOnboardingLiveMatchPersistenceAndSettings() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-ui-testing-reset"]
    app.launch()

    XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 8))
    capture(app, name: "01-onboarding")

    app.buttons["onboarding.skip"].tap()

    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))
    capture(app, name: "02-home")

    app.buttons["home.startMatch"].tap()
    XCTAssertTrue(app.buttons["matchSetup.start"].waitForExistence(timeout: 5))
    capture(app, name: "03-match-setup")
    app.buttons["matchSetup.start"].tap()

    XCTAssertTrue(app.otherElements["live.scoreboard"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["live.speechState"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["live.listen"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["live.transcript"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["live.reasoning"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["live.award.home"].exists)
    XCTAssertFalse(app.buttons["live.award.away"].exists)
    XCTAssertFalse(app.buttons["live.undo"].exists)
    XCTAssertFalse(app.buttons["live.correct"].exists)
    capture(app, name: "04-live-match")
    capture(app, name: "05-live-agent")

    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.buttons["live.listen"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.otherElements["live.scoreboard"].waitForExistence(timeout: 3))
    capture(app, name: "06-live-landscape")
    XCUIDevice.shared.orientation = .portrait

    app.buttons["live.close"].tap()
    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))

    app.terminate()
    app.launchArguments = ["-ui-testing"]
    app.launch()

    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["home.continue"].waitForExistence(timeout: 5))
    capture(app, name: "07-home-after-relaunch")

    app.tabBars.buttons["比赛"].tap()
    XCTAssertTrue(app.staticTexts["history.homeName"].waitForExistence(timeout: 5))
    capture(app, name: "08-match-history")

    app.tabBars.buttons["设置"].tap()
    XCTAssertTrue(app.buttons["settings.speechModels"].waitForExistence(timeout: 5))
    capture(app, name: "09-settings")

    app.buttons["settings.paywall"].tap()
    XCTAssertTrue(app.navigationBars["CourtVoice Pro"].waitForExistence(timeout: 5))
    capture(app, name: "10-paywall")
    app.buttons["paywall.done"].tap()

    app.buttons["settings.speechModels"].tap()
    XCTAssertTrue(app.navigationBars["语音与 AI"].waitForExistence(timeout: 5))
    capture(app, name: "11-model-settings")
  }

  func testMediaImportSurfaceStaysReachable() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-skip-onboarding"]
    app.launch()

    XCTAssertTrue(app.buttons["home.analyzeMedia"].waitForExistence(timeout: 8))
    app.buttons["home.analyzeMedia"].tap()
    XCTAssertTrue(app.navigationBars["分析比赛录像"].waitForExistence(timeout: 5))
    capture(app, name: "12-media-analysis")
    app.buttons["media.close"].tap()
    XCTAssertTrue(app.navigationBars["分析比赛录像"].waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))
    XCTAssertTrue(app.buttons["home.startMatch"].isHittable)
    capture(app, name: "13-home-after-media")
  }

  func testDeviceVoicePermissionAndAgentControls() throws {
    #if targetEnvironment(simulator)
      throw XCTSkip("Physical-device audio smoke requires a real iPhone or iPad.")
    #else
      let app = XCUIApplication()
      app.launchArguments = ["-ui-testing", "-ui-testing-reset", "-ui-testing-skip-onboarding"]
      addUIInterruptionMonitor(withDescription: "System permission prompts") { alert in
        MainActor.assumeIsolated {
          self.tapAllowIfPresent(in: alert)
        }
      }
      app.launch()

      XCTAssertTrue(app.buttons["home.startMatch"].waitForExistence(timeout: 8))
      app.buttons["home.startMatch"].tap()
      XCTAssertTrue(app.buttons["matchSetup.start"].waitForExistence(timeout: 5))
      app.buttons["matchSetup.start"].tap()
      XCTAssertTrue(app.buttons["live.listen"].waitForExistence(timeout: 8))
      capture(app, name: "14-device-before-listen")

      app.buttons["live.listen"].tap()
      resolveVoicePermissionAndStart(in: app)

      let speechState = app.staticTexts["live.speechState"]
      XCTAssertTrue(
        speechState.waitForExistence(timeout: 8),
        "Listening state must remain visible after the permission flow."
      )
      XCTAssertFalse(speechState.label.isEmpty)
      capture(app, name: "15-device-after-listen")

      dismissScoringErrorIfPresent(in: app)
      XCTAssertTrue(app.buttons["live.listen"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.buttons["live.listen"].isHittable)
      XCTAssertTrue(app.otherElements["live.scoreboard"].waitForExistence(timeout: 5))
      XCTAssertFalse(app.buttons["live.award.home"].exists)
      XCTAssertFalse(app.buttons["live.undo"].exists)
      capture(app, name: "16-device-agent-after-voice")

      XCUIDevice.shared.press(.home)
      Thread.sleep(forTimeInterval: 1.5)
      app.activate()
      dismissScoringErrorIfPresent(in: app)
      XCTAssertTrue(app.buttons["live.listen"].waitForExistence(timeout: 8))
      XCTAssertTrue(app.staticTexts["live.speechState"].waitForExistence(timeout: 5))
      XCTAssertTrue(app.otherElements["live.scoreboard"].waitForExistence(timeout: 5))
      capture(app, name: "17-device-after-background")
    #endif
  }

  private func resolveVoicePermissionAndStart(in app: XCUIApplication) {
    let speechState = app.staticTexts["live.speechState"]
    let deadline = Date().addingTimeInterval(20)

    while Date() < deadline {
      guard app.state == .runningForeground else {
        Thread.sleep(forTimeInterval: 0.4)
        continue
      }

      dismissScoringErrorIfPresent(in: app)
      tapAllowIfPresent(in: XCUIApplication(bundleIdentifier: "com.apple.springboard"))
      tapAllowIfPresent(in: app)

      if speechState.exists {
        let label = speechState.label
        if label.contains("Listening")
          || label.contains("Preparing")
          || label.contains("unavailable")
          || label.contains("Interrupted")
          || label.contains("Processing")
          || label.contains("正在听")
          || label.contains("正在准备")
          || label.contains("不可用")
          || label.contains("已中断")
          || label.contains("正在处理")
        {
          return
        }
        if label.contains("Requesting") || label.contains("请求权限") {
          tapLikelySystemAllowButtons()
        }
      }

      Thread.sleep(forTimeInterval: 0.6)
    }
  }

  private func capture(_ app: XCUIApplication, name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)

    guard let screenshotDirectory else { return }
    do {
      try FileManager.default.createDirectory(
        at: screenshotDirectory,
        withIntermediateDirectories: true
      )
      try screenshot.pngRepresentation.write(
        to: screenshotDirectory.appendingPathComponent("\(name).png")
      )
    } catch {
      // Device runners cannot write the host screenshot directory; the XCTest attachment remains.
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

  private func tapLikelySystemAllowButtons() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowPoints = [
      CGVector(dx: 0.72, dy: 0.52),
      CGVector(dx: 0.50, dy: 0.48),
      CGVector(dx: 0.72, dy: 0.56),
    ]
    for point in allowPoints {
      springboard.coordinate(withNormalizedOffset: point).tap()
    }
  }

  private func dismissScoringErrorIfPresent(in app: XCUIApplication) {
    let alert = app.alerts["记分出错"].exists ? app.alerts["记分出错"] : app.alerts["Scoring error"]
    guard alert.exists else { return }
    if alert.buttons["好"].exists {
      alert.buttons["好"].tap()
    } else if alert.buttons["OK"].exists {
      alert.buttons["OK"].tap()
    }
  }
}
