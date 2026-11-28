// MatchStore is the object the battle screen drives: every tap becomes a reducer command, an undo snapshot
// and a save. These tests run it against the in-memory repository and the app's bundled missions.
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain
@testable import MechBuddy

@MainActor
@Suite("Match store")
struct MatchStoreTests {
    private let catalog = BundleContentCatalogRepository(bundle: .main)

    private func started(_ id: ScenarioId = .ridgeLine) -> (MatchStore, InMemoryMatchSessionRepository) {
        let repo = InMemoryMatchSessionRepository()
        let store = MatchStore(repository: repo)
        store.startMission(id, from: catalog, replaceActive: false)
        return (store, repo)
    }

    /// Table ready, initiative rolled, placement confirmed: the first side is up to move.
    private func moving() -> (MatchStore, InMemoryMatchSessionRepository) {
        let (store, repo) = started()
        store.markTableReady()
        store.setInitiative(a1: 6, a2: 5, b1: 1, b2: 1)
        store.acknowledgeDeployment()
        return (store, repo)
    }

    @Test("Starting a mission saves an active game and loads the briefing")
    func startMission() throws {
        let (store, repo) = started()
        let session = try #require(store.session)
        #expect(store.isActive && store.lastError == nil)
        #expect(session.scenarioId == .ridgeLine && session.units.count == 4)
        #expect(store.scenario.id == "ridge-line" && !store.scenario.tableSteps.isEmpty)
        #expect(try repo.loadActive(mode: .alphaStrike)?.id == session.id)
        #expect(!store.canUndo && !store.canBack)
    }

    @Test("A second start is blocked while a game is in progress, and replaces it when asked")
    func replaceRules() throws {
        let (store, repo) = started()
        let first = try #require(store.session)
        let other = MatchStore(repository: repo)
        other.startMission(.ridgeLine, from: catalog, replaceActive: false)
        #expect(other.session == nil && other.lastError == "A game is already in progress")
        #expect(other.lastErrorTitle == "Couldn’t start the mission")
        other.startMission(.ridgeLine, from: catalog, replaceActive: true)
        let second = try #require(other.session)
        #expect(second.id != first.id)
        #expect(try repo.loadActive(mode: .alphaStrike)?.id == second.id)
    }

    @Test("A mission that isn't in the catalog reports an error and leaves no game")
    func unknownMission() {
        let store = MatchStore(repository: InMemoryMatchSessionRepository())
        store.startMission(ScenarioId(rawValue: "no-such-mission"), from: catalog, replaceActive: false)
        #expect(store.session == nil && store.lastError != nil)
    }

    @Test("Resume loads the saved game, or reports there is none")
    func resumeActive() throws {
        let (store, repo) = started()
        let fresh = MatchStore(repository: repo)
        #expect(try fresh.resumeActive())
        #expect(fresh.session?.id == store.session?.id)
        #expect(try !MatchStore(repository: InMemoryMatchSessionRepository()).resumeActive())
        #expect(try MatchStore.loadActive(from: repo)?.id == store.session?.id)
    }

    @Test("Setup steps advance the game: table ready, initiative dice, then placement")
    func setup() throws {
        let (store, _) = started()
        store.markTableReady()
        #expect(store.session?.tableReady == true)
        // Placement is confirmed in Movement; before the dice are in it is refused.
        store.acknowledgeDeployment()
        #expect(store.session?.deploymentAcknowledged == false && store.lastError != nil)
        store.setInitiative(a1: 6, a2: 5, b1: 1, b2: 1)
        let session = try #require(store.session)
        #expect(session.phase == .movement && session.initiativeWinner == .lanceA && session.activeSide == .lanceB)
        #expect(store.canUndo)
        store.acknowledgeDeployment()
        #expect(store.session?.deploymentAcknowledged == true && store.lastError == nil)
    }

    @Test("Dice outside 1–6 are refused with a message and change nothing")
    func badDice() {
        let (store, _) = started()
        store.markTableReady()
        store.setInitiative(a1: 7, a2: 1, b1: 1, b2: 1)
        #expect(store.lastErrorTitle == "Couldn’t use those dice" && store.lastError == "Dice must be 1–6")
        #expect(store.session?.phase == .initiative)
        #expect(store.applyAttack(attackerId: UUID(), defenderId: UUID(), range: .short, die1: 0, die2: 3,
                                  attackerMove: .ground, targetMove: .groundUsesTMM) == false)
        #expect(store.lastErrorTitle == "Couldn’t save the shot")
        #expect(store.applyPendingCrit(unitId: UUID(), die1: 9, die2: 1) == false)
        #expect(store.lastErrorTitle == "Couldn’t save the critical")
    }

    @Test("A reducer error shows its title and message, and the next good command clears it")
    func errorsClear() throws {
        let (store, _) = started()
        store.finishCombat()
        #expect(store.lastErrorTitle == "Couldn’t finish shooting" && store.lastError != nil)
        store.markTableReady()
        #expect(store.lastError == nil)
    }

    @Test("Recording a move names it in the undo menu, and undo takes it back")
    func moveAndUndo() throws {
        let (store, repo) = moving()
        let session = try #require(store.session)
        let mover = try #require(session.units.first { $0.side == session.activeSide })
        #expect(store.undoMenuTitle != "Undo Walked")
        store.setMove(unitId: mover.id, mode: .ground)
        let after = try #require(store.session)
        #expect(after.units.first { $0.id == mover.id }?.hasMovedThisTurn == true)
        #expect(store.undoMenuTitle == "Undo Walked")
        #expect(try repo.loadActive(mode: .alphaStrike)?.units.first { $0.id == mover.id }?.hasMovedThisTurn == true)
        store.undo()
        #expect(store.session?.units.first { $0.id == mover.id }?.hasMovedThisTurn == false)
        #expect(store.undoMenuTitle == "Undo last change")
    }

    @Test("Each recorded mode has its own undo verb")
    func undoVerbs() throws {
        let verbs: [(MovementMode, String)] = [(.standstill, "Stood still"), (.sprint, "Sprinted"), (.jump, "Jumped")]
        for (mode, verb) in verbs {
            let (store, _) = moving()
            let session = try #require(store.session)
            let unit = try #require(session.units.first { $0.side == session.activeSide && (mode != .jump || $0.canJump) })
            store.setMove(unitId: unit.id, mode: mode)
            if store.lastError == nil { #expect(store.undoMenuTitle == "Undo \(verb)") }
        }
    }

    @Test("Moving a unit out of turn reports a move error")
    func moveOutOfTurn() throws {
        let (store, _) = moving()
        let session = try #require(store.session)
        let wrong = try #require(session.units.first { $0.side != session.activeSide })
        store.setMove(unitId: wrong.id, mode: .ground)
        #expect(store.lastErrorTitle == "Couldn’t record the move" && store.lastError != nil)
        #expect(store.session?.units.first { $0.id == wrong.id }?.hasMovedThisTurn == false)
    }

    @Test("Skipping the rest of the moves goes straight to shooting")
    func skipMoves() {
        let (store, _) = moving()
        store.skipMovesAndAdvance()
        #expect(store.session?.phase == .combat)
        #expect(store.session?.units.allSatisfy(\.hasMovedThisTurn) == true)
    }

    @Test("Back hands the phone to the previous side without losing the recorded move")
    func backHandsOver() throws {
        let (store, _) = moving()
        let session = try #require(store.session)
        let mover = try #require(session.units.first { $0.side == session.activeSide })
        store.setMove(unitId: mover.id, mode: .ground)
        #expect(store.canBack && !store.backNeedsConfirm)
        store.back()
        let back = try #require(store.session)
        #expect(back.activeSide == session.activeSide)
        #expect(back.units.first { $0.id == mover.id }?.hasMovedThisTurn == true)
    }

    @Test("Back from Movement to Roll dice restores initiative; it asks first when results would be lost")
    func backRestoresStep() throws {
        let (store, _) = moving()
        #expect(store.canBack)
        store.skipMovesAndAdvance()
        #expect(store.session?.phase == .combat)
        #expect(store.backNeedsConfirm)
        store.back()
        #expect(store.session?.phase == .movement || store.session?.phase == .initiative)
    }

    @Test("The undo stack keeps the last twelve changes")
    func undoLimit() throws {
        let (store, _) = started()
        for _ in 0..<15 {
            store.setDiceMode(.auto)
            store.setDiceMode(.manual)
            store.markTableReady()
        }
        // Dice mode is not an undo step; markTableReady is.
        var undone = 0
        while store.canUndo { store.undo(); undone += 1 }
        #expect(undone == 12)
    }

    @Test("Dice mode is a preference: saved, but not an undo step, and unchanged values do nothing")
    func diceMode() {
        let (store, _) = started()
        store.setDiceMode(.manual)
        store.setDiceMode(.auto)
        #expect(store.session?.diceMode == .auto && !store.canUndo)
    }

    @Test("Mini colours and water are saved but can't be undone")
    func miniAndWater() throws {
        let (store, _) = started()
        let id = try #require(store.session?.units.first?.id)
        store.setMini(unitId: id, mini: .green)
        store.setInWater(unitId: id, true)
        let unit = try #require(store.session?.units.first { $0.id == id })
        #expect(unit.mini == .green && unit.inWater && !store.canUndo)
    }

    @Test("Players can agree initiative without dice, and the order is recorded")
    func agreeInitiative() {
        let (store, _) = started()
        store.markTableReady()
        store.agreeInitiative(firstToMove: .lanceB)
        #expect(store.session?.phase == .movement && store.session?.initiativeOrder == [.lanceB, .lanceA])
    }

    @Test("Auto initiative previews dice with a clear winner, and one tap applies it")
    func autoInitiative() throws {
        let (store, _) = started()
        store.markTableReady()
        let preview = try #require(store.previewAutoInitiative())
        #expect(preview.winner != nil && (1...6).contains(preview.a1))
        #expect(store.session?.phase == .initiative)
        let entry = try #require(store.rollInitiativeEntry())
        #expect(entry.isComplete)
        store.rollInitiative()
        #expect(store.session?.phase == .movement)
    }

    @Test("Range is remembered per shooter and target pair")
    func rememberedRange() {
        let store = MatchStore(repository: InMemoryMatchSessionRepository())
        let a = UUID(), b = UUID()
        #expect(store.rememberedRange(attacker: a, defender: b) == nil)
        store.rememberRange(12, attacker: a, defender: b)
        #expect(store.rememberedRange(attacker: a, defender: b) == 12)
        #expect(store.rememberedRange(attacker: b, defender: a) == nil)
    }

    @Test("A coach step is noted on the first turn it is seen and not moved afterwards")
    func coachSteps() {
        let store = MatchStore(repository: InMemoryMatchSessionRepository())
        store.noteCoachStep("k", turn: 2)
        store.noteCoachStep("k", turn: 5)
        #expect(store.coachFirstSeen == ["k": 2])
    }

    @Test("Resuming restores the undo history that was saved with the game")
    func resumeRestoresUndo() throws {
        let (store, repo) = moving()
        let session = try #require(store.session)
        let mover = try #require(session.units.first { $0.side == session.activeSide })
        store.setMove(unitId: mover.id, mode: .ground)
        let fresh = MatchStore(repository: repo)
        #expect(try fresh.resumeActive())
        #expect(fresh.canUndo)
        fresh.undo()
        #expect(fresh.session?.units.first { $0.id == mover.id }?.hasMovedThisTurn == false)
    }

    @Test("Leaving a game keeps it; abandoning deletes it; dismissing only clears a finished one")
    func leaving() throws {
        let (store, repo) = moving()
        store.leaveAndSave()
        #expect(try repo.loadActive(mode: .alphaStrike) != nil)
        store.dismissCompleted()
        #expect(store.session != nil)
        store.abandon()
        #expect(store.session == nil && !store.canUndo)
        #expect(try repo.loadActive(mode: .alphaStrike) == nil)
    }

    @Test("Conceding ends a two-side game and a rematch starts the mission fresh")
    func concedeAndRematch() throws {
        let (store, repo) = moving()
        let before = try #require(store.session)
        store.concede(side: .lanceA)
        #expect(store.session?.status == .completed && store.session?.outcome == .winner(.lanceB))
        store.dismissCompleted()
        #expect(store.session == nil)
        let (again, _) = started()
        again.concede(side: .lanceB)
        again.rematch(from: catalog)
        #expect(again.session?.status == .active && again.session?.id != before.id)
        _ = repo
    }

    @Test("Resuming a game with no briefing loads it from the catalog, once")
    func ensureScenario() throws {
        let (store, repo) = started()
        let fresh = MatchStore(repository: repo)
        _ = try fresh.resumeActive()
        #expect(fresh.scenario == .fallback)
        fresh.ensureScenario(from: catalog)
        #expect(fresh.scenario.id == "ridge-line")
        _ = store
    }

    @Test("A Play game starts from its setup, shows the Play briefing, and plays again with every 'Mech repaired")
    func playGame() throws {
        let library = CardLibrary(try catalog.cardLibrary())
        let picks = library.checkedFaces.prefix(2).compactMap(PlayUnits.pick)
        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [picks[0]]
        setup.forces[.lanceB] = [picks[1]]
        let repo = InMemoryMatchSessionRepository()
        let store = MatchStore(repository: repo)
        store.startPlay(setup, library: library, replaceActive: false)
        let session = try #require(store.session)
        #expect(session.isPlayGame && session.units.count == 2)
        #expect(store.scenario.title == "1 v 1" && store.scenario.winningSummary == PlayLayout.winningSummary(for: setup))

        store.concede(side: .lanceB)
        #expect(store.session?.status == .completed)
        let finished = try #require(store.session)
        store.playAgain(library: library)
        let next = try #require(store.session)
        #expect(next.id != finished.id && next.status == .active && next.units.allSatisfy { $0.armorDamage == 0 })
        #expect(try repo.loadActive(mode: .alphaStrike)?.id == next.id)
    }

    @Test("A Play game with an empty side is refused")
    func playNeedsUnits() {
        let library = CardLibrary(CardLibraryDTO(contentVersion: "0", cards: []))
        let store = MatchStore(repository: InMemoryMatchSessionRepository())
        store.startPlay(PlaySetup.pickup(), library: library, replaceActive: false)
        #expect(store.session == nil && store.lastError == "Add at least one ’Mech to each side.")
    }
}
