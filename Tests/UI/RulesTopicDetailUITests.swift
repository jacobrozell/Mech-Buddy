import XCTest

/// Rules tab to a topic page and back.
final class RulesTopicDetailUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testOpenTurnTopicFromRulesTab() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-open_rules"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["rules.home"].waitForExistence(timeout: 20))
        let row = app.descendants(matching: .any)["rules.as.turn"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["rules.as.detail.turn"].waitForExistence(timeout: 15))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["rules.home"].waitForExistence(timeout: 15))
    }
}
