import XCTest

/// 1 v 1 pickup game, setup 1–6 with app dice, to the result, then Play again (PlayModeSpec § 20 UI).
/// A 6-turn limit ends the game: driving shots through the shot sheet is out of scope for this smoke test.
final class PlayModePickupUITests: XCTestCase {
    private var taps: [String] = []

    override func setUp() {
        continueAfterFailure = false
        // A landscape run (screenshots) leaves the simulator rotated; these flows expect portrait.
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testPickupGameToResult() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        tabs.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])

        // 1. Sides
        XCTAssertTrue(element(app, "as.play.setup.sides").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.continue"])
        // 2. Size
        XCTAssertTrue(element(app, "as.play.setup.size").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.continue"])
        // 3. Forces: one 'Mech a side
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 5))
        addCard(app, side: "A", card: "locust-lct-7v", search: "Locust")
        tap(app.buttons["as.play.setup.forces.side.B"])
        addCard(app, side: "B", card: "wasp-wsp-5a", search: "Wasp")
        tap(app.buttons["as.play.setup.continue"])
        // 4. Battlefield
        XCTAssertTrue(element(app, "as.play.setup.map").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.play.setup.layout").exists)
        tap(app.buttons["as.play.setup.continue"])
        // 5. Rules: 6-turn limit, app dice
        XCTAssertTrue(element(app, "as.play.setup.rules").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.turnLimit"])
        tap(app.buttons["6 turns"])
        let dice = app.segmentedControls["as.play.setup.dice"].buttons["Let the app roll"]
        if !dice.isHittable { app.swipeUp() }
        tap(dice)
        tap(app.buttons["as.play.setup.continue"])
        // 6. Review
        XCTAssertTrue(element(app, "as.play.setup.review").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.start"])

        let victory = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier IN {'as.victory.screen', 'as.victory'}")
        ).firstMatch
        XCTAssertTrue(element(app, "as.ridge.tablePrep").waitForExistence(timeout: 10), "Table setup missing")
        let deadline = Date().addingTimeInterval(300)
        var idle = 0
        while Date() < deadline, !victory.exists {
            if advance(app) { idle = 0 } else {
                idle += 1
                if idle > 12 { break }
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(victory.waitForExistence(timeout: 10), "Result never appeared. Taps: \(taps.suffix(30).joined(separator: " > "))")
        XCTAssertTrue(element(app, "as.victory.standing.1").exists, "Standings missing")
        XCTAssertTrue(element(app, "as.victory.standing.2").exists)

        // Play again: a fresh game from the same setup.
        let again = app.buttons["as.victory.rematch"]
        if !again.isHittable { app.swipeUp() }
        tap(again)
        tap(app.buttons["Start over"])
        XCTAssertTrue(element(app, "as.ridge.tablePrep").waitForExistence(timeout: 10), "Play again didn't start a game")
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

    /// PM6: a 1 v 2 setup shows the team note and a second player field on Side B (PlayModeSpec § 5.1).
    @MainActor
    func testTeamPresetShowsPlayers() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        tabs.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])
        XCTAssertTrue(element(app, "as.play.setup.sides").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "as.play.setup.team.note").exists)
        tap(app.buttons["as.play.setup.preset.1v2"])
        XCTAssertTrue(element(app, "as.play.setup.team.note").waitForExistence(timeout: 5))
        let second = element(app, "as.play.setup.side.B.player.2")
        if !second.exists { app.swipeUp() }
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "as.play.setup.side.A.player.2").exists)
    }

    @MainActor
    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)", file: file, line: line)
        element.tap()
    }

    /// Same driver as the Ridge Line test.
    @MainActor
    private func advance(_ app: XCUIApplication) -> Bool {
        for title in ["Start shooting anyway", "Done shooting anyway"] {
            if tapIfExists(app.buttons[title]) { return true }
        }
        if tapIfExists(app.buttons["as.ridge.tableReady"]) { return true }
        if app.buttons["as.battle.skipRemaining"].exists {
            return tapIfExists(app.buttons["as.battle.skipRemaining"])
        }
        if tapIfExists(app.buttons["as.battle.doneShooting"]) { return true }
        let sideA = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Side A moves first'")).firstMatch
        if sideA.exists, sideA.isHittable {
            taps.append("Side A moves first")
            sideA.tap()
            return true
        }
        let agree = app.descendants(matching: .any)["as.initiative.agree"]
        if agree.exists {
            if !agree.isHittable { app.swipeUp() }
            if agree.isHittable {
                taps.append("as.initiative.agree")
                agree.tap()
                return true
            }
        }
        let primary = app.buttons["as.battle.primary"]
        if primary.exists, primary.isHittable {
            let label = primary.label
            if label == "Solve a shot" || label.hasPrefix("Roll critical") {
                return tapIfExists(app.buttons["as.battle.doneShooting"])
            }
            taps.append("primary[\(label)]")
            primary.tap()
            return true
        }
        return false
    }

    @MainActor
    private func tapIfExists(_ element: XCUIElement) -> Bool {
        guard element.exists, element.isHittable else { return false }
        taps.append(element.identifier.isEmpty ? element.label : "\(element.identifier)[\(element.label)]")
        element.tap()
        return true
    }
}
