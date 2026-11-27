import XCTest

/// PM11 leftovers: Find the Target, per-side objectives, MechWarrior cards, the Saved forces entry on the Force tab and
/// the dense move order for three or four sides.
final class PlayPM11LeftoversUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch(_ app: XCUIApplication, full: Bool) {
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding"] + (full ? ["-enable_full_product_surface"] : [])
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
    }

    // MARK: Saved forces on the Force tab

    @MainActor
    func testSavedForcesEntryOnForceTabBehindPlayMode() throws {
        let app = XCUIApplication()
        launch(app, full: true)
        app.tabBars.firstMatch.buttons["Force"].tap()
        XCTAssertTrue(scrollTo(app, "force.as.savedForces"), "Saved forces row missing on the Force tab")
        tap(element(app, "force.as.savedForces"))
        XCTAssertTrue(element(app, "as.play.forces.saved.sheet").waitForExistence(timeout: 8))
    }

    @MainActor
    func testNoSavedForcesEntryWithoutPlayMode() throws {
        let app = XCUIApplication()
        launch(app, full: false)
        app.tabBars.firstMatch.buttons["Force"].tap()
        XCTAssertTrue(element(app, "force.as.list").waitForExistence(timeout: 8))
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(element(app, "force.as.savedForces").exists)
    }

    // MARK: Rules step

    @MainActor
    private func openRules(_ app: XCUIApplication, preset: String = "as.play.setup.preset.1v1") {
        launch(app, full: true)
        app.tabBars.firstMatch.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])
        XCTAssertTrue(element(app, "as.play.setup.sides").waitForExistence(timeout: 12))
        tap(app.buttons[preset])
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 12))
        addCard(app, side: "A", card: "locust-lct-7v", search: "Locust")
        tap(app.buttons["as.play.setup.forces.side.B"])
        addCard(app, side: "B", card: "wasp-wsp-5a", search: "Wasp")
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.map").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.rules").waitForExistence(timeout: 12))
    }

    @MainActor
    func testFindTheTargetNeedsThreeBuildings() throws {
        let app = XCUIApplication()
        openRules(app)
        // Without buildings the lock note stands in for the tile.
        XCTAssertTrue(element(app, "as.play.setup.objective.findTheTarget").exists)
        XCTAssertFalse(app.buttons["as.play.setup.objective.findTheTarget"].exists)
        // Three buildings unlock it.
        XCTAssertTrue(scrollTo(app, "as.play.setup.buildings"))
        flip(app.switches["as.play.setup.buildings"])
        for _ in 0..<2 {
            XCTAssertTrue(scrollTo(app, "as.play.setup.buildings.add"))
            tap(app.buttons["as.play.setup.buildings.add"])
            tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Medium'")).firstMatch)
        }
        XCTAssertTrue(scrollBackTo(app, "as.play.setup.objective.findTheTarget"))
        let tile = app.buttons["as.play.setup.objective.findTheTarget"]
        XCTAssertTrue(tile.waitForExistence(timeout: 8), "Tile missing with three buildings")
        tile.tap()
        XCTAssertTrue(element(app, "as.play.setup.objective.notes").waitForExistence(timeout: 8))
    }

    @MainActor
    func testEachSideRollsItsOwnObjective() throws {
        let app = XCUIApplication()
        openRules(app)
        XCTAssertTrue(scrollBackTo(app, "as.play.setup.objective.perSide"))
        flip(app.switches["as.play.setup.objective.perSide"])
        for letter in ["A", "B"] {
            XCTAssertTrue(element(app, "as.play.setup.objective.side.\(letter).value").waitForExistence(timeout: 8))
            XCTAssertFalse(element(app, "as.play.setup.objective.side.\(letter).value").label.contains("Not rolled"))
        }
        XCTAssertTrue(element(app, "as.play.setup.objective.rollAll").exists)
        tap(app.buttons["as.play.setup.objective.side.A.roll"])
        XCTAssertTrue(element(app, "as.play.setup.objective.perSide.notes").exists)
        // The shared tiles are gone while sides roll their own.
        XCTAssertFalse(app.buttons["as.play.setup.objective.raid"].exists)
        // Back to one shared objective.
        flip(app.switches["as.play.setup.objective.perSide"])
        XCTAssertTrue(element(app, "as.play.setup.objective.roll").waitForExistence(timeout: 8))
    }

    @MainActor
    func testMechWarriorCardsToggleIsLive() throws {
        let app = XCUIApplication()
        openRules(app)
        XCTAssertTrue(scrollTo(app, "as.play.setup.rules.mechWarriorCards"))
        let toggle = app.switches["as.play.setup.rules.mechWarriorCards"]
        XCTAssertTrue(toggle.isEnabled, "MechWarrior cards toggle is still disabled")
        flip(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
    }

    @MainActor
    func testMechWarriorCardOnTheForcesStepAndReviewCheck() throws {
        let app = XCUIApplication()
        openRules(app)
        XCTAssertTrue(scrollTo(app, "as.play.setup.rules.mechWarriorCards"))
        flip(app.switches["as.play.setup.rules.mechWarriorCards"])
        // Back to Forces (Rules -> Map -> Forces).
        tap(app.buttons["as.play.setup.back"])
        tap(app.buttons["as.play.setup.back"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 12))
        let cardToggle = app.switches.matching(NSPredicate(format: "identifier ENDSWITH '.card'")).firstMatch
        XCTAssertTrue(cardToggle.waitForExistence(timeout: 8), "Card toggle missing on the Forces step")
        flip(cardToggle)
        let pilot = app.textFields.matching(NSPredicate(format: "identifier ENDSWITH '.pilot'")).firstMatch
        XCTAssertTrue(pilot.waitForExistence(timeout: 8), "Pilot name field missing")
        pilot.tap()
        pilot.typeText("Kell")
        // Only Side A has a card, so the review warns that Side B has none.
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.review").waitForExistence(timeout: 12))
        let warnings = element(app, "as.play.setup.review.warnings")
        var tries = 0
        while !warnings.exists && tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(warnings.exists, "Review warnings missing")
        XCTAssertTrue(warnings.label.contains("MechWarrior"), "Warning: \(warnings.label)")
    }

    // MARK: Dense move order

    @MainActor
    func testFourSideMoveOrderIsOneLinePerMech() throws {
        let app = XCUIApplication()
        launch(app, full: true)
        app.tabBars.firstMatch.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])
        XCTAssertTrue(element(app, "as.play.setup.sides").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.preset.1v1v1v1"])
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 12))
        for (index, letter) in ["A", "B", "C", "D"].enumerated() {
            if index > 0 { tap(app.buttons["as.play.setup.forces.side.\(letter)"]) }
            addCard(app, side: letter, card: "locust-lct-7v", search: "Locust")
        }
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.map").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.rules").waitForExistence(timeout: 12))
        // The app rolls initiative, so the test reaches Movement without entering dice.
        let dice = app.segmentedControls["as.play.setup.dice"].buttons["Let the app roll"]
        for _ in 0..<4 { app.swipeUp() }
        tap(dice)
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.review").waitForExistence(timeout: 12))
        tap(app.buttons["as.play.setup.start"])
        XCTAssertTrue(element(app, "as.ridge.tablePrep").waitForExistence(timeout: 10))
        // Through table setup, placement and initiative to the first Movement step.
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline, !element(app, "as.battle.move.ground").exists {
            let ready = app.buttons["as.ridge.tableReady"]
            let primary = app.buttons["as.battle.primary"]
            if ready.exists, ready.isHittable { ready.tap() }
            else if primary.exists, primary.isHittable { primary.tap() }
            else { Thread.sleep(forTimeInterval: 0.5) }
        }
        XCTAssertTrue(element(app, "as.battle.move.ground").exists, "Never reached Movement")
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'as.battle.moveOrder.'"))
        let tree = app.debugDescription.split(separator: "\n").filter { $0.contains("oveOrder") || $0.contains("Later") || $0.contains("Move order") || $0.contains("Next") }.prefix(20).joined(separator: " | ")
        XCTAssertEqual(rows.count, 4, "Expected one move-order row per 'Mech. Tree: \(tree)")
        // One line each: no row is taller than a 44 pt button plus its padding.
        for index in 0..<rows.count {
            XCTAssertLessThanOrEqual(rows.element(boundBy: index).frame.height, 56, "Row \(index) is not dense")
        }
        if let path = ProcessInfo.processInfo.environment["PM11_SCREENSHOT"] {
            try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
        }
    }

    // MARK: Helpers

    /// A SwiftUI toggle flips only when its switch is hit, which sits at the trailing edge of the row.
    @MainActor
    private func flip(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.waitForExistence(timeout: 12), "Missing \(toggle)")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
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
    private func scrollTo(_ app: XCUIApplication, _ id: String) -> Bool {
        for _ in 0..<10 {
            if element(app, id).exists && element(app, id).isHittable { return true }
            app.swipeUp()
        }
        return element(app, id).exists
    }

    @MainActor
    private func scrollBackTo(_ app: XCUIApplication, _ id: String) -> Bool {
        for _ in 0..<12 {
            if element(app, id).exists && element(app, id).isHittable { return true }
            app.swipeDown()
        }
        return element(app, id).exists
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
