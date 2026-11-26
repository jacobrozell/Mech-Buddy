import XCTest

/// Phase 6 happy path: Play → Ridge Line → victory. Spec: TestPlanSpec § UI smoke.
final class RidgeLineUITests: XCTestCase {
    private var taps: [String] = []

    override func setUp() {
        continueAfterFailure = false
        // A landscape run (screenshots) leaves the simulator rotated; these flows expect portrait.
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testPlayRidgeLineToVictory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding"]
        app.launch()

        let play = app.buttons["as.modeHome.ridgeLine"]
        XCTAssertTrue(play.waitForExistence(timeout: 20), "Ridge Line play button missing")
        play.tap()

        // `as.victory.screen` is a 1x1 clear marker that XCUITest does not always surface;
        // `as.victory` (same screen, per AccessibilitySpec) is the container and is queryable.
        let victory = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier IN {'as.victory.screen', 'as.victory'}")
        ).firstMatch
        let deadline = Date().addingTimeInterval(240)
        var idle = 0
        while Date() < deadline {
            if victory.exists { break }
            if advance(app) { idle = 0 } else {
                idle += 1
                if idle > 12 { break }
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(victory.waitForExistence(timeout: 10), "Victory screen never appeared. Taps: \(taps.joined(separator: " > "))")
    }

    /// Taps the first actionable control for the current step. Returns false if nothing was tappable.
    @MainActor
    private func advance(_ app: XCUIApplication) -> Bool {
        // Confirm dialogs first (they block everything else).
        for title in ["Start shooting anyway", "Done shooting anyway"] {
            if tapIfExists(app.buttons[title]) { return true }
        }
        // Table setup, deployment, initiative roll/confirm, cleanup, and "Next turn" share these ids.
        if tapIfExists(app.buttons["as.ridge.tableReady"]) { return true }
        if app.buttons["as.battle.skipRemaining"].exists {
            return tapIfExists(app.buttons["as.battle.skipRemaining"])
        }
        if tapIfExists(app.buttons["as.battle.doneShooting"]) { return true }
        // Initiative: skip the roll and let the table choose who moves first.
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
        // Primary: "Miniatures placed", "Roll both sides", "<Side> moves first — start", "Next turn", "See result".
        // Skip "Solve a shot" / "Roll critical" which open sheets we don't drive.
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
