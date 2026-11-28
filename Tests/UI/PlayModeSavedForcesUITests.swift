import XCTest

/// PM9: enter a card by hand, save the force, load it again (PlayModeSpec § 5.3).
final class PlayModeSavedForcesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testHandEnteredCardAndSavedForce() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        app.tabBars.firstMatch.buttons["Play"].tap()
        tap(app.buttons["as.play.new"])
        tap(app.buttons["as.play.setup.continue"])
        tap(app.buttons["as.play.setup.continue"])
        XCTAssertTrue(element(app, "as.play.setup.forces").waitForExistence(timeout: 5))

        // Card entry: a bad card is refused with a message, a good one is added.
        tap(app.buttons["as.play.setup.forces.add.A"])
        let enter = app.buttons["as.play.setup.cardEntry"]
        var tries = 0
        while !enter.isHittable && tries < 8 { app.swipeUp(); tries += 1 }
        tap(enter)
        XCTAssertTrue(element(app, "as.card.entry").waitForExistence(timeout: 5))
        tap(app.buttons["as.card.entry.save"])
        XCTAssertTrue(element(app, "as.card.entry.error.name").waitForExistence(timeout: 5))

        fill(app, "name", "Raven RVN-3L")
        fill(app, "pv", "28")
        fill(app, "move", "6")
        fill(app, "tmm", "2")
        fill(app, "armor", "3")
        fill(app, "structure", "3")
        fill(app, "short", "2")
        fill(app, "medium", "1")
        fill(app, "long", "0")
        tap(app.buttons["as.card.entry.save"])
        tap(app.buttons["as.play.setup.unitPicker.done"])
        XCTAssertTrue(app.staticTexts["Your numbers"].waitForExistence(timeout: 5))

        // Save the force, remove the unit, load it back.
        tap(app.buttons["as.play.forces.saved.save"])
        let name = app.alerts.textFields.firstMatch
        tap(name)
        name.typeText("Scouts")
        tap(app.alerts.buttons["Save"])
        XCTAssertTrue(element(app, "as.play.forces.saved.notice").waitForExistence(timeout: 5))
        tap(app.buttons["as.play.setup.forces.clear.A"])
        tap(app.buttons["as.play.forces.saved.load"])
        let row = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'as.play.forces.saved.row.'")
        ).firstMatch
        tap(row)
        XCTAssertTrue(app.staticTexts["Raven RVN-3L"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func fill(_ app: XCUIApplication, _ field: String, _ text: String) {
        let element = app.textFields["as.card.entry.\(field)"]
        var tries = 0
        // Drag in the top third: with the keyboard up, a swipe in the middle lands on the keyboard and scrolls nothing.
        func drag(_ from: Double, _ to: Double) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to)))
        }
        while (!element.exists || !element.isHittable) && tries < 10 { drag(0.38, 0.18); tries += 1 }
        while (!element.exists || !element.isHittable) && tries < 22 { drag(0.18, 0.38); tries += 1 }
        // The keyboard can still be settling from the previous field; re-tap until this one has focus.
        func hasFocus() -> Bool { (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }
        tap(element)
        var focusTries = 0
        while !hasFocus() && focusTries < 3 {
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 2)
            if !hasFocus() { element.tap() }
            focusTries += 1
        }
        element.typeText(text)
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
