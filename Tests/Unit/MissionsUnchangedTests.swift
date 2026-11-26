import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

/// PlayModeSpec § 20 "Missions": every mission plays exactly as before PM1.
///
/// Each playable mission (Ridge Line, Broken Ground, Running Hot, Close Quarters, Full Lances, Meet and Greet)
/// is played to the end many times with seeded dice. At every step the reducer's answer is checked against a
/// copy of the pre-PM1 two-side rules kept here: initiative (higher wins, lower moves first, ties re-roll,
/// same log line), the p. 14 move order, who is active in Combat, and the result (wipe, Forced Withdrawal,
/// Structure cap, draw). No "is out" line and no `.tied` ever appear in a two-side game.
@Suite("Missions unchanged by N-side domain")
struct MissionsUnchangedTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: MissionsUnchangedToken.self))
    }

    @Test("Every playable mission is covered")
    func coverage() throws {
        let ids = try catalog.scenarios().scenarios.filter { !$0.gated }.map(\.id)
        for id in ["ridge-line", "broken-ground", "running-hot", "close-quarters", "full-lances", "meet-and-greet"] {
            #expect(ids.contains(id), "\(id)")
        }
    }

    @Test("Seeded playthroughs follow the pre-PM1 two-side rules", arguments: 0..<12)
    func playthroughs(seed: Int) throws {
        for item in try catalog.scenarios().scenarios where !item.gated {
            let dto = try catalog.scenario(id: ScenarioId(rawValue: item.id))
            var rng = SeededRandom(seed: UInt64(seed * 7919 + item.id.count))
            try play(dto, scenarioId: ScenarioId(rawValue: item.id), rng: &rng)
        }
    }

    private func play(_ dto: GuidedScenarioDTO, scenarioId: ScenarioId, rng: inout SeededRandom) throws {
        let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
        var s = try MatchReducer.reduce(
            MatchSession(ruleset: ruleset),
            .startMission(scenarioId: scenarioId, ruleset: ruleset, units: GuidedScenarioFactory.makeUnits(from: dto))
        )
        s = try MatchReducer.reduce(s, .markTableReady)
        #expect(s.sides == MatchSide.missionPair)
        var turns = 0
        while s.status == .active, turns < 30 {
            turns += 1
            s = try initiative(s, rng: &rng)
            s = try movement(s, rng: &rng)
            s = try combat(s, rng: &rng)
            s = try endPhase(s)
        }
        #expect(s.status == .completed, "\(scenarioId.rawValue) never finished")
        #expect(!s.eventLog.contains { $0.message.hasSuffix(" is out.") })
        if case .tied = s.outcome { Issue.record("Two-side game ended .tied") }
    }

    private func initiative(_ session: MatchSession, rng: inout SeededRandom) throws -> MatchSession {
        // Agree the order now and then, like "Skip the roll".
        if rng.next(6) == 0 {
            let first: SideId = rng.next(2) == 0 ? .lanceA : .lanceB
            let s = try MatchReducer.reduce(session, .agreeInitiative(firstToMove: first))
            #expect(s.initiativeWinner == legacyOther(first))
            #expect(s.activeSide == legacyFirstMover(loser: first, units: s.units))
            return s
        }
        while true {
            let a = rng.roll(), b = rng.roll()
            let rolls = InitiativeRolls(lanceA: a, lanceB: b)
            guard a.total != b.total else {
                #expect(throws: MatchDomainError.initiativeTied) { try MatchReducer.reduce(session, .setInitiative(rolls)) }
                continue
            }
            let s = try MatchReducer.reduce(session, .setInitiative(rolls))
            let winner: SideId = a.total > b.total ? .lanceA : .lanceB
            #expect(s.initiativeWinner == winner)
            #expect(s.phase == .movement)
            #expect(s.activeSide == legacyFirstMover(loser: legacyOther(winner), units: s.units))
            #expect(s.eventLog.last?.message == "Initiative: \(a.total) to \(b.total). \(winner.displayName) goes last")
            return s
        }
    }

    private func movement(_ session: MatchSession, rng: inout SeededRandom) throws -> MatchSession {
        var s = session
        if s.needsDeploymentAcknowledgement {
            s = try MatchReducer.reduce(s, .acknowledgeDeployment)
        }
        let loser = legacyOther(try #require(s.initiativeWinner))
        while !AlphaStrikePhaseEngine.movementComplete(units: s.units) {
            let mover = try #require(AlphaStrikePhaseEngine.unitsNeedingMove(side: s.activeSide, units: s.units).first)
            let before = s.activeSide
            if rng.next(25) == 0, s.leaveTableBlockReason(mover) == nil {
                s = try MatchReducer.reduce(s, .leaveTable(unitId: mover.id))
            } else {
                s = try MatchReducer.reduce(s, .markMoved(unitId: mover.id))
            }
            #expect(s.activeSide == legacyNextActive(current: before, units: s.units, firstToMove: loser))
        }
        s = try MatchReducer.reduce(s, .advancePhase)
        #expect(s.activeSide == loser)
        return s
    }

    private func combat(_ session: MatchSession, rng: inout SeededRandom) throws -> MatchSession {
        var s = session
        for attacker in s.units where attacker.canAttackThisTurn {
            let targets = s.units.filter { $0.side != attacker.side && $0.combatStatus != .removed }
            guard !targets.isEmpty else { continue }
            let target = targets[rng.next(targets.count)]
            let shot = SATORAttackCommand(
                attackerId: attacker.id,
                defenderId: target.id,
                range: [.short, .medium, .long][rng.next(3)],
                roll: rng.roll(),
                targetMove: .groundUsesTMM,
                minimalDie: rng.next(6) + 1
            )
            do {
                s = try MatchReducer.reduce(s, .resolveSATOR(shot))
            } catch MatchDomainError.cannotAttack {
                continue
            }
            while let owed = s.units.first(where: \.pendingCritical) {
                s = try MatchReducer.reduce(s, .applyCritical(unitId: owed.id, roll: rng.roll()))
            }
        }
        return try MatchReducer.reduce(s, .finishCombat)
    }

    private func endPhase(_ session: MatchSession) throws -> MatchSession {
        let s = try MatchReducer.reduce(session, .resolveEndPhase)
        if s.status == .completed {
            #expect(s.outcome == legacyOutcome(s))
        } else {
            #expect(legacyWipe(s) == nil)
            #expect(s.initiativeOrder.isEmpty)
        }
        return s
    }

    // MARK: - Pre-PM1 rules, copied

    private func legacyOther(_ side: SideId) -> SideId { side == .lanceA ? .lanceB : .lanceA }

    private func legacyFirstMover(loser: SideId, units: [MatchUnitState]) -> SideId {
        legacyMovementSequence(firstToMove: loser, second: legacyOther(loser), units: units).first ?? loser
    }

    private func legacyNextActive(current: SideId, units: [MatchUnitState], firstToMove: SideId) -> SideId {
        let sequence = legacyMovementSequence(firstToMove: firstToMove, second: legacyOther(firstToMove), units: units)
        let moved = AlphaStrikePhaseEngine.movesRecorded(units: units)
        return moved < sequence.count ? sequence[moved] : current
    }

    private func legacyLiving(_ s: MatchSession) -> Set<SideId> {
        Set(s.units.filter { $0.combatStatus == .active && !(s.ruleset.forcedWithdrawal && $0.isCrippled) }.map(\.side))
    }

    private func legacyWipe(_ s: MatchSession) -> MatchOutcome? {
        let living = legacyLiving(s)
        if living.count == 1, let winner = living.first { return .winner(winner) }
        if living.isEmpty { return .draw }
        return nil
    }

    private func legacyOutcome(_ s: MatchSession) -> MatchOutcome? {
        if let wipe = legacyWipe(s) { return wipe }
        if case .destroyAllEnemiesOrStructureAfterTurn(let maxTurn) = s.ruleset.victory, s.turn >= maxTurn {
            let a = VictoryEvaluator.remainingStructure(side: .lanceA, in: s)
            let b = VictoryEvaluator.remainingStructure(side: .lanceB, in: s)
            return a > b ? .winner(.lanceA) : b > a ? .winner(.lanceB) : .draw
        }
        return nil
    }
}

/// SplitMix64: the same dice for the same seed on every run.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next(_ bound: Int) -> Int {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Int(z % UInt64(bound))
    }

    mutating func roll() -> DiceRoll2D6 {
        DiceRoll2D6(die1: next(6) + 1, die2: next(6) + 1)
    }
}

private final class MissionsUnchangedToken {}
