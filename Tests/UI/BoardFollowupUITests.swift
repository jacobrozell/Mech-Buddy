import XCTest

/// Board builder follow-ups behind `playBoards`: drag zone edges, move and turn mapsheets, objective tokens
/// (PlayModeSpec § 9.2, § 7.1).
final class BoardFollowupUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Zones

    @MainActor
    func testDragZoneEdgeChangesDepthAndUndoRestoresIt() throws {
        let app = launch()
        goToBattlefield(app)
        tap(app.buttons["as.play.setup.board.build"])
        let handle = element(app, "as.board.handle.zone.A")
        XCTAssertTrue(handle.waitForExistence(timeout: 15), "No zone handle")
        XCTAssertEqual(handle.value as? String, "6 inches")

        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 40, dy: 0)))
        let deeper = handle.value as? String
        XCTAssertNotEqual(deeper, "6 inches", "Dragging did not change the depth")
        XCTAssertEqual(element(app, "as.board.hud").exists, false, "The readout should clear when the drag ends")

        // The menu's Reset zones still works, and Undo brings the dragged depth back.
        tap(app.buttons["as.board.options"])
        tap(app.buttons["as.board.resetZones"])
        XCTAssertEqual(handle.value as? String, "6 inches")
        tap(app.buttons["as.board.undo"])
        XCTAssertEqual(handle.value as? String, deeper)
        tap(app.buttons["as.board.undo"])
        XCTAssertEqual(handle.value as? String, "6 inches")
    }

    // MARK: Mapsheets

    @MainActor
    func testSelectMoveAndTurnAMapsheetOnTheCanvas() throws {
        let app = launch()
        goToBattlefield(app)
        tap(app.buttons["Mapsheets"])
        scrollToBuild(app)
        tap(app.buttons["as.play.setup.board.build"])
        let canvas = element(app, "as.board.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "as.board.sheet.0").waitForExistence(timeout: 15), "The board has no mapsheet")

        // A tap on the sheet selects it (a drag on an unselected sheet pans instead).
        let sheet = element(app, "as.board.sheet.0")
        sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let position = element(app, "as.board.sheet.inspector.position")
        XCTAssertTrue(position.waitForExistence(timeout: 15), "The sheet did not open its inspector")
        let before = position.label

        // Turn it 90 degrees, then Undo on the canvas turns it back.
        let rotation = element(app, "as.board.sheet.inspector.rotation")
        let turnedBack = rotation.label
        tap(app.buttons["as.board.sheet.inspector.rotate"])
        XCTAssertTrue(rotation.label.contains("90"), rotation.label)
        tap(app.buttons["as.board.undo"])
        XCTAssertEqual(rotation.label, turnedBack, "Undo did not revert the turn")
        tap(app.buttons["as.board.sheet.inspector.rotate"])
        XCTAssertTrue(rotation.label.contains("90"), rotation.label)

        // Now it follows a drag.
        let from = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 40, dy: 30)))
        XCTAssertNotEqual(position.label, before, "Dragging did not move the sheet")

    }

    @MainActor
    func testListEditorMovesAndTurnsAMapsheetAndFitsTheTable() throws {
        let app = launch()
        goToBattlefield(app)
        tap(app.buttons["Mapsheets"])
        scrollToBuild(app)
        tap(app.buttons["as.play.setup.board.build"])
        XCTAssertTrue(element(app, "as.board.editor").waitForExistence(timeout: 15))

        tap(app.buttons["as.board.list"])
        XCTAssertTrue(element(app, "as.board.pieceList").waitForExistence(timeout: 15))
        tap(element(app, "as.board.pieceList.sheet.0"))
        let position = element(app, "as.board.sheet.inspector.position")
        XCTAssertTrue(position.waitForExistence(timeout: 15))
        let before = position.label
        tap(app.buttons["as.board.sheet.inspector.nudge.right"])
        tap(app.buttons["as.board.sheet.inspector.nudge.down"])
        XCTAssertNotEqual(position.label, before)
        tap(app.buttons["as.board.sheet.inspector.rotate"])
        XCTAssertTrue(element(app, "as.board.sheet.inspector.rotation").label.contains("90"))
        // Pushed to the right, the sheet reaches past the table: there is a warning and a way to fit the table.
        for _ in 0..<4 { app.buttons["as.board.sheet.inspector.nudge.right"].tap() }
        let fit = app.buttons["as.board.sheet.inspector.fitTable"]
        for _ in 0..<12 where !element(app, "as.board.sheet.inspector.warning").exists {
            app.buttons["as.board.sheet.inspector.nudge.right"].tap()
        }
        XCTAssertTrue(element(app, "as.board.sheet.inspector.warning").waitForExistence(timeout: 15), "No off-table warning")
        tap(fit)
        XCTAssertFalse(element(app, "as.board.sheet.inspector.warning").waitForExistence(timeout: 3), "The warning stayed after fitting the table")
    }

    // MARK: Objective tokens

    @MainActor
    func testPlaceMoveAndDeleteAGenericToken() throws {
        let app = launch()
        goToBattlefield(app)
        tap(app.buttons["as.play.setup.board.build"])
        XCTAssertTrue(element(app, "as.board.editor").waitForExistence(timeout: 15))
        addToken(app)
        XCTAssertTrue(element(app, "as.board.inspector.side").waitForExistence(timeout: 15))
        XCTAssertEqual(element(app, "as.board.counter").label, "0 of 16 choices placed", "A token is not a terrain choice")
        let position = element(app, "as.board.inspector.position")
        let before = position.label
        tap(app.buttons["as.board.inspector.nudge.right"])
        XCTAssertNotEqual(position.label, before)
        tap(app.buttons["as.board.inspector.delete"])
        tap(app.buttons["as.board.pieceList.done"])
        XCTAssertFalse(element(app, "as.board.piece.0").exists)
        tap(app.buttons["as.board.undo"])
        XCTAssertTrue(element(app, "as.board.piece.0").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "as.board.piece.0").label.contains("Token 1"), element(app, "as.board.piece.0").label)
    }

    @MainActor
    func testRaidNamesAndCountsTheTokens() throws {
        let app = launch()
        goToBattlefield(app)
        // Pick Raid on the next step, then come back and build the board.
        tap(app.buttons["as.play.setup.continue"])
        let raid = element(app, "as.play.setup.objective.raid")
        for _ in 0..<6 where !raid.isHittable { app.swipeUp() }
        tap(raid)
        tap(app.buttons["as.play.setup.back"])
        scrollToBuild(app)
        tap(app.buttons["as.play.setup.board.build"])
        XCTAssertTrue(element(app, "as.board.editor").waitForExistence(timeout: 15))
        let counter = element(app, "as.board.tokens.counter")
        XCTAssertTrue(counter.waitForExistence(timeout: 15), "No token counter for Raid")
        XCTAssertEqual(counter.label, "Raid tokens: A 0 of 3, B 0 of 3")

        addToken(app)
        XCTAssertTrue(element(app, "as.board.inspector.tokenNote").waitForExistence(timeout: 15))
        app.navigationBars.buttons.firstMatch.tap()
        tap(app.buttons["as.board.pieceList.done"])
        XCTAssertEqual(counter.label, "Raid tokens: A 1 of 3, B 0 of 3")
        XCTAssertTrue(element(app, "as.board.piece.0").label.contains("Raid 1"), element(app, "as.board.piece.0").label)
    }

    // MARK: Helpers

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()
        return app
    }

    /// Adds a token through the list editor (the palette strip scrolls; this path never needs to).
    @MainActor
    private func addToken(_ app: XCUIApplication) {
        tap(app.buttons["as.board.list"])
        XCTAssertTrue(element(app, "as.board.pieceList").waitForExistence(timeout: 15))
        tap(app.buttons["as.board.pieceList.add"])
        tap(app.buttons["as.board.pieceList.add.token"])
    }

    @MainActor
    private func scrollToBuild(_ app: XCUIApplication) {
        var tries = 0
        while !app.buttons["as.play.setup.board.build"].isHittable && tries < 8 { app.swipeUp(); tries += 1 }
    }

    /// Setup steps 1–3, to Battlefield.
    @MainActor
    private func goToBattlefield(_ app: XCUIApplication) {
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        tabs.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 15))
        addCard(app, side: "A", card: "locust-lct-7v", search: "Locust")
        tap(app.buttons["as.play.setup.forces.side.B"])
        addCard(app, side: "B", card: "wasp-wsp-5a", search: "Wasp")
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.map").waitForExistence(timeout: 15))
        scrollToBuild(app)
    }

    @MainActor
    private func addCard(_ app: XCUIApplication, side: String, card: String, search: String) {
        tap(app.buttons["as.play.setup.forces.add.\(side)"])
        let field = app.textFields["as.play.setup.unitPicker.search"]
        tap(field)
        field.typeText(search)
        let row = app.buttons["as.play.setup.unitPicker.card.\(card)"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Card \(card) missing")
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
        XCTAssertTrue(element.waitForExistence(timeout: 15), "Missing \(element)", file: file, line: line)
        element.tap()
    }
}
