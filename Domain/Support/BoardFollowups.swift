import Foundation

// Board builder follow-ups (PlayModeSpec § 9.2, § 9.4, § 7.1): drag zone edges, move and turn mapsheets, place
// objective tokens. Pure value logic; the views in Features/PlayMode/Board drive it. Quick-Start rules carry a page;
// anything else is marked [HOUSE].

// MARK: - Zones

extension BoardRules {
    /// How deep a zone can be dragged, inches (the rule is 6″, p. 11). The cap is a third of the table across, as the
    /// generated zones use, so opposite zones never meet.
    public static let zoneDepthRange: ClosedRange<Double> = 2...12

    /// The table edge a zone sits against. A zone from the board names it; otherwise it is the edge the zone is
    /// thinnest against (a west zone 6″ wide and 48″ tall touches three edges; west is the thin one).
    public static func homeEdge(of zone: BoardLayout.Zone, width: Double, depth: Double) -> TableEdge {
        if let edge = zone.homeEdge { return edge }
        let a = zone.area
        let eps = 0.01
        var touching: [(edge: TableEdge, thickness: Double)] = []
        if a.x <= eps { touching.append((.west, a.width)) }
        if a.maxX >= width - eps { touching.append((.east, a.width)) }
        if a.y <= eps { touching.append((.north, a.depth)) }
        if a.maxY >= depth - eps { touching.append((.south, a.depth)) }
        if let thin = touching.min(by: { $0.thickness < $1.thickness }) { return thin.edge }
        let gaps: [(TableEdge, Double)] = [(.west, a.x), (.east, width - a.maxX), (.north, a.y), (.south, depth - a.maxY)]
        return gaps.min { $0.1 < $1.1 }?.0 ?? .west
    }

    /// How far the zone reaches in from its home edge.
    public static func depth(of zone: BoardLayout.Zone, width: Double, depth: Double) -> Double {
        switch homeEdge(of: zone, width: width, depth: depth) {
        case .west, .east: zone.area.width
        case .north, .south: zone.area.depth
        }
    }

    /// The largest depth for a zone on `edge` of this table.
    public static func maxZoneDepth(edge: TableEdge, width: Double, depth: Double) -> Double {
        let across = (edge == .west || edge == .east) ? width : depth
        return max(zoneDepthRange.lowerBound, min(zoneDepthRange.upperBound, across / 3))
    }

    /// Distance from the zone's home edge to a table point: what dragging the handle to `point` asks for.
    public static func depth(toward point: BoardLayout.Point, edge: TableEdge, width: Double, depth: Double) -> Double {
        switch edge {
        case .west: point.x
        case .east: width - point.x
        case .north: point.y
        case .south: depth - point.y
        }
    }

    /// The zone at a new depth: snapped, clamped to 2″...12″ (and a third of the table), kept on its home edge.
    /// Its length along the edge stays as it was.
    public static func resized(_ zone: BoardLayout.Zone, toDepth requested: Double, width: Double, depth: Double, snap: BoardSnap = .whole) -> BoardLayout.Zone {
        let edge = homeEdge(of: zone, width: width, depth: depth)
        let limit = maxZoneDepth(edge: edge, width: width, depth: depth)
        let d = min(max(Self.snap(requested, to: snap), zoneDepthRange.lowerBound), limit)
        var area = zone.area
        switch edge {
        case .west: area.x = 0; area.width = d
        case .east: area.x = width - d; area.width = d
        case .north: area.y = 0; area.depth = d
        case .south: area.y = depth - d; area.depth = d
        }
        return BoardLayout.Zone(side: zone.side, area: area, homeEdge: edge)
    }

    /// Where the drag handle for a zone sits: the middle of its inner edge.
    public static func innerEdgeMidpoint(of zone: BoardLayout.Zone, width: Double, depth: Double) -> BoardLayout.Point {
        let a = zone.area
        switch homeEdge(of: zone, width: width, depth: depth) {
        case .west: return .init(x: a.maxX, y: a.midY)
        case .east: return .init(x: a.x, y: a.midY)
        case .north: return .init(x: a.midX, y: a.maxY)
        case .south: return .init(x: a.midX, y: a.y)
        }
    }

    /// How many terrain pieces overlap any zone (the § 9.4 warning count).
    public static func piecesInsideZones(_ features: [BoardLayout.Feature], zones: [BoardLayout.Zone]) -> Int {
        features.filter { !zoneWarnings(for: $0, zones: zones).isEmpty }.count
    }

    /// "1 piece is inside a zone." / "3 pieces are inside zones." Nil when none.
    public static func zoneWarningText(count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? "1 piece is inside a deployment zone." : "\(count) pieces are inside deployment zones."
    }
}

extension BoardEditor {
    /// One undoable change: the zone set for a game of `sideCount` sides.
    public mutating func setZoneSet(_ zones: [BoardLayout.Zone], sideCount: Int) {
        apply { Self.writeZones(zones, sideCount: sideCount, to: &$0) }
    }

    /// The middle of a zone drag (a checkpoint is already taken).
    public mutating func liveZoneSet(_ zones: [BoardLayout.Zone], sideCount: Int) {
        mutate { Self.writeZones(zones, sideCount: sideCount, to: &$0) }
    }

    private static func writeZones(_ zones: [BoardLayout.Zone], sideCount: Int, to board: inout BoardLayout) {
        var sets = board.zonesBySideCount ?? [:]
        sets[min(max(sideCount, 2), 4)] = zones
        board.zonesBySideCount = sets
    }
}

// MARK: - Mapsheets

extension BoardRules {
    /// Sheets snap edge to edge within this many inches (§ 9.2). Off when snap is off.
    public static let sheetMagnet = 1.5

    /// The topmost sheet under a point (later sheets draw on top).
    public static func sheetHit(_ sheets: [BoardLayout.Sheet], at point: BoardLayout.Point) -> Int? {
        sheets.indices.reversed().first { sheets[$0].area.contains(point) }
    }

    /// Sheets with any part off the table, by index.
    public static func sheetsOffTable(_ board: BoardLayout) -> [Int] {
        let eps = 0.01
        return board.sheets.indices.filter {
            let a = board.sheets[$0].area
            return a.x < -eps || a.y < -eps || a.maxX > board.width + eps || a.maxY > board.depth + eps
        }
    }

    /// "1 mapsheet is off the table." Nil when every sheet is on it.
    public static func sheetWarningText(_ board: BoardLayout) -> String? {
        let n = sheetsOffTable(board).count
        guard n > 0 else { return nil }
        return n == 1 ? "1 mapsheet reaches off the table." : "\(n) mapsheets reach off the table."
    }

    /// A sheet's top-left corner for a drag to (x, y): snapped to the grid, then pulled flush against another
    /// sheet's edge or the table's within `sheetMagnet` (no pull with snap off). A sheet stays at or below the
    /// table's top-left corner and within the biggest table (96″).
    public static func placedSheet(_ area: BoardLayout.Rect, x: Double, y: Double, others: [BoardLayout.Rect], table: (width: Double, depth: Double), snap: BoardSnap) -> BoardLayout.Rect {
        var px = Self.snap(x, to: snap)
        var py = Self.snap(y, to: snap)
        let w = area.width
        let d = area.depth
        if snap != .off {
            func pull(_ value: Double, _ targets: [Double]) -> Double {
                guard let best = targets.min(by: { abs($0 - value) < abs($1 - value) }), abs(best - value) <= sheetMagnet else { return value }
                return best
            }
            // Edges of sheets that sit beside this one in the other axis, plus the table's own edges.
            let beside = others.filter { $0.y < py + d + sheetMagnet && $0.maxY > py - sheetMagnet }
            px = pull(px, beside.flatMap { [$0.maxX, $0.x - w, $0.x, $0.maxX - w] } + [0, table.width - w])
            let above = others.filter { $0.x < px + w + sheetMagnet && $0.maxX > px - sheetMagnet }
            py = pull(py, above.flatMap { [$0.maxY, $0.y - d, $0.y, $0.maxY - d] } + [0, table.depth - d])
        }
        px = min(max(px, 0), max(0, BoardLayout.tableRange.upperBound - w))
        py = min(max(py, 0), max(0, BoardLayout.tableRange.upperBound - d))
        return BoardLayout.Rect(x: px, y: py, width: w, depth: d)
    }

    /// "Grassland #2 · turned 90°" for the label on the sheet.
    public static func sheetCaption(_ sheet: BoardLayout.Sheet) -> String {
        guard let turn = sheet.rotation, turn % 360 != 0 else { return sheet.name }
        return "\(sheet.name) · turned \(turn)°"
    }

    /// What VoiceOver says for a sheet (§ 9.6).
    public static func spoken(_ sheet: BoardLayout.Sheet, in board: BoardLayout) -> String {
        var text = "Mapsheet \(sheet.name), \(plain(sheet.area.width)) by \(plain(sheet.area.depth)) inches, top left corner \(plain(sheet.area.x)) inches from the left, \(plain(sheet.area.y)) from the top."
        if let turn = sheet.rotation, turn % 360 != 0 { text += " Turned \(turn) degrees." }
        if board.sheets.firstIndex(of: sheet).map({ sheetsOffTable(board).contains($0) }) == true { text += " Reaches off the table." }
        return text
    }
}

extension BoardEditor {
    /// During a sheet drag (a checkpoint is already taken): the sheet's corner moves to (x, y), snapped.
    public mutating func placeSheet(_ index: Int, x: Double, y: Double, snap: BoardSnap) {
        guard board.sheets.indices.contains(index) else { return }
        let others = board.sheets.enumerated().filter { $0.offset != index }.map(\.element.area)
        let placed = BoardRules.placedSheet(board.sheets[index].area, x: x, y: y, others: others, table: (board.width, board.depth), snap: snap)
        mutate { $0.sheets[index].area = placed }
    }

    /// One undoable step by (dx, dy) inches (buttons and VoiceOver actions). No magnet: the step is exact.
    public mutating func nudgeSheet(_ index: Int, dx: Double, dy: Double) {
        guard board.sheets.indices.contains(index) else { return }
        let area = board.sheets[index].area
        apply {
            $0.sheets[index].area.x = min(max(area.x + dx, 0), max(0, BoardLayout.tableRange.upperBound - area.width))
            $0.sheets[index].area.y = min(max(area.y + dy, 0), max(0, BoardLayout.tableRange.upperBound - area.depth))
        }
    }

    /// One undoable change: set the corner from the steppers.
    public mutating func setSheetPosition(_ index: Int, x: Double? = nil, y: Double? = nil) {
        guard board.sheets.indices.contains(index) else { return }
        let area = board.sheets[index].area
        apply {
            $0.sheets[index].area.x = min(max(x ?? area.x, 0), max(0, BoardLayout.tableRange.upperBound - area.width))
            $0.sheets[index].area.y = min(max(y ?? area.y, 0), max(0, BoardLayout.tableRange.upperBound - area.depth))
        }
    }

    /// Turns a sheet 90° clockwise about its centre: width and depth swap and `rotation` steps 0, 90, 180, 270.
    public mutating func rotateSheet(_ index: Int) {
        guard board.sheets.indices.contains(index) else { return }
        let sheet = board.sheets[index]
        let c = sheet.area.center
        let w = sheet.area.depth
        let d = sheet.area.width
        let next = ((sheet.rotation ?? 0) + 90) % 360
        apply {
            $0.sheets[index].area = .init(x: max(0, c.x - w / 2), y: max(0, c.y - d / 2), width: w, depth: d)
            $0.sheets[index].rotation = next == 0 ? nil : next
        }
    }

    /// The table follows the arrangement **[HOUSE]**: sized to the sheets' far edges (12″–96″), pieces kept on it and
    /// zones drawn again for the new table.
    public mutating func fitTableToSheets() {
        guard !board.sheets.isEmpty else { return }
        let far = board.sheets.reduce((x: 0.0, y: 0.0)) { (max($0.x, $1.area.maxX), max($0.y, $1.area.maxY)) }
        let range = BoardLayout.tableRange
        let w = min(max(far.x.rounded(.up), range.lowerBound), range.upperBound)
        let d = min(max(far.y.rounded(.up), range.lowerBound), range.upperBound)
        apply {
            $0.width = w
            $0.depth = d
            $0.zones = []
            $0.zonesBySideCount = nil
            $0 = $0.clampedToTable()
        }
    }
}

// MARK: - Objective tokens

/// Objective tokens on a board (§ 7.1, § 9.3). The setup's objective sets how many a side places and what they are
/// called; with no objective (or from the Boards list) tokens are generic and numbered.
public enum BoardTokens {
    /// One side's tokens for one objective.
    public struct Spec: Sendable, Equatable {
        public var side: String
        public var objective: ObjectiveId
        public var count: Int

        public init(side: String, objective: ObjectiveId, count: Int) {
            self.side = side
            self.objective = objective
            self.count = count
        }

        /// "Raid 1": the name a token carries on the board.
        public func label(_ number: Int) -> String { "\(objective.shortTitle) \(number)" }
        var prefix: String { objective.shortTitle }

        /// p. 7: Raid tokens go at least 21″ from the side's edge, Hold the Fort at least 12″; both 18″ apart.
        public var minimumFromEdge: Double { objective == .raid ? 21 : 12 }
        public static let apart = 18.0
    }

    /// Tokens the game's objectives call for. Raid tokens go out for every side once any side plays Raid **[HOUSE]**, as
    /// the scoring does (§ 5.5); Hold the Fort tokens only for the sides that play it.
    public static func plan(for setup: PlaySetup) -> [Spec] {
        let objectives = setup.sides.map { setup.objectiveId(for: $0.id) }
        var specs: [Spec] = []
        if objectives.contains(.raid) {
            for side in setup.sides { specs.append(Spec(side: side.id.letter, objective: .raid, count: ObjectiveId.raid.tokensPerSide)) }
        }
        for (side, objective) in zip(setup.sides, objectives) where objective == .holdTheFort {
            specs.append(Spec(side: side.id.letter, objective: .holdTheFort, count: ObjectiveId.holdTheFort.tokensPerSide))
        }
        return specs
    }

    public static let tokenSize = 1.5

    static func isToken(_ feature: BoardLayout.Feature) -> Bool { feature.kind == .objectiveToken }

    /// Tokens already on the board for a spec.
    public static func placed(for spec: Spec, in board: BoardLayout) -> [BoardLayout.Feature] {
        board.features.filter { isToken($0) && $0.side == spec.side && $0.name?.hasPrefix(spec.prefix + " ") == true }
    }

    /// The next token to place: the first one the plan still wants, else a generic "Token n" for Side A.
    public static func nextSlot(in board: BoardLayout, plan: [Spec]) -> (side: String, name: String) {
        for spec in plan {
            let names = Set(placed(for: spec, in: board).compactMap(\.name))
            for n in 1...max(spec.count, 1) where !names.contains(spec.label(n)) {
                return (spec.side, spec.label(n))
            }
        }
        let used = Set(board.features.filter(isToken).compactMap(\.name))
        var n = board.features.filter(isToken).count + 1
        while used.contains("Token \(n)") { n += 1 }
        return ("A", "Token \(n)")
    }

    /// "Raid tokens: A 2 of 3, B 0 of 3". Nil when the plan is empty.
    public static func counterText(_ board: BoardLayout, plan: [Spec]) -> String? {
        guard !plan.isEmpty else { return nil }
        var parts: [String] = []
        for objective in plan.reduce(into: [ObjectiveId]()) { if !$0.contains($1.objective) { $0.append($1.objective) } } {
            let specs = plan.filter { $0.objective == objective }
            let counts = specs.map { "\($0.side) \(min(placed(for: $0, in: board).count, $0.count)) of \($0.count)" }
            parts.append("\(objective.shortTitle) tokens: " + counts.joined(separator: ", "))
        }
        return parts.joined(separator: ". ")
    }

    /// The spec a token belongs to, by its side and the objective in its name.
    public static func spec(for feature: BoardLayout.Feature, plan: [Spec]) -> Spec? {
        guard isToken(feature) else { return nil }
        return plan.first { $0.side == feature.side && feature.name?.hasPrefix($0.prefix + " ") == true }
    }

    /// Placement hints, not blocks (p. 7): too close to its own edge, or within 18″ of another of its side's tokens.
    public static func warnings(for feature: BoardLayout.Feature, in board: BoardLayout, plan: [Spec], zones: [BoardLayout.Zone]) -> [String] {
        guard let spec = spec(for: feature, plan: plan) else { return [] }
        var result: [String] = []
        if let zone = zones.first(where: { $0.side == spec.side }) {
            let edge = BoardRules.homeEdge(of: zone, width: board.width, depth: board.depth)
            let away = BoardRules.depth(toward: feature.area.center, edge: edge, width: board.width, depth: board.depth)
            if away < spec.minimumFromEdge {
                result.append("\(BoardRules.inches(away)) from Side \(spec.side)’s edge; \(spec.objective.title) wants at least \(BoardRules.plain(spec.minimumFromEdge))″ (p. 7).")
            }
        }
        for other in placed(for: spec, in: board) where other.id != feature.id {
            let gap = BoardRules.distance(feature.area.center, other.area.center)
            if gap < Spec.apart {
                result.append("\(BoardRules.inches(gap)) from \(other.name ?? "another token"); keep them \(BoardRules.plain(Spec.apart))″ apart (p. 7).")
            }
        }
        return result
    }

    /// The digits on the token's face: the number in its name, else its side letter.
    public static func badge(_ feature: BoardLayout.Feature) -> String {
        let digits = feature.name.map { String($0.reversed().prefix { $0.isNumber }.reversed()) } ?? ""
        return digits.isEmpty ? (feature.side ?? "A") : digits
    }

    /// "Raid 1, objective token for Side A, centre 30 inches from the left, 9 from the top."
    public static func spoken(_ feature: BoardLayout.Feature) -> String {
        let name = feature.name.flatMap { $0.isEmpty ? nil : $0 }.map { "\($0), " } ?? ""
        return "\(name)objective token for Side \(feature.side ?? "A"), centre \(BoardRules.plain(feature.area.midX)) inches from the left, \(BoardRules.plain(feature.area.midY)) from the top."
    }
}

extension TerrainPaletteItem {
    /// The palette's token tile: a marker, not terrain (§ 9.3).
    public static let objectiveToken = TerrainPaletteItem(
        id: "token",
        kind: .objectiveToken,
        title: "Objective token",
        shape: .ellipse,
        width: BoardTokens.tokenSize,
        depth: BoardTokens.tokenSize,
        level: nil,
        buildingClass: nil,
        glyph: "diamond.fill",
        movement: "None. A token has no effect on movement.",
        lineOfSight: "None.",
        attack: "None.",
        choices: "Not a terrain choice",
        pages: "p. 7",
        note: "Raid: 3 tokens a side at least 21″ from its edge and 18″ apart. Hold the Fort: 2 tokens a side at least 12″ from its edge and 18″ apart."
    )
}

extension BoardEditor {
    /// Adds an objective token centred at (x, y), owned by `side`, as one undoable change.
    @discardableResult
    public mutating func addToken(side: String, name: String, centredAt x: Double, _ y: Double, snap: BoardSnap = .whole) -> UUID {
        var piece = TerrainPaletteItem.objectiveToken.makeFeature(centredAt: x, y, on: board)
        piece.side = side
        piece.name = name
        piece.area.x = min(max(BoardRules.snap(piece.area.x, to: snap), 0), board.width - piece.area.width)
        piece.area.y = min(max(BoardRules.snap(piece.area.y, to: snap), 0), board.depth - piece.area.depth)
        let id = piece.id ?? UUID()
        piece.id = id
        apply { $0.features.append(piece) }
        return id
    }

    /// One undoable change: who owns a token.
    public mutating func setSide(_ id: UUID, _ side: String) {
        guard let i = index(of: id) else { return }
        apply { $0.features[i].side = side }
    }
}
