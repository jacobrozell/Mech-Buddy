import Foundation

/// One piece in the terrain palette (§ 9.3): its default size and the plain-words rules copy for the inspector.
/// Decoded from `as-terrain-palette.json`.
public struct TerrainPaletteItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: BoardLayout.FeatureKind
    public var title: String
    public var shape: BoardLayout.Shape
    public var width: Double
    public var depth: Double
    /// Hill level or building height, inches.
    public var level: Double?
    public var buildingClass: BoardLayout.BuildingClass?
    /// SF Symbol drawn on the piece and on the palette button.
    public var glyph: String
    public var movement: String
    public var lineOfSight: String
    public var attack: String
    /// How many of a side's p. 8 choices the piece uses.
    public var choices: String
    public var pages: String
    public var note: String?

    /// A new piece of this kind, centred at (x, y) and clamped to the table.
    public func makeFeature(centredAt x: Double, _ y: Double, on board: BoardLayout) -> BoardLayout.Feature {
        let w = min(width, board.width)
        let d = min(depth, board.depth)
        let cx = min(max(x, w / 2), board.width - w / 2)
        let cy = min(max(y, d / 2), board.depth - d / 2)
        return BoardLayout.Feature(
            id: UUID(),
            kind: kind,
            area: .init(x: cx - w / 2, y: cy - d / 2, width: w, depth: d),
            shape: shape,
            level: level,
            buildingClass: buildingClass,
            cf: buildingClass?.defaultCF
        )
    }
}

/// The copy file's shape.
public struct TerrainPaletteFile: Codable, Sendable, Equatable {
    public var version: Int
    public var items: [TerrainPaletteItem]
    /// Notes shown under the palette (light and heavy woods, the level-change question, buildings).
    public var notes: [String]

    public func item(_ id: String) -> TerrainPaletteItem? { items.first { $0.id == id } }
}

/// The board being edited, with undo and redo (§ 9.4). Pure value logic: the editor view drives it.
public struct BoardEditor: Sendable, Equatable {
    public private(set) var board: BoardLayout
    private var undoStack: [BoardLayout] = []
    private var redoStack: [BoardLayout] = []
    public static let historyLimit = 100

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public init(board: BoardLayout) {
        self.board = board.assigningIDs()
    }

    // MARK: History

    /// Remember the board before a change. A drag calls this once, then `mutate` many times.
    public mutating func checkpoint() {
        undoStack.append(board)
        if undoStack.count > Self.historyLimit { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    /// Drops the last checkpoint when nothing changed since (a tap that didn't move anything).
    public mutating func discardEmptyCheckpoint() {
        if undoStack.last == board { undoStack.removeLast() }
    }

    /// Changes the board without a checkpoint (the middle of a drag).
    public mutating func mutate(_ change: (inout BoardLayout) -> Void) {
        change(&board)
    }

    /// One undoable change.
    public mutating func apply(_ change: (inout BoardLayout) -> Void) {
        checkpoint()
        change(&board)
        discardEmptyCheckpoint()
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        redoStack.append(board)
        board = previous
        return true
    }

    @discardableResult
    public mutating func redo() -> Bool {
        guard let next = redoStack.popLast() else { return false }
        undoStack.append(board)
        board = next
        return true
    }

    // MARK: Pieces

    public func index(of id: UUID) -> Int? { board.features.firstIndex { $0.id == id } }

    public func feature(_ id: UUID) -> BoardLayout.Feature? { index(of: id).map { board.features[$0] } }

    /// Adds a palette piece centred at (x, y) and returns its id.
    @discardableResult
    public mutating func add(_ item: TerrainPaletteItem, centredAt x: Double, _ y: Double, snap: BoardSnap = .whole) -> UUID {
        var piece = item.makeFeature(centredAt: x, y, on: board)
        piece.area.x = min(max(BoardRules.snap(piece.area.x, to: snap), 0), board.width - piece.area.width)
        piece.area.y = min(max(BoardRules.snap(piece.area.y, to: snap), 0), board.depth - piece.area.depth)
        let id = piece.id ?? UUID()
        piece.id = id
        apply { $0.features.append(piece) }
        return id
    }

    /// Moves the piece's top-left corner to (x, y), snapped and kept on the table.
    public mutating func place(_ id: UUID, x: Double, y: Double, snap: BoardSnap) {
        guard let i = index(of: id) else { return }
        let area = board.features[i].area
        let nx = min(max(BoardRules.snap(x, to: snap), 0), board.width - area.width)
        let ny = min(max(BoardRules.snap(y, to: snap), 0), board.depth - area.depth)
        board.features[i].area.x = nx
        board.features[i].area.y = ny
    }

    /// Moves a piece by (dx, dy) inches as one undoable change (the nudge buttons and VoiceOver actions).
    public mutating func nudge(_ id: UUID, dx: Double, dy: Double) {
        guard let i = index(of: id) else { return }
        let area = board.features[i].area
        let nx = min(max(area.x + dx, 0), board.width - area.width)
        let ny = min(max(area.y + dy, 0), board.depth - area.depth)
        apply {
            $0.features[i].area.x = nx
            $0.features[i].area.y = ny
        }
    }

    /// Turns a piece by `degrees` (15° with snap on; free with snap off).
    public mutating func rotate(_ id: UUID, by degrees: Double, snapOn: Bool) {
        guard let i = index(of: id) else { return }
        let next = BoardRules.snapRotation(board.features[i].degrees + degrees, snapOn: snapOn)
        apply { $0.features[i].rotation = next == 0 ? nil : next }
    }

    public mutating func setRotation(_ id: UUID, _ degrees: Double, snapOn: Bool) {
        guard let i = index(of: id) else { return }
        let next = BoardRules.snapRotation(degrees, snapOn: snapOn)
        apply { $0.features[i].rotation = next == 0 ? nil : next }
    }

    /// Sets a piece's size (inches), kept inside the table and at least ½″.
    public mutating func resize(_ id: UUID, width: Double, depth: Double) {
        guard let i = index(of: id) else { return }
        let w = min(max(width, 0.5), board.width)
        let d = min(max(depth, 0.5), board.depth)
        apply { board in
            board.features[i].area.width = w
            board.features[i].area.depth = d
            board.features[i].area.x = min(max(board.features[i].area.x, 0), board.width - w)
            board.features[i].area.y = min(max(board.features[i].area.y, 0), board.depth - d)
        }
    }

    public mutating func setLevel(_ id: UUID, _ level: Double) {
        guard let i = index(of: id) else { return }
        let kind = board.features[i].kind
        apply { $0.features[i].level = BoardRules.clampedLevel(level, kind: kind) }
    }

    public mutating func setName(_ id: UUID, _ name: String) {
        guard let i = index(of: id) else { return }
        let trimmed = String(name.trimmingCharacters(in: .whitespaces).prefix(40))
        apply { $0.features[i].name = trimmed.isEmpty ? nil : trimmed }
    }

    public mutating func setBuildingClass(_ id: UUID, _ buildingClass: BoardLayout.BuildingClass) {
        guard let i = index(of: id) else { return }
        apply {
            $0.features[i].buildingClass = buildingClass
            $0.features[i].cf = buildingClass.defaultCF
        }
    }

    /// A copy 1″ right and down of the original, on top. Returns the copy's id.
    @discardableResult
    public mutating func duplicate(_ id: UUID) -> UUID? {
        guard let source = feature(id) else { return nil }
        var copy = source
        let copyID = UUID()
        copy.id = copyID
        copy.area.x = min(source.area.x + 1, board.width - source.area.width)
        copy.area.y = min(source.area.y + 1, board.depth - source.area.depth)
        apply { $0.features.append(copy) }
        return copyID
    }

    public mutating func delete(_ id: UUID) {
        guard let i = index(of: id) else { return }
        apply { _ = $0.features.remove(at: i) }
    }

    /// Resets the zone sets to the § 6.4 rule for the table.
    public mutating func resetZones() {
        apply {
            $0.zones = []
            $0.zonesBySideCount = nil
        }
    }

    /// Re-sizes the table, clamping pieces onto it.
    public mutating func setTable(width: Double, depth: Double) {
        apply {
            $0.width = width
            $0.depth = depth
            $0 = $0.clampedToTable()
        }
    }
}
