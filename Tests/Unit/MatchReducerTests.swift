import Foundation
import Testing
import MechBuddyDomain

@Suite("MatchReducer")
struct MatchReducerTests {
    private func twoUnits() -> [MatchUnitState] {
        [
            MatchUnitState(name: "A1", side: .lanceA, pv: 1, sz: 1, mv: "10\"", tmm: 1, s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2),
            MatchUnitState(name: "B1", side: .lanceB, pv: 1, sz: 1, mv: "10\"", tmm: 1, s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2)
        ]
    }

    @Test("Start mission then initiative sets loser as active")
    func startAndInitiative() throws {
        let units = twoUnits()
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: units)
        )
        #expect(session.forcesLoaded)
        #expect(session.units.count == 2)

        let rolls = InitiativeRolls(
            lanceA: DiceRoll2D6(die1: 6, die2: 5),
            lanceB: DiceRoll2D6(die1: 1, die2: 1)
        )
        session = try MatchReducer.reduce(session, .setInitiative(rolls))
        #expect(session.initiativeWinner == .lanceA)
        #expect(session.activeSide == .lanceB)
        #expect(session.phase == .movement)
    }

    @Test("Victory after end when one side remains stores outcome")
    func victory() throws {
        let units = [
            MatchUnitState(name: "A1", side: .lanceA, pv: 1, sz: 1, mv: "10\"", tmm: 1, s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2),
            MatchUnitState(name: "B1", side: .lanceB, pv: 1, sz: 1, mv: "10\"", tmm: 1, s: 1, m: 1, l: 0, ov: 0, armorCap: 0, structureCap: 2, structureDamage: 2, combatStatus: .destroyedPendingEnd)
        ]
        var session = MatchSession(
            ruleset: .ridgeLine,
            turn: 1,
            phase: .end,
            units: units,
            status: .active,
            tableReady: true,
            forcesLoaded: true
        )
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        #expect(session.status == MatchStatus.completed)
        #expect(session.outcome == .winner(.lanceA))
    }

    @Test("Second attack by same unit is rejected")
    func rejectsSecondAttack() throws {
        var session = try combatReadySession()
        let attacker = session.units.first { $0.side == .lanceB }!
        let defender = session.units.first { $0.side == .lanceA }!
        let cmd = SATORAttackCommand(
            attackerId: attacker.id,
            defenderId: defender.id,
            range: .short,
            roll: DiceRoll2D6(die1: 6, die2: 6),
            attackerMove: .ground,
            targetMove: .standstill
        )
        session = try MatchReducer.reduce(session, .resolveSATOR(cmd))
        #expect(session.units.first { $0.id == attacker.id }?.hasAttackedThisTurn == true)
        #expect(session.units.first { $0.id == attacker.id }?.turnShot?.hit == true)
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .resolveSATOR(cmd))
        }
    }

    @Test("A miss is recorded on the shooter and does no damage")
    func missStaysVisible() throws {
        var session = try combatReadySession()
        let attacker = session.units.first { $0.side == .lanceB }!
        let defender = session.units.first { $0.side == .lanceA }!
        session = try MatchReducer.reduce(
            session,
            .resolveSATOR(
                SATORAttackCommand(
                    attackerId: attacker.id,
                    defenderId: defender.id,
                    range: .short,
                    roll: DiceRoll2D6(die1: 1, die2: 1),
                    attackerMove: .ground,
                    targetMove: .standstill
                )
            )
        )
        let shot = try #require(session.units.first { $0.id == attacker.id }?.turnShot)
        #expect(shot.hit == false)
        #expect(shot.targetName == defender.name)
        #expect(shot.total == 2)
        #expect(shot.rowTitle == "Missed \(defender.name)")
        #expect(session.units.first { $0.id == defender.id }?.armorDamage == 0)
        #expect(session.eventLog.last?.message.contains("missed") == true)
    }

    @Test("Sprint cannot attack via reducer")
    func sprintCannotAttack() throws {
        var session = try combatReadySession()
        let attackerIdx = session.units.firstIndex { $0.side == .lanceB }!
        session.units[attackerIdx].movementMode = .sprint
        let attacker = session.units[attackerIdx]
        let defender = session.units.first { $0.side == .lanceA }!
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(
                session,
                .resolveSATOR(
                    SATORAttackCommand(
                        attackerId: attacker.id,
                        defenderId: defender.id,
                        range: .short,
                        roll: DiceRoll2D6(die1: 4, die2: 4),
                        attackerMove: .sprint,
                        targetMove: .standstill
                    )
                )
            )
        }
    }

    @Test("Movement alternates activeSide after markMoved")
    func movementAlternates() throws {
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: twoUnits())
        )
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 5),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        #expect(session.activeSide == .lanceB)
        let b = session.units.first { $0.side == .lanceB }!
        session = try MatchReducer.reduce(session, .setMovementMode(unitId: b.id, mode: .ground))
        session = try MatchReducer.reduce(session, .markMoved(unitId: b.id))
        #expect(session.activeSide == .lanceA)
    }

    @Test("Wrong-phase resolveEnd throws")
    func endPhaseGuard() {
        let session = MatchSession(ruleset: .ridgeLine, phase: .combat, tableReady: true, forcesLoaded: true)
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .resolveEndPhase)
        }
    }

    @Test("Finish combat blocked while critical pending")
    func finishBlockedByCrit() throws {
        var session = try combatReadySession()
        let idx = session.units.firstIndex { $0.side == .lanceA }!
        session.units[idx].pendingCritical = true
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .finishCombat)
        }
    }

    @Test("Fire is simultaneous: either side shoots first, one finish ends the phase")
    func simultaneousFire() throws {
        var session = try combatReadySession()
        // The side that would have waited under side-by-side fire shoots first.
        let waiting = session.otherSide(of: session.activeSide)
        let attacker = try #require(session.units.first { $0.side == waiting })
        let target = try #require(session.units.first { $0.side != waiting })
        session = try MatchReducer.reduce(
            session,
            .resolveSATOR(
                SATORAttackCommand(
                    attackerId: attacker.id,
                    defenderId: target.id,
                    range: .short,
                    roll: DiceRoll2D6(die1: 1, die2: 1),
                    attackerMove: .ground,
                    targetMove: .standstill
                )
            )
        )
        #expect(session.units.first { $0.id == attacker.id }?.hasAttackedThisTurn == true)
        // The other side can still fire after the "second" side already did.
        #expect(session.units.contains { $0.side != waiting && $0.canAttackThisTurn })
        session = try MatchReducer.reduce(session, .finishCombat)
        #expect(session.phase == .end)
    }

    @Test("Agreed initiative: chosen side moves first, no dice recorded")
    func agreedInitiative() throws {
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: twoUnits())
        )
        session = try MatchReducer.reduce(session, .agreeInitiative(firstToMove: .lanceB))
        #expect(session.phase == .movement)
        #expect(session.activeSide == .lanceB)
        #expect(session.initiativeWinner == .lanceA)
        #expect(session.initiativeRolls == nil)
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .agreeInitiative(firstToMove: .lanceA))
        }
    }

    @Test("Skip remaining moves records Walk")
    func skipStampsWalk() throws {
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: twoUnits())
        )
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 5),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        session = try MatchReducer.reduce(session, .skipRemainingMoves)
        #expect(session.units.allSatisfy { $0.hasMovedThisTurn && $0.movementMode == .ground })
    }

    @Test("Jump is rejected when the card has no jump")
    func jumpRequiresCard() throws {
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: twoUnits())
        )
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 5),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        let walker = session.units.first { $0.side == .lanceB }!
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .setMovementMode(unitId: walker.id, mode: .jump))
        }

        var jumper = walker
        jumper.mv = "10\"j"
        jumper.id = UUID()
        session.units.append(jumper)
        session = try MatchReducer.reduce(session, .setMovementMode(unitId: jumper.id, mode: .jump))
        #expect(session.units.first { $0.id == jumper.id }?.movementMode == .jump)
    }

    @Test("Revise movement keeps the recorded move and whose turn it is")
    func reviseMovement() throws {
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: twoUnits())
        )
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 5),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        let mover = session.units.first { $0.side == session.activeSide }!
        let sideBefore = session.activeSide
        session = try MatchReducer.reduce(session, .setMovementMode(unitId: mover.id, mode: .ground))
        session = try MatchReducer.reduce(session, .markMoved(unitId: mover.id))
        let flipped = session.activeSide
        session = try MatchReducer.reduce(session, .reviseMovement(unitId: mover.id, mode: .standstill))
        #expect(session.activeSide == flipped)
        #expect(session.activeSide != sideBefore)
        #expect(session.units.first { $0.id == mover.id }?.movementMode == .standstill)
        #expect(session.units.first { $0.id == mover.id }?.hasMovedThisTurn == true)
    }

    @Test("Swap sides until the first move")
    func swapSides() throws {
        let units = twoUnits()
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: units)
        )
        let originalA = session.units.first { $0.side == .lanceA }!.id
        session = try MatchReducer.reduce(session, .swapSides)
        #expect(session.units.first { $0.id == originalA }?.side == .lanceB)
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 3, die2: 3),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        let mover = session.units.first { $0.side == session.activeSide }!
        session = try MatchReducer.reduce(session, .setMovementMode(unitId: mover.id, mode: .ground))
        session = try MatchReducer.reduce(session, .markMoved(unitId: mover.id))
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .swapSides)
        }
    }

    @Test("Hand back keeps a recorded move")
    func handBackKeepsMove() throws {
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine, tableReady: true),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: twoUnits())
        )
        session.tableReady = true
        let beforeMove = session
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 5),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        let mover = session.units.first { $0.side == session.activeSide }!
        let preMove = session
        session = try MatchReducer.reduce(session, .setMovementMode(unitId: mover.id, mode: .sprint))
        session = try MatchReducer.reduce(session, .markMoved(unitId: mover.id))
        let handed = MatchRecovery.handBack(current: session, undoStack: [beforeMove, preMove])
        let restored = try #require(handed)
        #expect(restored.activeSide == preMove.activeSide)
        #expect(restored.units.first { $0.id == mover.id }?.movementMode == .sprint)
        #expect(restored.units.first { $0.id == mover.id }?.hasMovedThisTurn == true)
        #expect(MatchRecovery.handBack(current: restored, undoStack: [beforeMove, preMove]) == nil)
    }

    @Test("A shot waits until the owed critical is rolled")
    func shotBlockedByCrit() throws {
        var session = try combatReadySession()
        let defender = session.units.first { $0.side == .lanceA }!
        session.units[session.units.firstIndex { $0.id == defender.id }!].criticalsOwed = 1
        let attacker = session.units.first { $0.side == .lanceB }!
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(
                session,
                .resolveSATOR(
                    SATORAttackCommand(
                        attackerId: attacker.id,
                        defenderId: defender.id,
                        range: .short,
                        roll: DiceRoll2D6(die1: 6, die2: 6),
                        attackerMove: .ground,
                        targetMove: .standstill
                    )
                )
            )
        }
    }

    @Test("An immobilized ’Mech can only stand still")
    func immobileCannotWalk() throws {
        var session = try combatReadySession()
        session.phase = .movement
        session.activeSide = .lanceB
        let idx = session.units.firstIndex { $0.side == .lanceB }!
        session.units[idx].mv = "0\""
        session.units[idx].hasMovedThisTurn = false
        let id = session.units[idx].id
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .setMovementMode(unitId: id, mode: .ground))
        }
        session = try MatchReducer.reduce(session, .setMovementMode(unitId: id, mode: .standstill))
        #expect(session.units[idx].movementMode == .standstill)
    }

    @Test("Engine heat lands in the End Phase after the unit fires")
    func engineHeatOnFire() throws {
        var session = try combatReadySession()
        let aIdx = session.units.firstIndex { $0.side == .lanceB }!
        // An engine crit carried in from an earlier turn: it is part of this phase's snapshot.
        session.units[aIdx].crits.engineHits = 1
        session.units[aIdx].combatPhaseCrits = session.units[aIdx].crits
        let attacker = session.units[aIdx]
        let defender = session.units.first { $0.side == .lanceA }!
        session = try MatchReducer.reduce(
            session,
            .resolveSATOR(
                SATORAttackCommand(
                    attackerId: attacker.id,
                    defenderId: defender.id,
                    range: .short,
                    roll: DiceRoll2D6(die1: 1, die2: 1),
                    attackerMove: .ground,
                    targetMove: .standstill
                )
            )
        )
        // Heat waits for the End Phase (rulebook: Engine Hit, Cooling Down).
        #expect(session.units[aIdx].heat == 0)
        session.phase = .end
        session = try MatchReducer.reduce(session, .resolveEndPhase)
        let unit = try #require(session.units.first { $0.id == attacker.id })
        #expect(unit.heat == 1)
    }

    private func combatReadySession() throws -> MatchSession {
        var session = try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: twoUnits())
        )
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 5),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        session = try MatchReducer.reduce(session, .skipRemainingMoves)
        session = try MatchReducer.reduce(session, .advancePhase)
        #expect(session.phase == .combat)
        #expect(session.activeSide == .lanceB)
        return session
    }

    @Test("Dice mode sticks and old saves without the field stay manual")
    func diceModeRoundTrip() throws {
        var session = MatchSession(ruleset: .ridgeLine)
        #expect(session.diceMode == .manual)
        session = try MatchReducer.reduce(session, .setDiceMode(.auto))
        #expect(session.diceMode == .auto)

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(MatchSession.self, from: data)
        #expect(decoded.diceMode == .auto)

        // Drop the key structurally: a text replace missed it whenever the encoder wrote it first (no leading comma).
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "diceMode")
        let legacy = try JSONDecoder().decode(MatchSession.self, from: try JSONSerialization.data(withJSONObject: object))
        #expect(legacy.diceMode == .manual)
    }
}
