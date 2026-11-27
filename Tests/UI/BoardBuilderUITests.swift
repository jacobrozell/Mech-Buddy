import XCTest

/// PM12: the terrain board builder in Play setup (PlayModeSpec § 9, § 20 UI), behind `playBoards`.
final class BoardBuilderUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Drag path

    @MainActor
    func testDragWoodsMoveRotateDeleteUndo() throws {
        let app = launch()
        goToBattlefield(app)
        tap(app.buttons["as.play.setup.board.build"])
        XCTAssertTrue(element(app, "as.board.editor").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "as.board.counter").label, "0 of 16 choices placed")

        // Touch, hold and drag a woods from the palette onto the table.
        let canvas = element(app, "as.board.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        let woods = element(app, "as.board.palette.woods")
        XCTAssertTrue(woods.waitForExistence(timeout: 5))
        let drop = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        woods.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.6, thenDragTo: drop)
        XCTAssertTrue(element(app, "as.board.piece.0").waitForExistence(timeout: 5), "Woods was not placed")
        XCTAssertEqual(element(app, "as.board.counter").label, "1 of 16 choices placed")
        XCTAssertTrue(canvas.label.contains("1 woods"), canvas.label)

        // The inspector opens on the new piece. Move it by dragging it on the table.
        let position = element(app, "as.board.inspector.position")
        XCTAssertTrue(position.waitForExistence(timeout: 5))
        let before = position.label
        let from = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.4)))
        XCTAssertNotEqual(position.label, before, "Dragging did not move the piece")

        // Rotate: the 15 degree button, twice.
        tap(app.buttons["as.board.inspector.rotate.plus"])
        tap(app.buttons["as.board.inspector.rotate.plus"])
        XCTAssertTrue(element(app, "as.board.inspector.rotation").label.contains("30"), element(app, "as.board.inspector.rotation").label)

        // Delete, then undo brings it back.
        tap(app.buttons["as.board.inspector.delete"])
        XCTAssertEqual(element(app, "as.board.counter").label, "0 of 16 choices placed")
        XCTAssertFalse(element(app, "as.board.piece.0").exists)
        tap(app.buttons["as.board.undo"])
        XCTAssertEqual(element(app, "as.board.counter").label, "1 of 16 choices placed")
        XCTAssertTrue(element(app, "as.board.piece.0").waitForExistence(timeout: 5))
    }

    // MARK: List editor only (accessibility path)

    @MainActor
    func testListEditorBuildsTheSameBoardWithoutDragging() throws {
        let app = launch()
        goToBattlefield(app)
        tap(app.buttons["as.play.setup.board.build"])
        XCTAssertTrue(element(app, "as.board.editor").waitForExistence(timeout: 5))

        tap(app.buttons["as.board.list"])
        XCTAssertTrue(element(app, "as.board.pieceList").waitForExistence(timeout: 5))
        // Add a woods and set its place with the buttons.
        tap(app.buttons["as.board.pieceList.add"])
        tap(app.buttons["as.board.pieceList.add.woods"])
        XCTAssertTrue(element(app, "as.board.inspector").waitForExistence(timeout: 5))
        let position = element(app, "as.board.inspector.position")
        let before = position.label
        tap(app.buttons["as.board.inspector.nudge.right"])
        tap(app.buttons["as.board.inspector.nudge.down"])
        XCTAssertNotEqual(position.label, before)
        tap(app.buttons["as.board.inspector.rotate.plus"])
        XCTAssertTrue(element(app, "as.board.inspector.rotation").label.contains("15"))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(app, "as.board.pieceList.row.0").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.board.pieceList.row.0").label.contains("Woods"))

        // A hill, too, then the list reads both.
        tap(app.buttons["as.board.pieceList.add"])
        tap(app.buttons["as.board.pieceList.add.hill"])
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(element(app, "as.board.pieceList.row.1").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "as.board.pieceList.counter").label, "2 of 16 choices placed")
        tap(app.buttons["as.board.pieceList.done"])
        XCTAssertTrue(element(app, "as.board.canvas").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.board.canvas").label.contains("1 woods, 1 hill level 1"), element(app, "as.board.canvas").label)
    }

    // MARK: Starter board, into the game

    @MainActor
    func testRidgeLineStarterBoardGoesIntoSetupAndTheGame() throws {
        let app = launch()
        goToBattlefield(app)
        var scrolls = 0
        while !app.buttons["as.play.setup.board.ridgeLine"].isHittable && scrolls < 6 { app.swipeUp(); scrolls += 1 }
        tap(app.buttons["as.play.setup.board.ridgeLine"])
        let canvas = element(app, "as.board.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        // Ridge Line's table is 36 by 22 with three woods.
        XCTAssertTrue(canvas.label.contains("36 by 22 inch table"), canvas.label)
        XCTAssertTrue(canvas.label.contains("3 woods"), canvas.label)
        XCTAssertEqual(element(app, "as.board.counter").label, "3 of 16 choices placed")
        tap(app.buttons["as.board.done"])

        XCTAssertTrue(element(app, "as.play.setup.board.summary").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.play.setup.board.summary").label.contains("Ridge Line"))
        XCTAssertTrue(element(app, "as.play.setup.layout").exists)
        XCTAssertTrue(element(app, "as.play.setup.layout").label.contains("3 patches of woods"), element(app, "as.play.setup.layout").label)
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.rules").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.review").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.start"])

        // Table setup shows the board, and Board in the toolbar opens it read-only.
        XCTAssertTrue(element(app, "as.ridge.tablePrep").waitForExistence(timeout: 10))
        var tries = 0
        while !element(app, "as.battle.board.briefing").exists && tries < 6 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(element(app, "as.battle.board.briefing").exists, "Board missing from table setup")
        tap(app.buttons["as.battle.board"])
        XCTAssertTrue(element(app, "as.battle.board.sheet").waitForExistence(timeout: 5))
        tap(app.buttons["as.battle.board.done"])
    }

    // MARK: Flag

    @MainActor
    func testBuilderIsHiddenWithoutTheFlag() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding"]
        app.launch()
        // Release surface: no Play tab, so no Build a board anywhere.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        XCTAssertFalse(app.tabBars.firstMatch.buttons["Learn"].exists)
        XCTAssertFalse(app.buttons["as.play.setup.board.build"].exists)
    }

    // MARK: Helpers

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()
        return app
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
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 5))
        addCard(app, side: "A", card: "locust-lct-7v", search: "Locust")
        tap(app.buttons["as.play.setup.forces.side.B"])
        addCard(app, side: "B", card: "wasp-wsp-5a", search: "Wasp")
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.map").waitForExistence(timeout: 5))
        var tries = 0
        while !app.buttons["as.play.setup.board.build"].isHittable && tries < 6 { app.swipeUp(); tries += 1 }
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
