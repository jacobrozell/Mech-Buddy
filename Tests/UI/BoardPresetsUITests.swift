import XCTest

/// PM13: board presets. Save a board and pick it in setup, starter boards, manage the list (PlayModeSpec § 9.7, § 9.10).
final class BoardPresetsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Save, then pick it in setup

    @MainActor
    func testSaveBoardThenPickItInSetupWithStretch() throws {
        let app = launch()
        goToBattlefield(app)
        scrollTo(app.buttons["as.play.setup.board.ridgeLine"], app)
        tap(app.buttons["as.play.setup.board.ridgeLine"])
        XCTAssertTrue(element(app, "as.board.canvas").waitForExistence(timeout: 5))
        tap(app.buttons["as.board.done"])

        // Save it under a name.
        scrollTo(app.buttons["as.play.setup.board.save"], app)
        tap(app.buttons["as.play.setup.board.save"])
        XCTAssertTrue(element(app, "as.play.board.save").waitForExistence(timeout: 5))
        let name = app.textFields["as.play.board.save.name"]
        tap(name)
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        name.typeText("My ridge")
        tap(app.buttons["as.play.board.save.confirm"])
        XCTAssertTrue(element(app, "as.play.setup.board.summary").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.play.setup.board.summary").label.contains("My ridge"), element(app, "as.play.setup.board.summary").label)

        // Drop the board from the game, then pick the saved one.
        tap(app.buttons["as.play.setup.board.remove"])
        scrollTo(app.buttons["as.play.setup.board.pick"], app)
        tap(app.buttons["as.play.setup.board.pick"])
        XCTAssertTrue(element(app, "as.play.board.list").waitForExistence(timeout: 5))
        let mine = app.buttons.matching(NSPredicate(format: "identifier MATCHES '^as\\\\.play\\\\.board\\\\.row\\\\.[0-9A-F-]{36}$'")).firstMatch
        XCTAssertTrue(mine.waitForExistence(timeout: 5), "Saved board missing from the list")
        XCTAssertTrue(mine.label.contains("My ridge"), mine.label)
        mine.tap()

        // 36 × 22 is smaller than the 48 × 36 mat: stretch it.
        let stretch = app.buttons["Stretch to 48 × 36″"].firstMatch
        XCTAssertTrue(stretch.waitForExistence(timeout: 5), "No stretch question")
        stretch.tap()
        XCTAssertTrue(element(app, "as.play.setup.board.summary").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.play.setup.board.summary").label.contains("My ridge"))
        XCTAssertTrue(element(app, "as.play.setup.layout").exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '48″ × 36″'")).firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: Starter boards

    @MainActor
    func testStarterBoardsArePickable() throws {
        let app = launch()
        goToBattlefield(app)
        scrollTo(app.buttons["as.play.setup.board.pick"], app)
        tap(app.buttons["as.play.setup.board.pick"])
        XCTAssertTrue(element(app, "as.play.board.list").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.play.board.empty").exists, "A fresh install has no saved boards")
        let open = app.buttons["as.play.board.row.starter.open-4-4-for-four"]
        scrollTo(open, app)
        XCTAssertTrue(open.label.contains("4′ × 4′"), open.label)
        open.tap()
        // 48 × 48 is bigger than the mat: no question, it's the table now.
        XCTAssertTrue(element(app, "as.play.setup.board.summary").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "as.play.setup.board.summary").label.contains("Open 4′ × 4′ for four"))
    }

    // MARK: Manage the list

    @MainActor
    func testBoardsListDuplicateRenameDelete() throws {
        let app = launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 20))
        tabs.buttons["Play"].tap()
        tap(app.buttons["as.play.boards"])
        XCTAssertTrue(element(app, "as.play.board.list").waitForExistence(timeout: 5))

        // Starter boards are read-only; Duplicate makes one of yours.
        tap(app.buttons["as.play.board.menu.starter.ridge-line"])
        tap(app.buttons["Duplicate"])
        let copy = app.buttons.matching(NSPredicate(format: "identifier MATCHES '^as\\\\.play\\\\.board\\\\.row\\\\.[0-9A-F-]{36}$'")).firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        XCTAssertTrue(copy.label.contains("Ridge Line copy"), copy.label)
        XCTAssertFalse(element(app, "as.play.board.empty").exists)

        // Rename.
        let menu = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'as.play.board.menu.' AND NOT identifier CONTAINS 'starter'")).firstMatch
        tap(menu)
        tap(app.buttons["Rename"])
        let field = app.alerts.textFields.firstMatch
        tap(field)
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30))
        field.typeText("Skirmish")
        tap(app.alerts.buttons["Save"])
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Skirmish'")).firstMatch.waitForExistence(timeout: 5))

        // Delete is confirmed.
        tap(menu)
        tap(app.buttons["Delete"])
        tap(app.buttons.matching(identifier: "as.play.board.delete.confirm").firstMatch)
        XCTAssertTrue(element(app, "as.play.board.empty").waitForExistence(timeout: 5))
    }

    // MARK: Helpers

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()
        return app
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, _ app: XCUIApplication) {
        var tries = 0
        while (!element.exists || !element.isHittable) && tries < 8 { app.swipeUp(); tries += 1 }
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
