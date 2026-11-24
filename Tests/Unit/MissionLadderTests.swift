import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

@Suite("Mission ladder")
struct MissionLadderTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: LadderBundleToken.self))
    }

    @Test("Ladder is numbered 1…n with no gaps, Ridge Line first")
    func numbering() throws {
        let items = try catalog.scenarios().scenarios
        let numbers = items.compactMap(\.missionNumber).sorted()
        #expect(numbers.count == items.count)
        #expect(numbers == Array(1...items.count))
        let first = try #require(items.first { $0.missionNumber == 1 })
        #expect(first.id == ScenarioId.ridgeLine.rawValue)
    }

    @Test("Every playable mission loads, matches its id, and builds two sides")
    func playableLoad() throws {
        for item in try catalog.scenarios().scenarios where !item.gated {
            let dto = try catalog.scenario(id: ScenarioId(rawValue: item.id))
            #expect(dto.scenarioId == item.id)
            #expect(dto.title == item.title)
            #expect(dto.missionNumber == item.missionNumber)
            let units = GuidedScenarioFactory.makeUnits(from: dto)
            #expect(!units.filter { $0.side == .lanceA }.isEmpty, "\(item.id)")
            #expect(!units.filter { $0.side == .lanceB }.isEmpty, "\(item.id)")
            #expect(!dto.tableSteps.isEmpty, "\(item.id)")
        }
    }

    @Test("Gated missions have no pack and refuse to load")
    func gatedRefuse() throws {
        let gated = try catalog.scenarios().scenarios.filter(\.gated)
        #expect(!gated.isEmpty)
        for item in gated {
            #expect(item.bundle == nil, "\(item.id)")
            #expect(item.comingSoonSummary?.isEmpty == false, "\(item.id)")
            #expect(throws: ContentLoadError.self) {
                try catalog.scenario(id: ScenarioId(rawValue: item.id))
            }
        }
    }

    @Test("Unknown mission id throws")
    func unknown() {
        #expect(throws: ContentLoadError.self) {
            try catalog.scenario(id: ScenarioId(rawValue: "no-such-mission"))
        }
    }

    /// Card numbers are only trusted once checked against the Master Unit List.
    /// Ridge Line's four were checked first; `checkedCards` holds the box 'Mechs checked later.
    @Test("Every mission uses only checked card numbers")
    func cardsAreChecked() throws {
        let golden = try catalog.ridgeLineScenario()
        var checked = Dictionary(
            uniqueKeysWithValues: (golden.sides.lanceA + golden.sides.lanceB).map { ($0.name, $0) }
        )
        for card in Self.checkedCards {
            checked[card.name] = card
        }
        for item in try catalog.scenarios().scenarios where !item.gated {
            let dto = try catalog.scenario(id: ScenarioId(rawValue: item.id))
            for unit in dto.sides.lanceA + dto.sides.lanceB {
                let card = try #require(checked[unit.name], "\(item.id): \(unit.name) has no checked card")
                #expect(unit.pv == card.pv && unit.mv == card.mv && unit.tmm == card.tmm, "\(unit.name)")
                #expect(unit.sz == card.sz && unit.s == card.s && unit.m == card.m && unit.l == card.l, "\(unit.name)")
                #expect(unit.ov == card.ov && unit.armor == card.armor && unit.structure == card.structure, "\(unit.name)")
                #expect(unit.skill == card.skill && unit.abilities == card.abilities, "\(unit.name)")
            }
        }
    }

    /// masterunitlist.battletech.com, checked 2026-11-24 (docs/game-modes/alpha-strike/mission-ladder-rules-intake.md).
    static let checkedCards: [ScenarioUnitDTO] = [
        card("Catapult CPLT-C1", pv: 32, mv: "8\"j", tmm: 1, sz: 3, dmg: (2, 3, 2), ov: 1, armor: 5, structure: 5, abilities: "IF1,LRM1/1/1"),
        card("Thunderbolt TDR-5S", pv: 36, mv: "8\"", tmm: 1, sz: 3, dmg: (3, 3, 1), ov: 1, armor: 7, structure: 5, abilities: "IF1"),
        card("Awesome AWS-8Q", pv: 39, mv: "6\"", tmm: 1, sz: 4, dmg: (3, 3, 3), ov: 0, armor: 8, structure: 6, abilities: "ENE"),
        card("BattleMaster BLR-1G", pv: 40, mv: "8\"", tmm: 1, sz: 4, dmg: (3, 3, 1), ov: 1, armor: 8, structure: 7, abilities: "REAR1/1/-")
    ]

    private static func card(
        _ name: String, pv: Int, mv: String, tmm: Int, sz: Int, dmg: (Int, Int, Int),
        ov: Int, armor: Int, structure: Int, abilities: String
    ) -> ScenarioUnitDTO {
        ScenarioUnitDTO(
            name: name, pv: pv, mv: mv, tmm: tmm, sz: sz, s: dmg.0, m: dmg.1, l: dmg.2,
            ov: ov, armor: armor, structure: structure, skill: 4, abilities: abilities
        )
    }

    @Test("Running Hot: overheat on, one OV heavy per side, 8 turns")
    func runningHot() throws {
        let dto = try catalog.scenario(id: .runningHot)
        #expect(dto.missionNumber == 3)
        let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
        #expect(ruleset.overheatAllowed)
        #expect(!ruleset.physicalAttacksAllowed && !ruleset.forcedWithdrawal)
        #expect(ruleset.maxTurns == 8)
        let units = GuidedScenarioFactory.makeUnits(from: dto)
        for side in SideId.allCases {
            #expect(units.filter { $0.side == side && $0.ov > 0 }.count == 1, "\(side)")
        }
    }

    @Test("Broken Ground: new pairings, 8 turns, no overheat or melee yet")
    func brokenGround() throws {
        let dto = try catalog.scenario(id: .brokenGround)
        #expect(dto.missionNumber == 2)
        #expect(dto.introduces?.isEmpty == false)
        let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
        #expect(ruleset.maxTurns == 8)
        #expect(ruleset.victory == .destroyAllEnemiesOrStructureAfterTurn(maxTurn: 8))
        #expect(!ruleset.overheatAllowed && !ruleset.physicalAttacksAllowed && !ruleset.forcedWithdrawal)
        // Each side has exactly one jumper.
        let units = GuidedScenarioFactory.makeUnits(from: dto)
        for side in SideId.allCases {
            #expect(units.filter { $0.side == side && $0.canJump }.count == 1, "\(side)")
        }
    }

    @Test("Starting Broken Ground records its scenario id and turn cap")
    func startBrokenGround() throws {
        let dto = try catalog.scenario(id: .brokenGround)
        let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
        let session = try MatchReducer.reduce(
            MatchSession(ruleset: ruleset),
            .startMission(scenarioId: .brokenGround, ruleset: ruleset, units: GuidedScenarioFactory.makeUnits(from: dto))
        )
        #expect(session.scenarioId == .brokenGround)
        #expect(session.ruleset.maxTurns == 8)
        #expect(session.units.count == 4)
        let decoded = try JSONDecoder().decode(MatchSession.self, from: JSONEncoder().encode(session))
        #expect(decoded.scenarioId == .brokenGround)
    }
}

private final class LadderBundleToken {}
