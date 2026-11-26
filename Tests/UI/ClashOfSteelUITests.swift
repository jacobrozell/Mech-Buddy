import XCTest

/// Clash of Steel (Quick-Start p. 31): the scenario rules sheet works at the table. Buys secret Battlefield
/// Support, picks Combat Intuition 'Mechs and opens a building. Screenshots go to build/shots/.
final class ClashOfSteelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func save(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("build/shots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }

    @MainActor
    func testScenarioRulesSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-open_mission", "clash-of-steel"]
        app.launch()

        let open = app.buttons["cos.rules.open"]
        XCTAssertTrue(open.waitForExistence(timeout: 20), "Scenario rules button missing")
        open.tap()
        XCTAssertTrue(app.buttons["cos.support.A"].waitForExistence(timeout: 5))
        save(app, "cos-rules-sheet")

        // Side A buys Light Strike (2) + Sniper (3) = 5 and writes it down.
        app.buttons["cos.support.A"].tap()
        let strike = app.steppers["cos.support.buy.lightStrike"]
        XCTAssertTrue(strike.waitForExistence(timeout: 5))
        strike.buttons.element(boundBy: 1).tap()
        app.steppers["cos.support.buy.sniper"].buttons.element(boundBy: 1).tap()
        save(app, "cos-support-buy")
        app.buttons["cos.support.lock"].tap()
        let revealed = app.buttons["cos.support.reveal"].waitForExistence(timeout: 5)
        save(app, "cos-support-locked")
        XCTAssertTrue(revealed || app.buttons["cos.support.reveal"].waitForExistence(timeout: 5), "Support not written down")
        let back = app.navigationBars["Side A"].buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()

        // Combat Intuition: two Command Lance 'Mechs, not the Atlas.
        let choose = app.buttons["cos.ci.choose"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        choose.tap()
        for name in ["Archer ARC-7C", "Blackjack BJ-5"] {
            let toggle = app.switches[name].firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        app.buttons["cos.ci.save"].tap()
        XCTAssertTrue(app.navigationBars["Scenario rules"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["cos.ci.choose"].exists, "Combat Intuition not saved")
        save(app, "cos-formations")

        // A large building: Heavy, CF 12.
        let building = app.descendants(matching: .any)["cos.building.L1"].firstMatch
        for _ in 0..<10 where !(building.exists && building.isHittable) { app.swipeUp() }
        building.tap()
        let cf = app.descendants(matching: .any)["cos.building.cf"].firstMatch
        XCTAssertTrue(cf.waitForExistence(timeout: 5))
        save(app, "cos-building")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '12 of 12'")).count > 0
            || cf.label.contains("12 of 12") || (cf.value as? String)?.contains("12 of 12") == true, "CF: \(cf.label)")
    }
}
