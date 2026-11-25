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

public struct ScenarioUnitDTO: Codable, Sendable {
    public var name: String
    public var pv: Int
    public var mv: String
    public var tmm: Int
    public var sz: Int
    public var s: Int
    public var m: Int
    public var l: Int
    public var ov: Int
    public var armor: Int
    public var structure: Int
    public var skill: Int
    public var abilities: String

    public init(
        name: String, pv: Int, mv: String, tmm: Int, sz: Int, s: Int, m: Int, l: Int,
        ov: Int, armor: Int, structure: Int, skill: Int, abilities: String
    ) {
        self.name = name
        self.pv = pv
        self.mv = mv
        self.tmm = tmm
        self.sz = sz
        self.s = s
        self.m = m
        self.l = l
        self.ov = ov
        self.armor = armor
        self.structure = structure
        self.skill = skill
        self.abilities = abilities
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
}

public struct RulesTopicDTO: Codable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var screenId: String?
    /// One-line row summary. Omitted by older packs; the rules list falls back to the first sentence.
    public var summary: String?
    /// `start`, `during`, or `reference`. Omitted by older packs; the rules list maps by topic id.
    public var group: String?
    public var sections: [RulesSectionDTO]
}

public struct RulesSectionDTO: Codable, Sendable {
    public var heading: String
    public var body: String
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

    public init(
        id: String, title: String, subtitle: String, game: Game, miniCount: Int,
        units: [String], requires: [String]? = nil, sourceURL: String, contentsConfirmed: Bool
    ) {
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
