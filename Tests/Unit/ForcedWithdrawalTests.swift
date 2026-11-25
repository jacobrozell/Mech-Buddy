import Foundation
import Testing
import MechBuddyDomain

/// Crippled 'Mechs, Forced Withdrawal and leaving the table. Alpha Strike Quick-Start Rulebook p. 12.
/// Rules intake: docs/game-modes/alpha-strike/mission-ladder-rules-intake.md §4.
@Suite("Forced Withdrawal")
struct ForcedWithdrawalTests {
    // MARK: Fixtures

    private func thunderbolt(
        side: SideId = .lanceA,
        armorDamage: Int = 0,
        structureDamage: Int = 0,
        crits: CritFlags = CritFlags(),
        heat: Int = 0
    ) -> MatchUnitState {
        MatchUnitState(
            name: "Thunderbolt TDR-5S", side: side, pv: 36, sz: 3, mv: "8\"", tmm: 1,
            s: 3, m: 3, l: 1, ov: 1, armorCap: 7, structureCap: 5,
            armorDamage: armorDamage, structureDamage: structureDamage, heat: heat,
            abilities: "IF1", crits: crits
        )
    }

    private func blr(side: SideId = .lanceB, armorDamage: Int = 0, structureDamage: Int = 0) -> MatchUnitState {
        MatchUnitState(
            name: "BattleMaster BLR-1G", side: side, pv: 40, sz: 4, mv: "8\"", tmm: 1,
            s: 3, m: 3, l: 1, ov: 1, armorCap: 8, structureCap: 7,
            armorDamage: armorDamage, structureDamage: structureDamage, abilities: "REAR1/1/-"
        )
    }

    private func locust(side: SideId = .lanceB, crits: CritFlags = CritFlags()) -> MatchUnitState {
        MatchUnitState(
            name: "Locust LCT-1V", side: side, pv: 18, sz: 1, mv: "16\"", tmm: 3,
            s: 1, m: 1, l: 0, ov: 0, armorCap: 2, structureCap: 2, crits: crits
        )
    }

    private var fullLancesRules: ScenarioRuleset {
        ScenarioRuleset(
            overheatAllowed: true,
            physicalAttacksAllowed: true,
            forcedWithdrawal: true,
            maxTurns: 10,
            victory: .destroyAllEnemiesOrStructureAfterTurn(maxTurn: 10)
        )
    }

    private func session(
        _ units: [MatchUnitState],
        phase: PhaseId,
        activeSide: SideId = .lanceA,
        initiativeWinner: SideId? = .lanceB,
        ruleset: ScenarioRuleset? = nil
    ) -> MatchSession {
        MatchSession(
            ruleset: ruleset ?? fullLancesRules,
            phase: phase,
            activeSide: activeSide,
            initiativeWinner: initiativeWinner,
            units: units,
            status: .active,
            tableReady: true,
            forcesLoaded: true,
            deploymentAcknowledged: true
        )
    }

    // MARK: Crippled

    @Test("No armor and structure at half, rounded up: 5 → 3, 7 → 4, 2 → 1")
    func halfStructureRoundsUp() {
        // Thunderbolt: 7 armor, 5 structure. Half of 5 rounded up is 3.
        #expect(!thunderbolt(armorDamage: 7, structureDamage: 1).isCrippled) // 4 left
        #expect(thunderbolt(armorDamage: 7, structureDamage: 2).isCrippled) // 3 left
        #expect(thunderbolt(armorDamage: 7, structureDamage: 3).isCrippled) // 2 left
        // BattleMaster: 7 structure, half rounded up is 4.
        #expect(!blr(armorDamage: 8, structureDamage: 2).isCrippled) // 5 left
        #expect(blr(armorDamage: 8, structureDamage: 3).isCrippled) // 4 left
        // Locust: 2 structure, half is 1.
        var light = locust()
        light.armorDamage = 2
        #expect(!light.isCrippled)
        light.structureDamage = 1
        #expect(light.isCrippled)
    }

    @Test("Armor left means not crippled, however low the structure")
    func armorLeftIsNotCrippled() {
        #expect(!thunderbolt(armorDamage: 6, structureDamage: 4).isCrippled)
        #expect(!thunderbolt(armorDamage: 7).isCrippled)
        #expect(!thunderbolt().isCrippled)
    }

    @Test("Medium and Long both 0 after weapon hits")
    func mediumAndLongGone() {
        // Locust prints 1/1/0: one weapon hit takes Medium to 0.
        #expect(!locust().isCrippled)
        #expect(locust(crits: CritFlags(weaponHits: 1)).isCrippled)
        // Thunderbolt prints 3/3/1: Long goes first, Medium only after three hits.
        #expect(!thunderbolt(crits: CritFlags(weaponHits: 1)).isCrippled)
        #expect(!thunderbolt(crits: CritFlags(weaponHits: 2)).isCrippled)
        #expect(thunderbolt(crits: CritFlags(weaponHits: 3)).isCrippled)
    }

    @Test("A card that prints 0 Medium and 0 Long was never reduced, so it isn't crippled by that")
    func printedZeroIsNotReduced() {
        let shortOnly = MatchUnitState(
            name: "Short only", side: .lanceA, pv: 10, sz: 1, mv: "10\"", tmm: 2,
            s: 2, m: 0, l: 0, ov: 0, armorCap: 2, structureCap: 2
        )
        #expect(!shortOnly.isCrippled)
    }

    @Test("Immobilized by MP hits; a heat shutdown doesn't count")
    func immobilized() {
        // 8″ → 4″ → 2″ → 0″.
        #expect(!thunderbolt(crits: CritFlags(mpHits: 2)).isCrippled)
        let stuck = thunderbolt(crits: CritFlags(mpHits: 3))
        #expect(stuck.isImmobilizedByCrits)
        #expect(stuck.isCrippled)
        let shutDown = thunderbolt(heat: 4)
        #expect(shutDown.isImmobile)
        #expect(!shutDown.isCrippled)
    }

    @Test("Must withdraw only with Forced Withdrawal on and the 'Mech still on the table")
    func mustWithdrawNeedsTheRule() {
        let hurt = locust(crits: CritFlags(weaponHits: 1))
        #expect(session([thunderbolt(), hurt], phase: .movement).mustWithdraw(hurt))
        #expect(!session([thunderbolt(), hurt], phase: .movement, ruleset: .ridgeLine).mustWithdraw(hurt))
        var wreck = hurt
        wreck.combatStatus = .destroyedPendingEnd
        #expect(!session([thunderbolt(), wreck], phase: .combat).mustWithdraw(wreck))
    }

    // MARK: End Phase

    @Test("The End Phase says once that a 'Mech is crippled")
    func endPhaseAnnouncesOnce() throws {
        let start = session([thunderbolt(), blr(), locust(crits: CritFlags(weaponHits: 1))], phase: .end)
        #expect(start.newlyCrippled.map(\.name) == ["Locust LCT-1V"])

        let next = try MatchReducer.reduce(start, .resolveEndPhase)
        let line = "Locust LCT-1V is crippled and must withdraw"
        #expect(next.eventLog.filter { $0.message == line }.count == 1)
        #expect(next.newlyCrippled.isEmpty)
        #expect(next.mustWithdraw(next.units[2]))

        var later = next
        later.phase = .end
        let again = try MatchReducer.reduce(later, .resolveEndPhase)
        #expect(again.eventLog.filter { $0.message == line }.count == 1)
    }

    @Test("No crippled line without Forced Withdrawal")
    func noAnnouncementWithoutTheRule() throws {
        let start = session(
            [thunderbolt(), blr(), locust(crits: CritFlags(weaponHits: 1))],
            phase: .end,
            ruleset: .ridgeLine
        )
        #expect(start.newlyCrippled.isEmpty)
        let next = try MatchReducer.reduce(start, .resolveEndPhase)
        #expect(!next.eventLog.contains { $0.message.contains("crippled") })
    }

    @Test("A crippled 'Mech can still attack")
    func crippledStillShoots() throws {
        let hurt = thunderbolt(armorDamage: 7, structureDamage: 3)
        var start = session([hurt, blr()], phase: .combat)
        start.units[0].movementMode = .ground
        start.units[0].hasMovedThisTurn = true
        #expect(start.units[0].canAttackThisTurn)
        let next = try MatchReducer.reduce(start, .resolveSATOR(SATORAttackCommand(
            attackerId: start.units[0].id,
            defenderId: start.units[1].id,
            range: .short,
            roll: DiceRoll2D6(die1: 6, die2: 6),
            targetMove: .standstill
        )))
        #expect(next.units[0].hasAttackedThisTurn)
    }

    // MARK: Leaving the table

    @Test("Left the table: removed, logged, and counts as destroyed for victory")
    func leftTableIsDestroyed() throws {
        var start = session([thunderbolt(), blr(), locust()], phase: .combat)
        for i in start.units.indices {
            start.units[i].hasMovedThisTurn = true
            start.units[i].movementMode = .ground
        }
        let bmID = start.units[1].id
        let afterBM = try MatchReducer.reduce(start, .leaveTable(unitId: bmID))
        let bm = try #require(afterBM.units.first { $0.id == bmID })
        #expect(bm.combatStatus == .removed)
        #expect(bm.leftTable)
        #expect(!bm.canFire)
        #expect(afterBM.eventLog.last?.message == "BattleMaster BLR-1G left the table")
        // Its structure no longer counts.
        #expect(VictoryEvaluator.remainingStructure(side: .lanceB, in: afterBM) == 2)

        let afterLocust = try MatchReducer.reduce(afterBM, .leaveTable(unitId: afterBM.units[2].id))
        #expect(VictoryEvaluator.livingSides(in: afterLocust) == [.lanceA])

        let done = try MatchReducer.reduce(try MatchReducer.reduce(afterLocust, .finishCombat), .resolveEndPhase)
        #expect(done.status == .completed)
        #expect(done.outcome == .winner(.lanceA))
        // Leaving isn't wrecking: the End Phase keeps it as it was.
        #expect(done.units[1].leftTable && done.units[1].combatStatus == .removed)
    }

    @Test("Undo: the session before Left the table is unchanged, and Back sees a result to discard")
    func leftTableIsUndoable() throws {
        var start = session([thunderbolt(), blr()], phase: .combat)
        for i in start.units.indices { start.units[i].hasMovedThisTurn = true }
        let next = try MatchReducer.reduce(start, .leaveTable(unitId: start.units[1].id))
        #expect(start.units[1].combatStatus == .active)
        #expect(!start.units[1].leftTable)
        #expect(MatchRecovery.discardsResults(current: next, restoring: start))
    }

    @Test("Leaving on its own move keeps the move order alternating")
    func leaveOnItsMove() throws {
        // Side B won initiative, so Side A moves first: A, B, A, B.
        let units = [thunderbolt(side: .lanceA), locust(side: .lanceA), blr(side: .lanceB), locust(side: .lanceB)]
        let start = session(units, phase: .movement, activeSide: .lanceA)
        let first = try MatchReducer.reduce(start, .leaveTable(unitId: units[1].id))
        #expect(first.units[1].leftTable)
        #expect(first.units[1].hasMovedThisTurn)
        #expect(first.activeSide == .lanceB)
        #expect(AlphaStrikePhaseEngine.movesRecorded(units: first.units) == 1)

        let second = try MatchReducer.reduce(first, .markMoved(unitId: units[2].id))
        #expect(second.activeSide == .lanceA)
        let third = try MatchReducer.reduce(second, .markMoved(unitId: units[0].id))
        #expect(third.activeSide == .lanceB)
        let fourth = try MatchReducer.reduce(third, .markMoved(unitId: units[3].id))
        #expect(AlphaStrikePhaseEngine.movementComplete(units: fourth.units))

        // Next turn it's out of the order: 1 vs 2 moves A, B, B.
        var reset = fourth.units
        AlphaStrikePhaseEngine.resetTurnFlags(&reset)
        #expect(!reset[1].hasMovedThisTurn)
        #expect(AlphaStrikePhaseEngine.movementSequence(firstToMove: .lanceA, units: reset) == [.lanceA, .lanceB, .lanceB])
    }

    @Test("Can't record leaving for the other side's 'Mech mid-move, while a crit is owed, or twice")
    func leaveBlocked() throws {
        let units = [thunderbolt(side: .lanceA), blr(side: .lanceB)]
        let moving = session(units, phase: .movement, activeSide: .lanceA)
        #expect(moving.leaveTableBlockReason(moving.units[1]) == "Record this on its move.")
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(moving, .leaveTable(unitId: units[1].id))
        }

        var owed = session(units, phase: .combat)
        owed.units[0].criticalsOwed = 1
        #expect(owed.leaveTableBlockReason(owed.units[1]) == "Roll the critical first.")

        var gone = session(units, phase: .combat)
        gone.units[1].hasMovedThisTurn = true
        let left = try MatchReducer.reduce(gone, .leaveTable(unitId: units[1].id))
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(left, .leaveTable(unitId: units[1].id))
        }
    }

    @Test("Left the table and the crippled flag survive a save; old saves decode as false")
    func persistence() throws {
        var unit = locust()
        unit.leftTable = true
        unit.withdrawalAnnounced = true
        unit.combatStatus = .removed
        let data = try JSONEncoder().encode(unit)
        let decoded = try JSONDecoder().decode(MatchUnitState.self, from: data)
        #expect(decoded.leftTable && decoded.withdrawalAnnounced)

        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "leftTable")
        json.removeValue(forKey: "withdrawalAnnounced")
        let old = try JSONDecoder().decode(MatchUnitState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!old.leftTable && !old.withdrawalAnnounced)
    }
}
