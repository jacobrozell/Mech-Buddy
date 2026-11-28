// Behaviour and edge-case tests for domain code the older suites skip: small value types, Codable
// shapes (including old saves), error paths in the reducers, and the Back/undo recovery rules.
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

private final class GapBundleToken {}

private func gapUnit(_ name: String, _ side: SideId, sz: Int = 2, armor: Int = 4, structure: Int = 2) -> MatchUnitState {
    MatchUnitState(name: name, side: side, skill: 3, pv: 30, sz: sz, mv: "10\"", tmm: 2,
                   s: 3, m: 3, l: 1, ov: 0, armorCap: armor, structureCap: structure)
}

private func gapSession(phase: PhaseId = .movement, turn: Int = 1) -> MatchSession {
    MatchSession(ruleset: .ridgeLine, turn: turn, phase: phase,
                 units: [gapUnit("A1", .lanceA), gapUnit("B1", .lanceB)],
                 status: .active, tableReady: true, forcesLoaded: true)
}

@Suite("Mini markers")
struct MiniMarkerTests {
    @Test("Nine colours, capitalised names, raw value is the id")
    func names() {
        #expect(MiniMarker.allCases.count == 9)
        #expect(MiniMarker.orange.displayName == "Orange")
        #expect(MiniMarker.grey.displayName == "Grey")
        for marker in MiniMarker.allCases {
            #expect(marker.id == marker.rawValue)
            #expect(marker.displayName.first?.isUppercase == true)
            #expect(marker.displayName.dropFirst() == marker.rawValue.dropFirst())
        }
    }

    @Test("Codable uses the colour word, and an unknown word fails to decode")
    func codable() throws {
        let data = try JSONEncoder().encode([MiniMarker.purple])
        #expect(String(data: data, encoding: .utf8) == "[\"purple\"]")
        #expect(try JSONDecoder().decode([MiniMarker].self, from: data) == [.purple])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([MiniMarker].self, from: Data("[\"teal\"]".utf8))
        }
    }

    @Test("A marker set through the reducer survives a save round trip and can be cleared")
    func reducerAndSave() throws {
        var session = gapSession()
        let id = session.units[0].id
        session = try MatchReducer.reduce(session, .setMini(unitId: id, mini: .orange))
        let decoded = try JSONDecoder().decode(MatchSession.self, from: JSONEncoder().encode(session))
        #expect(decoded.units[0].mini == .orange)
        #expect(decoded.units[1].mini == nil)
        session = try MatchReducer.reduce(session, .setMini(unitId: id, mini: nil))
        #expect(session.units[0].mini == nil)
        #expect(throws: MatchDomainError.self) {
            try MatchReducer.reduce(session, .setMini(unitId: UUID(), mini: .red))
        }
    }
}

@Suite("Domain identifiers")
struct IdentifierTests {
    @Test("A recorded move counts for the target the way the book says")
    func targetMoveModifier() {
        #expect(MovementMode.standstill.asTargetMoveModifier == .standstill)
        #expect(MovementMode.jump.asTargetMoveModifier == .jumpedUsesTMMPlus1)
        for mode in [MovementMode.ground, .sprint, .unset] {
            #expect(mode.asTargetMoveModifier == .groundUsesTMM)
        }
    }

    @Test("Every movement mode and combat status has plain-words copy")
    func copy() {
        for mode in MovementMode.allCases {
            #expect(!mode.displayName.isEmpty && !mode.coachDetail.isEmpty)
        }
        #expect(UnitCombatStatus.active.displayName == "In play")
        #expect(UnitCombatStatus.destroyedPendingEnd.displayName.contains("still shoots"))
        #expect(UnitCombatStatus.removed.displayName == "Off the table")
    }

    @Test("Sides keep their saved spelling and letters; unknown side names fail")
    func sides() throws {
        #expect(SideId.allCases.map(\.rawValue) == ["lanceA", "lanceB", "lanceC", "lanceD"])
        #expect(SideId.allCases.map(\.letter) == ["A", "B", "C", "D"])
        #expect(SideId.lanceC.displayName == "Side C")
        #expect(SideId.missionPair == [.lanceA, .lanceB])
        let dict = try JSONDecoder().decode([SideId: Int].self, from: Data("{\"lanceB\":2}".utf8))
        #expect(dict == [.lanceB: 2])
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(SideId.self, from: Data("\"lanceZ\"".utf8)) }
    }

    @Test("Phases read in turn order")
    func phases() {
        #expect(PhaseId.allCases.map(\.displayName) == ["Roll dice", "Move", "Shoot", "Clean up"])
    }
}

@Suite("Initiative dice (two sides)")
struct InitiativeDiceTests {
    @Test("Higher total wins and the lower side moves first")
    func winner() {
        #expect(InitiativeDice.winner(a1: 6, a2: 5, b1: 1, b2: 1) == .lanceA)
        #expect(InitiativeDice.firstToMove(a1: 6, a2: 5, b1: 1, b2: 1) == .lanceB)
        #expect(InitiativeDice.winner(a1: 1, a2: 2, b1: 3, b2: 3) == .lanceB)
        #expect(InitiativeDice.firstToMove(a1: 1, a2: 2, b1: 3, b2: 3) == .lanceA)
    }

    @Test("A tie has no winner; missing dice have no winner and are not a tie")
    func tieAndMissing() {
        #expect(InitiativeDice.winner(a1: 3, a2: 4, b1: 2, b2: 5) == nil)
        #expect(InitiativeDice.firstToMove(a1: 3, a2: 4, b1: 2, b2: 5) == nil)
        #expect(InitiativeDice.isTie(a1: 3, a2: 4, b1: 2, b2: 5))
        #expect(!InitiativeDice.isTie(a1: 3, a2: 4, b1: 2, b2: 6))
        #expect(InitiativeDice.winner(a1: 3, a2: nil, b1: 2, b2: 5) == nil)
        #expect(!InitiativeDice.isTie(a1: 3, a2: 4, b1: nil, b2: 5))
    }

    @Test("Initiative rolls summary lists sides in seat order with totals")
    func summary() {
        let rolls = InitiativeRolls(rolls: [
            .lanceC: DiceRoll2D6(die1: 1, die2: 3),
            .lanceA: DiceRoll2D6(die1: 3, die2: 4),
            .lanceB: DiceRoll2D6(die1: 6, die2: 3)
        ])
        #expect(rolls.summary { $0.letter } == "A 7, B 9, C 4")
    }
}

@Suite("Match outcome and victory rule Codable")
struct OutcomeCodableTests {
    @Test("Every outcome round-trips and reads correctly")
    func roundTrip() throws {
        let cases: [MatchOutcome] = [.winner(.lanceB), .draw, .tied([.lanceA, .lanceC])]
        for outcome in cases {
            let data = try JSONEncoder().encode(outcome)
            #expect(try JSONDecoder().decode(MatchOutcome.self, from: data) == outcome)
        }
        #expect(MatchOutcome.winner(.lanceB).displaySummary == "Side B wins")
        #expect(MatchOutcome.draw.displaySummary == "It’s a draw")
        #expect(MatchOutcome.tied([.lanceA, .lanceC]).displaySummary == "Tie: Side A, Side C")
        #expect(MatchOutcome.winner(.lanceB).winningSides == [.lanceB])
        #expect(MatchOutcome.tied([.lanceA, .lanceC]).winningSides == [.lanceA, .lanceC])
        #expect(MatchOutcome.draw.winningSides.isEmpty)
    }

    @Test("An unknown outcome type is a decoding error, not a silent draw")
    func unknown() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(MatchOutcome.self, from: Data("{\"type\":\"forfeit\"}".utf8))
        }
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(VictoryRule.self, from: Data("{\"type\":\"capture\"}".utf8))
        }
    }

    @Test("Victory rules keep their turn limit")
    func victoryRule() throws {
        let rule = VictoryRule.destroyAllEnemiesOrStructureAfterTurn(maxTurn: 6)
        let decoded = try JSONDecoder().decode(VictoryRule.self, from: JSONEncoder().encode(rule))
        #expect(decoded == rule)
    }
}

@Suite("Session helpers")
struct SessionHelperTests {
    @Test("Player names drop blanks and trim")
    func playerNames() {
        var session = gapSession()
        session.sides[0].players = ["  Ana ", "", "  "]
        #expect(session.playerNames(of: .lanceA) == ["Ana"])
        #expect(session.playerNames(of: .lanceC).isEmpty)
    }

    @Test("First to move is the lowest initiative")
    func firstToMove() {
        var session = gapSession()
        #expect(session.firstToMove == nil)
        session.initiativeOrder = [.lanceB, .lanceA]
        #expect(session.firstToMove == .lanceB)
    }
}

@Suite("Back and undo recovery")
struct MatchRecoveryTests {
    @Test("Step key tracks turn, phase, side, status and table readiness")
    func stepKey() {
        let a = gapSession()
        var b = a
        #expect(MatchStepKey(a) == MatchStepKey(b))
        b.activeSide = .lanceB
        #expect(MatchStepKey(a) != MatchStepKey(b))
        b = a
        b.phase = .combat
        #expect(MatchStepKey(a) != MatchStepKey(b))
    }

    @Test("Previous step is the newest snapshot from a different step")
    func previousStep() {
        let movement = gapSession(phase: .movement)
        var sameStepLater = movement
        sameStepLater.units[0].hasMovedThisTurn = true
        let initiative = gapSession(phase: .initiative)
        let found = MatchRecovery.previousStep(current: movement, undoStack: [initiative, sameStepLater])
        #expect(found?.phase == .initiative)
        #expect(MatchRecovery.previousStep(current: movement, undoStack: [sameStepLater]) == nil)
        #expect(MatchRecovery.previousStep(current: movement, undoStack: []) == nil)
    }

    @Test("Restoring discards results when the turn, status, a move, a shot or damage differ")
    func discardsResults() {
        let base = gapSession()
        #expect(!MatchRecovery.discardsResults(current: base, restoring: base))

        var nextTurn = base
        nextTurn.turn = 2
        #expect(MatchRecovery.discardsResults(current: nextTurn, restoring: base))

        var done = base
        done.status = .completed
        #expect(MatchRecovery.discardsResults(current: done, restoring: base))

        var moved = base
        moved.units[0].hasMovedThisTurn = true
        #expect(MatchRecovery.discardsResults(current: moved, restoring: base))

        var modeChanged = base
        modeChanged.units[0].movementMode = .jump
        #expect(MatchRecovery.discardsResults(current: modeChanged, restoring: base))

        var shot = base
        shot.units[1].hasAttackedThisTurn = true
        #expect(MatchRecovery.discardsResults(current: shot, restoring: base))

        var hurt = base
        hurt.units[1].armorDamage = 1
        #expect(MatchRecovery.discardsResults(current: hurt, restoring: base))
    }

    @Test("A unit missing from the current game, or an extra one, counts as lost results")
    func unitSetChanged() {
        let base = gapSession()
        var fewer = base
        fewer.units.removeLast()
        #expect(MatchRecovery.discardsResults(current: fewer, restoring: base))
        var more = base
        more.units.append(gapUnit("B2", .lanceB))
        #expect(MatchRecovery.discardsResults(current: more, restoring: base))
    }

    @Test("Hand back refuses outside movement, with no history, or when damage would be lost")
    func handBackGuards() {
        let movement = gapSession()
        #expect(MatchRecovery.handBack(current: gapSession(phase: .combat), undoStack: [movement]) == nil)
        #expect(MatchRecovery.handBack(current: movement, undoStack: []) == nil)
        // Same side on top: nothing to hand back.
        #expect(MatchRecovery.handBack(current: movement, undoStack: [movement]) == nil)
        var previous = movement
        previous.activeSide = .lanceB
        var hurt = movement
        hurt.units[0].structureDamage = 1
        #expect(MatchRecovery.handBack(current: hurt, undoStack: [previous]) == nil)
        let handed = MatchRecovery.handBack(current: movement, undoStack: [previous])
        #expect(handed?.activeSide == .lanceB)
        var otherTurn = previous
        otherTurn.turn = 2
        #expect(MatchRecovery.handBack(current: movement, undoStack: [otherTurn]) == nil)
    }
}

@Suite("Reducer guard rails")
struct ReducerGuardTests {
    private func rejects(_ session: MatchSession, _ command: MatchCommand) -> Bool {
        (try? MatchReducer.reduce(session, command)) == nil
    }

    @Test("Movement commands only work in Movement, on the active side, on a unit that exists")
    func movementGuards() throws {
        let initiative = gapSession(phase: .initiative)
        let a = initiative.units[0].id
        #expect(rejects(initiative, .setMovementMode(unitId: a, mode: .ground)))
        #expect(rejects(initiative, .reviseMovement(unitId: a, mode: .ground)))
        #expect(rejects(initiative, .markMoved(unitId: a)))
        #expect(rejects(initiative, .skipRemainingMoves))

        var movement = gapSession()
        movement.activeSide = .lanceA
        let other = movement.units[1].id
        #expect(rejects(movement, .setMovementMode(unitId: UUID(), mode: .ground)))
        #expect(rejects(movement, .setMovementMode(unitId: other, mode: .ground)))
        #expect(rejects(movement, .markMoved(unitId: other)))
        #expect(rejects(movement, .markMoved(unitId: UUID())))
        // Nothing has moved yet, so there is no move to revise.
        #expect(rejects(movement, .reviseMovement(unitId: movement.units[0].id, mode: .standstill)))
        #expect(rejects(movement, .reviseMovement(unitId: UUID(), mode: .standstill)))
        // A removed 'Mech can't be given a move.
        movement.units[0].combatStatus = .removed
        #expect(rejects(movement, .setMovementMode(unitId: movement.units[0].id, mode: .ground)))
    }

    @Test("Skipping the rest of the moves marks every active 'Mech moved and defaults to Walked")
    func skipRemaining() throws {
        var session = gapSession()
        session.units[1].combatStatus = .removed
        let next = try MatchReducer.reduce(session, .skipRemainingMoves)
        #expect(next.units[0].hasMovedThisTurn && next.units[0].movementMode == .ground)
        #expect(!next.units[1].hasMovedThisTurn)
    }

    @Test("Initiative can be agreed once, only for sides in the game, and in full order")
    func agreeInitiative() throws {
        let initiative = gapSession(phase: .initiative)
        #expect(rejects(initiative, .agreeInitiative(firstToMove: .lanceC)))
        #expect(rejects(initiative, .agreeInitiativeOrder([.lanceA])))
        #expect(rejects(initiative, .agreeInitiativeOrder([.lanceA, .lanceC])))
        let agreed = try MatchReducer.reduce(initiative, .agreeInitiative(firstToMove: .lanceB))
        #expect(agreed.phase == .movement && agreed.activeSide == .lanceB && agreed.initiativeOrder == [.lanceB, .lanceA])
        #expect(rejects(agreed, .agreeInitiative(firstToMove: .lanceA)))
        #expect(rejects(agreed, .agreeInitiativeOrder([.lanceA, .lanceB])))
        let ordered = try MatchReducer.reduce(initiative, .agreeInitiativeOrder([.lanceA, .lanceB]))
        #expect(ordered.initiativeWinner == .lanceB && ordered.activeSide == .lanceA)
        // Rolls must cover exactly the sides in the game.
        let partial = InitiativeRolls(rolls: [.lanceA: DiceRoll2D6(die1: 1, die2: 1)])
        #expect(rejects(initiative, .setInitiative(partial)))
        #expect(rejects(agreed, .setInitiative(InitiativeRolls(lanceA: DiceRoll2D6(die1: 1, die2: 2), lanceB: DiceRoll2D6(die1: 3, die2: 3)))))
    }

    @Test("Conceding: unknown or finished games are refused, and the last side standing wins")
    func concede() throws {
        let session = gapSession()
        #expect(rejects(session, .concede(side: .lanceC)))
        var over = session
        over.status = .completed
        #expect(rejects(over, .concede(side: .lanceA)))
        var owed = session
        owed.units[0].criticalsOwed = 1
        #expect(rejects(owed, .concede(side: .lanceB)))
        let done = try MatchReducer.reduce(session, .concede(side: .lanceA))
        #expect(done.status == .completed)
        #expect(done.outcome == .winner(.lanceB))
        #expect(done.units[0].combatStatus == .removed)
        #expect(rejects(done, .concede(side: .lanceB)))
    }

    @Test("Abandoning clears any outcome")
    func abandon() throws {
        var session = gapSession()
        session.outcome = .draw
        let next = try MatchReducer.reduce(session, .abandonMatch)
        #expect(next.status == .abandoned && next.outcome == nil)
    }

    @Test("Criticals, finishing combat and water need the right state")
    func combatGuards() throws {
        let movement = gapSession()
        let a = movement.units[0].id
        #expect(rejects(movement, .finishCombat))
        #expect(rejects(movement, .applyCritical(unitId: a, roll: DiceRoll2D6(die1: 3, die2: 3))))
        #expect(rejects(movement, .applyCritical(unitId: UUID(), roll: DiceRoll2D6(die1: 3, die2: 3))))
        #expect(rejects(movement, .setInWater(unitId: UUID(), inWater: true)))
        let wet = try MatchReducer.reduce(movement, .setInWater(unitId: a, inWater: true))
        #expect(wet.units[0].inWater)
        var combat = gapSession(phase: .combat)
        combat.units[0].criticalsOwed = 1
        #expect(rejects(combat, .finishCombat))
        #expect(rejects(gapSession(turn: 2), .acknowledgeDeployment))
    }

    @Test("Home edges: only before placement, only for sides in the game, and swapping edges trades them")
    func homeEdges() throws {
        var session = gapSession(phase: .initiative)
        session.sides = [MatchSide(id: .lanceA, homeEdge: .west), MatchSide(id: .lanceB, homeEdge: .east)]
        #expect(rejects(session, .assignHomeEdge(side: .lanceC, edge: .north)))
        let swapped = try MatchReducer.reduce(session, .assignHomeEdge(side: .lanceA, edge: .east))
        #expect(swapped.side(.lanceA)?.homeEdge == .east)
        #expect(swapped.side(.lanceB)?.homeEdge == .west)
        var later = session
        later.turn = 2
        #expect(rejects(later, .assignHomeEdge(side: .lanceA, edge: .north)))
    }
}

@Suite("Box rules reducer guard rails")
struct BoxRulesGuardTests {
    private func session() -> MatchSession {
        let a = ["Atlas", "Archer", "Warhammer", "Blackjack"].map { gapUnit($0, .lanceA) }
        let b = ["Warhawk", "Wolf"].map { gapUnit($0, .lanceB) }
        var s = MatchSession(ruleset: .ridgeLine, phase: .combat, units: a + b, status: .active, tableReady: true, forcesLoaded: true)
        s.boxRules = BoxRulesState(
            support: [.lanceA: SupportInventory(budget: 5)],
            formations: [FormationState(id: "cmd", kind: .commandLance, memberIds: a.map(\.id), commandUnitId: a[0].id, combatIntuitionCount: 2)],
            buildings: [
                BuildingState(id: "L1", name: "Large", type: .heavy, heightInches: 3),
                BuildingState(id: "S1", name: "Light", type: .light, heightInches: 2)
            ]
        )
        return s
    }

    private func rejects(_ s: MatchSession, _ command: BoxRulesCommand) -> Bool {
        (try? BoxRulesReducer.reduce(s, command)) == nil
    }

    @Test("A mission without box rules refuses every command")
    func noBoxRules() {
        var s = session()
        s.boxRules = nil
        #expect(rejects(s, .lockSupportPicks(side: .lanceA)))
    }

    @Test("Support: unknown side, unknown pick, wrong phase, and a owed critical all stop a call")
    func supportGuards() throws {
        var s = session()
        #expect(rejects(s, .setSupportPicks(side: .lanceB, picks: [.thumper])))
        #expect(rejects(s, .lockSupportPicks(side: .lanceB)))
        s = try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceA, picks: [.lightStrike]))
        let pick = s.boxRules!.support[.lanceA]!.picks[0].id
        let roll = DiceRoll2D6(die1: 6, die2: 6)
        let target = s.units[4].id
        func use(_ id: UUID, targets: [UUID]) -> BoxRulesCommand {
            .useSupport(side: .lanceA, pickId: id, roll: roll, scatterDirection: nil, scatterDistance: nil, unitsHit: targets)
        }
        #expect(rejects(s, use(UUID(), targets: [target])))
        #expect(rejects(s, use(pick, targets: [])))
        #expect(rejects(s, use(pick, targets: [UUID()])))
        var movement = s
        movement.phase = .movement
        #expect(rejects(movement, use(pick, targets: [target])))
        var owed = s
        owed.units[5].criticalsOwed = 1
        #expect(rejects(owed, use(pick, targets: [target])))
        let used = try BoxRulesReducer.reduce(s, use(pick, targets: [target]))
        #expect(used.units[4].armorDamage > 0)
        #expect(rejects(used, use(pick, targets: [target])))
    }

    @Test("A scattering support needs both scatter dice when it misses")
    func scatterNeedsDice() throws {
        var s = session()
        s = try BoxRulesReducer.reduce(s, .setSupportPicks(side: .lanceA, picks: [.heavyBombing]))
        let pick = s.boxRules!.support[.lanceA]!.picks[0].id
        let miss = DiceRoll2D6(die1: 1, die2: 1)
        #expect(rejects(s, .useSupport(side: .lanceA, pickId: pick, roll: miss, scatterDirection: 3, scatterDistance: nil, unitsHit: [])))
        let ok = try BoxRulesReducer.reduce(s, .useSupport(side: .lanceA, pickId: pick, roll: miss, scatterDirection: 3, scatterDistance: 2, unitsHit: []))
        #expect(ok.eventLog.last?.message.contains("scatters") == true)
    }

    @Test("Formations: unknown ids, the wrong unit and a late designation are refused")
    func formationGuards() {
        var s = session()
        let atlas = s.units[0].id, archer = s.units[1].id, warhammer = s.units[2].id
        #expect(rejects(s, .designateCombatIntuition(formationId: "nope", unitIds: [archer, warhammer])))
        #expect(rejects(s, .designateCombatIntuition(formationId: "cmd", unitIds: [archer])))
        #expect(rejects(s, .designateCombatIntuition(formationId: "cmd", unitIds: [atlas, archer])))
        s.turn = 2
        #expect(rejects(s, .designateCombatIntuition(formationId: "cmd", unitIds: [archer, warhammer])))
        #expect(rejects(s, .rerollInitiative(formationId: "nope", roll: DiceRoll2D6(die1: 1, die2: 1))))
        #expect(rejects(s, .useLucky(formationId: "nope", unitId: archer)))
        let attack = SATORAttackCommand(attackerId: UUID(), defenderId: s.units[4].id, range: .short, roll: DiceRoll2D6(die1: 3, die2: 3),
                                        attackerMove: .ground, targetMove: .groundUsesTMM)
        #expect(rejects(s, .combatIntuitionAttack(formationId: "cmd", attack: attack)))
    }

    @Test("Buildings: unknown ids, rubble and bad collapse dice are refused; height is clamped")
    func buildingGuards() throws {
        var s = session()
        let atlas = s.units[0].id
        #expect(rejects(s, .damageBuilding(buildingId: "none", amount: 1)))
        #expect(rejects(s, .setBuildingHeight(buildingId: "none", inches: 3)))
        #expect(rejects(s, .collapseBuilding(buildingId: "none", inside: [], onRoof: [], minimalDice: [:])))
        #expect(rejects(s, .attackBuilding(buildingId: "none", attackerId: atlas, bracket: .short, roll: DiceRoll2D6(die1: 3, die2: 3), attackerMove: .ground)))
        // Zero or negative damage is a no-op, not an error.
        let same = try BoxRulesReducer.reduce(s, .damageBuilding(buildingId: "L1", amount: 0))
        #expect(same.boxRules?.building("L1")?.cf == s.boxRules?.building("L1")?.cf)
        // A Light building needs a minimal-damage die for each 'Mech caught inside.
        #expect(rejects(s, .collapseBuilding(buildingId: "S1", inside: [atlas], onRoof: [], minimalDice: [:])))
        s = try BoxRulesReducer.reduce(s, .setBuildingHeight(buildingId: "L1", inches: 99))
        #expect(s.boxRules?.building("L1")?.heightInches == 12)
        s = try BoxRulesReducer.reduce(s, .setBuildingHeight(buildingId: "L1", inches: -4))
        #expect(s.boxRules?.building("L1")?.heightInches == 1)
        // Rubble can't be shot or damaged again, and the attack needs combat.
        s = try BoxRulesReducer.reduce(s, .damageBuilding(buildingId: "L1", amount: 99))
        #expect(s.boxRules?.building("L1")?.collapsed == true)
        #expect(rejects(s, .damageBuilding(buildingId: "L1", amount: 1)))
        #expect(rejects(s, .attackBuilding(buildingId: "L1", attackerId: atlas, bracket: .short, roll: DiceRoll2D6(die1: 3, die2: 3), attackerMove: .ground)))
        var movement = session()
        movement.phase = .movement
        #expect(rejects(movement, .attackBuilding(buildingId: "L1", attackerId: atlas, bracket: .short, roll: DiceRoll2D6(die1: 3, die2: 3), attackerMove: .ground)))
        #expect(rejects(session(), .attackBuilding(buildingId: "S1", attackerId: UUID(), bracket: .short, roll: DiceRoll2D6(die1: 3, die2: 3), attackerMove: .ground)))
    }

    @Test("A missed building attack logs the roll and leaves CF alone")
    func buildingMiss() throws {
        let s = session()
        let atlas = s.units[0].id
        let next = try BoxRulesReducer.reduce(s, .attackBuilding(buildingId: "L1", attackerId: atlas, bracket: .long,
                                                                 roll: DiceRoll2D6(die1: 1, die2: 1), attackerMove: .ground))
        #expect(next.boxRules?.building("L1")?.cf == s.boxRules?.building("L1")?.cf)
        #expect(next.eventLog.last?.message.contains("missed") == true)
        #expect(next.units[0].hasAttackedThisTurn)
    }

    @Test("Looking up a formation by unit and kind")
    func formationLookup() {
        let s = session()
        let rules = s.boxRules!
        let archer = s.units[1].id
        #expect(rules.formation(of: archer, kind: .commandLance)?.id == "cmd")
        #expect(rules.formation(of: archer, kind: .battleStar) == nil)
        #expect(rules.formation(of: s.units[4].id, kind: .commandLance) == nil)
    }
}

@Suite("Objective setup and preview")
struct ObjectiveGapTests {
    @Test("Tokens are made per side with side-letter ids; objectives without tokens make none")
    func tokens() {
        let raid = ObjectiveState.make(objective: .raid, sides: [.lanceA, .lanceC])
        #expect(raid.tokens.count == ObjectiveId.raid.tokensPerSide * 2)
        #expect(raid.tokens.first?.id == "A1")
        #expect(raid.tokens.contains { $0.id.hasPrefix("C") && $0.owner == .lanceC })
        #expect(ObjectiveState.make(objective: .destroyTheEnemy, sides: [.lanceA, .lanceB]).tokens.isEmpty)
    }

    @Test("Preview points follow each objective's scoring line")
    func previewPoints() {
        var session = gapSession(phase: .end)
        session.units[0].sz = 3
        let atlas = session.units[0].id
        func entry(_ kind: ObjectiveScoreEntry.Kind, unit: UUID? = nil, token: String? = nil) -> ObjectiveScoreEntry {
            ObjectiveScoreEntry(kind: kind, unitId: unit, tokenId: token)
        }
        // Raid: 2 per returned token.
        #expect(ObjectiveRules.previewPoints(.raid, side: .lanceA, entries: [entry(.returned), entry(.returned)], in: session) == 4)
        // Control the Field: each distinct 'Mech in position scores its Size once.
        #expect(ObjectiveRules.previewPoints(.controlTheField, side: .lanceA, entries: [entry(.inPosition, unit: atlas), entry(.inPosition, unit: atlas)], in: session) == 3)
        // Hold the Fort: 1 per guarded token, two at most.
        let guarded = ["A1", "A2", "A3"].map { entry(.guarded, token: $0) }
        #expect(ObjectiveRules.previewPoints(.holdTheFort, side: .lanceA, entries: guarded, in: session) == 2)
        // Breakthrough: Size of 'Mechs that exited.
        #expect(ObjectiveRules.previewPoints(.breakthrough, side: .lanceA, entries: [entry(.exited, unit: atlas)], in: session) >= 3)
        // The other two score by what happened in combat, not by answers.
        #expect(ObjectiveRules.previewPoints(.destroyTheEnemy, side: .lanceA, entries: [entry(.returned)], in: session) == 0)
        #expect(ObjectiveRules.previewPoints(.findTheTarget, side: .lanceA, entries: [], in: session) == 0)
    }
}

@Suite("Play setup copy and budgets")
struct PlaySetupGapTests {
    @Test("Map arrangements have titles, sheet counts and grids that agree")
    func arrangements() {
        #expect(MapArrangement.allCases.map(\.title) == ["1 sheet", "2 sheets", "2 × 2", "3 × 2"])
        for arrangement in MapArrangement.allCases {
            #expect(arrangement.grid.columns * arrangement.grid.rows == arrangement.sheetCount)
        }
        let table = Battlefield(kind: .mapsheets, arrangement: .threeByTwo)
        #expect(table.width == 66 && table.depth == 34)
        #expect(Battlefield(kind: .mapsheets, arrangement: .single).summary == "1 sheet mapsheets")
    }

    @Test("Table advice: small tables, many sides, big budgets, and none when it suits")
    func advice() {
        #expect(Battlefield(matWidth: 30, matDepth: 30).advice(sides: 2, budgetPV: 250) == "Small table. Forces will meet on Turn 1.")
        #expect(Battlefield(matWidth: 48, matDepth: 30).advice(sides: 2, budgetPV: nil) == "Small table. Forces will meet on Turn 1.")
        #expect(Battlefield(matWidth: 48, matDepth: 36).advice(sides: 3, budgetPV: nil)?.contains("4′ × 4′") == true)
        #expect(Battlefield(matWidth: 48, matDepth: 48).advice(sides: 3, budgetPV: nil) == nil)
        #expect(Battlefield(matWidth: 48, matDepth: 48).advice(sides: 2, budgetPV: 400)?.contains("4′ × 6′") == true)
        #expect(Battlefield(matWidth: 72, matDepth: 48).advice(sides: 2, budgetPV: 400) == nil)
        #expect(Battlefield(matWidth: 48, matDepth: 36).advice(sides: 2, budgetPV: 250) == nil)
        #expect(Battlefield(matWidth: 40, matDepth: 40).advice(sides: 2, budgetPV: 250)?.contains("3′ × 4′") == true)
    }

    @Test("Budget text reads left, on budget and over for points and for counts with a Size cap")
    func budgetText() {
        func pick(_ pv: Int, size: Int = 2) -> ForcePick {
            ForcePick(cardId: "x", name: "X", basePV: pv, size: size, skill: 4, isClan: false)
        }
        let points = BudgetCheck.evaluate(.pointValue(50), picks: [pick(30)])
        #expect(points.status == .under && points.text == "20 PV left")
        #expect(BudgetCheck.evaluate(.pointValue(30), picks: [pick(30)]).text == "On budget")
        let over = BudgetCheck.evaluate(.pointValue(20), picks: [pick(30)])
        #expect(over.isOver && over.text == "10 PV over")

        let count = BudgetCheck.evaluate(.count(units: 3, sizeCap: nil), picks: [pick(10), pick(10)])
        #expect(count.text == "1 ’Mech left")
        let few = BudgetCheck.evaluate(.count(units: 4, sizeCap: nil), picks: [pick(10), pick(10)])
        #expect(few.text == "2 ’Mechs left")
        let tooMany = BudgetCheck.evaluate(.count(units: 1, sizeCap: nil), picks: [pick(10), pick(10), pick(10)])
        #expect(tooMany.text == "2 ’Mechs over")
        let oneOver = BudgetCheck.evaluate(.count(units: 1, sizeCap: nil), picks: [pick(10), pick(10)])
        #expect(oneOver.text == "1 ’Mech over")
        // Size cap beats the count: within the unit limit but too big.
        let heavy = BudgetCheck.evaluate(.count(units: 3, sizeCap: 5), picks: [pick(10, size: 3), pick(10, size: 3)])
        #expect(heavy.isOver && heavy.text == "Size 6 of 5")
    }

    @Test("Totals sum a side's picks and ignore sides with none")
    func totals() {
        var setup = PlaySetup.pickup()
        let sideA = setup.sides[0].id
        setup.forces[sideA] = [
            ForcePick(cardId: "a", name: "A", basePV: 30, size: 2, skill: 4, isClan: false),
            ForcePick(cardId: "b", name: "B", basePV: 20, size: 3, skill: 4, isClan: false)
        ]
        #expect(setup.totalSize(sideA) == 5)
        #expect(setup.totalPV(sideA) == 50)
        #expect(setup.unitCount == 2)
        #expect(setup.totalSize(.lanceD) == 0)
    }
}

@Suite("Board editor gaps")
struct BoardEditorGapTests {
    private func palette() throws -> TerrainPaletteFile {
        try BundleContentCatalogRepository(bundle: Bundle(for: GapBundleToken.self)).terrainPalette()
    }

    private func editor() -> BoardEditor {
        BoardEditor(board: BoardLayout(width: 48, depth: 48, zones: BoardZones.generate(width: 48, depth: 48, sideCount: 2)))
    }

    @Test("Set rotation snaps to 15° with snap on, is free with it off, and 0 clears the angle")
    func setRotation() throws {
        let woods = try #require(try palette().item("woods"))
        var editor = editor()
        let id = editor.add(woods, centredAt: 24, 24)
        editor.setRotation(id, 100, snapOn: true)
        #expect(editor.board.features[0].rotation == 105)
        editor.setRotation(id, 100, snapOn: false)
        #expect(editor.board.features[0].rotation == 100)
        editor.setRotation(id, 360, snapOn: true)
        #expect(editor.board.features[0].rotation == nil)
        editor.setRotation(UUID(), 45, snapOn: true)
        #expect(editor.board.features.count == 1)
    }

    @Test("Zone depth is clamped to 2–12″ and kept per side count; reset removes the custom sets")
    func zoneDepth() {
        var editor = editor()
        editor.setZoneDepth(30, sideCount: 2)
        let deep = editor.board.zonesBySideCount?[2]
        #expect(deep?.isEmpty == false)
        editor.setZoneDepth(0.5, sideCount: 3)
        #expect(editor.board.zonesBySideCount?[3] != nil)
        #expect(editor.board.zonesBySideCount?[2] == deep)
        // Out-of-range side counts file under 2 or 4.
        editor.setZoneDepth(6, sideCount: 9)
        #expect(editor.board.zonesBySideCount?[4] != nil)
        #expect(editor.canUndo)
        editor.resetZones()
        #expect(editor.board.zonesBySideCount == nil && editor.board.zones.isEmpty)
        let undone = editor.undo()
        #expect(undone)
        #expect(editor.board.zonesBySideCount?[4] != nil)
    }
}

@Suite("Phase engine fallback rotation")
struct PhaseEngineRotationTests {
    @Test("With no initiative order, the next mover is the next seat with 'Mechs left")
    func rotation() {
        let units = [gapUnit("A", .lanceA), gapUnit("B", .lanceB), gapUnit("C", .lanceC)]
        #expect(AlphaStrikePhaseEngine.nextMovementActiveSide(current: .lanceA, units: units, order: []) == .lanceB)
        var moved = units
        moved[1].hasMovedThisTurn = true
        #expect(AlphaStrikePhaseEngine.nextMovementActiveSide(current: .lanceA, units: moved, order: []) == .lanceC)
        moved[2].hasMovedThisTurn = true
        // Nobody else has anything to move: stay put.
        #expect(AlphaStrikePhaseEngine.nextMovementActiveSide(current: .lanceA, units: moved, order: []) == .lanceA)
    }
}
