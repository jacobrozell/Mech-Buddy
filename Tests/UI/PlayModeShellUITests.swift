import XCTest

/// Learn | Play shell (PlayModeSpec § 3, § 20 UI: Flag off, Flag on).
final class PlayModeShellUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testFlagOffKeepsFourTabsAndMissionPath() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["play.home"].waitForExistence(timeout: 20))
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 5))
        XCTAssertEqual(tabs.buttons.count, 4, "Flag off shows today's four tabs")
        XCTAssertFalse(tabs.buttons["Learn"].exists)
        XCTAssertTrue(app.buttons["as.modeHome.ridgeLine"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testFlagOnShowsLearnAndPlay() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()

        // A new player lands on Learn, which holds the mission path under both ids.
        XCTAssertTrue(app.descendants(matching: .any)["learn.home"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["play.home"].exists)
        XCTAssertTrue(app.buttons["as.modeHome.ridgeLine"].waitForExistence(timeout: 10))
        let tabs = app.tabBars.firstMatch
        XCTAssertEqual(tabs.buttons.count, 5, "Flag on shows five tabs")

        tabs.buttons["Play"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["as.play.home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["as.play.empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["as.play.new"].exists)
    }
}
