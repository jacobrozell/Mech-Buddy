import Foundation

/// How the editor snaps position and size (§ 9.2): 1″ (default), ½″ or off.
public enum BoardSnap: String, Codable, Sendable, CaseIterable {
    case whole, half, off

    public var step: Double? {
        switch self {
        case .whole: 1
        case .half: 0.5
        case .off: nil
        }
    }

    public var title: String {
        switch self {
        case .whole: "1″"
        case .half: "½″"
        case .off: "Off"
        }
    }

    /// Next in the toolbar cycle.
    public var next: BoardSnap {
        switch self {
        case .whole: .half
        case .half: .off
        case .off: .whole
        }
    }
}

/// Which p. 8 band a piece sits in, for two sides (the centre line runs between the home edges).
public enum PlacementBand: Sendable, Equatable {
    /// Within 6″ of the centre line.
    case nearCentre
    /// 6″–24″ from the centre line, on this side's half ("A" or "B").
    case half(side: String)
    /// More than 24″ from the centre line.
    case beyond

    public var text: String {
        switch self {
        case .nearCentre: "Within 6″ of the centre line"
        case .half(let side): "6″–24″ from the centre line, Side \(side)’s half"
        case .beyond: "More than 24″ from the centre line"
        }
    }
}

/// Rules helpers and geometry for the board builder (PlayModeSpec § 9). Placement rules are Quick-Start p. 8
/// unless marked **[HOUSE]**.
public enum BoardRules {
    // MARK: Snap

    public static func snap(_ value: Double, to mode: BoardSnap) -> Double {
        guard let step = mode.step else { return value }
        return (value / step).rounded() * step
    }

    /// 15° steps with snap on, free with snap off. Always 0 ..< 360.
    public static func snapRotation(_ degrees: Double, snapOn: Bool) -> Double {
        let wrapped = normalized(degrees)
        guard snapOn else { return wrapped }
        let snapped = (wrapped / 15).rounded() * 15
        return normalized(snapped)
    }

    public static func normalized(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Hills 1″–4″ per piece, buildings 1″–12″ (§ 9.3).
    public static func clampedLevel(_ level: Double, kind: BoardLayout.FeatureKind) -> Double {
        switch kind {
        case .hill: min(max(level, 1), 4)
        case .building: min(max(level, 1), 12)
        default: level
        }
    }

    // MARK: Terrain choices (p. 8)

    /// Terrain choices each side picks: 8 for two sides, 6 for three or four **[HOUSE]** (§ 5.4).
    public static func choicesPerSide(sideCount: Int) -> Int { sideCount > 2 ? 6 : 8 }

    public static func choiceBudget(sideCount: Int) -> Int {
        choicesPerSide(sideCount: sideCount) * max(sideCount, 2)
    }

    /// A woods, hill or water piece bigger than the standard template counts as two choices.
    /// **[HOUSE]** threshold: a footprint over 30 sq in (the 5″ round template is 25, the 3″ × 9″ strip 27).
    public static let largeTemplateArea = 30.0

    public static func isLarge(_ feature: BoardLayout.Feature) -> Bool {
        feature.area.width * feature.area.depth > largeTemplateArea
    }

    public static func isSmallRough(_ feature: BoardLayout.Feature) -> Bool {
        feature.area.width <= 2 && feature.area.depth <= 2
    }

    /// Small box building (the 1.6″ × 1.6″ one, p. 10): two make one choice.
    public static func isSmallBuilding(_ feature: BoardLayout.Feature) -> Bool {
        feature.area.width * feature.area.depth <= 4
    }

    /// Terrain choices the pieces use: 2 trees = 1, large woods / hill / water = 2, two small rough or rubble = 1,
    /// two small buildings = 1, everything else 1. Objective tokens are not terrain.
    public static func terrainChoices(_ features: [BoardLayout.Feature]) -> Int {
        var trees = 0
        var smallGround = 0
        var smallBuildings = 0
        var total = 0
        for feature in features {
            switch feature.kind {
            case .tree: trees += 1
            case .woods, .hill, .water: total += isLarge(feature) ? 2 : 1
            case .rough, .rubble:
                if isSmallRough(feature) { smallGround += 1 } else { total += 1 }
            case .building:
                if isSmallBuilding(feature) { smallBuildings += 1 } else { total += 1 }
            case .wall: total += 1
            case .objectiveToken: break
            }
        }
        return total + (trees + 1) / 2 + (smallGround + 1) / 2 + (smallBuildings + 1) / 2
    }

    /// "14 of 16 choices placed".
    public static func choiceSummary(_ features: [BoardLayout.Feature], sideCount: Int) -> String {
        "\(terrainChoices(features)) of \(choiceBudget(sideCount: sideCount)) choices placed"
    }

    // MARK: Hills (p. 9)

    /// A hill placed inside another hill's outline gets the next level: its own level plus the levels of the
    /// bigger hills under its centre. Returns nil for a feature that isn't a hill.
    public static func hillLevel(at index: Int, in features: [BoardLayout.Feature]) -> Double? {
        guard features.indices.contains(index), features[index].kind == .hill else { return nil }
        let hill = features[index]
        var level = hill.level ?? 1
        for (other, candidate) in features.enumerated() where other != index && candidate.kind == .hill {
            let bigger = candidate.area.width * candidate.area.depth > hill.area.width * hill.area.depth
            if bigger, contains(candidate, point: hill.area.center) {
                level += candidate.level ?? 1
            }
        }
        return level
    }

    // MARK: Geometry

    public static func distance(_ a: BoardLayout.Point, _ b: BoardLayout.Point) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    /// "14.5″" or "14″". Measure rounds to the half inch.
    public static func inches(_ value: Double) -> String {
        let rounded = (value * 2).rounded() / 2
        return rounded == rounded.rounded() ? "\(Int(rounded))″" : String(format: "%.1f″", rounded)
    }

    /// A table point as an offset from the piece's centre, turned back by the piece's rotation.
    private static func local(_ point: BoardLayout.Point, in feature: BoardLayout.Feature) -> BoardLayout.Point {
        let c = feature.area.center
        let angle = -feature.degrees * .pi / 180
        let dx = point.x - c.x
        let dy = point.y - c.y
        return .init(x: dx * cos(angle) - dy * sin(angle), y: dx * sin(angle) + dy * cos(angle))
    }

    /// Hit test, with rotation: a rotated rectangle or ellipse (§ 9.10).
    public static func contains(_ feature: BoardLayout.Feature, point: BoardLayout.Point) -> Bool {
        let p = local(point, in: feature)
        let a = feature.area.width / 2
        let b = feature.area.depth / 2
        guard a > 0, b > 0 else { return false }
        switch feature.drawnShape {
        case .rect: return abs(p.x) <= a && abs(p.y) <= b
        case .ellipse: return (p.x * p.x) / (a * a) + (p.y * p.y) / (b * b) <= 1
        }
    }

    /// The topmost piece under a point (later pieces draw on top). Nil when there is none.
    public static func hit(_ features: [BoardLayout.Feature], at point: BoardLayout.Point) -> Int? {
        features.indices.reversed().first { contains(features[$0], point: point) }
    }

    /// The axis-aligned box around a rotated piece.
    public static func bounds(of feature: BoardLayout.Feature) -> BoardLayout.Rect {
        let angle = feature.degrees * .pi / 180
        let w = feature.area.width
        let d = feature.area.depth
        let width = abs(w * cos(angle)) + abs(d * sin(angle))
        let depth = abs(w * sin(angle)) + abs(d * cos(angle))
        let c = feature.area.center
        return .init(x: c.x - width / 2, y: c.y - depth / 2, width: width, depth: depth)
    }

    /// Sides whose zone the piece sits inside, for the game's side count (a hint, not a block, § 9.4).
    public static func zoneWarnings(for feature: BoardLayout.Feature, zones: [BoardLayout.Zone]) -> [String] {
        guard feature.kind.isTerrain else { return [] }
        let box = bounds(of: feature)
        return zones.filter { $0.area.overlaps(box) }.map(\.side)
    }

    /// Gap in inches between two pieces' boxes; 0 when they touch or overlap.
    public static func gap(_ a: BoardLayout.Feature, _ b: BoardLayout.Feature) -> Double {
        let boxA = bounds(of: a)
        let boxB = bounds(of: b)
        let dx = max(0, max(boxA.x - boxB.maxX, boxB.x - boxA.maxX))
        let dy = max(0, max(boxA.y - boxB.maxY, boxB.y - boxA.maxY))
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Other terrain pieces closer than `limit` inches (4″ for three or four sides **[HOUSE]**, § 5.4),
    /// nearest first, as (index, gap).
    public static func neighbours(of index: Int, in features: [BoardLayout.Feature], within limit: Double = 4) -> [(index: Int, gap: Double)] {
        guard features.indices.contains(index), features[index].kind.isTerrain else { return [] }
        return features.indices
            .filter { $0 != index && features[$0].kind.isTerrain }
            .map { (index: $0, gap: gap(features[index], features[$0])) }
            .filter { $0.gap < limit }
            .sorted { $0.gap < $1.gap }
    }

    /// The p. 8 band for two sides: the centre line runs between the home edges (west is Side A).
    public static func band(of feature: BoardLayout.Feature, tableWidth: Double) -> PlacementBand {
        let away = feature.area.midX - tableWidth / 2
        let d = abs(away)
        if d <= 6 { return .nearCentre }
        if d <= 24 { return .half(side: away < 0 ? "A" : "B") }
        return .beyond
    }

    // MARK: Words

    public static func name(of kind: BoardLayout.FeatureKind) -> String {
        switch kind {
        case .hill: "Hill"
        case .woods: "Woods"
        case .wall: "Wall"
        case .tree: "Tree"
        case .building: "Building"
        case .water: "Water"
        case .rough: "Rough"
        case .rubble: "Rubble"
        case .objectiveToken: "Objective"
        }
    }

    /// What VoiceOver says for one piece (§ 9.6): "Woods, 5 by 5 inches, centre 14 inches from the left, 9 from
    /// the top. Inside Side A's zone."
    public static func spoken(_ feature: BoardLayout.Feature, in board: BoardLayout, sideCount: Int) -> String {
        var text = feature.name.flatMap { $0.isEmpty ? nil : "\($0), " } ?? ""
        text += name(of: feature.kind)
        text += ", \(plain(feature.area.width)) by \(plain(feature.area.depth)) inches, centre \(plain(feature.area.midX)) inches from the left, \(plain(feature.area.midY)) from the top."
        if feature.degrees != 0 { text += " Turned \(plain(feature.degrees)) degrees." }
        if let index = board.features.firstIndex(of: feature), let level = hillLevel(at: index, in: board.features) {
            text += " Level \(plain(level)) inches."
        }
        let sides = zoneWarnings(for: feature, zones: board.zones(sideCount: sideCount))
        if !sides.isEmpty {
            text += " Inside " + sides.map { "Side \($0)’s zone" }.joined(separator: " and ") + "."
        }
        return text
    }

    /// The whole board in a sentence (§ 9.6): "48 by 48 inch table. 2 woods, 1 hill level 2, 1 water. Zones for 4 sides."
    public static func summary(_ board: BoardLayout, sideCount: Int) -> String {
        var parts = ["\(plain(board.width)) by \(plain(board.depth)) inch table."]
        var counts: [String] = []
        for kind in BoardLayout.FeatureKind.allCases {
            let items = board.features.enumerated().filter { $0.element.kind == kind }
            guard !items.isEmpty else { continue }
            if kind == .hill {
                for (index, _) in items {
                    let level = hillLevel(at: index, in: board.features) ?? 1
                    counts.append("1 hill level \(plain(level))")
                }
            } else {
                counts.append("\(items.count) \(name(of: kind).lowercased())")
            }
        }
        parts.append(counts.isEmpty ? "No terrain." : counts.joined(separator: ", ") + ".")
        parts.append("Zones for \(min(max(sideCount, 2), 4)) sides.")
        return parts.joined(separator: " ")
    }

    public static func plain(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
