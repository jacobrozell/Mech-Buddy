import Foundation

// The terrain board (PlayModeSpec § 9.8): a top-down plan of the real table, in inches, origin top-left.
//
// Every mission's `layout` JSON decodes into this and encodes back to the same JSON: each new field is
// optional and omitted when nil. A piece kind this build doesn't know is dropped on decode (it never fails
// the whole board), and `droppedPieceCount` says how many.

public struct BoardLayout: Codable, Sendable, Equatable {
    public struct Rect: Codable, Sendable, Equatable {
        public var x: Double
        public var y: Double
        public var width: Double
        public var depth: Double

        public init(x: Double, y: Double, width: Double, depth: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.depth = depth
        }

        public var maxX: Double { x + width }
        public var maxY: Double { y + depth }
        public var midX: Double { x + width / 2 }
        public var midY: Double { y + depth / 2 }
        public var center: Point { Point(x: midX, y: midY) }

        /// True when the two rectangles share more than an edge.
        public func overlaps(_ other: Rect) -> Bool {
            x < other.maxX && other.x < maxX && y < other.maxY && other.y < maxY
        }

        public func contains(_ point: Point) -> Bool {
            point.x >= x && point.x <= maxX && point.y >= y && point.y <= maxY
        }
    }

    public struct Point: Sendable, Equatable {
        public var x: Double
        public var y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// A printed mapsheet on the table, named as printed. `rotation` is 0, 90, 180 or 270 (nil = 0).
    public struct Sheet: Codable, Sendable, Equatable {
        public var name: String
        public var area: Rect
        public var rotation: Int?

        public init(name: String, area: Rect, rotation: Int? = nil) {
            self.name = name
            self.area = area
            self.rotation = rotation
        }
    }

    /// Where a side sets up. `side` is "A" to "D". `homeEdge` names the edge when the board knows it.
    public struct Zone: Codable, Sendable, Equatable {
        public var side: String
        public var area: Rect
        public var homeEdge: TableEdge?

        public init(side: String, area: Rect, homeEdge: TableEdge? = nil) {
            self.side = side
            self.area = area
            self.homeEdge = homeEdge
        }
    }

    public enum FeatureKind: String, Codable, Sendable, CaseIterable {
        case hill, woods, wall, tree, building
        case water, rough, rubble
        /// A marker owned by a side (§ 7.1). Not terrain: no rules effect on the board.
        case objectiveToken

        /// Terrain from the Quick-Start only (the palette's pieces); the token is a marker.
        public var isTerrain: Bool { self != .objectiveToken }
    }

    public enum Shape: String, Codable, Sendable {
        case rect, ellipse
    }

    /// Building class, p. 28.
    public enum BuildingClass: String, Codable, Sendable, CaseIterable {
        case light, medium, heavy, hardened

        /// Default CF by class (p. 28).
        public var defaultCF: Int {
            switch self {
            case .light: 15
            case .medium: 30
            case .heavy: 45
            case .hardened: 60
            }
        }

        public var title: String { rawValue.capitalized }
    }

    public struct Feature: Codable, Sendable, Equatable {
        /// Assigned by the editor (`BoardLayout.assigningIDs()`); missions have none.
        public var id: UUID?
        public var kind: FeatureKind
        public var area: Rect
        public var name: String?
        /// Nil = the kind's usual shape (`defaultShape`).
        public var shape: Shape?
        /// Degrees clockwise about the centre. Nil = 0.
        public var rotation: Double?
        /// Hills 1″–4″ per piece, buildings 1″–12″ (p. 9, p. 10).
        public var level: Double?
        public var buildingClass: BuildingClass?
        public var cf: Int?
        /// The owner of an objective token ("A" to "D").
        public var side: String?

        public init(
            id: UUID? = nil,
            kind: FeatureKind,
            area: Rect,
            name: String? = nil,
            shape: Shape? = nil,
            rotation: Double? = nil,
            level: Double? = nil,
            buildingClass: BuildingClass? = nil,
            cf: Int? = nil,
            side: String? = nil
        ) {
            self.id = id
            self.kind = kind
            self.area = area
            self.name = name
            self.shape = shape
            self.rotation = rotation
            self.level = level
            self.buildingClass = buildingClass
            self.cf = cf
            self.side = side
        }

        /// What a mission map has always drawn: hills and single trees round, everything else a box.
        public static func defaultShape(for kind: FeatureKind) -> Shape {
            switch kind {
            case .hill, .tree, .objectiveToken: .ellipse
            default: .rect
            }
        }

        public var drawnShape: Shape { shape ?? Self.defaultShape(for: kind) }
        public var degrees: Double { rotation ?? 0 }
    }

    public static let currentSchemaVersion = 1
    /// Table sides the builder allows, inches (§ 9.2).
    public static let tableRange: ClosedRange<Double> = 12...96

    public var schemaVersion: Int?
    public var id: UUID?
    public var name: String?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var isStarter: Bool?
    /// Set on the copy a game or setup holds: the saved board it came from, and that board's `updatedAt` at
    /// the time. Lets setup say "Board changed since" (§ 9.7). Nil on presets and starters.
    public var presetID: UUID?
    public var presetUpdatedAt: Date?
    public var width: Double
    public var depth: Double
    /// Suggested mapsheets. Empty when played on an open table.
    public var sheets: [Sheet]
    /// The zones the board was authored with (a mission's two). Read through `zones(sideCount:)`.
    public var zones: [Zone]
    /// Zone sets for 2, 3 and 4 sides (§ 9.7). Unset counts are generated.
    public var zonesBySideCount: [Int: [Zone]]?
    public var features: [Feature]
    public var openTable: String
    /// Pieces with a kind this build doesn't know, dropped on decode. Not stored.
    public var droppedPieceCount = 0

    public init(
        schemaVersion: Int? = nil,
        id: UUID? = nil,
        name: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        isStarter: Bool? = nil,
        width: Double,
        depth: Double,
        sheets: [Sheet] = [],
        zones: [Zone] = [],
        zonesBySideCount: [Int: [Zone]]? = nil,
        features: [Feature] = [],
        openTable: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isStarter = isStarter
        self.width = width
        self.depth = depth
        self.sheets = sheets
        self.zones = zones
        self.zonesBySideCount = zonesBySideCount
        self.features = features
        self.openTable = openTable
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, name, createdAt, updatedAt, isStarter, presetID, presetUpdatedAt
        case width, depth, sheets, zones, zonesBySideCount, features, openTable
    }

    /// Decodes an element without ever failing, so one unknown kind can't lose the board.
    private struct Lossy<T: Decodable>: Decodable {
        var value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
        id = try c.decodeIfPresent(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        isStarter = try c.decodeIfPresent(Bool.self, forKey: .isStarter)
        presetID = try c.decodeIfPresent(UUID.self, forKey: .presetID)
        presetUpdatedAt = try c.decodeIfPresent(Date.self, forKey: .presetUpdatedAt)
        width = try c.decode(Double.self, forKey: .width)
        depth = try c.decode(Double.self, forKey: .depth)
        sheets = try c.decodeIfPresent([Sheet].self, forKey: .sheets) ?? []
        zones = try c.decodeIfPresent([Zone].self, forKey: .zones) ?? []
        if let raw = try c.decodeIfPresent([String: [Zone]].self, forKey: .zonesBySideCount) {
            var sets: [Int: [Zone]] = [:]
            for (key, value) in raw {
                if let count = Int(key) { sets[count] = value }
            }
            zonesBySideCount = sets.isEmpty ? nil : sets
        }
        let lossy = try c.decodeIfPresent([Lossy<Feature>].self, forKey: .features) ?? []
        features = lossy.compactMap(\.value)
        droppedPieceCount = lossy.count - features.count
        openTable = try c.decodeIfPresent(String.self, forKey: .openTable) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(isStarter, forKey: .isStarter)
        try c.encodeIfPresent(presetID, forKey: .presetID)
        try c.encodeIfPresent(presetUpdatedAt, forKey: .presetUpdatedAt)
        try c.encode(width, forKey: .width)
        try c.encode(depth, forKey: .depth)
        try c.encode(sheets, forKey: .sheets)
        try c.encode(zones, forKey: .zones)
        if let zonesBySideCount, !zonesBySideCount.isEmpty {
            // JSON object keys are strings; an Int-keyed dictionary would encode as an array.
            let raw = Dictionary(uniqueKeysWithValues: zonesBySideCount.map { (String($0.key), $0.value) })
            try c.encode(raw, forKey: .zonesBySideCount)
        }
        try c.encode(features, forKey: .features)
        try c.encode(openTable, forKey: .openTable)
    }

    // MARK: Zones

    /// The zone set for a game of `sideCount` sides (§ 9.7): the stored set, the authored zones for two
    /// sides, or a set generated from § 6.4.
    public func zones(sideCount: Int) -> [Zone] {
        let count = min(max(sideCount, 2), 4)
        if let stored = zonesBySideCount?[count], !stored.isEmpty { return stored }
        if count == 2, !zones.isEmpty { return zones }
        return BoardZones.generate(width: width, depth: depth, sideCount: count)
    }

    // MARK: Editing helpers

    /// A copy where every piece has an id (the editor needs stable ids; missions have none).
    public func assigningIDs() -> BoardLayout {
        var copy = self
        for index in copy.features.indices where copy.features[index].id == nil {
            copy.features[index].id = UUID()
        }
        return copy
    }

    /// A copy that fits the table: size within `tableRange`, pieces, sheets and zones kept on the table,
    /// no piece bigger than the table, levels within their limits.
    public func clampedToTable() -> BoardLayout {
        var copy = self
        copy.width = min(max(width, Self.tableRange.lowerBound), Self.tableRange.upperBound)
        copy.depth = min(max(depth, Self.tableRange.lowerBound), Self.tableRange.upperBound)
        let w = copy.width
        let d = copy.depth
        func fit(_ r: Rect) -> Rect {
            let width = min(max(r.width, 0), w)
            let depth = min(max(r.depth, 0), d)
            return Rect(x: min(max(r.x, 0), w - width), y: min(max(r.y, 0), d - depth), width: width, depth: depth)
        }
        copy.sheets = copy.sheets.map { Sheet(name: $0.name, area: fit($0.area), rotation: $0.rotation) }
        copy.zones = copy.zones.map { Zone(side: $0.side, area: fit($0.area), homeEdge: $0.homeEdge) }
        copy.zonesBySideCount = copy.zonesBySideCount?.mapValues { set in
            set.map { Zone(side: $0.side, area: fit($0.area), homeEdge: $0.homeEdge) }
        }
        copy.features = copy.features.map { feature in
            var piece = feature
            piece.area = fit(feature.area)
            if let level = feature.level { piece.level = BoardRules.clampedLevel(level, kind: feature.kind) }
            return piece
        }
        return copy
    }

    // MARK: Fitting a bigger table (§ 9.7)

    /// The board on a bigger table with positions spread in proportion: every piece and sheet keeps its size,
    /// its centre moves to the same share of the new width and depth. Zones are regenerated for the new table.
    public func stretched(toWidth newWidth: Double, depth newDepth: Double) -> BoardLayout {
        remapped(toWidth: newWidth, depth: newDepth) { rect in
            let cx = width > 0 ? rect.midX / width * newWidth : rect.midX
            let cy = depth > 0 ? rect.midY / depth * newDepth : rect.midY
            return Rect(x: cx - rect.width / 2, y: cy - rect.depth / 2, width: rect.width, depth: rect.depth)
        }
    }

    /// The board kept at its own size in the middle of a bigger table. Zones are regenerated for the new table.
    public func centred(onWidth newWidth: Double, depth newDepth: Double) -> BoardLayout {
        let dx = (newWidth - width) / 2
        let dy = (newDepth - depth) / 2
        return remapped(toWidth: newWidth, depth: newDepth) { rect in
            Rect(x: rect.x + dx, y: rect.y + dy, width: rect.width, depth: rect.depth)
        }
    }

    private func remapped(toWidth newWidth: Double, depth newDepth: Double, _ move: (Rect) -> Rect) -> BoardLayout {
        var copy = self
        copy.width = newWidth
        copy.depth = newDepth
        copy.sheets = sheets.map { Sheet(name: $0.name, area: move($0.area), rotation: $0.rotation) }
        copy.features = features.map { feature in
            var piece = feature
            piece.area = move(feature.area)
            return piece
        }
        copy.zones = []
        copy.zonesBySideCount = nil
        return copy.clampedToTable()
    }

    /// Terrain pieces only (not tokens).
    public var terrain: [Feature] { features.filter { $0.kind.isTerrain } }
}

/// Zones from § 6.4 for a given table and side count.
public enum BoardZones {
    /// Deployment depth from the home edge, inches (p. 11, "within 6 inches").
    public static let zoneDepth = 6.0
    /// Three or four sides use the middle 3/8 of their edge **[HOUSE]** (§ 6.4).
    public static let houseZoneShare = 3.0 / 8.0

    public static func generate(width: Double, depth: Double, sideCount: Int, zoneDepth: Double = BoardZones.zoneDepth) -> [BoardLayout.Zone] {
        let edges = [TableEdge.west, .east, .south, .north].prefix(min(max(sideCount, 2), 4))
        let seats = edges.enumerated().map { (letter: ["A", "B", "C", "D"][$0.offset], edge: $0.element) }
        return generate(width: width, depth: depth, seats: seats, zoneDepth: zoneDepth)
    }

    /// One zone per side on its home edge, 6″ deep. Two sides take the full edge (p. 11); three or four take
    /// the middle 3/8 of it so neighbouring zones stay apart **[HOUSE]**.
    public static func generate(width: Double, depth: Double, seats: [(letter: String, edge: TableEdge)], zoneDepth: Double = BoardZones.zoneDepth) -> [BoardLayout.Zone] {
        let narrow = seats.count > 2
        return seats.map { seat in
            let vertical = seat.edge == .west || seat.edge == .east
            let edgeLength = vertical ? depth : width
            let band = narrow ? edgeLength * houseZoneShare : edgeLength
            let offset = (edgeLength - band) / 2
            let thick = min(zoneDepth, (vertical ? width : depth) / 3)
            let area: BoardLayout.Rect
            switch seat.edge {
            case .west: area = .init(x: 0, y: offset, width: thick, depth: band)
            case .east: area = .init(x: width - thick, y: offset, width: thick, depth: band)
            case .north: area = .init(x: offset, y: 0, width: band, depth: thick)
            case .south: area = .init(x: offset, y: depth - thick, width: band, depth: thick)
            }
            return .init(side: seat.letter, area: area, homeEdge: seat.edge)
        }
    }
}
