import Foundation
import MechBuddyDomain

// MARK: - DTOs matching Resources/Content JSON

public struct GameModesManifestDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var modes: [GameModeDTO]
}

public struct GameModeDTO: Codable, Sendable {
    public var id: String
    public var displayName: String
    public var shortLabel: String?
    public var playEngine: String
    public var availability: String
    public var catalogBundle: String?
    public var capabilities: CapabilitiesDTO
}

public struct CapabilitiesDTO: Codable, Sendable {
    public var showsGuidedMission: Bool
    public var showsSATOR: Bool
    public var showsArmorStructurePips: Bool
    public var showsHitLocations: Bool
    public var showsHeatScale: Bool
    public var showsPVBalance: Bool
    public var showsPhysicalAttacks: Bool
    public var allowsMULPasteImport: Bool
}

/// One ready-made guided mission (Ridge Line and the missions after it).
public struct GuidedScenarioDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var scenarioId: String
    public var title: String
    public var subtitle: String?
    /// Place in the mission ladder, starting at 1. Omitted by older packs.
    public var missionNumber: Int?
    /// Short names of what this mission adds over the one before it. Empty for the first mission.
    public var introduces: [String]?
    public var estimatedMinutes: Int?
    public var ruleset: ScenarioRulesetDTO
    public var sides: ScenarioSidesDTO
    public var tableSteps: [String]
    public var winningSummary: String?
    public var coachNotes: [String]?
    /// Maps needed and a top-down table diagram. Optional in older packs.
    public var layout: MissionLayoutDTO?
}

public struct ScenarioRulesetDTO: Codable, Sendable {
    public var overheatAllowed: Bool
    public var physicalAttacksAllowed: Bool
    public var forcedWithdrawal: Bool
    public var maxTurns: Int?
    public var victory: VictoryDTO
}

public struct VictoryDTO: Codable, Sendable {
    public var type: String
    public var maxTurn: Int?
}

public struct ScenarioSidesDTO: Codable, Sendable {
    public var lanceA: [ScenarioUnitDTO]
    public var lanceB: [ScenarioUnitDTO]
}

/// A card damage value as printed: a number, or the string "0*" for minimal damage (rulebook p. 21).
/// Plain JSON numbers keep decoding as before; "0*" decodes to 0 plus a minimal flag.
struct PrintedDamage {
    var value: Int
    var minimal: Bool

    static func decode<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) throws -> PrintedDamage {
        if let n = try? c.decode(Int.self, forKey: key) { return PrintedDamage(value: n, minimal: false) }
        let text = try c.decode(String.self, forKey: key)
        guard let parsed = MinimalDamage.parse(text) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Bad damage value \(text)")
        }
        return PrintedDamage(value: parsed.value, minimal: parsed.minimal)
    }

    static func encode<K: CodingKey>(_ value: Int, minimal: Bool, _ c: inout KeyedEncodingContainer<K>, _ key: K) throws {
        if minimal { try c.encode("0*", forKey: key) } else { try c.encode(value, forKey: key) }
    }
}

public struct ScenarioUnitDTO: Codable, Sendable {
    public var name: String
    public var pv: Int
    public var mv: String
    public var tmm: Int
    public var sz: Int
    public var s: Int
    public var m: Int
    public var l: Int
    /// Bands printed "0*". The matching `s`/`m`/`l` is 0. JSON writes it as the string "0*".
    public var minimalDamage: MinimalDamageBands
    public var ov: Int
    public var armor: Int
    public var structure: Int
    public var skill: Int
    public var abilities: String

    public init(
        name: String, pv: Int, mv: String, tmm: Int, sz: Int, s: Int, m: Int, l: Int,
        ov: Int, armor: Int, structure: Int, skill: Int, abilities: String,
        minimalDamage: MinimalDamageBands = .none
    ) {
        self.name = name
        self.pv = pv
        self.mv = mv
        self.tmm = tmm
        self.sz = sz
        self.s = s
        self.m = m
        self.l = l
        self.minimalDamage = minimalDamage
        self.ov = ov
        self.armor = armor
        self.structure = structure
        self.skill = skill
        self.abilities = abilities
    }

    private enum CodingKeys: String, CodingKey {
        case name, pv, mv, tmm, sz, s, m, l, ov, armor, structure, skill, abilities
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        pv = try c.decode(Int.self, forKey: .pv)
        mv = try c.decode(String.self, forKey: .mv)
        tmm = try c.decode(Int.self, forKey: .tmm)
        sz = try c.decode(Int.self, forKey: .sz)
        let ps = try PrintedDamage.decode(c, .s)
        let pm = try PrintedDamage.decode(c, .m)
        let pl = try PrintedDamage.decode(c, .l)
        s = ps.value
        m = pm.value
        l = pl.value
        minimalDamage = MinimalDamageBands(short: ps.minimal, medium: pm.minimal, long: pl.minimal)
        ov = try c.decode(Int.self, forKey: .ov)
        armor = try c.decode(Int.self, forKey: .armor)
        structure = try c.decode(Int.self, forKey: .structure)
        skill = try c.decode(Int.self, forKey: .skill)
        abilities = try c.decode(String.self, forKey: .abilities)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(pv, forKey: .pv)
        try c.encode(mv, forKey: .mv)
        try c.encode(tmm, forKey: .tmm)
        try c.encode(sz, forKey: .sz)
        try PrintedDamage.encode(s, minimal: minimalDamage.short, &c, .s)
        try PrintedDamage.encode(m, minimal: minimalDamage.medium, &c, .m)
        try PrintedDamage.encode(l, minimal: minimalDamage.long, &c, .l)
        try c.encode(ov, forKey: .ov)
        try c.encode(armor, forKey: .armor)
        try c.encode(structure, forKey: .structure)
        try c.encode(skill, forKey: .skill)
        try c.encode(abilities, forKey: .abilities)
    }
}

public struct BoxRosterDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var cards: [BoxCardDTO]
}

public struct BoxCardDTO: Codable, Sendable {
    public var name: String
    public var back: String?
    public var sz: Int
    public var defaultSide: String
    public var pv: Int?
    public var mv: String?
    public var tmm: Int?
    public var s: Int?
    public var m: Int?
    public var l: Int?
    public var ov: Int?
    public var armor: Int?
    public var structure: Int?
    public var skill: Int?
    public var abilities: String?
    /// Bands printed "0*" (the matching s/m/l decodes to 0). JSON writes them as the string "0*".
    public var minimalDamage: MinimalDamageBands = .none

    private enum CodingKeys: String, CodingKey {
        case name, back, sz, defaultSide, pv, mv, tmm, s, m, l, ov, armor, structure, skill, abilities
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        back = try c.decodeIfPresent(String.self, forKey: .back)
        sz = try c.decode(Int.self, forKey: .sz)
        defaultSide = try c.decode(String.self, forKey: .defaultSide)
        pv = try c.decodeIfPresent(Int.self, forKey: .pv)
        mv = try c.decodeIfPresent(String.self, forKey: .mv)
        tmm = try c.decodeIfPresent(Int.self, forKey: .tmm)
        let ps = try c.contains(.s) && !c.decodeNil(forKey: .s) ? PrintedDamage.decode(c, .s) : nil
        let pm = try c.contains(.m) && !c.decodeNil(forKey: .m) ? PrintedDamage.decode(c, .m) : nil
        let pl = try c.contains(.l) && !c.decodeNil(forKey: .l) ? PrintedDamage.decode(c, .l) : nil
        s = ps?.value
        m = pm?.value
        l = pl?.value
        minimalDamage = MinimalDamageBands(short: ps?.minimal ?? false, medium: pm?.minimal ?? false, long: pl?.minimal ?? false)
        ov = try c.decodeIfPresent(Int.self, forKey: .ov)
        armor = try c.decodeIfPresent(Int.self, forKey: .armor)
        structure = try c.decodeIfPresent(Int.self, forKey: .structure)
        skill = try c.decodeIfPresent(Int.self, forKey: .skill)
        abilities = try c.decodeIfPresent(String.self, forKey: .abilities)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(back, forKey: .back)
        try c.encode(sz, forKey: .sz)
        try c.encode(defaultSide, forKey: .defaultSide)
        try c.encodeIfPresent(pv, forKey: .pv)
        try c.encodeIfPresent(mv, forKey: .mv)
        try c.encodeIfPresent(tmm, forKey: .tmm)
        if let s { try PrintedDamage.encode(s, minimal: minimalDamage.short, &c, .s) }
        if let m { try PrintedDamage.encode(m, minimal: minimalDamage.medium, &c, .m) }
        if let l { try PrintedDamage.encode(l, minimal: minimalDamage.long, &c, .l) }
        try c.encodeIfPresent(ov, forKey: .ov)
        try c.encodeIfPresent(armor, forKey: .armor)
        try c.encodeIfPresent(structure, forKey: .structure)
        try c.encodeIfPresent(skill, forKey: .skill)
        try c.encodeIfPresent(abilities, forKey: .abilities)
    }
}


public struct CritTableDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var entries: [CritEntryDTO]
}

public struct CritEntryDTO: Codable, Sendable {
    public var roll: Int
    public var id: String
    public var title: String
    public var effect: String?
}

public struct RulesTopicsDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var disclaimer: String?
    public var topics: [RulesTopicDTO]

    public init(schemaVersion: Int, contentVersion: String, disclaimer: String?, topics: [RulesTopicDTO]) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.disclaimer = disclaimer
        self.topics = topics
    }
}

public struct RulesTopicDTO: Codable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var screenId: String?
    /// One-line row summary. Omitted by older packs; the rules list falls back to the first sentence.
    public var summary: String?
    /// `start`, `during`, or `reference`. Omitted by older packs; the rules list maps by topic id.
    public var group: String?
    /// Which game the topic belongs to. Every bundled topic sets it; the content tests check.
    public var game: RulesGameTag?
    public var sections: [RulesSectionDTO]

    public init(
        id: String,
        title: String,
        screenId: String? = nil,
        summary: String? = nil,
        group: String? = nil,
        game: RulesGameTag? = nil,
        sections: [RulesSectionDTO]
    ) {
        self.id = id
        self.title = title
        self.screenId = screenId
        self.summary = summary
        self.group = group
        self.game = game
        self.sections = sections
    }
}

public struct RulesSectionDTO: Codable, Sendable {
    public var heading: String
    public var body: String

    public init(heading: String, body: String) {
        self.heading = heading
        self.body = body
    }
}

public struct GettingStartedDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var items: [GettingStartedItemDTO]
}

public struct GettingStartedItemDTO: Codable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var detail: String?
    public var linkURL: String?
}

public struct ScenariosCatalogDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var scenarios: [ScenarioCatalogItemDTO]
}

public struct ScenarioCatalogItemDTO: Codable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var subtitle: String?
    /// Place in the mission ladder, starting at 1.
    public var missionNumber: Int?
    /// What this mission adds over the one before it.
    public var introduces: [String]?
    public var bundle: String?
    public var release: String?
    public var gated: Bool
    public var comingSoonSummary: String?
    /// SF Symbol for the mission's node on the Play path.
    public var icon: String?
    /// `nil` for the training path. Otherwise the title of a later section, such as
    /// "From the Alpha Strike box", shown below the training path's trophy.
    public var stage: String?
}

/// `as-box-sets.json`: the boxes a player can say they own. Unit names only, never card numbers.
public struct BoxSetsDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var sourceNote: String?
    public var boxes: [BoxSetDTO]
    /// Mission chassis → closest minis from other boxes, best first. Optional in older files.
    public var standIns: [String: [String]]?
}

/// `map-catalog.json`: known mapsheets and BattleMats by product, for map name suggestions.
public struct MapCatalogDTO: Codable, Sendable, ContentSchemaVersioned {
    public struct Product: Codable, Sendable, Equatable {
        public var name: String
        public var year: Int?
        public var maps: [String]
    }

    public var schemaVersion: Int
    public var contentVersion: String
    public var sourceNote: String?
    public var products: [Product]

    /// Every map name once, in catalog order (first spelling wins, compared ignoring case).
    public var allMaps: [String] {
        var seen = Set<String>()
        return products.flatMap(\.maps).filter { seen.insert($0.lowercased()).inserted }
    }

    /// Up to `limit` names containing `text` (ignoring case), names that start with it first.
    public func suggestions(for text: String, limit: Int = 5) -> [String] {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard query.count >= 2 else { return [] }
        let hits = allMaps.filter { $0.lowercased().contains(query) }
        let starts = hits.filter { $0.lowercased().hasPrefix(query) }
        let rest = hits.filter { !$0.lowercased().hasPrefix(query) }
        return Array((starts + rest).prefix(limit))
    }
}

public struct BoxSetDTO: Codable, Sendable, Identifiable, Equatable {
    public enum Game: String, Codable, Sendable {
        case alphaStrike
        case classic
        case both
    }

    public var id: String
    public var title: String
    public var subtitle: String
    public var game: Game
    /// Miniatures in the box, vehicles included. Can be more than `units` when the list isn't confirmed.
    public var miniCount: Int
    /// Unit names as printed. A variant code is kept when the publisher states it.
    public var units: [String]
    /// Box ids this one needs to play (Mercenaries needs A Game of Armored Combat).
    public var requires: [String]?
    public var sourceURL: String
    /// False when the unit list isn't confirmed: `units` is empty and the player adds them by hand.
    public var contentsConfirmed: Bool
    /// Paper maps in the box, one name per printed side, as printed. `nil` when the names aren't known.
    public var maps: [String]?
    /// Map sheets in the box (a double-sided sheet counts once), shown when `maps` is unknown.
    public var mapSheets: Int?

    public init(
        id: String, title: String, subtitle: String, game: Game, miniCount: Int,
        units: [String], requires: [String]? = nil, sourceURL: String, contentsConfirmed: Bool,
        maps: [String]? = nil, mapSheets: Int? = nil
    ) {
        self.maps = maps
        self.mapSheets = mapSheets
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.game = game
        self.miniCount = miniCount
        self.units = units
        self.requires = requires
        self.sourceURL = sourceURL
        self.contentsConfirmed = contentsConfirmed
    }
}


/// A mission's table, drawn top-down like the scenario layouts in A Game of Armored Combat.
/// Inches, origin top-left. `width` runs from Side A's home edge (left) to Side B's (right).
public struct MissionLayoutDTO: Codable, Sendable, Equatable {
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
    }

    /// A printed mapsheet laid on the table, named as printed ("Grassland #2").
    public struct Sheet: Codable, Sendable, Equatable {
        public var name: String
        public var area: Rect

        public init(name: String, area: Rect) {
            self.name = name
            self.area = area
        }
    }

    /// Where a side sets up. `side` is "A" or "B".
    public struct Zone: Codable, Sendable, Equatable {
        public var side: String
        public var area: Rect

        public init(side: String, area: Rect) {
            self.side = side
            self.area = area
        }
    }

    public enum FeatureKind: String, Codable, Sendable, CaseIterable {
        case hill, woods, wall, tree
    }

    /// Terrain to add on an open table. On printed maps, the map's own terrain is used instead.
    public struct Feature: Codable, Sendable, Equatable {
        public var kind: FeatureKind
        public var area: Rect

        public init(kind: FeatureKind, area: Rect) {
            self.kind = kind
            self.area = area
        }
    }

    public var width: Double
    public var depth: Double
    /// Suggested mapsheets. Empty when the mission is played on an open table.
    public var sheets: [Sheet]
    public var zones: [Zone]
    public var features: [Feature]
    /// What to use without the maps, e.g. "Any open table, 36 × 22 inches".
    public var openTable: String

    public init(width: Double, depth: Double, sheets: [Sheet], zones: [Zone], features: [Feature], openTable: String) {
        self.width = width
        self.depth = depth
        self.sheets = sheets
        self.zones = zones
        self.features = features
        self.openTable = openTable
    }

    /// "Grassland #2 and Desert #2".
    public var sheetNames: [String] { sheets.map(\.name) }
}
