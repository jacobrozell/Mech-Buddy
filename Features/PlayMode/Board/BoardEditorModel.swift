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
    private let onChange: (BoardLayout) -> Void

    init(board: BoardLayout, sides: [MatchSide], palette: TerrainPaletteFile, onChange: @escaping (BoardLayout) -> Void) {
        editor = BoardEditor(board: board)
        self.sides = sides
        self.palette = palette
        self.onChange = onChange
    }

    var board: BoardLayout { editor.board }
    var sideCount: Int { max(sides.count, 2) }
    var selected: BoardLayout.Feature? { selection.flatMap { editor.feature($0) } }
    var selectedIndex: Int? { selection.flatMap { editor.index(of: $0) } }

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
        let candidates = palette.items.filter { $0.kind == feature.kind }
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
        selection = editor.add(item, centredAt: p.x, p.y, snap: snap)
        commit()
        announce("\(item.title) added")
    }

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
        selection = editor.duplicate(id)
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

    func setZoneDepth(_ inches: Double) {
        editor.setZoneDepth(inches, sideCount: sideCount)
        commit()
    }

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
