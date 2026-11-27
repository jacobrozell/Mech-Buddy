import XCTest

/// PM7: three and four sides in Play (PlayModeSpec § 5.1, § 6, § 14). Behind `playModeMultiSide`, which the
/// `-enable_full_product_surface` launch argument turns on with `playMode`.
final class PlayModeMultiSideUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func openSetup(_ app: XCUIApplication) {
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        tabs.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])
        XCTAssertTrue(element(app, "as.play.setup.sides").waitForExistence(timeout: 5))
    }

    @MainActor
    func testFourSidePresetShowsFourSidesAndHouseRules() throws {
        let app = XCUIApplication()
        openSetup(app)
        // Free-for-all presets exist beside the team presets; none shows the house-rules note yet.
        XCTAssertTrue(app.buttons["as.play.setup.preset.1v1"].exists)
        XCTAssertTrue(app.buttons["as.play.setup.preset.1v1v1"].exists)
        XCTAssertFalse(element(app, "as.play.setup.houseRules").exists)
        tap(app.buttons["as.play.setup.preset.1v1v1v1"])
        XCTAssertTrue(element(app, "as.play.setup.houseRules").waitForExistence(timeout: 5))
        for letter in ["A", "B", "C", "D"] {
            let field = element(app, "as.play.setup.side.\(letter)")
            if !field.exists { app.swipeUp() }
            XCTAssertTrue(field.waitForExistence(timeout: 5), "Side \(letter) row missing")
        }
        // The info button opens the house rules page.
        let info = app.buttons["as.play.setup.houseRules"]
        if !info.isHittable { app.swipeDown(); app.swipeDown() }
        tap(info)
        XCTAssertTrue(element(app, "as.play.setup.houseRules.sheet").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.houseRules.done"])
        // Back to three sides: the note stays; back to two: it goes.
        tap(app.buttons["as.play.setup.preset.1v1"])
        XCTAssertFalse(element(app, "as.play.setup.houseRules").exists)
    }

    /// Plays a 1 v 1 v 1 v 1 to the first Combat phase with two 'Mechs a side and captures the roster, so one
    /// portrait screen proves four sides fit. Set `PM7_SCREENSHOT` to a file path to also save the picture.
    @MainActor
    func testFourSideBattleRosterFits() throws {
        let app = XCUIApplication()
        openSetup(app)
        tap(app.buttons["as.play.setup.preset.1v1v1v1"])
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.size").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 5))
        for (index, letter) in ["A", "B", "C", "D"].enumerated() {
            if index > 0 { tap(app.buttons["as.play.setup.forces.side.\(letter)"]) }
            addCard(app, side: letter, card: "locust-lct-7v", search: "Locust")
            addCard(app, side: letter, card: "wasp-wsp-5a", search: "Wasp")
        }
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.map").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.rules").waitForExistence(timeout: 5))
        let dice = app.segmentedControls["as.play.setup.dice"].buttons["Let the app roll"]
        if !dice.isHittable { app.swipeUp() }
        tap(dice)
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.review").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.play.setup.review.side.D").exists || { app.swipeUp(); return element(app, "as.play.setup.review.side.D").exists }())
        tap(app.buttons["as.play.setup.start"])

        XCTAssertTrue(element(app, "as.ridge.tablePrep").waitForExistence(timeout: 10), "Table setup missing")
        // Initiative (app dice), then skip the moves, then the Combat step lists every side with its 'Mechs.
        var taps: [String] = []
        let deadline = Date().addingTimeInterval(90)
        let shooters = element(app, "as.battle.shooters.lanceA")
        while Date() < deadline, !shooters.exists {
            for title in ["Start shooting anyway"] where app.buttons[title].exists && app.buttons[title].isHittable {
                taps.append(title)
                app.buttons[title].tap()
            }
            let tableReady = app.buttons["as.ridge.tableReady"]
            let skip = app.buttons["as.battle.skipRemaining"]
            let primary = app.buttons["as.battle.primary"]
            if tableReady.exists, tableReady.isHittable {
                taps.append("tableReady"); tableReady.tap()
            } else if skip.exists, skip.isHittable {
                taps.append("skip"); skip.tap()
            } else if primary.exists, primary.isHittable {
                taps.append(primary.label); primary.tap()
            } else {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        XCTAssertTrue(shooters.exists, "Never reached Combat. Taps: \(taps.joined(separator: " > "))")
        Thread.sleep(forTimeInterval: 1)

        let screen = app.screenshot()
        let attachment = XCTAttachment(screenshot: screen)
        attachment.lifetime = .keepAlways
        attachment.name = "four-side-roster"
        add(attachment)
        if let path = ProcessInfo.processInfo.environment["PM7_SCREENSHOT"] {
            try? screen.pngRepresentation.write(to: URL(fileURLWithPath: path))
        }
        // Every side's header is on this one screen without scrolling.
        let window = app.windows.firstMatch.frame
        for side in ["lanceA", "lanceB", "lanceC", "lanceD"] {
            let header = element(app, "as.battle.shooters.\(side)")
            XCTAssertTrue(header.exists, "Header for \(side) missing. Taps: \(taps.joined(separator: " > "))")
            XCTAssertTrue(window.contains(header.frame), "Header for \(side) is off screen: \(header.frame) in \(window)")
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
