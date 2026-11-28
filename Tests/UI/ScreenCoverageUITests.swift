import XCTest

/// Short smoke tests for screens that had no UI test: Lore, Settings, and the Event log and Unit focus sheets in battle.
final class ScreenCoverageUITests: XCTestCase {
    private let wait: TimeInterval = 15

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ extra: [String] = [], reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-skip_onboarding"] + (reset ? ["-reset_state"] : []) + extra
        app.launch()
        return app
    }

    private func any(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: wait), "Missing \(element)", file: file, line: line)
        element.tap()
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
    }

    // MARK: Lore

    @MainActor
    func testLoreOverviewTimelineAndEraDetail() throws {
        let app = launch(["-open_rules"])
        XCTAssertTrue(any(app, "rules.home").waitForExistence(timeout: 20))
        let entry = any(app, "as.lore.entry")
        for _ in 0..<8 where !entry.exists || !entry.isHittable { app.swipeUp() }
        tap(entry)
        XCTAssertTrue(any(app, "as.lore.overview").waitForExistence(timeout: wait))
        XCTAssertTrue(any(app, "as.lore.summary").waitForExistence(timeout: wait))

        // An era's detail page.
        let era = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'as.lore.era.'")).firstMatch
        tap(era)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'as.lore.era.detail.'")).firstMatch.waitForExistence(timeout: wait))
        back(app)

        // The timeline.
        let timeline = any(app, "as.lore.timeline.entry")
        for _ in 0..<6 where !timeline.isHittable { app.swipeUp() }
        tap(timeline)
        XCTAssertTrue(any(app, "as.lore.timeline").waitForExistence(timeout: wait))
    }

    // MARK: Settings

    @MainActor
    func testSettingsHapticsToggleSticksAfterRelaunch() throws {
        var app = launch()
        tap(app.tabBars.buttons["Settings"])
        XCTAssertTrue(any(app, "settings.home").waitForExistence(timeout: wait))
        var haptics = app.switches["Haptics"]
        XCTAssertTrue(haptics.waitForExistence(timeout: wait))
        let before = haptics.value as? String
        haptics.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let after = haptics.value as? String
        XCTAssertNotEqual(before, after, "The toggle did not flip")

        app.terminate()
        app = launch(reset: false)
        tap(app.tabBars.buttons["Settings"])
        haptics = app.switches["Haptics"]
        XCTAssertTrue(haptics.waitForExistence(timeout: wait))
        XCTAssertEqual(haptics.value as? String, after, "The setting did not survive a relaunch")
    }

    // MARK: Battle sheets

    /// Starts Ridge Line and steps through setup to the movement step and opens its "On the table" list.
    @MainActor
    private func reachUnitRows(_ app: XCUIApplication) -> XCUIElement {
        let play = app.buttons["as.modeHome.ridgeLine"]
        XCTAssertTrue(play.waitForExistence(timeout: 20), "Ridge Line play button missing")
        play.tap()
        let unit = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'as.battle.unit.'")).firstMatch
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline, !unit.exists {
            if app.buttons["On the table"].exists {
                if app.buttons["On the table"].isHittable { app.buttons["On the table"].tap(); break }
                app.swipeUp()
                continue
            }
            if app.buttons["as.ridge.tableReady"].exists { app.buttons["as.ridge.tableReady"].tap() }
            else if app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Side A moves first'")).firstMatch.exists {
                app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Side A moves first'")).firstMatch.tap()
            }
            else if app.buttons["Let the app roll"].exists, app.buttons["Let the app roll"].isHittable { app.buttons["Let the app roll"].tap() }
            else if app.buttons["as.initiative.agree"].exists, app.buttons["as.initiative.agree"].isHittable { app.buttons["as.initiative.agree"].tap() }
            else if app.buttons["as.battle.primary"].exists, app.buttons["as.battle.primary"].isHittable { app.buttons["as.battle.primary"].tap() }
            else { Thread.sleep(forTimeInterval: 0.5) }
        }
        _ = unit.waitForExistence(timeout: wait)
        XCTAssertTrue(unit.exists, "No unit rows in the battle")
        return unit
    }

    @MainActor
    func testBattleEventLogSheetOpensAndCloses() throws {
        let app = launch()
        tap(app.buttons["as.modeHome.ridgeLine"])
        tap(app.buttons["as.battle.eventLog"])
        XCTAssertTrue(any(app, "as.battle.log").waitForExistence(timeout: wait))
        tap(app.buttons["Close"])
        XCTAssertTrue(app.buttons["as.battle.eventLog"].waitForExistence(timeout: wait))
        XCTAssertFalse(any(app, "as.battle.log").exists)
    }

    @MainActor
    func testBattleUnitFocusSheetOpensFromAUnitRow() throws {
        let app = launch()
        let unit = reachUnitRows(app)
        unit.tap()
        XCTAssertTrue(any(app, "as.unitFocus.sheet").waitForExistence(timeout: wait))
        tap(app.buttons["Close"])
        XCTAssertFalse(any(app, "as.unitFocus.sheet").waitForExistence(timeout: 3))
    }
}
