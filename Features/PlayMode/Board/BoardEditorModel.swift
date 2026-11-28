import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// State behind the board builder (PlayModeSpec § 9). The pure editing and undo live in `BoardEditor`;
/// this adds selection, snap, the measure tool and a write-through to the setup.
@MainActor
@Observable
final class BoardEditorModel {
    private(set) var editor: BoardEditor
    var selection: UUID?
    /// The selected mapsheet, by index (sheets have no ids and never reorder). Only one of piece and sheet is selected.
    var sheetSelection: Int?
    var snap: BoardSnap = .whole
    var showBands = false
    var isMeasuring = false
    var measureA: BoardLayout.Point?
    var measureB: BoardLayout.Point?
    /// Shown while a gesture runs: "5 × 5″", "30°".
    var hud: String?
    /// The canvas view, kept here so a palette drop can find its place on the table.
    var zoom: CGFloat = 1
    var pan: CGSize = .zero
    let palette: TerrainPaletteFile
    let sides: [MatchSide]
    /// Tokens the game's objective calls for (§ 7.1); empty means generic numbered tokens.
    let tokenPlan: [BoardTokens.Spec]
    private let onChange: (BoardLayout) -> Void

    init(board: BoardLayout, sides: [MatchSide], palette: TerrainPaletteFile, tokenPlan: [BoardTokens.Spec] = [], onChange: @escaping (BoardLayout) -> Void) {
        editor = BoardEditor(board: board)
        self.sides = sides
        self.palette = palette
        self.tokenPlan = tokenPlan
        self.onChange = onChange
    }

    var board: BoardLayout { editor.board }
    var sideCount: Int { max(sides.count, 2) }
    var selected: BoardLayout.Feature? { selection.flatMap { editor.feature($0) } }
    var selectedIndex: Int? { selection.flatMap { editor.index(of: $0) } }
    var hasSelection: Bool { selection != nil || sheetSelection != nil }

    /// The palette's terrain plus the objective token tile.
    var paletteItems: [TerrainPaletteItem] { palette.items + [.objectiveToken] }

    func select(_ id: UUID?) {
        selection = id
        if id != nil { sheetSelection = nil }
    }

    func selectSheet(_ index: Int?) {
        sheetSelection = index
        if index != nil { selection = nil }
    }

    func clearSelection() {
        selection = nil
        sheetSelection = nil
    }

    /// What VoiceOver says for one piece (tokens read as tokens).
    func spoken(_ feature: BoardLayout.Feature) -> String {
        feature.kind == .objectiveToken ? BoardTokens.spoken(feature) : BoardRules.spoken(feature, in: board, sideCount: sideCount)
    }

    /// The zones for this game: the board's own for the game's sides, or generated from § 6.4.
    var zones: [BoardLayout.Zone] {
        PlayLayout.board(for: Battlefield(kind: .mat, matWidth: board.width, matDepth: board.depth, board: board), sides: sides).zones
    }

    /// Sides whose zones a piece overlaps, by piece id.
    var warnings: [UUID: [String]] {
        var result: [UUID: [String]] = [:]
        let set = zones
        for feature in board.features {
            guard let id = feature.id else { continue }
            let hit = BoardRules.zoneWarnings(for: feature, zones: set)
            if !hit.isEmpty { result[id] = hit }
        }
        return result
    }

    var counterText: String { BoardRules.choiceSummary(board.features, sideCount: sideCount) }
    var summary: String { BoardRules.summary(board, sideCount: sideCount) }
    var zoneDepth: Double { zones.first.map { min($0.area.width, $0.area.depth) } ?? BoardZones.zoneDepth }

    func paletteItem(_ feature: BoardLayout.Feature) -> TerrainPaletteItem? {
        // The closest palette piece of the same kind: used for the rules copy in the inspector.
        let candidates = paletteItems.filter { $0.kind == feature.kind }
        return candidates.min { abs($0.width * $0.depth - feature.area.width * feature.area.depth) < abs($1.width * $1.depth - feature.area.width * feature.area.depth) }
    }

    // MARK: Changes (each writes through to the setup)

    /// Writes the board to the setup. Held back while a drag runs, so the draft saves once per gesture.
    private var isDragging = false

    private func commit() {
        if !isDragging { onChange(editor.board) }
    }

    func add(_ item: TerrainPaletteItem, centredAt point: BoardLayout.Point? = nil) {
        let p = point ?? .init(x: board.width / 2, y: board.depth / 2)
        if item.kind == .objectiveToken {
            addToken(centredAt: point == nil ? nil : p)
            return
        }
        select(editor.add(item, centredAt: p.x, p.y, snap: snap))
        commit()
        announce("\(item.title) added")
    }

    // MARK: Objective tokens (§ 7.1)

    /// Adds the next token the game's objective wants (or a generic numbered one). Tapped in with no place given,
    /// each token steps 2″ along from the centre so they don't stack.
    func addToken(centredAt point: BoardLayout.Point? = nil) {
        let slot = BoardTokens.nextSlot(in: board, plan: tokenPlan)
        let existing = board.features.filter { $0.kind == .objectiveToken }.count
        let p = point ?? .init(x: board.width / 2 + Double(existing % 8) * 2 - 7, y: board.depth / 2)
        select(editor.addToken(side: slot.side, name: slot.name, centredAt: p.x, p.y, snap: snap))
        commit()
        announce("\(slot.name) added")
    }

    func setSide(_ id: UUID, _ side: String) { editor.setSide(id, side); commit() }

    /// "Raid tokens: A 2 of 3, B 0 of 3", or nil with no objective tokens to place.
    var tokenCounterText: String? { BoardTokens.counterText(board, plan: tokenPlan) }

    /// Hints for one token: too near its own edge, or too near a sibling (p. 7).
    func tokenWarnings(_ feature: BoardLayout.Feature) -> [String] {
        BoardTokens.warnings(for: feature, in: board, plan: tokenPlan, zones: zones)
    }

    /// Sides a token can belong to: the game's.
    var sideLetters: [String] { Array(["A", "B", "C", "D"].prefix(sideCount)) }

    func beginGesture() {
        editor.checkpoint()
        isDragging = true
    }

    func endGesture() {
        editor.discardEmptyCheckpoint()
        hud = nil
        isDragging = false
        commit()
    }

    func place(_ id: UUID, x: Double, y: Double) {
        editor.place(id, x: x, y: y, snap: snap)
        commit()
    }

    func nudge(_ id: UUID, dx: Double, dy: Double) {
        editor.nudge(id, dx: dx, dy: dy)
        commit()
        if let f = editor.feature(id) {
            announce("Centre \(BoardRules.plain(f.area.midX)) from the left, \(BoardRules.plain(f.area.midY)) from the top")
        }
    }

    /// The nudge step: the snap step, or 1″ with snap off.
    var step: Double { snap.step ?? 1 }

    func rotate(_ id: UUID, by degrees: Double) {
        editor.rotate(id, by: degrees, snapOn: snap != .off)
        commit()
    }

    func setRotation(_ id: UUID, _ degrees: Double) {
        guard let i = editor.index(of: id) else { return }
        let next = BoardRules.snapRotation(degrees, snapOn: snap != .off)
        editor.mutate { $0.features[i].rotation = next == 0 ? nil : next }
        hud = "\(BoardRules.plain(next))°"
        commit()
    }

    func resize(_ id: UUID, width: Double, depth: Double) {
        editor.resize(id, width: width, depth: depth)
        commit()
    }

    /// During a resize drag (a checkpoint is already taken).
    func liveResize(_ id: UUID, width: Double, depth: Double) {
        guard let i = editor.index(of: id) else { return }
        let w = min(max(BoardRules.snap(width, to: snap), 0.5), board.width)
        let d = min(max(BoardRules.snap(depth, to: snap), 0.5), board.depth)
        editor.mutate { b in
            let c = b.features[i].area.center
            b.features[i].area = .init(x: min(max(c.x - w / 2, 0), b.width - w), y: min(max(c.y - d / 2, 0), b.depth - d), width: w, depth: d)
        }
        hud = "\(BoardRules.plain(w)) × \(BoardRules.plain(d))″"
        commit()
    }

    func bigger(_ id: UUID) { scale(id, by: 1) }
    func smaller(_ id: UUID) { scale(id, by: -1) }

    private func scale(_ id: UUID, by steps: Double) {
        guard let f = editor.feature(id) else { return }
        let delta = steps * step
        resize(id, width: f.area.width + delta, depth: f.area.depth + delta)
    }

    func setLevel(_ id: UUID, _ level: Double) { editor.setLevel(id, level); commit() }
    func setName(_ id: UUID, _ name: String) { editor.setName(id, name); commit() }
    func setBuildingClass(_ id: UUID, _ value: BoardLayout.BuildingClass) { editor.setBuildingClass(id, value); commit() }

    func setPosition(_ id: UUID, x: Double? = nil, y: Double? = nil) {
        guard let f = editor.feature(id) else { return }
        editor.apply { b in
            guard let i = b.features.firstIndex(where: { $0.id == id }) else { return }
            let area = f.area
            b.features[i].area.x = min(max(x ?? area.x, 0), b.width - area.width)
            b.features[i].area.y = min(max(y ?? area.y, 0), b.depth - area.depth)
        }
        commit()
    }

    func duplicate(_ id: UUID) {
        select(editor.duplicate(id))
        commit()
        announce("Duplicated")
    }

    func delete(_ id: UUID) {
        editor.delete(id)
        if selection == id { selection = nil }
        commit()
        announce("Deleted")
    }

    func undo() {
        if editor.undo() { afterHistory() }
    }

    func redo() {
        if editor.redo() { afterHistory() }
    }

    private func afterHistory() {
        if let selection, editor.feature(selection) == nil { self.selection = nil }
        if let sheet = sheetSelection, !board.sheets.indices.contains(sheet) { sheetSelection = nil }
        commit()
    }

    var canUndo: Bool { editor.canUndo }
    var canRedo: Bool { editor.canRedo }

    /// After Save board: the copy now names the saved board it matches, so setup can tell when that board changes.
    func linkToPreset(_ stored: BoardLayout) {
        editor.mutate {
            $0.name = stored.name
            $0.presetID = stored.id
            $0.presetUpdatedAt = stored.updatedAt
        }
        commit()
    }

    func resetZones() {
        editor.resetZones()
        commit()
        announce("Zones reset")
    }

    /// The menu: every zone for this game's sides to the same depth, along each side's own home edge.
    func setZoneDepth(_ inches: Double) {
        let set = zones.map { BoardRules.resized($0, toDepth: inches, width: board.width, depth: board.depth, snap: .whole) }
        editor.setZoneSet(set, sideCount: sideCount)
        commit()
    }

    // MARK: Zone edges (§ 9.2)

    func zone(_ side: String) -> BoardLayout.Zone? { zones.first { $0.side == side } }

    func zoneDepth(of side: String) -> Double? {
        zone(side).map { BoardRules.depth(of: $0, width: board.width, depth: board.depth) }
    }

    /// During a handle drag (a checkpoint is already taken): the zone's inner edge follows the finger, snapped.
    func liveZoneDepth(_ side: String, toward point: BoardLayout.Point) {
        guard let zone = zone(side) else { return }
        let edge = BoardRules.homeEdge(of: zone, width: board.width, depth: board.depth)
        let wanted = BoardRules.depth(toward: point, edge: edge, width: board.width, depth: board.depth)
        let changed = BoardRules.resized(zone, toDepth: wanted, width: board.width, depth: board.depth, snap: snap)
        editor.liveZoneSet(zones.map { $0.side == side ? changed : $0 }, sideCount: sideCount)
        let inside = BoardRules.piecesInsideZones(board.features, zones: self.zones)
        hud = "Side \(side) zone \(BoardRules.plain(BoardRules.depth(of: changed, width: board.width, depth: board.depth)))″"
            + (inside > 0 ? " · \(inside) inside" : "")
        commit()
    }

    /// VoiceOver's adjustable action: 1″ deeper or shallower, one undoable change.
    func nudgeZoneDepth(_ side: String, by inches: Double) {
        guard let zone = zone(side) else { return }
        let now = BoardRules.depth(of: zone, width: board.width, depth: board.depth)
        let changed = BoardRules.resized(zone, toDepth: now + inches, width: board.width, depth: board.depth, snap: .off)
        editor.setZoneSet(zones.map { $0.side == side ? changed : $0 }, sideCount: sideCount)
        commit()
        let depth = BoardRules.plain(BoardRules.depth(of: changed, width: board.width, depth: board.depth))
        announce("Side \(side) zone \(depth) inches" + (BoardRules.zoneWarningText(count: BoardRules.piecesInsideZones(board.features, zones: zones)).map { ". \($0)" } ?? ""))
    }

    // MARK: Mapsheets (§ 9.2)

    var selectedSheet: BoardLayout.Sheet? {
        sheetSelection.flatMap { board.sheets.indices.contains($0) ? board.sheets[$0] : nil }
    }

    /// During a sheet drag (a checkpoint is already taken).
    func placeSheet(_ index: Int, x: Double, y: Double) {
        editor.placeSheet(index, x: x, y: y, snap: snap)
        if board.sheets.indices.contains(index) {
            let a = board.sheets[index].area
            hud = "\(BoardRules.plain(a.x))″, \(BoardRules.plain(a.y))″"
        }
        commit()
    }

    func nudgeSheet(_ index: Int, dx: Double, dy: Double) {
        editor.nudgeSheet(index, dx: dx, dy: dy)
        commit()
        if board.sheets.indices.contains(index) {
            let a = board.sheets[index].area
            announce("Top left \(BoardRules.plain(a.x)) from the left, \(BoardRules.plain(a.y)) from the top")
        }
    }

    func setSheetPosition(_ index: Int, x: Double? = nil, y: Double? = nil) {
        editor.setSheetPosition(index, x: x, y: y)
        commit()
    }

    func rotateSheet(_ index: Int) {
        editor.rotateSheet(index)
        commit()
        if board.sheets.indices.contains(index) {
            announce("Turned \(board.sheets[index].rotation ?? 0) degrees")
        }
    }

    func fitTableToSheets() {
        editor.fitTableToSheets()
        commit()
        announce("Table is \(BoardRules.plain(board.width)) by \(BoardRules.plain(board.depth)) inches")
    }

    var sheetWarning: String? { BoardRules.sheetWarningText(board) }

    /// Distance readout for the Measure tool.
    var measureText: String? {
        guard let a = measureA, let b = measureB else { return nil }
        return BoardRules.inches(BoardRules.distance(a, b))
    }

    func clearMeasure() {
        measureA = nil
        measureB = nil
    }

    func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
