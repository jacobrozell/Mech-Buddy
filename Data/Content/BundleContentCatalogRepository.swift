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
    func ridgeLineScenario() throws -> RidgeLineScenarioDTO
    func boxRoster() throws -> BoxRosterDTO
    func critTable() throws -> CritTableDTO
    func rulesTopics() throws -> RulesTopicsDTO
    func gettingStarted() throws -> GettingStartedDTO
    func scenarios() throws -> ScenariosCatalogDTO
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

    public func ridgeLineScenario() throws -> RidgeLineScenarioDTO {
        try load("as-ridge-line", subdirectory: "Content/AlphaStrike", as: RidgeLineScenarioDTO.self)
    }

    public func boxRoster() throws -> BoxRosterDTO {
        try load("as-box-roster", subdirectory: "Content/AlphaStrike", as: BoxRosterDTO.self)
    }

    public func critTable() throws -> CritTableDTO {
        try load("as-crit-table", subdirectory: "Content/AlphaStrike", as: CritTableDTO.self)
    }

    public func rulesTopics() throws -> RulesTopicsDTO {
        try load("as-rules-topics", subdirectory: "Content/AlphaStrike", as: RulesTopicsDTO.self)
    }

    public func gettingStarted() throws -> GettingStartedDTO {
        try load("as-getting-started", subdirectory: "Content/AlphaStrike", as: GettingStartedDTO.self)
    }

    public func scenarios() throws -> ScenariosCatalogDTO {
        try load("as-scenarios", subdirectory: "Content/AlphaStrike", as: ScenariosCatalogDTO.self)
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

public enum RidgeLineFactory {
    public static func makeUnits(from scenario: RidgeLineScenarioDTO) -> [MatchUnitState] {
        var units: [MatchUnitState] = []
        units += scenario.sides.lanceA.map { mapUnit($0, side: .lanceA) }
        units += scenario.sides.lanceB.map { mapUnit($0, side: .lanceB) }
        return units
    }

    public static func mapRuleset(_ dto: RidgeRulesetDTO) -> ScenarioRuleset {
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

    private static func mapUnit(_ dto: RidgeUnitDTO, side: SideId) -> MatchUnitState {
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
            abilities: dto.abilities
        )
    }
}
