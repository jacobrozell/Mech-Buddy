import XCTest

/// Landscape pass (docs/landscape-checklist.md). Drives the new Play screens in iPhone landscape and writes one PNG
/// per screen. Skipped unless `LANDSCAPE_DIR` is set, so the normal UI run isn't slowed:
///   TEST_RUNNER_LANDSCAPE_DIR=/tmp/shots xcodebuild ... test -only-testing:MechBuddyUITests/LandscapeScreenshotUITests
/// Nothing here fails on a missing control: a screen that can't be reached is written to `misses.txt` in the same folder.
final class LandscapeScreenshotUITests: XCTestCase {
    private var dir: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        dir = ProcessInfo.processInfo.environment["LANDSCAPE_DIR"]
        try XCTSkipIf(dir == nil, "Set TEST_RUNNER_LANDSCAPE_DIR to take landscape screenshots")
        try? FileManager.default.createDirectory(atPath: dir!, withIntermediateDirectories: true)
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Scenarios

    @MainActor
    func testSetupSteps() throws {
        let app = launch()
        shot(app, "play-home")
        go(app.buttons["as.play.new"])
        shot(app, "setup-1-sides")
        go(app.buttons["as.play.setup.preset.1v1v1v1"])
        shot(app, "setup-1-sides-four")
        go(app.buttons["as.play.setup.continue"])
        shot(app, "setup-2-size")
        go(app.buttons["as.play.setup.continue"])
        shot(app, "setup-3-forces-empty")
        add(app, side: "A", card: "locust-lct-7v", search: "Locust", shotName: "unit-picker")
        shot(app, "setup-3-forces")
        // Card entry, with the keyboard up on a lower field.
        go(app.buttons["as.play.setup.forces.add.A"])
        scrollInto(app, app.buttons["as.play.setup.cardEntry"])
        go(app.buttons["as.play.setup.cardEntry"])
        shot(app, "card-entry")
        let pv = app.textFields["as.card.entry.long"]
        scrollInto(app, pv)
        go(pv)
        pv.typeText("1")
        shot(app, "card-entry-keyboard")
        app.buttons["as.card.entry.cancel"].firstMatchTap()
        go(app.buttons["as.play.setup.unitPicker.done"])
        // Save, load.
        go(app.buttons["as.play.forces.saved.save"])
        shot(app, "save-force-alert")
        app.alerts.buttons["Cancel"].firstMatchTap()
        go(app.buttons["as.play.forces.saved.load"])
        shot(app, "saved-forces-sheet")
        go(app.buttons["as.play.forces.saved.done"])
        // Rules first, to turn the MechWarrior card and buildings on.
        go(app.buttons["as.play.setup.continue"])
        shot(app, "setup-4-battlefield")
        scrollInto(app, app.buttons["as.play.setup.board.build"])
        shot(app, "setup-4-battlefield-board")
        go(app.buttons["as.play.setup.continue"])
        shot(app, "setup-5-rules-top")
        scrollInto(app, element(app, "as.play.setup.objective.controlTheField"))
        shot(app, "setup-5-rules-objectives")
        go(app.buttons["as.play.setup.objective.perSide"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
        shot(app, "setup-5-rules-perside")
        scrollInto(app, element(app, "as.play.setup.rules.mechWarriorCards"))
        shot(app, "setup-5-rules-optional")
        element(app, "as.play.setup.rules.mechWarriorCards").coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.buttons["as.play.setup.back"].firstMatchTap()
        app.buttons["as.play.setup.back"].firstMatchTap()
        shot(app, "setup-3-forces-mechwarrior")
        let card = app.descendants(matching: .any).matching(NSPredicate(format: "identifier ENDSWITH '.card'")).firstMatch
        scrollInto(app, card)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        shot(app, "mechwarrior-card-controls")
        let pilot = app.descendants(matching: .any).matching(NSPredicate(format: "identifier ENDSWITH '.pilot'")).firstMatch
        if pilot.waitForExistence(timeout: 3) {
            scrollInto(app, pilot)
            pilot.tap()
            pilot.typeText("Kai")
            shot(app, "mechwarrior-card-keyboard")
        }
    }

    @MainActor
    func testBattle() throws {
        let app = launch()
        go(app.buttons["as.play.new"])
        go(app.buttons["as.play.setup.preset.1v1v1v1"])
        go(app.buttons["as.play.setup.continue"])
        go(app.buttons["as.play.setup.continue"])
        for (index, letter) in ["A", "B", "C", "D"].enumerated() {
            if index > 0 { go(app.buttons["as.play.setup.forces.side.\(letter)"]) }
            add(app, side: letter, card: "locust-lct-7v", search: "Locust", shotName: nil)
            add(app, side: letter, card: "wasp-wsp-5a", search: "Wasp", shotName: nil)
        }
        go(app.buttons["as.play.setup.continue"])
        go(app.buttons["as.play.setup.continue"])
        let cotf = element(app, "as.play.setup.objective.controlTheField")
        scrollInto(app, cotf)
        go(cotf)
        // Buildings, so the Battlefield Support / building controls exist in battle.
        let buildings = element(app, "as.play.setup.buildings")
        scrollInto(app, buildings)
        buildings.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        scrollInto(app, app.segmentedControls["as.play.setup.dice"].buttons["Let the app roll"])
        go(app.segmentedControls["as.play.setup.dice"].buttons["Let the app roll"])
        go(app.buttons["as.play.setup.continue"])
        shot(app, "setup-6-review")
        scrollInto(app, app.buttons["as.play.setup.start"])
        shot(app, "setup-6-review-bottom")
        go(app.buttons["as.play.setup.start"])
        XCTAssertTrue(element(app, "as.ridge.tablePrep").waitForExistence(timeout: 12))
        shot(app, "table-setup")
        scrollInto(app, app.buttons["as.ridge.tableReady"])
        shot(app, "table-setup-bottom")
        var seen = Set<String>()
        let deadline = Date().addingTimeInterval(150)
        var turn = 0
        while Date() < deadline {
            let tableReady = app.buttons["as.ridge.tableReady"]
            let skip = app.buttons["as.battle.skipRemaining"]
            let primary = app.buttons["as.battle.primary"]
            for title in ["Start shooting anyway", "Done shooting anyway"] where app.buttons[title].exists && app.buttons[title].isHittable { app.buttons[title].tap() }
            if tableReady.exists, tableReady.isHittable {
                tableReady.tap()
            } else if skip.exists, skip.isHittable {
                if seen.insert("movement").inserted { shot(app, "battle-movement-dense"); scrollInto(app, skip); shot(app, "battle-movement-dense-bottom") }
                skip.tap()
            } else if element(app, "as.battle.shooters.lanceA").exists {
                if seen.insert("combat").inserted {
                    shot(app, "battle-combat")
                    shot(app, "battle-vp-strip")
                }
                let done = app.buttons["as.battle.doneShooting"]
                if done.exists, done.isHittable { done.tap() } else { Thread.sleep(forTimeInterval: 0.5) }
            } else if app.buttons["as.battle.objective.lanceA.inPosition.0"].exists {
                if seen.insert("score").inserted { shot(app, "battle-score-card"); scrollInto(app, app.buttons["as.battle.primary"]); shot(app, "battle-score-card-bottom") }
                break
            } else if primary.exists, primary.isHittable, primary.label != "Solve a shot" {
                if primary.label == "Score and next turn" { break }
                let key = primary.label.replacingOccurrences(of: " ", with: "-").lowercased()
                if seen.insert("step-" + key).inserted { shot(app, "battle-step-" + key) }
                primary.tap()
            } else {
                Thread.sleep(forTimeInterval: 0.5)
            }
            turn += 1
        }
        if !seen.contains("score") {
            miss("battle", "never reached the Score step; seen \(seen)")
        }
        shot(app, "battle-last")
    }

    @MainActor
    func testBoards() throws {
        let app = launch()
        go(app.buttons["as.play.boards"])
        shot(app, "boards-list")
        // Build one from the setup Battlefield step so there is a board to show.
        app.navigationBars.buttons.firstMatch.firstMatchTap()
        go(app.buttons["as.play.new"])
        go(app.buttons["as.play.setup.continue"])
        go(app.buttons["as.play.setup.continue"])
        add(app, side: "A", card: "locust-lct-7v", search: "Locust", shotName: nil)
        go(app.buttons["as.play.setup.forces.side.B"])
        add(app, side: "B", card: "wasp-wsp-5a", search: "Wasp", shotName: nil)
        go(app.buttons["as.play.setup.continue"])
        let ridge = app.buttons["as.play.setup.board.ridgeLine"]
        scrollInto(app, ridge)
        go(ridge)
        shot(app, "setup-4-battlefield-with-board")
        let edit = app.buttons["as.play.setup.board.edit"]
        scrollInto(app, edit)
        go(edit)
        shot(app, "board-editor")
        let canvas = element(app, "as.board.canvas")
        if canvas.waitForExistence(timeout: 5) {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            shot(app, "board-inspector")
        }
        scrollInto(app, app.buttons["as.board.inspector.delete"])
        shot(app, "board-inspector-bottom")
        go(app.buttons["as.board.list"])
        shot(app, "board-piece-list")
        app.navigationBars.buttons.firstMatch.firstMatchTap()
        // Options menu: Save board.
        let more = app.buttons["as.board.options"]
        go(more)
        shot(app, "board-options")
        let save = app.buttons["as.board.save"]
        if save.waitForExistence(timeout: 3) {
            save.tap()
            let name = app.textFields.firstMatch
            if name.waitForExistence(timeout: 3) { name.tap() }
            shot(app, "board-save-sheet")
        } else {
            miss("board-save-sheet", "no as.board.save in the options menu")
        }
    }

    // MARK: Helpers

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui_testing", "-reset_state", "-skip_onboarding", "-enable_full_product_surface"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        let tabs = app.tabBars.firstMatch
        if tabs.waitForExistence(timeout: 20) { tabs.buttons["Play"].tap() }
        Thread.sleep(forTimeInterval: 1)
        return app
    }

    @MainActor
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    @MainActor
    private func go(_ element: XCUIElement) {
        guard element.waitForExistence(timeout: 6) else { miss("go", "missing \(element)"); return }
        if !element.isHittable { miss("go", "not hittable at first: \(element.identifier)") }
        element.tap()
        Thread.sleep(forTimeInterval: 0.6)
    }

    @MainActor
    private func go(_ coordinate: XCUICoordinate) {
        coordinate.tap()
        Thread.sleep(forTimeInterval: 0.6)
    }

    /// Drags in the top third, where the keyboard never is, until the element can be hit.
    @MainActor
    private func scrollInto(_ app: XCUIApplication, _ element: XCUIElement) {
        func drag(_ from: Double, _ to: Double) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to)))
        }
        var tries = 0
        while (!element.exists || !element.isHittable) && tries < 14 { drag(0.4, 0.12); tries += 1 }
        tries = 0
        while (!element.exists || !element.isHittable) && tries < 28 { drag(0.12, 0.4); tries += 1 }
        if !element.exists || !element.isHittable { miss("scroll", "could not reach \(element.identifier)") }
    }

    @MainActor
    private func add(_ app: XCUIApplication, side: String, card: String, search: String, shotName: String?) {
        go(app.buttons["as.play.setup.forces.add.\(side)"])
        let field = app.textFields["as.play.setup.unitPicker.search"]
        go(field)
        field.typeText(search)
        if let shotName { shot(app, shotName) }
        let row = app.buttons["as.play.setup.unitPicker.card.\(card)"]
        _ = row.waitForExistence(timeout: 6)
        scrollInto(app, row)
        row.tap()
        go(app.buttons["as.play.setup.unitPicker.done"])
    }

    /// XCUIScreenshot's PNG comes out unrotated in landscape, so the picture is taken by the host: this writes
    /// `request.txt` and waits until a watcher (`xcrun simctl io <udid> screenshot <dir>/<name>.png`) deletes it.
    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 0.8)
        let request = "\(dir!)/request.txt"
        try? name.write(toFile: request, atomically: true, encoding: .utf8)
        let deadline = Date().addingTimeInterval(15)
        while FileManager.default.fileExists(atPath: request), Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
    }

    private func miss(_ what: String, _ detail: String) {
        let line = "\(what): \(detail)\n"
        let url = URL(fileURLWithPath: "\(dir!)/misses.txt")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

private extension XCUIElement {
    /// Taps when it is there; never fails the run.
    func firstMatchTap() {
        if waitForExistence(timeout: 3), isHittable { tap() }
    }
}
