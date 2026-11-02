import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

@Suite("Ridge Line simulation")
struct RidgeLineSimulationTests {
    @Test("Wipe win ends on or before turn 6")
    func wipeWin() throws {
        var session = try startedRidgeLine()
        var witness = Witness()
        try playGame(&session, witness: &witness, shotsHit: true)
        #expect(session.status == .completed)
        #expect(session.turn <= 6)
        guard case .winner = session.outcome else {
            Issue.record("Expected a winner")
            return
        }
    }

    @Test("Turn-6 structure tiebreak is a draw when every shot misses")
    func turnSixDraw() throws {
        var session = try startedRidgeLine()
        var witness = Witness()
        try playGame(&session, witness: &witness, shotsHit: false)
        #expect(session.status == .completed)
        #expect(session.turn == 6)
        #expect(session.outcome == .draw)
        #expect(session.units.allSatisfy { $0.armorDamage == 0 && $0.structureDamage == 0 })
    }

    @Test("Codec round-trip mid-game")
    func codecRoundTrip() throws {
        var session = try startedRidgeLine()
        var witness = Witness()
        try playTurn(&session, witness: &witness, shotsHit: true)
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(MatchSession.self, from: data)
        #expect(decoded == session)
    }

    private func startedRidgeLine() throws -> MatchSession {
        let catalog = BundleContentCatalogRepository(bundle: Bundle(for: BundleToken.self))
        let scenario = try catalog.ridgeLineScenario()
        let units = RidgeLineFactory.makeUnits(from: scenario)
        let ruleset = RidgeLineFactory.mapRuleset(scenario.ruleset)
        var session = MatchSession(ruleset: ruleset)
        var witness = Witness()
        try play(
            &session,
            .startMission(scenarioId: .ridgeLine, ruleset: ruleset, units: units),
            witness: &witness
        )
        try play(&session, .markTableReady, witness: &witness)
        return session
    }

    private func playGame(_ session: inout MatchSession, witness: inout Witness, shotsHit: Bool) throws {
        var turnsPlayed = 0
        while session.status == .active {
            turnsPlayed += 1
            if turnsPlayed > 6 {
                Issue.record("Game did not finish by turn 6")
                return
            }
            try playTurn(&session, witness: &witness, shotsHit: shotsHit)
        }
    }

    private func playTurn(_ session: inout MatchSession, witness: inout Witness, shotsHit: Bool) throws {
        try play(
            &session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 6),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            ),
            witness: &witness
        )
        try moveStandstill(&session, witness: &witness)
        try shootSide(&session, witness: &witness, shotsHit: shotsHit)
        try play(&session, .finishCombatSide, witness: &witness)
        try shootSide(&session, witness: &witness, shotsHit: shotsHit)
        try play(&session, .finishCombatSide, witness: &witness)
        try play(&session, .resolveEndPhase, witness: &witness)
    }

    private func moveStandstill(_ session: inout MatchSession, witness: inout Witness) throws {
        if session.needsDeploymentAcknowledgement {
            try play(&session, .acknowledgeDeployment, witness: &witness)
        }
        var steps = 0
        while !AlphaStrikePhaseEngine.movementComplete(units: session.units) {
            steps += 1
            if steps > 8 {
                Issue.record("Movement did not finish")
                return
            }
            guard let unit = session.units.first(where: {
                $0.side == session.activeSide && $0.combatStatus == .active && !$0.hasMovedThisTurn
            }) else {
                Issue.record("No unit left to move")
                return
            }
            try play(&session, .setMovementMode(unitId: unit.id, mode: .standstill), witness: &witness)
            try play(&session, .markMoved(unitId: unit.id), witness: &witness)
        }
        try play(&session, .advancePhase, witness: &witness)
    }

    private func shootSide(_ session: inout MatchSession, witness: inout Witness, shotsHit: Bool) throws {
        let roll = shotsHit ? DiceRoll2D6(die1: 6, die2: 5) : DiceRoll2D6(die1: 1, die2: 1)
        var steps = 0
        while steps < 16 {
            steps += 1
            if let owed = session.units.first(where: { $0.criticalsOwed > 0 }) {
                try play(
                    &session,
                    .applyCritical(unitId: owed.id, roll: DiceRoll2D6(die1: 5, die2: 4)),
                    witness: &witness
                )
                continue
            }
            guard let attacker = session.units.first(where: {
                $0.side == session.activeSide && $0.canAttackThisTurn
            }), let target = session.units.first(where: {
                $0.side != attacker.side && $0.combatStatus == .active
            }) else {
                return
            }
            try play(
                &session,
                .resolveSATOR(
                    SATORAttackCommand(
                        attackerId: attacker.id,
                        defenderId: target.id,
                        range: .short,
                        roll: roll,
                        targetMove: .standstill
                    )
                ),
                witness: &witness
            )
        }
        Issue.record("Combat did not finish")
    }

    private func play(_ session: inout MatchSession, _ command: MatchCommand, witness: inout Witness) throws {
        let turnBefore = session.turn
        let phaseBefore = session.phase
        session = try MatchReducer.reduce(session, command)
        #expect(session.turn >= turnBefore)
        #expect(phaseAdvances(from: phaseBefore, to: session.phase))
        for unit in session.units {
            #expect(unit.armorDamage >= 0 && unit.armorDamage <= unit.armorCap)
            #expect(unit.structureDamage >= 0 && unit.structureDamage <= unit.structureCap)
            #expect(unit.criticalsOwed >= 0)
            #expect((0...4).contains(unit.heat))
            if unit.combatStatus == .removed {
                if let attackedWhenRemoved = witness.removedAttacked[unit.id] {
                    if attackedWhenRemoved == false {
                        #expect(unit.hasAttackedThisTurn == false)
                    }
                } else {
                    witness.removedAttacked[unit.id] = unit.hasAttackedThisTurn
                }
            }
        }
        let coach = BattleCoach(session: session)
        if coach.step == .initiative || coach.step == .combat || coach.step == .end {
            #expect(coach.primary != nil)
        }
    }

    private func phaseAdvances(from: PhaseId, to: PhaseId) -> Bool {
        if from == to { return true }
        switch (from, to) {
        case (.initiative, .movement), (.movement, .combat), (.combat, .end), (.end, .initiative):
            return true
        default:
            return false
        }
    }
}

private struct Witness {
    var removedAttacked: [UUID: Bool] = [:]
}

private final class BundleToken {}
