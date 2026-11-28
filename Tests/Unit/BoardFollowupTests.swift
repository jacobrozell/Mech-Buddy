import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

// Board builder follow-ups: drag zone edges, move and turn mapsheets, objective tokens (PlayModeSpec § 9.2, § 7.1).

private func board(width: Double = 48, depth: Double = 48, sheets: [BoardLayout.Sheet] = [], features: [BoardLayout.Feature] = []) -> BoardLayout {
    BoardLayout(width: width, depth: depth, sheets: sheets, features: features)
}

private func sheet(_ name: String, x: Double, y: Double, w: Double = 22, d: Double = 17) -> BoardLayout.Sheet {
    .init(name: name, area: .init(x: x, y: y, width: w, depth: d))
}

@Suite("Board follow-ups: zones")
struct BoardZoneEdgeTests {
    @Test("A zone's home edge is read from the board or the edge it is thin against")
    func homeEdges() {
        let zones = BoardZones.generate(width: 48, depth: 36, sideCount: 2)
        let bare = zones.map { BoardLayout.Zone(side: $0.side, area: $0.area) }
        #expect(bare.map { BoardRules.homeEdge(of: $0, width: 48, depth: 36) } == [.west, .east])
        let four = BoardZones.generate(width: 48, depth: 48, sideCount: 4).map { BoardLayout.Zone(side: $0.side, area: $0.area) }
        #expect(four.map { BoardRules.homeEdge(of: $0, width: 48, depth: 48) } == [.west, .east, .south, .north])
        #expect(bare.map { BoardRules.depth(of: $0, width: 48, depth: 36) } == [6, 6])
        #expect(BoardRules.depth(of: BoardLayout.Zone(side: "C", area: four[2].area), width: 48, depth: 48) == 6)
    }

    @Test("Resizing keeps the zone on its edge and its length, snaps, and clamps to 2 to 12")
    func resizing() {
        let west = BoardLayout.Zone(side: "A", area: .init(x: 0, y: 0, width: 6, depth: 48))
        let a = BoardRules.resized(west, toDepth: 8.4, width: 48, depth: 48, snap: .whole)
        #expect(a.area == .init(x: 0, y: 0, width: 8, depth: 48))
        let half = BoardRules.resized(west, toDepth: 8.4, width: 48, depth: 48, snap: .half)
        #expect(half.area.width == 8.5)
        #expect(BoardRules.resized(west, toDepth: 0, width: 48, depth: 48).area.width == 2)
        #expect(BoardRules.resized(west, toDepth: 40, width: 48, depth: 48).area.width == 12)

        let east = BoardLayout.Zone(side: "B", area: .init(x: 42, y: 0, width: 6, depth: 48))
        #expect(BoardRules.resized(east, toDepth: 10, width: 48, depth: 48).area == .init(x: 38, y: 0, width: 10, depth: 48))
        let south = BoardLayout.Zone(side: "C", area: .init(x: 15, y: 42, width: 18, depth: 6))
        #expect(BoardRules.resized(south, toDepth: 9, width: 48, depth: 48).area == .init(x: 15, y: 39, width: 18, depth: 9))
        // On a 24″ table a third is 8″.
        #expect(BoardRules.resized(west, toDepth: 12, width: 24, depth: 48).area.width == 8)
    }

    @Test("Dragging toward a point measures from the home edge")
    func dragDepth() {
        #expect(BoardRules.depth(toward: .init(x: 9, y: 20), edge: .west, width: 48, depth: 36) == 9)
        #expect(BoardRules.depth(toward: .init(x: 40, y: 20), edge: .east, width: 48, depth: 36) == 8)
        #expect(BoardRules.depth(toward: .init(x: 20, y: 5), edge: .north, width: 48, depth: 36) == 5)
        #expect(BoardRules.depth(toward: .init(x: 20, y: 30), edge: .south, width: 48, depth: 36) == 6)
        let handle = BoardRules.innerEdgeMidpoint(of: .init(side: "A", area: .init(x: 0, y: 0, width: 6, depth: 36)), width: 48, depth: 36)
        #expect(handle == .init(x: 6, y: 18))
    }

    @Test("Editing a zone stores a set for the side count, undoes, and warns about pieces inside")
    func editorSetsZones() {
        let piece = BoardLayout.Feature(kind: .woods, area: .init(x: 7, y: 20, width: 4, depth: 4))
        var editor = BoardEditor(board: board(features: [piece]))
        let zones = editor.board.zones(sideCount: 2)
        #expect(BoardRules.piecesInsideZones(editor.board.features, zones: zones) == 0)
        let deeper = zones.map { BoardRules.resized($0, toDepth: 9, width: 48, depth: 48) }
        editor.setZoneSet(deeper, sideCount: 2)
        let now = editor.board.zones(sideCount: 2)
        #expect(now.first?.area.width == 9)
        #expect(BoardRules.piecesInsideZones(editor.board.features, zones: now) == 1)
        #expect(BoardRules.zoneWarningText(count: 1) == "1 piece is inside a deployment zone.")
        #expect(BoardRules.zoneWarningText(count: 0) == nil)
        // Other side counts are untouched.
        #expect(editor.board.zonesBySideCount?[3] == nil)
        _ = editor.undo()
        #expect(editor.board.zonesBySideCount == nil)
    }

    @Test("A drag is one undo step, and an unchanged drag leaves none")
    func dragIsOneStep() {
        var editor = BoardEditor(board: board())
        editor.checkpoint()
        for d in [7.0, 8, 9, 10] {
            let set = editor.board.zones(sideCount: 2).map { BoardRules.resized($0, toDepth: d, width: 48, depth: 48) }
            editor.liveZoneSet(set, sideCount: 2)
        }
        #expect(editor.board.zones(sideCount: 2).first?.area.width == 10)
        _ = editor.undo()
        #expect(editor.board.zones(sideCount: 2).first?.area.width == 6)
        #expect(!editor.canUndo)
    }
}

@Suite("Board follow-ups: mapsheets")
struct BoardSheetTests {
    @Test("Rotating turns 90 degrees about the centre, swapping width and depth, and wraps to nil")
    func rotate() throws {
        var editor = BoardEditor(board: board(sheets: [sheet("Grassland #1", x: 0, y: 0)]))
        editor.rotateSheet(0)
        let turned = editor.board.sheets[0]
        #expect(turned.rotation == 90)
        #expect(turned.area.width == 17 && turned.area.depth == 22)
        #expect(turned.area.x >= 0 && turned.area.y >= 0)
        editor.rotateSheet(0)
        #expect(editor.board.sheets[0].rotation == 180)
        editor.rotateSheet(0)
        editor.rotateSheet(0)
        #expect(editor.board.sheets[0].rotation == nil)
        #expect(editor.board.sheets[0].area.width == 22)
        for _ in 0..<4 { _ = editor.undo() }
        #expect(editor.board.sheets[0] == sheet("Grassland #1", x: 0, y: 0))
    }

    @Test("A moved sheet snaps to the grid, then flush to a neighbour or the table edge; snap off is free")
    func moveAndMagnet() {
        let a = sheet("A", x: 0, y: 0)
        var editor = BoardEditor(board: board(width: 44, depth: 34, sheets: [a, sheet("B", x: 30, y: 20)]))
        // Close to A's right edge (22): pulled flush.
        editor.placeSheet(1, x: 23.2, y: 0.4, snap: .whole)
        #expect(editor.board.sheets[1].area.x == 22)
        #expect(editor.board.sheets[1].area.y == 0)
        // Far from anything: just the grid.
        editor.placeSheet(1, x: 30.4, y: 12.4, snap: .whole)
        #expect(editor.board.sheets[1].area.x == 30 && editor.board.sheets[1].area.y == 12)
        // Snap off: exactly where it was put, no pull.
        editor.placeSheet(1, x: 23.2, y: 0.4, snap: .off)
        #expect(editor.board.sheets[1].area.x == 23.2)
        // Never above or left of the table corner.
        editor.placeSheet(1, x: -9, y: -3, snap: .whole)
        #expect(editor.board.sheets[1].area.x == 0 && editor.board.sheets[1].area.y == 0)
    }

    @Test("Nudge and steppers are undoable and exact")
    func nudge() {
        var editor = BoardEditor(board: board(sheets: [sheet("A", x: 5, y: 5)]))
        editor.nudgeSheet(0, dx: 1, dy: -2)
        #expect(editor.board.sheets[0].area.x == 6 && editor.board.sheets[0].area.y == 3)
        editor.setSheetPosition(0, x: 10)
        #expect(editor.board.sheets[0].area.x == 10 && editor.board.sheets[0].area.y == 3)
        editor.nudgeSheet(0, dx: -50, dy: 0)
        #expect(editor.board.sheets[0].area.x == 0)
        _ = editor.undo(); _ = editor.undo(); _ = editor.undo()
        #expect(editor.board.sheets[0].area.x == 5)
    }

    @Test("Sheets off the table are listed and warned about; Fit table sizes the table to them")
    func offTable() {
        var editor = BoardEditor(board: board(width: 44, depth: 34, sheets: [sheet("A", x: 0, y: 0), sheet("B", x: 22, y: 0), sheet("C", x: 44, y: 0)],
                                              features: [.init(kind: .woods, area: .init(x: 40, y: 10, width: 4, depth: 4))]))
        #expect(BoardRules.sheetsOffTable(editor.board) == [2])
        #expect(BoardRules.sheetWarningText(editor.board) == "1 mapsheet reaches off the table.")
        #expect(BoardRules.spoken(editor.board.sheets[2], in: editor.board).contains("Reaches off the table"))
        editor.fitTableToSheets()
        #expect(editor.board.width == 66 && editor.board.depth == 17)
        #expect(BoardRules.sheetsOffTable(editor.board).isEmpty)
        #expect(BoardRules.sheetWarningText(editor.board) == nil)
        #expect(editor.board.zonesBySideCount == nil)
        _ = editor.undo()
        #expect(editor.board.width == 44 && editor.board.depth == 34)
        // Smaller than the 12″ minimum is held at 12″.
        var tiny = BoardEditor(board: board(sheets: [sheet("S", x: 0, y: 0, w: 8, d: 8)]))
        tiny.fitTableToSheets()
        #expect(tiny.board.width == 12 && tiny.board.depth == 12)
    }

    @Test("Hit testing picks the topmost sheet; captions and speech name a turned sheet")
    func hitAndWords() {
        let sheets = [sheet("A", x: 0, y: 0), sheet("B", x: 10, y: 5)]
        #expect(BoardRules.sheetHit(sheets, at: .init(x: 12, y: 6)) == 1)
        #expect(BoardRules.sheetHit(sheets, at: .init(x: 1, y: 1)) == 0)
        #expect(BoardRules.sheetHit(sheets, at: .init(x: 40, y: 30)) == nil)
        var turned = sheet("A", x: 0, y: 0)
        #expect(BoardRules.sheetCaption(turned) == "A")
        turned.rotation = 90
        #expect(BoardRules.sheetCaption(turned) == "A · turned 90°")
        #expect(BoardRules.spoken(turned, in: board(sheets: [turned])).contains("Turned 90 degrees"))
    }

    @Test("Sheet turns survive JSON; boards saved before turning, and files without rotation, still load")
    func codable() throws {
        var turned = sheet("Desert #2", x: 22, y: 0, w: 17, d: 22)
        turned.rotation = 90
        let original = board(sheets: [turned])
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(BoardLayout.self, from: data)
        #expect(back.sheets == [turned])
        #expect(back.sheets[0].rotation == 90)

        // An older board: sheets with no rotation, zones with no homeEdge.
        let old = """
        {"width":44,"depth":34,"sheets":[{"name":"Grassland #1","area":{"x":0,"y":0,"width":22,"depth":17}}],
         "zones":[{"side":"A","area":{"x":0,"y":0,"width":6,"depth":34}},{"side":"B","area":{"x":38,"y":0,"width":6,"depth":34}}],
         "features":[],"openTable":"Mat"}
        """
        let loaded = try JSONDecoder().decode(BoardLayout.self, from: Data(old.utf8))
        #expect(loaded.sheets[0].rotation == nil)
        #expect(loaded.zones[0].homeEdge == nil)
        #expect(BoardRules.homeEdge(of: loaded.zones[1], width: 44, depth: 34) == .east)
        // Unturned sheets re-encode with no rotation key.
        let again = String(decoding: try JSONEncoder().encode(loaded), as: UTF8.self)
        #expect(!again.contains("rotation"))
    }

    @Test("An older .mechboard with sheets imports; a turned one keeps its turn")
    func fileRoundTrip() throws {
        let old = """
        {"schemaVersion":1,"width":44,"depth":34,"sheets":[{"name":"Grassland #1","area":{"x":0,"y":0,"width":22,"depth":17}}],"zones":[],"features":[],"openTable":""}
        """
        let imported = try BoardFile.importBoard(from: Data(old.utf8), existingNames: [])
        #expect(imported.board.sheets.count == 1)
        #expect(imported.board.sheets[0].rotation == nil)

        var editor = BoardEditor(board: imported.board)
        editor.rotateSheet(0)
        let data = try BoardFile.export(editor.board)
        let again = try BoardFile.importBoard(from: data, existingNames: [])
        #expect(again.board.sheets[0].rotation == 90)
        #expect(again.board.sheets[0].area.width == 17)
    }
}

@Suite("Board follow-ups: objective tokens")
struct BoardTokenTests {
    private func setup(objective: ObjectiveId?, sides: Int = 2) -> PlaySetup {
        var setup = PlaySetup.pickup()
        setup.objectiveId = objective
        return setup
    }

    @Test("The plan follows the setup's objective")
    func plan() {
        #expect(BoardTokens.plan(for: setup(objective: nil)).isEmpty)
        #expect(BoardTokens.plan(for: setup(objective: .destroyTheEnemy)).isEmpty)
        let raid = BoardTokens.plan(for: setup(objective: .raid))
        #expect(raid.map(\.side) == ["A", "B"])
        #expect(raid.allSatisfy { $0.objective == .raid && $0.count == 3 })
        let hold = BoardTokens.plan(for: setup(objective: .holdTheFort))
        #expect(hold.allSatisfy { $0.objective == .holdTheFort && $0.count == 2 })
        #expect(hold[0].label(2) == "Hold 2")
        #expect(raid[0].minimumFromEdge == 21 && hold[0].minimumFromEdge == 12)
    }

    @Test("Mixed objectives: Raid for every side, Hold the Fort only for the side that plays it")
    func mixed() {
        var mixed = PlaySetup.pickup()
        mixed.setObjective(.raid, for: mixed.sides[0].id)
        mixed.setObjective(.holdTheFort, for: mixed.sides[1].id)
        let plan = BoardTokens.plan(for: mixed)
        #expect(plan.filter { $0.objective == .raid }.map(\.side) == ["A", "B"])
        #expect(plan.filter { $0.objective == .holdTheFort }.map(\.side) == ["B"])
    }

    @Test("Adding tokens fills the plan in order, then falls back to generic numbered tokens")
    func slots() {
        let plan = [BoardTokens.Spec(side: "A", objective: .holdTheFort, count: 2), .init(side: "B", objective: .holdTheFort, count: 2)]
        var editor = BoardEditor(board: board())
        var names: [String] = []
        var sides: [String] = []
        for _ in 0..<5 {
            let slot = BoardTokens.nextSlot(in: editor.board, plan: plan)
            editor.addToken(side: slot.side, name: slot.name, centredAt: 10, 10)
            names.append(slot.name)
            sides.append(slot.side)
        }
        #expect(names == ["Hold 1", "Hold 2", "Hold 1", "Hold 2", "Token 5"])
        #expect(sides == ["A", "A", "B", "B", "A"])
        #expect(BoardTokens.counterText(editor.board, plan: plan) == "Hold tokens: A 2 of 2, B 2 of 2")
        // Deleting one frees its slot.
        let first = editor.board.features[0].id!
        editor.delete(first)
        #expect(BoardTokens.nextSlot(in: editor.board, plan: plan).name == "Hold 1")
        #expect(BoardTokens.counterText(editor.board, plan: []) == nil)
    }

    @Test("Generic tokens number themselves when there is no objective")
    func generic() {
        var editor = BoardEditor(board: board())
        for _ in 0..<3 {
            let slot = BoardTokens.nextSlot(in: editor.board, plan: [])
            editor.addToken(side: slot.side, name: slot.name, centredAt: 5, 5)
        }
        #expect(editor.board.features.compactMap(\.name) == ["Token 1", "Token 2", "Token 3"])
        #expect(editor.board.features.allSatisfy { $0.kind == .objectiveToken && $0.side == "A" })
        #expect(editor.board.terrain.isEmpty)
        #expect(BoardRules.terrainChoices(editor.board.features) == 0)
    }

    @Test("A token moves, changes owner and deletes as undoable steps")
    func undoable() {
        var editor = BoardEditor(board: board())
        let id = editor.addToken(side: "A", name: "Token 1", centredAt: 10, 10)
        let startX = editor.feature(id)!.area.midX
        editor.nudge(id, dx: 3, dy: 0)
        editor.setSide(id, "C")
        #expect(editor.feature(id)?.side == "C")
        #expect(editor.feature(id)?.area.midX == startX + 3)
        editor.delete(id)
        #expect(editor.board.features.isEmpty)
        _ = editor.undo(); _ = editor.undo(); _ = editor.undo()
        #expect(editor.feature(id)?.side == "A")
        #expect(editor.feature(id)?.area.midX == startX)
        _ = editor.undo()
        #expect(editor.feature(id) == nil)
    }

    @Test("Hints: too near the side's edge or its other tokens (p. 7), per the plan")
    func hints() {
        let plan = [BoardTokens.Spec(side: "A", objective: .raid, count: 3)]
        var editor = BoardEditor(board: board(width: 72, depth: 48))
        let zones = editor.board.zones(sideCount: 2)
        let near = editor.addToken(side: "A", name: "Raid 1", centredAt: 10, 20)
        let far = editor.addToken(side: "A", name: "Raid 2", centredAt: 30, 20)
        let close = editor.addToken(side: "A", name: "Raid 3", centredAt: 40, 20)
        let w1 = BoardTokens.warnings(for: editor.feature(near)!, in: editor.board, plan: plan, zones: zones)
        #expect(w1.count == 1 && w1[0].contains("21"))
        #expect(BoardTokens.warnings(for: editor.feature(far)!, in: editor.board, plan: plan, zones: zones).count == 1)   // 10″ from Raid 3
        let w3 = BoardTokens.warnings(for: editor.feature(close)!, in: editor.board, plan: plan, zones: zones)
        #expect(w3.count == 1 && w3[0].contains("Raid 2"))
        editor.nudge(close, dx: 20, dy: 0)
        #expect(BoardTokens.warnings(for: editor.feature(close)!, in: editor.board, plan: plan, zones: zones).isEmpty)
        // A generic token, or no plan, has nothing to warn about.
        #expect(BoardTokens.warnings(for: editor.feature(near)!, in: editor.board, plan: [], zones: zones).isEmpty)
    }

    @Test("The badge shows the token's number, and speech names its owner")
    func words() {
        let token = BoardLayout.Feature(kind: .objectiveToken, area: .init(x: 10, y: 10, width: 1.5, depth: 1.5), name: "Raid 2", side: "B")
        #expect(BoardTokens.badge(token) == "2")
        #expect(BoardTokens.badge(.init(kind: .objectiveToken, area: token.area, side: "C")) == "C")
        #expect(BoardTokens.spoken(token).hasPrefix("Raid 2, objective token for Side B, centre 10.8 inches"))
        #expect(TerrainPaletteItem.objectiveToken.kind == .objectiveToken)
    }

    @Test("Tokens round-trip, and a board saved before tokens were placeable still loads")
    func codable() throws {
        var editor = BoardEditor(board: board())
        editor.addToken(side: "B", name: "Hold 1", centredAt: 30, 12)
        let back = try JSONDecoder().decode(BoardLayout.self, from: JSONEncoder().encode(editor.board))
        #expect(back.features.first?.kind == .objectiveToken)
        #expect(back.features.first?.side == "B")
        #expect(back.features.first?.name == "Hold 1")
        let old = #"{"width":48,"depth":48,"features":[{"kind":"hill","area":{"x":1,"y":1,"width":5,"depth":5}}]}"#
        let loaded = try JSONDecoder().decode(BoardLayout.self, from: Data(old.utf8))
        #expect(loaded.features.count == 1)
        #expect(loaded.sheets.isEmpty)
    }
}
