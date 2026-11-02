import Foundation
import Testing
import MechBuddyDomain

@Suite("Battle coach and launch")
struct BattleCoachTests {
    private func twoUnits(aMoved: Bool = false) -> [MatchUnitState] {
        [
            MatchUnitState(
                name: "A1", side: .lanceA, pv: 1, sz: 1, mv: "10\"", tmm: 1,
                s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2,
                movementMode: aMoved ? .ground : .unset, hasMovedThisTurn: aMoved
            ),
            MatchUnitState(
                name: "B1", side: .lanceB, pv: 1, sz: 1, mv: "10\"", tmm: 1,
                s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2
            )
        ]
    }

    private func started() throws -> MatchSession {
        try MatchReducer.reduce(
            MatchSession(ruleset: .ridgeLine),
            .startMission(scenarioId: .ridgeLine, ruleset: .ridgeLine, units: twoUnits())
        )
    }

    @Test("Setup, initiative, then placement are distinct steps")
    func placementIsAStep() throws {
        var session = try started()
        #expect(BattleCoach(session: session).step == .tableSetup)
        #expect(BattleCoach(session: session).primary == nil)

        session = try MatchReducer.reduce(session, .markTableReady)
        let initiative = BattleCoach(session: session)
        #expect(initiative.step == .initiative)
        #expect(initiative.primary == .useInitiativeRolls)
        #expect(initiative.canSwapSides)

        session.diceMode = .auto
        #expect(BattleCoach(session: session).primary == .rollInitiative)

        session.diceMode = .manual
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 5),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        let placing = BattleCoach(session: session)
        #expect(placing.step == .placeMiniatures)
        #expect(placing.primary == .acknowledgeDeployment)

        session = try MatchReducer.reduce(session, .acknowledgeDeployment)
        let moving = BattleCoach(session: session)
        #expect(session.deploymentAcknowledged)
        #expect(moving.step == .movement)
        #expect(moving.primary == nil)

        session = try MatchReducer.reduce(session, .skipRemainingMoves)
        #expect(BattleCoach(session: session).primary == .startShooting)
    }

    @Test("A saved move counts as placed even without the new flag")
    func legacyMoveSkipsPlacement() {
        let session = MatchSession(
            ruleset: .ridgeLine,
            phase: .movement,
            units: twoUnits(aMoved: true),
            tableReady: true,
            deploymentAcknowledged: false
        )
        #expect(BattleCoach(session: session).step == .movement)
    }

    @Test("Old saves without deploymentAcknowledged still decode")
    func legacyDecode() throws {
        let session = MatchSession(ruleset: .ridgeLine, phase: .movement, tableReady: true)
        let data = try JSONEncoder().encode(session)
        let json = try #require(String(data: data, encoding: .utf8))
        let stripped = json.replacingOccurrences(of: "\"deploymentAcknowledged\":false,", with: "")
        #expect(!stripped.contains("deploymentAcknowledged"))
        let legacy = try JSONDecoder().decode(MatchSession.self, from: Data(stripped.utf8))
        #expect(legacy.deploymentAcknowledged == false)
        #expect(BattleCoach(session: legacy).step == .placeMiniatures)
    }

    @Test("Placement cannot be confirmed once the turn has moved on")
    func acknowledgeOnlyAtPlacement() throws {
        let session = try started()
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .acknowledgeDeployment)
        }
    }

    @Test("Swap hides after the first move, and a critical owns the primary action")
    func swapAndCritical() throws {
        var session = try started()
        session = try MatchReducer.reduce(session, .markTableReady)
        session = try MatchReducer.reduce(
            session,
            .setInitiative(
                InitiativeRolls(
                    lanceA: DiceRoll2D6(die1: 6, die2: 5),
                    lanceB: DiceRoll2D6(die1: 1, die2: 1)
                )
            )
        )
        session = try MatchReducer.reduce(session, .acknowledgeDeployment)
        let mover = try #require(session.units.first { $0.side == session.activeSide })
        session = try MatchReducer.reduce(session, .setMovementMode(unitId: mover.id, mode: .ground))
        session = try MatchReducer.reduce(session, .markMoved(unitId: mover.id))
        #expect(BattleCoach(session: session).canSwapSides == false)

        session = try MatchReducer.reduce(session, .skipRemainingMoves)
        session = try MatchReducer.reduce(session, .advancePhase)
        let combat = BattleCoach(session: session)
        #expect(combat.step == .combat)
        #expect(combat.primary == .solveShot)
        #expect(combat.finishCombatNeedsConfirm)

        var owed = session
        let idx = try #require(owed.units.firstIndex { $0.side == owed.activeSide })
        owed.units[idx].criticalsOwed = 1
        let crit = BattleCoach(session: owed)
        #expect(crit.pendingCritical?.unitName == owed.units[idx].name)
        #expect(crit.primary == .rollCritical(count: 1))
        #expect(crit.finishCombatNeedsConfirm == false)
    }

    @Test("Starting a mission does not discard an active save unless asked")
    func launchPolicy() {
        let active = MatchSession(ruleset: .ridgeLine, status: .active)
        let finished = MatchSession(ruleset: .ridgeLine, status: .completed)
        #expect(MatchLaunch.decide(existingActive: nil, replaceActive: false) == .startFresh)
        #expect(MatchLaunch.decide(existingActive: finished, replaceActive: false) == .startFresh)
        #expect(MatchLaunch.decide(existingActive: active, replaceActive: false) == .blocked)
        #expect(MatchLaunch.decide(existingActive: active, replaceActive: true) == .replace(active.id))
    }

    @Test("Last turn and a wipe tell the clean-up button to finish")
    func endHints() {
        let units = twoUnits()
        let mid = MatchSession(
            ruleset: .ridgeLine,
            turn: 3,
            phase: .end,
            units: units,
            tableReady: true,
            deploymentAcknowledged: true
        )
        let midCoach = BattleCoach(session: mid)
        #expect(midCoach.step == .end)
        #expect(midCoach.isLastTurn == false)
        #expect(midCoach.endWouldFinishMatch == false)
        #expect(midCoach.primary == .resolveEnd)

        var last = mid
        last.turn = 6
        let lastCoach = BattleCoach(session: last)
        #expect(lastCoach.isLastTurn)
        #expect(lastCoach.endWouldFinishMatch)

        var moving = last
        moving.phase = .movement
        #expect(BattleCoach(session: moving).isLastTurn)
        #expect(BattleCoach(session: moving).endWouldFinishMatch)

        var wiped = mid
        wiped.turn = 2
        wiped.units[1].combatStatus = .destroyedPendingEnd
        let wipedCoach = BattleCoach(session: wiped)
        #expect(wipedCoach.isLastTurn == false)
        #expect(wipedCoach.endWouldFinishMatch)

        let open = ScenarioRuleset(
            overheatAllowed: false,
            physicalAttacksAllowed: false,
            forcedWithdrawal: false,
            maxTurns: nil,
            victory: .destroyAllEnemies
        )
        let endless = MatchSession(
            ruleset: open,
            turn: 9,
            phase: .end,
            units: units,
            tableReady: true,
            deploymentAcknowledged: true
        )
        #expect(BattleCoach(session: endless).isLastTurn == false)
        #expect(BattleCoach(session: endless).endWouldFinishMatch == false)
    }
}
