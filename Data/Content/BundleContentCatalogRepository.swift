import Foundation
import MechBuddyDomain

public enum ContentLoadError: Error, Sendable, Equatable, LocalizedError {
    case missingResource(String)
    case unsupportedSchema(Int)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing content: \(name)"
        case .unsupportedSchema(let version):
            return "Unsupported content schema \(version)"
        case .decodingFailed(let message):
            return message
        }
    }
}

public protocol ContentSchemaVersioned {
    var schemaVersion: Int { get }
}

public protocol ContentCatalogRepository: Sendable {
    func gameModesManifest() throws -> GameModesManifestDTO
    /// The playable mission with this id. Throws when the catalog has no bundle for it (gated or unknown).
    func scenario(id: ScenarioId) throws -> GuidedScenarioDTO
    func boxRoster() throws -> BoxRosterDTO
    /// Every Alpha Strike card face from the owner's boxes (PlayModeSpec §10).
    func cardLibrary() throws -> CardLibraryDTO
    /// Boxes a player can own, for onboarding and the Force tab collection.
    func boxSets() throws -> BoxSetsDTO
    func critTable() throws -> CritTableDTO
    func rulesTopics() throws -> RulesTopicsDTO
    /// Alpha Strike, Classic, and the shared "how the games differ" pack, for the Rules tab.
    func rulesLibrary() throws -> RulesLibrary
    func gettingStarted() throws -> GettingStartedDTO
    func scenarios() throws -> ScenariosCatalogDTO
    /// General BattleTech history for the Lore section (reached from the Rules tab).
    func lore() throws -> LoreDocumentDTO
}

public extension ContentCatalogRepository {
    func ridgeLineScenario() throws -> GuidedScenarioDTO {
        try scenario(id: .ridgeLine)
    }
}

public struct BundleContentCatalogRepository: ContentCatalogRepository, Sendable {
    public static let supportedSchemaVersion = 1

    private let bundle: Bundle
    private let decoder: JSONDecoder

    public init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.decoder = JSONDecoder()
    }

    public func gameModesManifest() throws -> GameModesManifestDTO {
        try load("game-modes-manifest", subdirectory: "Content", as: GameModesManifestDTO.self)
    }

    public func scenario(id: ScenarioId) throws -> GuidedScenarioDTO {
        let entry = try scenarios().scenarios.first { $0.id == id.rawValue }
        guard let entry, !entry.gated, let bundleFile = entry.bundle else {
            throw ContentLoadError.missingResource(id.rawValue)
        }
        let name = bundleFile.hasSuffix(".json") ? String(bundleFile.dropLast(5)) : bundleFile
        let dto = try load(name, subdirectory: "Content/AlphaStrike", as: GuidedScenarioDTO.self)
        guard dto.scenarioId == id.rawValue else {
            throw ContentLoadError.decodingFailed("\(name): scenarioId \(dto.scenarioId) does not match \(id.rawValue)")
        }
        return dto
    }

    public func boxRoster() throws -> BoxRosterDTO {
        try load("as-box-roster", subdirectory: "Content/AlphaStrike", as: BoxRosterDTO.self)
    }

    public func cardLibrary() throws -> CardLibraryDTO {
        try load("as-card-library", subdirectory: "Content/AlphaStrike", as: CardLibraryDTO.self)
    }

    /// Classic record sheets for the A Game of Armored Combat booklet. Not on the protocol until Classic ships.
    public func classicSheets() throws -> ClassicSheetsDTO {
        try load("classic-agoac-sheets", subdirectory: "Content/Classic", as: ClassicSheetsDTO.self)
    }

    /// Known maps for name suggestions. Not on the protocol: only the collection editor uses it.
    public func mapCatalog() throws -> MapCatalogDTO {
        try load("map-catalog", subdirectory: "Content", as: MapCatalogDTO.self)
    }

    /// The terrain palette's sizes and rules copy for the board builder (PlayModeSpec § 9.3). Not on the protocol: only Play's builder uses it.
    public func terrainPalette() throws -> TerrainPaletteFile {
        try load("as-terrain-palette", subdirectory: "Content/AlphaStrike", as: TerrainPaletteFile.self)
    }

    public func boxSets() throws -> BoxSetsDTO {
        try load("as-box-sets", subdirectory: "Content/AlphaStrike", as: BoxSetsDTO.self)
    }

    public func critTable() throws -> CritTableDTO {
        try load("as-crit-table", subdirectory: "Content/AlphaStrike", as: CritTableDTO.self)
    }

    public func rulesTopics() throws -> RulesTopicsDTO {
        try load("as-rules-topics", subdirectory: "Content/AlphaStrike", as: RulesTopicsDTO.self)
    }

    /// Classic BattleTech rules topics. Reading only: Classic isn't playable in the app yet.
    public func classicRulesTopics() throws -> RulesTopicsDTO {
        try load("classic-rules-topics", subdirectory: "Content/Classic", as: RulesTopicsDTO.self)
    }

    /// Pages tagged `both`, such as how the two games differ.
    public func sharedRulesTopics() throws -> RulesTopicsDTO {
        try load("rules-both-games", subdirectory: "Content", as: RulesTopicsDTO.self)
    }

    public func rulesLibrary() throws -> RulesLibrary {
        RulesLibrary(packs: [try rulesTopics(), try classicRulesTopics(), try sharedRulesTopics()])
    }

    public func gettingStarted() throws -> GettingStartedDTO {
        try load("as-getting-started", subdirectory: "Content/AlphaStrike", as: GettingStartedDTO.self)
    }

    public func scenarios() throws -> ScenariosCatalogDTO {
        try load("as-scenarios", subdirectory: "Content/AlphaStrike", as: ScenariosCatalogDTO.self)
    }

    public func lore() throws -> LoreDocumentDTO {
        try load("battletech-lore", subdirectory: "Content/Lore", as: LoreDocumentDTO.self)
    }

    private func load<T: Decodable>(
        _ name: String,
        subdirectory: String?,
        as type: T.Type
    ) throws -> T {
        let candidates: [URL?] = [
            subdirectory.flatMap { bundle.url(forResource: name, withExtension: "json", subdirectory: $0) },
            bundle.url(forResource: name, withExtension: "json", subdirectory: "AlphaStrike"),
            bundle.url(forResource: name, withExtension: "json")
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw ContentLoadError.missingResource(name)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ContentLoadError.decodingFailed(error.localizedDescription)
        }
        let decoded: T
        do {
            decoded = try decoder.decode(T.self, from: data)
        } catch {
            throw ContentLoadError.decodingFailed("\(name): \(error)")
        }
        if let versioned = decoded as? any ContentSchemaVersioned {
            guard versioned.schemaVersion == Self.supportedSchemaVersion else {
                throw ContentLoadError.unsupportedSchema(versioned.schemaVersion)
            }
        }
        return decoded
    }
}

public enum GuidedScenarioFactory {
    public static func makeUnits(from scenario: GuidedScenarioDTO) -> [MatchUnitState] {
        var units: [MatchUnitState] = []
        units += scenario.sides.lanceA.map { mapUnit($0, side: .lanceA) }
        units += scenario.sides.lanceB.map { mapUnit($0, side: .lanceB) }
        return units
    }

    public static func mapRuleset(_ dto: ScenarioRulesetDTO) -> ScenarioRuleset {
        let victory: VictoryRule
        if dto.victory.type == "destroyAllEnemiesOrStructureAfterTurn",
           let maxTurn = dto.victory.maxTurn {
            victory = .destroyAllEnemiesOrStructureAfterTurn(maxTurn: maxTurn)
        } else {
            victory = .destroyAllEnemies
        }
        return ScenarioRuleset(
            overheatAllowed: dto.overheatAllowed,
            physicalAttacksAllowed: dto.physicalAttacksAllowed,
            forcedWithdrawal: dto.forcedWithdrawal,
            maxTurns: dto.maxTurns,
            victory: victory
        )
    }

    /// The box rules for a new match, tied to the units `makeUnits` made. Nil when the scenario has none.
    public static func makeBoxRules(from scenario: GuidedScenarioDTO, units: [MatchUnitState]) -> BoxRulesState? {
        guard let setup = scenario.boxRules else { return nil }
        func id(_ name: String) -> UUID? { units.first { $0.name == name }?.id }
        var support: [SideId: SupportInventory] = [:]
        if let points = setup.battlefieldSupportPoints {
            for side in Set(units.map(\.side)) { support[side] = SupportInventory(budget: points) }
        }
        let formations = setup.formations.compactMap { f -> FormationState? in
            guard let kind = FormationKind(rawValue: f.kind) else { return nil }
            return FormationState(
                id: f.id, kind: kind, name: f.name, memberIds: f.members.compactMap(id),
                commandUnitId: f.commandUnit.flatMap(id),
                combatIntuitionCount: f.combatIntuitionCount ?? 0,
                luckyUsesLeft: f.luckyUses ?? 0
            )
        }
        let buildings = setup.buildings.compactMap { b -> BuildingState? in
            guard let type = BuildingType(rawValue: b.type) else { return nil }
            return BuildingState(id: b.id, name: b.name, type: type, cf: b.cf, heightInches: b.heightInches ?? 2)
        }
        return BoxRulesState(support: support, formations: formations, buildings: buildings)
    }

    public static func mapUnit(_ dto: ScenarioUnitDTO, side: SideId) -> MatchUnitState {
        MatchUnitState(
            name: dto.name,
            side: side,
            skill: dto.skill,
            pv: dto.pv,
            sz: dto.sz,
            mv: dto.mv,
            tmm: dto.tmm,
            s: dto.s,
            m: dto.m,
            l: dto.l,
            ov: dto.ov,
            armorCap: dto.armor,
            structureCap: dto.structure,
            abilities: dto.abilities,
            minimalDamage: dto.minimalDamage
        )
    }
}
