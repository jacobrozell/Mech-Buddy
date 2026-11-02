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

public struct RidgeLineScenarioDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var scenarioId: String
    public var title: String
    public var subtitle: String?
    public var estimatedMinutes: Int?
    public var ruleset: RidgeRulesetDTO
    public var sides: RidgeSidesDTO
    public var tableSteps: [String]
    public var winningSummary: String?
    public var coachNotes: [String]?
}

public struct RidgeRulesetDTO: Codable, Sendable {
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

public struct RidgeSidesDTO: Codable, Sendable {
    public var lanceA: [RidgeUnitDTO]
    public var lanceB: [RidgeUnitDTO]
}

public struct RidgeUnitDTO: Codable, Sendable {
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
    public var bundle: String?
    public var release: String?
    public var gated: Bool
    public var comingSoonSummary: String?
}
