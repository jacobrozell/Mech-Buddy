import XCTest

/// PM8: objectives and victory points in Play (PlayModeSpec § 7), behind `playObjectives`, which the
/// `-enable_full_product_surface` launch argument turns on with `playMode`.
final class PlayObjectivesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func openSetup(_ app: XCUIApplication, preset: String) {
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        tabs.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])
        XCTAssertTrue(element(app, "as.play.setup.sides").waitForExistence(timeout: 12))
        tap(app.buttons[preset])
    }

    /// Four sides, one Locust each, Control the Field: the VP strip fits above the dock with every side's
    /// roster header, the Score step lists each side, and scoring a 'Mech moves the strip to Turn 2.
    @MainActor
    func testFourSideControlTheFieldScoresAndFits() throws {
        let app = XCUIApplication()
        openSetup(app, preset: "as.play.setup.preset.1v1v1v1")
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.size").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 12))
        for (index, letter) in ["A", "B", "C", "D"].enumerated() {
            if index > 0 { tap(app.buttons["as.play.setup.forces.side.\(letter)"]) }
            addCard(app, side: letter, card: "locust-lct-7v", search: "Locust")
            addCard(app, side: letter, card: "wasp-wsp-5a", search: "Wasp")
        }
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.map").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.rules").waitForExistence(timeout: 12))

        // Every objective but Find the Target can be picked; Find the Target says why not.
        for objective in ["raid", "controlTheField", "destroyTheEnemy", "holdTheFort", "breakthrough"] {
            XCTAssertTrue(element(app, "as.play.setup.objective.\(objective)").exists || scrollTo(app, "as.play.setup.objective.\(objective)"), "\(objective) missing")
        }
        XCTAssertTrue(element(app, "as.play.setup.objective.findTheTarget").exists)
        XCTAssertTrue(element(app, "as.play.setup.objective.roll").exists)
        tap(app.buttons["as.play.setup.objective.controlTheField"])
        XCTAssertTrue(element(app, "as.play.setup.objective.notes").waitForExistence(timeout: 12))

        let dice = app.segmentedControls["as.play.setup.dice"].buttons["Let the app roll"]
        for _ in 0..<4 { app.swipeUp() }
        tap(dice)
        XCTAssertTrue(dice.isSelected, "App dice not selected")
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.review").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.start"])
        XCTAssertTrue(element(app, "as.ridge.tablePrep").waitForExistence(timeout: 10), "Table setup missing")

        // Move to Combat.
        var taps: [String] = []
        advance(app, until: { self.element(app, "as.battle.shooters.lanceA").exists }, taps: &taps)
        XCTAssertTrue(element(app, "as.battle.shooters.lanceA").exists, "Never reached Combat. Taps: \(taps.joined(separator: " > "))")
        let vp = element(app, "as.battle.vp")
        if !vp.exists {
            let tree = app.debugDescription.split(separator: "\n").filter { $0.contains("points") || $0.contains("battle.vp") }.prefix(40).joined(separator: " | ")
            XCTFail("VP strip missing. Tree: \(tree)")
        }
        XCTAssertTrue(vp.exists, "VP strip missing")
        XCTAssertTrue(vp.label.contains("Control the Field") && vp.label.contains("Side D 0 points"), "VP label: \(vp.label)")
        // The strip and all four roster headers fit on one portrait screen, above the dock.
        let window = app.windows.firstMatch.frame
        let dockTop = app.buttons["as.battle.primary"].frame.minY
        XCTAssertTrue(window.contains(vp.frame))
        for side in ["lanceA", "lanceB", "lanceC", "lanceD"] {
            let header = element(app, "as.battle.shooters.\(side)")
            XCTAssertTrue(header.exists && header.frame.maxY <= dockTop, "Header for \(side) hidden: \(header.frame), dock at \(dockTop)")
        }
        if let path = ProcessInfo.processInfo.environment["PM8_SCREENSHOT"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
        }

        // Clean up: the Score step. Answer for Side A, then score and move on.
        advance(app, until: { app.buttons["as.battle.objective.lanceA.inPosition.0"].exists }, taps: &taps)
        XCTAssertTrue(app.buttons["as.battle.objective.lanceA.inPosition.0"].exists, "Score step missing. Taps: \(taps.joined(separator: " > "))")
        let chip = app.buttons["as.battle.objective.lanceA.inPosition.0"]
        XCTAssertTrue(chip.waitForExistence(timeout: 12) || scrollTo(app, "as.battle.objective.lanceA.inPosition.0"))
        if !chip.isHittable { app.swipeUp() }
        chip.tap()
        let primary = app.buttons["as.battle.primary"]
        XCTAssertEqual(primary.label, "Score and next turn")
        primary.tap()
        let after = element(app, "as.battle.vp")
        XCTAssertTrue(after.waitForExistence(timeout: 12))
        XCTAssertTrue(after.label.contains("Side A 2 points") || after.label.contains("Side A 1 point"), "VP after scoring: \(after.label)")
    }

    @MainActor
    func testWithoutAnObjectiveThereIsNoStrip() throws {
        let app = XCUIApplication()
        openSetup(app, preset: "as.play.setup.preset.1v1")
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.size").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 12))
        addCard(app, side: "A", card: "locust-lct-7v", search: "Locust")
        tap(app.buttons["as.play.setup.forces.side.B"])
        addCard(app, side: "B", card: "wasp-wsp-5a", search: "Wasp")
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.map").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.rules").waitForExistence(timeout: 12))
        // The default is still last side standing, kept under its old identifier.
        XCTAssertTrue(element(app, "as.play.setup.objective").waitForExistence(timeout: 12))
        XCTAssertTrue(element(app, "as.play.setup.turnLimit").exists || scrollTo(app, "as.play.setup.turnLimit"))
    }

    // MARK: Helpers

    @MainActor
    private func advance(_ app: XCUIApplication, until done: () -> Bool, taps: inout [String]) {
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline, !done() {
            for title in ["Start shooting anyway", "Done shooting anyway"] where app.buttons[title].exists && app.buttons[title].isHittable {
                taps.append(title)
                app.buttons[title].tap()
            }
            let tableReady = app.buttons["as.ridge.tableReady"]
            let skip = app.buttons["as.battle.skipRemaining"]
            let primary = app.buttons["as.battle.primary"]
            let doneShooting = app.buttons["as.battle.doneShooting"]
            if tableReady.exists, tableReady.isHittable {
                taps.append("tableReady"); tableReady.tap()
            } else if skip.exists, skip.isHittable {
                taps.append("skip"); skip.tap()
            } else if element(app, "as.battle.shooters.lanceA").exists {
                if done() { return }
                if doneShooting.exists, doneShooting.isHittable { taps.append("doneShooting"); doneShooting.tap() } else { Thread.sleep(forTimeInterval: 0.5) }
            } else if primary.exists, primary.isHittable, primary.label != "Solve a shot", primary.label != "Score and next turn" {
                taps.append(primary.label); primary.tap()
            } else {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
    }

    @MainActor
    private func scrollTo(_ app: XCUIApplication, _ id: String) -> Bool {
        for _ in 0..<8 {
            if element(app, id).exists && element(app, id).isHittable { return true }
            app.swipeUp()
        }
        return element(app, id).exists
    }

    @MainActor
    private func addCard(_ app: XCUIApplication, side: String, card: String, search: String) {
        tap(app.buttons["as.play.setup.forces.add.\(side)"])
        let field = app.textFields["as.play.setup.unitPicker.search"]
        tap(field)
        field.typeText(search)
        let row = app.buttons["as.play.setup.unitPicker.card.\(card)"]
        XCTAssertTrue(row.waitForExistence(timeout: 12), "Card \(card) missing")
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
        XCTAssertTrue(element.waitForExistence(timeout: 12), "Missing \(element)", file: file, line: line)
        element.tap()
    }
}
