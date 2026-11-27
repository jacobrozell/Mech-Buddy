import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

// PM12: the terrain board model, rules helpers, geometry and editor (PlayModeSpec § 9.10).

private final class BoardBundleToken {}

@Suite("PM12 board model")
struct BoardModelTests {
    private var bundle: Bundle { Bundle(for: BoardBundleToken.self) }

    /// Every mission pack's raw `layout` JSON object.
    private func missionLayouts() throws -> [(id: String, json: [String: Any])] {
        let catalog = BundleContentCatalogRepository(bundle: bundle)
        var result: [(String, [String: Any])] = []
        for item in try catalog.scenarios().scenarios where !item.gated {
            guard let file = item.bundle else { continue }
            let name = file.hasSuffix(".json") ? String(file.dropLast(5)) : file
            let url = try #require(
                bundle.url(forResource: name, withExtension: "json", subdirectory: "Content/AlphaStrike")
                    ?? bundle.url(forResource: name, withExtension: "json")
            )
            let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            if let layout = object["layout"] as? [String: Any] { result.append((item.id, layout)) }
        }
        return result
    }

    @Test("Every mission layout decodes as a BoardLayout and encodes back to the same JSON")
    func missionsRoundTrip() throws {
        let layouts = try missionLayouts()
        #expect(layouts.count >= 6)
        for (id, json) in layouts {
            let data = try JSONSerialization.data(withJSONObject: json)
            let board = try JSONDecoder().decode(BoardLayout.self, from: data)
            #expect(board.droppedPieceCount == 0, "\(id)")
            let again = try JSONSerialization.jsonObject(with: JSONEncoder().encode(board)) as? NSDictionary
            #expect(again == (json as NSDictionary), "\(id) changed on re-encode")
        }
    }

    @Test("A board built from the mission DTO equals the one decoded from its JSON")
    func dtoConversion() throws {
        for (id, json) in try missionLayouts() {
            let data = try JSONSerialization.data(withJSONObject: json)
            let dto = try JSONDecoder().decode(MissionLayoutDTO.self, from: data)
            let board = try JSONDecoder().decode(BoardLayout.self, from: data)
            #expect(BoardLayout(dto) == board, "\(id)")
        }
    }

    @Test("New fields round-trip")
    func newFieldsRoundTrip() throws {
        let id = UUID()
        var board = BoardLayout(
            schemaVersion: 1, id: UUID(), name: "Ridge", createdAt: Date(timeIntervalSince1970: 1000),
            updatedAt: Date(timeIntervalSince1970: 2000), isStarter: false, width: 48, depth: 48,
            sheets: [.init(name: "Grassland #2", area: .init(x: 0, y: 0, width: 22, depth: 17), rotation: 90)],
            zones: BoardZones.generate(width: 48, depth: 48, sideCount: 2),
            zonesBySideCount: [3: BoardZones.generate(width: 48, depth: 48, sideCount: 3)],
            features: [
                .init(id: id, kind: .building, area: .init(x: 5, y: 6, width: 4.25, depth: 3), name: "Depot", shape: .rect,
                      rotation: 45, level: 3, buildingClass: .heavy, cf: 45),
                .init(kind: .objectiveToken, area: .init(x: 20, y: 20, width: 1, depth: 1), side: "C")
            ],
            openTable: "Any table"
        )
        board.features[1].id = UUID()
        let data = try JSONEncoder().encode(board)
        let back = try JSONDecoder().decode(BoardLayout.self, from: data)
        #expect(back == board)
        #expect(back.zonesBySideCount?[3]?.count == 3)
        // The sets are JSON-object keyed, not an alternating array.
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["zonesBySideCount"] is [String: Any])
    }

    @Test("An unknown piece kind fails soft: the rest of the board loads")
    func unknownKindFailsSoft() throws {
        let json = """
        {"width":36,"depth":22,"sheets":[],"zones":[],"openTable":"",
         "features":[{"kind":"woods","area":{"x":1,"y":1,"width":5,"depth":5}},
                     {"kind":"lava","area":{"x":8,"y":1,"width":5,"depth":5}},
                     {"kind":"hill","area":{"x":9,"y":9,"width":5,"depth":5}, "futureField": 3}]}
        """
        let board = try JSONDecoder().decode(BoardLayout.self, from: Data(json.utf8))
        #expect(board.features.map(\.kind) == [.woods, .hill])
        #expect(board.droppedPieceCount == 1)
    }

    @Test("Missing optional fields decode with defaults; the table itself is required")
    func decodesMinimal() throws {
        let board = try JSONDecoder().decode(BoardLayout.self, from: Data(#"{"width":48,"depth":36}"#.utf8))
        #expect(board.features.isEmpty && board.zones.isEmpty && board.sheets.isEmpty)
        #expect(board.zones(sideCount: 2).count == 2)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(BoardLayout.self, from: Data("{}".utf8)) }
    }

    @Test("Clamp: table within 12–96″, pieces kept on the table and no bigger than it, levels limited")
    func clamps() {
        let wild = BoardLayout(
            width: 200, depth: 4,
            zones: [.init(side: "A", area: .init(x: -5, y: -5, width: 500, depth: 500))],
            features: [
                .init(kind: .woods, area: .init(x: 90, y: -4, width: 40, depth: 40)),
                .init(kind: .hill, area: .init(x: 2, y: 2, width: 5, depth: 5), level: 9),
                .init(kind: .building, area: .init(x: 2, y: 2, width: 2, depth: 2), level: 40)
            ]
        )
        let fit = wild.clampedToTable()
        #expect(fit.width == 96 && fit.depth == 12)
        let woods = fit.features[0].area
        #expect(woods.width == 40 && woods.depth == 12 && woods.x == 56 && woods.y == 0)
        #expect(fit.features[1].level == 4)
        #expect(fit.features[2].level == 12)
        #expect(fit.zones[0].area.maxX <= 96 && fit.zones[0].area.x >= 0)
    }

    @Test("A setup saved before boards decodes; a board travels with the setup as its own copy")
    func setupKeepsItsBoard() throws {
        var setup = PlaySetup.pickup()
        let old = try JSONEncoder().encode(setup)
        #expect(try JSONDecoder().decode(PlaySetup.self, from: old).battlefield.board == nil)

        var board = BoardLayout(name: "Mine", width: 48, depth: 48, zones: BoardZones.generate(width: 48, depth: 48, sideCount: 2))
        board.features = [.init(id: UUID(), kind: .woods, area: .init(x: 10, y: 10, width: 5, depth: 5))]
        setup.battlefield.board = board
        #expect(setup.battlefield.width == 48 && setup.battlefield.depth == 48)
        let copy = try JSONDecoder().decode(PlaySetup.self, from: JSONEncoder().encode(setup))
        // Editing "the preset" afterwards doesn't touch the game's copy.
        board.features.removeAll()
        #expect(copy.battlefield.board?.features.count == 1)
        #expect(copy.battlefield.summary.hasPrefix("Mine"))
    }

    @Test("PlayLayout.board: the built board with zones for the game's sides")
    func playLayoutBoard() {
        var battlefield = Battlefield(kind: .mat, matWidth: 48, matDepth: 48)
        let plain = PlayLayout.board(for: battlefield, sides: PlaySetup.pickup().sides)
        #expect(plain.features.isEmpty && plain.zones.count == 2)
        battlefield.board = BoardLayout(width: 48, depth: 48, features: [.init(kind: .hill, area: .init(x: 20, y: 20, width: 6, depth: 6))])
        var four = PlaySetup.pickup()
        four.setPlayerCounts([1, 1, 1, 1])
        let board = PlayLayout.board(for: battlefield, sides: four.sides)
        #expect(board.features.count == 1)
        #expect(board.zones.map(\.side) == ["A", "B", "C", "D"])
    }
}

@Suite("PM12 board rules")
struct BoardRulesTests {
    private func feature(_ kind: BoardLayout.FeatureKind, _ w: Double, _ d: Double, x: Double = 0, y: Double = 0,
                         shape: BoardLayout.Shape? = nil, rotation: Double? = nil, level: Double? = nil) -> BoardLayout.Feature {
        .init(kind: kind, area: .init(x: x, y: y, width: w, depth: d), shape: shape, rotation: rotation, level: level)
    }

    @Test("Terrain choices: 2 trees = 1, large templates = 2, 2 small buildings = 1")
    func choices() {
        #expect(BoardRules.terrainChoices([feature(.tree, 2, 2)]) == 1)
        #expect(BoardRules.terrainChoices([feature(.tree, 2, 2), feature(.tree, 2, 2)]) == 1)
        #expect(BoardRules.terrainChoices(Array(repeating: feature(.tree, 2, 2), count: 3)) == 2)
        #expect(BoardRules.terrainChoices([feature(.woods, 5, 5)]) == 1)
        #expect(BoardRules.terrainChoices([feature(.woods, 9, 3)]) == 1)
        #expect(BoardRules.terrainChoices([feature(.woods, 8, 8)]) == 2)
        #expect(BoardRules.terrainChoices([feature(.hill, 7, 7), feature(.water, 12, 4)]) == 4)
        #expect(BoardRules.terrainChoices([feature(.building, 1.6, 1.6), feature(.building, 1.6, 1.6)]) == 1)
        #expect(BoardRules.terrainChoices([feature(.building, 1.6, 1.6), feature(.building, 4.25, 3)]) == 2)
        #expect(BoardRules.terrainChoices([feature(.rough, 2, 2), feature(.rubble, 2, 2), feature(.rough, 4, 4)]) == 2)
        #expect(BoardRules.terrainChoices([feature(.wall, 6, 0.5)]) == 1)
        #expect(BoardRules.terrainChoices([feature(.objectiveToken, 1, 1)]) == 0)
    }

    @Test("Choice budget: 8 a side for two sides, 6 for three or four [HOUSE]")
    func budget() {
        #expect(BoardRules.choiceBudget(sideCount: 2) == 16)
        #expect(BoardRules.choiceBudget(sideCount: 3) == 18)
        #expect(BoardRules.choiceBudget(sideCount: 4) == 24)
        let pieces = Array(repeating: feature(.woods, 5, 5), count: 14)
        #expect(BoardRules.choiceSummary(pieces, sideCount: 2) == "14 of 16 choices placed")
    }

    @Test("A hill inside another hill gets the next level")
    func hillStacking() {
        let features = [
            feature(.hill, 10, 10, x: 10, y: 10, level: 1),
            feature(.hill, 4, 4, x: 13, y: 13, level: 1),
            feature(.hill, 4, 4, x: 30, y: 30, level: 1),
            feature(.woods, 4, 4, x: 13, y: 13)
        ]
        #expect(BoardRules.hillLevel(at: 0, in: features) == 1)
        #expect(BoardRules.hillLevel(at: 1, in: features) == 2)
        #expect(BoardRules.hillLevel(at: 2, in: features) == 1)
        #expect(BoardRules.hillLevel(at: 3, in: features) == nil)
    }

    @Test("Zone generation for 2, 3 and 4 sides on 36 × 48, 48 × 48 and 48 × 72")
    func zones() throws {
        for (w, d) in [(36.0, 48.0), (48.0, 48.0), (48.0, 72.0)] {
            let two = BoardZones.generate(width: w, depth: d, sideCount: 2)
            #expect(two.map(\.side) == ["A", "B"])
            #expect(two[0].area == .init(x: 0, y: 0, width: 6, depth: d))
            #expect(two[1].area == .init(x: w - 6, y: 0, width: 6, depth: d))
            let three = BoardZones.generate(width: w, depth: d, sideCount: 3)
            #expect(three.map(\.side) == ["A", "B", "C"])
            // A, B: the middle 3/8 of the west and east edges. C: the middle 3/8 of the south edge.
            #expect(three[0].area == .init(x: 0, y: d * 5 / 16, width: 6, depth: d * 3 / 8))
            #expect(three[2].area == .init(x: w * 5 / 16, y: d - 6, width: w * 3 / 8, depth: 6))
            let four = BoardZones.generate(width: w, depth: d, sideCount: 4)
            #expect(four.map(\.side) == ["A", "B", "C", "D"])
            #expect(four[3].area == .init(x: w * 5 / 16, y: 0, width: w * 3 / 8, depth: 6))
            for zone in four {
                #expect(zone.area.x >= 0 && zone.area.maxX <= w && zone.area.y >= 0 && zone.area.maxY <= d)
            }
        }
        // 18″ on a 48″ edge (§ 6.4).
        #expect(BoardZones.generate(width: 48, depth: 48, sideCount: 4)[2].area.width == 18)
    }

    @Test("A board stores a zone set per side count; unset counts are generated")
    func zoneSets() {
        var board = BoardLayout(width: 48, depth: 48)
        #expect(board.zones(sideCount: 4).count == 4)
        let custom = [BoardLayout.Zone(side: "A", area: .init(x: 0, y: 0, width: 9, depth: 48))]
        board.zonesBySideCount = [2: custom]
        #expect(board.zones(sideCount: 2) == custom)
        #expect(board.zones(sideCount: 3).count == 3)
    }

    @Test("Snap to 1″ and ½″, and not at all")
    func snapping() {
        #expect(BoardRules.snap(3.4, to: .whole) == 3)
        #expect(BoardRules.snap(3.6, to: .whole) == 4)
        #expect(BoardRules.snap(3.26, to: .half) == 3.5)
        #expect(BoardRules.snap(3.2, to: .half) == 3)
        #expect(BoardRules.snap(3.37, to: .off) == 3.37)
    }

    @Test("Rotation snaps to 15° with snap on and wraps; free with snap off")
    func rotationSnap() {
        #expect(BoardRules.snapRotation(22, snapOn: true) == 15)
        #expect(BoardRules.snapRotation(23, snapOn: true) == 30)
        #expect(BoardRules.snapRotation(-10, snapOn: true) == 345)
        #expect(BoardRules.snapRotation(359, snapOn: true) == 0)
        #expect(BoardRules.snapRotation(367.3, snapOn: false) > 7.29 && BoardRules.snapRotation(367.3, snapOn: false) < 7.31)
    }

    @Test("Hit-testing follows rotation and the ellipse outline")
    func hitTesting() {
        // A 10 × 2 strip turned 90° is a 2 × 10 strip standing on its centre (10, 10).
        let strip = feature(.woods, 10, 2, x: 5, y: 9, shape: .rect, rotation: 90)
        #expect(BoardRules.contains(strip, point: .init(x: 10, y: 14)))
        #expect(!BoardRules.contains(strip, point: .init(x: 14, y: 10)))
        // An ellipse 10 × 4 at the origin: the corner of its box is outside, the axis ends inside.
        let ellipse = feature(.hill, 10, 4, x: 0, y: 0, shape: .ellipse)
        #expect(BoardRules.contains(ellipse, point: .init(x: 9.5, y: 2)))
        #expect(!BoardRules.contains(ellipse, point: .init(x: 9.5, y: 0.2)))
        // Rotated 90° it is 4 wide and 10 tall about (5, 2).
        let turned = feature(.hill, 10, 4, x: 0, y: 0, shape: .ellipse, rotation: 90)
        #expect(BoardRules.contains(turned, point: .init(x: 5, y: 6.5)))
        #expect(!BoardRules.contains(turned, point: .init(x: 9.5, y: 2)))
        // The later piece is on top.
        #expect(BoardRules.hit([ellipse, feature(.woods, 4, 4, x: 4, y: 0, shape: .rect)], at: .init(x: 5, y: 2)) == 1)
    }

    @Test("Inside-zone warning names the side; outside is clear")
    func zoneWarning() {
        let zones = BoardZones.generate(width: 48, depth: 48, sideCount: 2)
        #expect(BoardRules.zoneWarnings(for: feature(.woods, 5, 5, x: 4, y: 20), zones: zones) == ["A"])
        #expect(BoardRules.zoneWarnings(for: feature(.woods, 5, 5, x: 20, y: 20), zones: zones).isEmpty)
        #expect(BoardRules.zoneWarnings(for: feature(.woods, 5, 5, x: 40, y: 20), zones: zones) == ["B"])
        // Touching the zone's edge isn't inside it.
        #expect(BoardRules.zoneWarnings(for: feature(.woods, 5, 5, x: 6, y: 20), zones: zones).isEmpty)
        // A token isn't terrain.
        #expect(BoardRules.zoneWarnings(for: feature(.objectiveToken, 1, 1, x: 2, y: 20), zones: zones).isEmpty)
    }

    @Test("Distance readout and nearby pieces")
    func distances() {
        #expect(BoardRules.distance(.init(x: 0, y: 0), .init(x: 3, y: 4)) == 5)
        #expect(BoardRules.inches(14.5) == "14.5″")
        #expect(BoardRules.inches(14.2) == "14″")
        #expect(BoardRules.inches(14.3) == "14.5″")
        let features = [feature(.woods, 5, 5, x: 0, y: 0), feature(.hill, 5, 5, x: 8, y: 0), feature(.hill, 5, 5, x: 30, y: 0)]
        #expect(BoardRules.gap(features[0], features[1]) == 3)
        let near = BoardRules.neighbours(of: 0, in: features)
        #expect(near.count == 1 && near[0].index == 1 && near[0].gap == 3)
    }

    @Test("p. 8 bands for two sides")
    func bands() {
        #expect(BoardRules.band(of: feature(.woods, 4, 4, x: 22, y: 5), tableWidth: 48) == .nearCentre)
        #expect(BoardRules.band(of: feature(.woods, 4, 4, x: 10, y: 5), tableWidth: 48) == .half(side: "A"))
        #expect(BoardRules.band(of: feature(.woods, 4, 4, x: 38, y: 5), tableWidth: 48) == .half(side: "B"))
        #expect(BoardRules.band(of: feature(.woods, 4, 4, x: 0, y: 5), tableWidth: 72) == .beyond)
    }

    @Test("Spoken summary and piece description")
    func spoken() {
        var board = BoardLayout(width: 48, depth: 48, features: [
            feature(.woods, 5, 5, x: 11.5, y: 6.5),
            feature(.woods, 5, 5, x: 30, y: 30),
            feature(.hill, 10, 10, x: 20, y: 20, level: 1),
            feature(.hill, 4, 4, x: 23, y: 23, level: 1),
            feature(.water, 5, 5, x: 5, y: 40)
        ])
        board = board.assigningIDs()
        let text = BoardRules.summary(board, sideCount: 4)
        #expect(text == "48 by 48 inch table. 2 woods, 1 hill level 1, 1 hill level 2, 1 water. Zones for 4 sides.")
        let woods = BoardRules.spoken(board.features[0], in: board, sideCount: 2)
        #expect(woods == "Woods, 5 by 5 inches, centre 14 inches from the left, 9 from the top.")
        var inZone = board.features[4]
        inZone.area.x = 2
        board.features[4] = inZone
        #expect(BoardRules.spoken(inZone, in: board, sideCount: 2).hasSuffix("Inside Side A’s zone."))
    }
}

@Suite("PM12 board editor")
struct BoardEditorTests {
    private func palette() throws -> TerrainPaletteFile {
        try BundleContentCatalogRepository(bundle: Bundle(for: BoardBundleToken.self)).terrainPalette()
    }

    private func editor() -> BoardEditor {
        BoardEditor(board: BoardLayout(width: 48, depth: 48, zones: BoardZones.generate(width: 48, depth: 48, sideCount: 2)))
    }

    @Test("Palette copy covers every QSR piece with pages and rules text")
    func paletteCopy() throws {
        let file = try palette()
        for kind in BoardLayout.FeatureKind.allCases where kind.isTerrain {
            #expect(file.items.contains { $0.kind == kind }, "\(kind)")
        }
        for item in file.items {
            #expect(!item.movement.isEmpty && !item.lineOfSight.isEmpty && !item.attack.isEmpty, "\(item.id)")
            #expect(item.pages.hasPrefix("p"), "\(item.id)")
            #expect(item.width > 0 && item.depth > 0)
        }
        let ids = file.items.map(\.id)
        #expect(Set(ids).count == ids.count)
        // Sizes from § 9.3.
        #expect(file.item("tree")?.width == 2)
        #expect(file.item("woods")?.width == 5)
        #expect(file.item("woods-strip")?.width == 9 && file.item("woods-strip")?.depth == 3)
        #expect(file.item("building-small")?.buildingClass == .medium)
        #expect(file.item("building-large")?.buildingClass == .heavy)
        #expect(file.item("building-large")?.width == 4.25)
        #expect(file.item("wall")?.depth == 0.5)
        #expect(file.notes.contains { $0.contains("Light and heavy woods") })
        #expect(file.notes.contains { $0.contains("D27") })
    }

    @Test("Add, move, rotate, resize, delete and undo")
    func editingAndUndo() throws {
        let woods = try #require(try palette().item("woods"))
        var editor = editor()
        let id = editor.add(woods, centredAt: 24, 24)
        #expect(editor.board.features.count == 1)
        #expect(editor.board.features[0].area == .init(x: 22, y: 22, width: 5, depth: 5))

        editor.place(id, x: 10.4, y: 10.6, snap: .whole)
        #expect(editor.feature(id)?.area.x == 10 && editor.feature(id)?.area.y == 11)
        editor.nudge(id, dx: 1, dy: 0)
        #expect(editor.feature(id)?.area.x == 11)
        editor.rotate(id, by: 15, snapOn: true)
        editor.rotate(id, by: 15, snapOn: true)
        #expect(editor.feature(id)?.degrees == 30)
        editor.resize(id, width: 6, depth: 4)
        #expect(editor.feature(id)?.area.width == 6)

        editor.delete(id)
        #expect(editor.board.features.isEmpty)
        let undone = editor.undo()
        #expect(undone)
        #expect(editor.feature(id)?.area.width == 6)
        // Back through resize, two rotations and the nudge: the piece is where `place` left it (a drag is its own step).
        for _ in 0..<4 { let ok = editor.undo(); #expect(ok) }
        #expect(editor.feature(id)?.area == .init(x: 10, y: 11, width: 5, depth: 5))
        let redone = editor.redo()
        #expect(redone)
        // Undo to empty, then a new change clears redo.
        while editor.undo() {}
        #expect(editor.board.features.isEmpty)
        #expect(editor.canRedo)
        editor.add(woods, centredAt: 5, 5)
        #expect(!editor.canRedo)
    }

    @Test("A drag is one undo step; a drag that moves nothing leaves no step")
    func dragCheckpoint() throws {
        let hill = try #require(try palette().item("hill"))
        var editor = editor()
        let id = editor.add(hill, centredAt: 24, 24)
        editor.checkpoint()
        for step in 1...5 { editor.place(id, x: 10 + Double(step), y: 10, snap: .whole) }
        editor.discardEmptyCheckpoint()
        #expect(editor.feature(id)?.area.x == 15)
        editor.undo()
        #expect(editor.feature(id)?.area.x == 22)
        editor.checkpoint()
        editor.discardEmptyCheckpoint()
        let depth = editor.canUndo
        editor.undo()
        #expect(editor.board.features.isEmpty)
        #expect(depth)
    }

    @Test("Pieces stay on the table; duplicate puts a copy on top; levels clamp")
    func bounds() throws {
        let hill = try #require(try palette().item("hill"))
        var editor = editor()
        let id = editor.add(hill, centredAt: 0, 0)
        #expect(editor.feature(id)?.area.x == 0 && editor.feature(id)?.area.y == 0)
        editor.place(id, x: 100, y: 100, snap: .whole)
        #expect(editor.feature(id)?.area.maxX == 48 && editor.feature(id)?.area.maxY == 48)
        editor.setLevel(id, 9)
        #expect(editor.feature(id)?.level == 4)
        let made = editor.duplicate(id)
        let copy = try #require(made)
        #expect(copy != id && editor.board.features.last?.id == copy)
        editor.setName(id, String(repeating: "x", count: 60))
        #expect(editor.feature(id)?.name?.count == 40)
        editor.setTable(width: 24, depth: 24)
        #expect(editor.board.features.allSatisfy { $0.area.maxX <= 24 && $0.area.maxY <= 24 })
    }

    @Test("VoiceOver actions move a piece by 1″ and a custom step")
    func accessibilityMoves() throws {
        let woods = try #require(try palette().item("woods"))
        var editor = editor()
        let id = editor.add(woods, centredAt: 24, 24)
        let start = try #require(editor.feature(id)).area
        editor.nudge(id, dx: 1, dy: 0)
        editor.nudge(id, dx: 0, dy: -1)
        #expect(editor.feature(id)?.area.x == start.x + 1 && editor.feature(id)?.area.y == start.y - 1)
        editor.nudge(id, dx: -0.5, dy: 0)
        #expect(editor.feature(id)?.area.x == start.x + 0.5)
    }

    @Test("Building class sets the default CF; starter board decodes with ids assigned")
    func buildings() throws {
        let large = try #require(try palette().item("building-large"))
        var editor = editor()
        let id = editor.add(large, centredAt: 24, 24)
        #expect(editor.feature(id)?.cf == 45)
        editor.setBuildingClass(id, .hardened)
        #expect(editor.feature(id)?.cf == 60)
        #expect(editor.board.features.allSatisfy { $0.id != nil })
    }
}
