import XCTest

/// FUTURE-PLAN 1.7: the landscape table view. In iPhone landscape the battle shows every side's column
/// (`as.battle.side.<sideId>` headers) with the step and its dock on the right, so both must be hittable at once.
///
/// Optional screenshots: set `TEST_RUNNER_LANDSCAPE_SYNC=<dir>` and a host-side script answers each checkpoint
/// (`ready-<name>` appears, the script runs `simctl io screenshot`, then writes `go-<name>`). XCUIScreenshot is
/// not rotated with the device, hence the handshake.
final class LandscapeBattleUITests: XCTestCase {
    private var syncDir: String? { ProcessInfo.processInfo.environment["LANDSCAPE_SYNC"] }
    private var seen = Set<String>()

    override func setUp() {
        continueAfterFailure = false
        // Set-up screens are driven in portrait (the proven path); each test rotates once the battle is up.
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testMissionTableShowsBothSidesAndDock() throws {
        let app = launch(extra: [])
        let play = app.buttons["as.modeHome.ridgeLine"]
        XCTAssertTrue(play.waitForExistence(timeout: 20), "Ridge Line play button missing")
        play.tap()
        XCTAssertTrue(app.buttons["as.ridge.tableReady"].waitForExistence(timeout: 15))
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)
        try driveToCombat(app, sides: ["lanceA", "lanceB"], prefix: "mission")
    }

    @MainActor
    func testFourSideTableShowsEverySideAndDock() throws {
        let app = launch(extra: ["-enable_full_product_surface"])
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        app.tabBars.firstMatch.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])
        let preset = app.buttons["as.play.setup.preset.1v1v1v1"]
        tap(preset)
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 5))
        for (index, letter) in ["A", "B", "C", "D"].enumerated() {
            if index > 0 { tap(app.buttons["as.play.setup.forces.side.\(letter)"]) }
            addCard(app, side: letter, card: "locust-lct-7v", search: "Locust")
            addCard(app, side: letter, card: "wasp-wsp-5a", search: "Wasp")
        }
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.continue"])
        let dice = app.segmentedControls["as.play.setup.dice"].buttons["Let the app roll"]
        if !dice.isHittable { app.swipeUp() }
        tap(dice)
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.start"])
        XCTAssertTrue(element(app, "as.ridge.tablePrep").waitForExistence(timeout: 10), "Table setup missing")
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1)
        try driveToCombat(app, sides: ["lanceA", "lanceB", "lanceC", "lanceD"], prefix: "four")
    }

    // MARK: Driving

    /// Taps through set-up to Combat. At the first screen of each step that shows the table, checks every side's
    /// header and the dock, and calls the screenshot checkpoint.
    @MainActor
    private func driveToCombat(_ app: XCUIApplication, sides: [String], prefix: String) throws {
        var taps: [String] = []
        let deadline = Date().addingTimeInterval(120)
        var checkedTable = false
        while Date() < deadline {
            let header = element(app, "as.battle.side.\(sides[0])")
            let step = currentStep(app)
            if header.exists, let step, !seen.contains(step) {
                seen.insert(step)
                Thread.sleep(forTimeInterval: 1)
                assertTable(app, sides: sides, step: step, taps: taps)
                checkpoint("\(prefix)-\(step)")
                checkedTable = true
            }
            if seen.contains("combat") { return }
            for title in ["Start shooting anyway"] where app.buttons[title].exists && app.buttons[title].isHittable {
                taps.append(title); app.buttons[title].tap()
            }
            let tableReady = app.buttons["as.ridge.tableReady"]
            let skip = app.buttons["as.battle.skipRemaining"]
            let primary = app.buttons["as.battle.primary"]
            let sideFirst = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Side A moves first'")).firstMatch
            if tableReady.exists, tableReady.isHittable {
                taps.append("tableReady"); tableReady.tap()
            } else if skip.exists, skip.isHittable {
                if seen.contains("movement") { taps.append("skip"); skip.tap() } else { Thread.sleep(forTimeInterval: 0.5) }
            } else if sideFirst.exists, sideFirst.isHittable {
                taps.append("Side A first"); sideFirst.tap()
            } else if element(app, "as.initiative.agree").exists, !element(app, "as.initiative.agree").isHittable {
                // Initiative with real dice: skip the roll; the step is in the right-hand column, so scroll there.
                scrollToolColumn(app)
            } else if element(app, "as.initiative.agree").exists, element(app, "as.initiative.agree").isHittable {
                taps.append("agree"); element(app, "as.initiative.agree").tap()
            } else if primary.exists, primary.isHittable, primary.isEnabled, primary.label != "Solve a shot" {
                taps.append(primary.label); primary.tap()
            } else {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        XCTFail("Never reached Combat. checkedTable=\(checkedTable) Taps: \(taps.joined(separator: " > "))")
    }

    /// A rough step name from what is on screen; nil when none of the step controls are up.
    @MainActor
    private func currentStep(_ app: XCUIApplication) -> String? {
        let primary = app.buttons["as.battle.primary"]
        if app.buttons["as.battle.doneShooting"].exists || (primary.exists && primary.label == "Solve a shot") { return "combat" }
        if app.buttons["as.battle.skipRemaining"].exists { return "movement" }
        if element(app, "as.initiative.agree").exists || element(app, "as.initiative.multi").exists { return "initiative" }
        if primary.exists { return "other-\(primary.label)" }
        return nil
    }

    @MainActor
    private func assertTable(_ app: XCUIApplication, sides: [String], step: String, taps: [String]) {
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(window.width, window.height, "Not in landscape")
        var rightEdge: CGFloat = .infinity
        let dock = app.buttons["as.battle.primary"].exists ? app.buttons["as.battle.primary"] : app.buttons["as.battle.skipRemaining"]
        if dock.exists {
            XCTAssertTrue(dock.isHittable, "Dock not hittable at \(step). Taps: \(taps.joined(separator: " > "))")
            rightEdge = dock.frame.minX
        }
        for side in sides {
            let header = element(app, "as.battle.side.\(side)")
            XCTAssertTrue(header.exists, "Header for \(side) missing at \(step)")
            XCTAssertTrue(header.isHittable, "Header for \(side) not hittable at \(step): \(header.frame)")
            // Side by side with the dock, not under it.
            XCTAssertLessThanOrEqual(header.frame.maxX, rightEdge + 1, "\(side) header runs under the dock at \(step)")
        }
    }

    // MARK: Helpers

    @MainActor
    private func scrollToolColumn(_ app: XCUIApplication) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.6))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.25))
        from.press(forDuration: 0.1, thenDragTo: to)
    }

    @MainActor
    private func launch(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding"] + extra
        app.launch()
        return app
    }

    private func checkpoint(_ name: String) {
        guard let dir = syncDir else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: "\(dir)/ready-\(name)", contents: Data())
        let end = Date().addingTimeInterval(20)
        while Date() < end, !FileManager.default.fileExists(atPath: "\(dir)/go-\(name)") {
            Thread.sleep(forTimeInterval: 0.3)
        }
    }

    @MainActor
    private func addCard(_ app: XCUIApplication, side: String, card: String, search: String) {
        tap(app.buttons["as.play.setup.forces.add.\(side)"])
        let field = app.textFields["as.play.setup.unitPicker.search"]
        tap(field)
        field.typeText(search)
        let row = app.buttons["as.play.setup.unitPicker.card.\(card)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Card \(card) missing")
        var tries = 0
        while !row.isHittable && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        row.tap()
        tap(app.buttons["as.play.setup.unitPicker.done"])
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    @MainActor
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        element.tap()
    }
}
