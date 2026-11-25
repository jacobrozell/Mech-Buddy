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

    /// Full Lances was the last gated mission. Any mission gated later must still refuse to load.
    @Test("Gated missions have no pack and refuse to load")
    func gatedRefuse() throws {
        let gated = try catalog.scenarios().scenarios.filter(\.gated)
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
                // Cards print PV at Skill 4; a better pilot costs more (Quick-Start p. 33).
                let pv = AlphaStrikePointValue.adjusted(base: card.pv, skill: unit.skill)
                #expect(unit.pv == pv && unit.mv == card.mv && unit.tmm == card.tmm, "\(unit.name)")
                #expect(unit.sz == card.sz && unit.s == card.s && unit.m == card.m && unit.l == card.l, "\(unit.name)")
                #expect(unit.ov == card.ov && unit.armor == card.armor && unit.structure == card.structure, "\(unit.name)")
                #expect((1...6).contains(unit.skill) && unit.abilities == card.abilities, "\(unit.name)")
            }
        }
    }

    /// masterunitlist.battletech.com, checked 2026-11-24 (docs/game-modes/alpha-strike/mission-ladder-rules-intake.md).
    static let checkedCards: [ScenarioUnitDTO] = [
        card("Catapult CPLT-C1", pv: 32, mv: "8\"j", tmm: 1, sz: 3, dmg: (2, 3, 2), ov: 1, armor: 5, structure: 5, abilities: "IF1,LRM1/1/1"),
        card("Thunderbolt TDR-5S", pv: 36, mv: "8\"", tmm: 1, sz: 3, dmg: (3, 3, 1), ov: 1, armor: 7, structure: 5, abilities: "IF1"),
        card("Awesome AWS-8Q", pv: 39, mv: "6\"", tmm: 1, sz: 4, dmg: (3, 3, 3), ov: 0, armor: 8, structure: 6, abilities: "ENE"),
        card("BattleMaster BLR-1G", pv: 40, mv: "8\"", tmm: 1, sz: 4, dmg: (3, 3, 1), ov: 1, armor: 8, structure: 7, abilities: "REAR1/1/-"),
        // Alpha Strike Box Set, Meet and Greet (Quick-Start p. 26). MUL unit pages, checked 2026-11-24.
        card("Blackjack BJ-5", pv: 27, mv: "8\"j", tmm: 1, sz: 2, dmg: (2, 3, 3), ov: 0, armor: 5, structure: 2, abilities: "CASEII"),
        card("Phoenix Hawk PXH-4M", pv: 31, mv: "12\"j", tmm: 2, sz: 2, dmg: (3, 3, 1), ov: 0, armor: 5, structure: 2, abilities: "ENE"),
        card("Wasp WSP-5A", pv: 17, mv: "16\"j", tmm: 3, sz: 1, dmg: (1, 1, 0), ov: 0, armor: 2, structure: 1, abilities: "CASEII"),
        card("Locust LCT-7V", pv: 25, mv: "20\"", tmm: 4, sz: 1, dmg: (2, 2, 0), ov: 0, armor: 2, structure: 1, abilities: ""),
        card("Nova T", pv: 42, mv: "10\"j", tmm: 2, sz: 2, dmg: (6, 6, 0), ov: 0, armor: 5, structure: 3, abilities: "CASE, OMNI"),
        card("Pouncer T", pv: 29, mv: "12\"/10\"j", tmm: 2, sz: 2, dmg: (3, 3, 0), ov: 0, armor: 4, structure: 2, abilities: "ENE, HT1/1/-, OMNI")
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

    @Test("Close Quarters: punches and overheat on, 3 vs 3, the two Size 4s on one side, 8 turns")
    func closeQuarters() throws {
        let entry = try #require(try catalog.scenarios().scenarios.first { $0.id == ScenarioId.closeQuarters.rawValue })
        #expect(!entry.gated)
        #expect(entry.release == "1.3.0")
        #expect(entry.icon == "hand.raised.fill")
        #expect(entry.introduces?.contains("Physical attacks") == true)

        let dto = try catalog.scenario(id: .closeQuarters)
        #expect(dto.missionNumber == 4)
        #expect(dto.coachNotes?.contains { $0.contains("Punch or kick") } == true)
        let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
        #expect(ruleset.physicalAttacksAllowed && ruleset.overheatAllowed)
        #expect(!ruleset.forcedWithdrawal)
        #expect(ruleset.maxTurns == 8)
        #expect(ruleset.victory == .destroyAllEnemiesOrStructureAfterTurn(maxTurn: 8))

        let units = GuidedScenarioFactory.makeUnits(from: dto)
        let sideA = units.filter { $0.side == .lanceA }
        let sideB = units.filter { $0.side == .lanceB }
        #expect(sideA.count == 3 && sideB.count == 3)
        let names = Set(sideA.map(\.name))
        #expect(names.isSuperset(of: ["Awesome AWS-8Q", "BattleMaster BLR-1G"]))
        let pvA = sideA.map(\.pv).reduce(0, +)
        let pvB = sideB.map(\.pv).reduce(0, +)
        #expect(abs(pvA - pvB) <= 3, "PV \(pvA) vs \(pvB)")
    }

    @Test("Every mission on the path is playable, so the finish trophy can be earned")
    func wholePathPlayable() throws {
        let items = try catalog.scenarios().scenarios.filter { $0.stage == nil }
        #expect(items.count == 5)
        for item in items {
            #expect(!item.gated, "\(item.id)")
            #expect(item.bundle != nil, "\(item.id)")
        }
    }

    @Test("Full Lances: all eight box 'Mechs, 4 vs 4, every rule and Forced Withdrawal on, 10 turns")
    func fullLances() throws {
        let entry = try #require(try catalog.scenarios().scenarios.first { $0.id == ScenarioId.fullLances.rawValue })
        #expect(!entry.gated)
        #expect(entry.bundle == "as-full-lances.json")
        #expect(entry.release == "1.4.0")
        #expect(entry.icon == "shield.lefthalf.filled")
        #expect(entry.introduces?.contains("Forced Withdrawal") == true)

        let dto = try catalog.scenario(id: .fullLances)
        #expect(dto.missionNumber == 5)
        #expect(dto.coachNotes?.contains { $0.contains("crippled") } == true)
        #expect(dto.coachNotes?.contains { $0.contains("Left the table") } == true)
        let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
        #expect(ruleset.overheatAllowed && ruleset.physicalAttacksAllowed && ruleset.forcedWithdrawal)
        #expect(ruleset.maxTurns == 10)
        #expect(ruleset.victory == .destroyAllEnemiesOrStructureAfterTurn(maxTurn: 10))

        let units = GuidedScenarioFactory.makeUnits(from: dto)
        let sideA = units.filter { $0.side == .lanceA }
        let sideB = units.filter { $0.side == .lanceB }
        #expect(sideA.count == 4 && sideB.count == 4)
        let roster = try catalog.boxRoster().cards.map(\.name)
        #expect(Set(units.map(\.name)) == Set(roster))
        #expect(units.count == roster.count)
        // One of each size per side.
        #expect(sideA.map(\.sz).sorted() == [1, 2, 3, 4])
        #expect(sideB.map(\.sz).sorted() == [1, 2, 3, 4])
        let pvA = sideA.map(\.pv).reduce(0, +)
        let pvB = sideB.map(\.pv).reduce(0, +)
        #expect(pvA == 122 && pvB == 122, "PV \(pvA) vs \(pvB)")
    }

    @Test("Starting Full Lances records Forced Withdrawal on the session")
    func startFullLances() throws {
        let dto = try catalog.scenario(id: .fullLances)
        let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
        let session = try MatchReducer.reduce(
            MatchSession(ruleset: ruleset),
            .startMission(scenarioId: .fullLances, ruleset: ruleset, units: GuidedScenarioFactory.makeUnits(from: dto))
        )
        #expect(session.ruleset.forcedWithdrawal)
        #expect(session.units.count == 8)
        #expect(session.newlyCrippled.isEmpty)
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

@Suite("Meet and Greet and box scenarios")
struct MeetAndGreetTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: MeetAndGreetBundleToken.self))
    }

    @Test("Listed after the training path, in the Alpha Strike box section")
    func catalogEntry() throws {
        let items = try catalog.scenarios().scenarios
        let entry = try #require(items.first { $0.id == "meet-and-greet" })
        #expect(entry.stage == "From the Alpha Strike box")
        #expect(!entry.gated)
        let lastTraining = try #require(items.lastIndex { $0.stage == nil })
        #expect(try #require(items.firstIndex { $0.id == "meet-and-greet" }) > lastTraining)
    }

    @Test("The book's forces: four Highlanders vs two Jade Falcons, book skills, Forced Withdrawal on")
    func forces() throws {
        let dto = try catalog.scenario(id: ScenarioId(rawValue: "meet-and-greet"))
        #expect(dto.sides.lanceA.map(\.skill) == [3, 3, 4, 4])
        #expect(dto.sides.lanceB.map(\.skill) == [2, 3])
        #expect(dto.sides.lanceA.map(\.pv).reduce(0, +) == 111)
        #expect(dto.sides.lanceB.map(\.pv).reduce(0, +) == 93)
        let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
        #expect(ruleset.forcedWithdrawal && ruleset.overheatAllowed && ruleset.physicalAttacksAllowed)
    }

    @Test("Alpha Strike box owners have every mini, exactly, with no stand-ins")
    func boxCoversIt() throws {
        let dto = try catalog.scenario(id: ScenarioId(rawValue: "meet-and-greet"))
        let forces = (dto.sides.lanceA + dto.sides.lanceB).map(\.name)
        let check = CollectionMath.miniCheck(
            forces: forces, collection: OwnedCollection(boxes: ["alpha-strike-box": 1]),
            boxes: try catalog.boxSets().boxes
        )
        #expect(check.hasAll && check.standIns.isEmpty, "\(check.summary)")
    }
}

private final class MeetAndGreetBundleToken {}
