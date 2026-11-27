import Foundation
import Observation
import MechBuddyData
import MechBuddyDomain

@Observable
@MainActor
final class MatchStore: Identifiable {
    let id = UUID()
    private(set) var session: MatchSession?
    var lastError: String?
    var lastErrorTitle: String = "Something went wrong"
    /// Mission briefing text. Loaded once per store, never from `body`.
    private(set) var scenario: ScenarioPresentation = .fallback
    private var scenarioLoaded = false
    private let repository: any MatchSessionRepository
    private var undoStack: [MatchSession] = []
    /// Range (inches) last used for a shooter→target pair. Minis rarely move far between turns,
    /// so the solver reopens on the measured band instead of the most generous one.
    private(set) var lastRangeInches: [String: Int] = [:]

    func rememberRange(_ inches: Int, attacker: UUID, defender: UUID) {
        lastRangeInches["\(attacker)|\(defender)"] = inches
    }

    func rememberedRange(attacker: UUID, defender: UUID) -> Int? {
        lastRangeInches["\(attacker)|\(defender)"]
    }

    var isActive: Bool {
        guard let session else { return false }
        return session.status == .active
    }

    var canUndo: Bool { !undoStack.isEmpty }

    /// "Undo Walked" when the last snapshot changed exactly one recorded move.
    var undoMenuTitle: String {
        guard let name = undoActionName else { return "Undo last change" }
        return "Undo \(name)"
    }

    init(repository: any MatchSessionRepository) {
        self.repository = repository
    }

    static func loadActive(from repository: any MatchSessionRepository) throws -> MatchSession? {
        try repository.loadActive(mode: .alphaStrike)
    }

    /// Loads the saved Alpha Strike match into this store. Returns false when nothing is active.
    @discardableResult
    func resumeActive() throws -> Bool {
        guard let session = try Self.loadActive(from: repository) else {
            return false
        }
        resume(session)
        return true
    }

    func startMission(_ scenarioId: ScenarioId, from catalog: any ContentCatalogRepository, replaceActive: Bool) {
        do {
            let existing = try Self.loadActive(from: repository)
            switch MatchLaunch.decide(existingActive: existing, replaceActive: replaceActive) {
            case .blocked:
                lastErrorTitle = "Couldn’t start the mission"
                lastError = "A game is already in progress"
                return
            case .replace(let id):
                try repository.delete(id: id)
            case .startFresh:
                break
            }
            let dto = try catalog.scenario(id: scenarioId)
            adoptScenario(dto)
            let ruleset = GuidedScenarioFactory.mapRuleset(dto.ruleset)
            let units = GuidedScenarioFactory.makeUnits(from: dto)
            session = try MatchReducer.reduce(
                MatchSession(ruleset: ruleset),
                .startMission(scenarioId: scenarioId, ruleset: ruleset, units: units)
            )
            session?.boxRules = GuidedScenarioFactory.makeBoxRules(from: dto, units: units)
            undoStack.removeAll()
            lastError = nil
            persist()
        } catch {
            lastErrorTitle = "Couldn’t start the mission"
            lastError = error.localizedDescription
        }
    }

    /// Starts a Play mode game from its setup (PlayModeSpec § 5.6). Same replace rules as a mission.
    func startPlay(_ setup: PlaySetup, library: CardLibrary, replaceActive: Bool) {
        do {
            let existing = try Self.loadActive(from: repository)
            switch MatchLaunch.decide(existingActive: existing, replaceActive: replaceActive) {
            case .blocked:
                lastErrorTitle = "Couldn’t start the game"
                lastError = "A game is already in progress"
                return
            case .replace(let id):
                try repository.delete(id: id)
            case .startFresh:
                break
            }
            let units = PlayUnits.make(setup: setup, library: library)
            guard !units.isEmpty else {
                lastErrorTitle = "Couldn’t start the game"
                lastError = "Add at least one ’Mech to each side."
                return
            }
            adoptPlay(setup)
            session = try MatchReducer.reduce(
                MatchSession(ruleset: setup.ruleset),
                .startPlay(setup: setup, units: units)
            )
            undoStack.removeAll()
            lastError = nil
            persist()
        } catch {
            lastErrorTitle = "Couldn’t start the game"
            lastError = error.localizedDescription
        }
    }

    /// Play again (§ 11): a new session from the same setup, every ’Mech repaired.
    func playAgain(library: CardLibrary) {
        guard let setup = session?.play else { return }
        if let session, session.status == .completed {
            try? repository.delete(id: session.id)
        }
        startPlay(setup, library: library, replaceActive: false)
    }

    /// Briefing for a Play game: its format, the Play table checklist and the generated layout.
    private func adoptPlay(_ setup: PlaySetup) {
        scenario = ScenarioPresentation(
            id: "",
            title: setup.formatName,
            subtitle: "\(setup.budget.summary) · \(setup.battlefield.summary)",
            tableSteps: PlayLayout.tableSteps(for: setup),
            winningSummary: PlayLayout.winningSummary(for: setup),
            layout: PlayLayout.layout(for: setup.battlefield, sides: setup.sides),
            board: setup.battlefield.board == nil ? nil : PlayLayout.board(for: setup.battlefield, sides: setup.sides)
        )
        scenarioLoaded = true
    }

    /// Resume path. `startMission` already cached the briefing, so this is a no-op then.
    /// Games saved before the mission ladder have no scenario id. They were all Ridge Line.
    func ensureScenario(from catalog: any ContentCatalogRepository) {
        guard !scenarioLoaded else { return }
        if let setup = session?.play {
            adoptPlay(setup)
            return
        }
        scenarioLoaded = true
        guard let dto = try? catalog.scenario(id: session?.scenarioId ?? .ridgeLine) else { return }
        adoptScenario(dto)
    }

    /// Same mission again, fresh armor and structure.
    func rematch(from catalog: any ContentCatalogRepository) {
        startFresh(session?.scenarioId ?? .ridgeLine, from: catalog)
    }

    /// Clears a finished match and starts `scenarioId` (rematch, or the next mission on the path).
    func startFresh(_ scenarioId: ScenarioId, from catalog: any ContentCatalogRepository) {
        if let session, session.status == .completed {
            try? repository.delete(id: session.id)
        }
        startMission(scenarioId, from: catalog, replaceActive: false)
    }

    func resume(_ session: MatchSession) {
        self.session = session
        undoStack = session.recoverySnapshots.map { snapshot in
            var copy = snapshot
            copy.recoverySnapshots = []
            return copy
        }
        lastError = nil
    }

    var canBack: Bool {
        guard let session else { return false }
        return MatchRecovery.handBack(current: session, undoStack: undoStack) != nil
            || MatchRecovery.previousStep(current: session, undoStack: undoStack) != nil
    }

    /// Back keeps recorded moves when it only hands the phone to the previous side.
    /// Restoring an earlier step asks first when shots, damage, or moves would disappear.
    var backNeedsConfirm: Bool {
        guard let session else { return false }
        if MatchRecovery.handBack(current: session, undoStack: undoStack) != nil {
            return false
        }
        guard let target = MatchRecovery.previousStep(current: session, undoStack: undoStack) else {
            return false
        }
        return MatchRecovery.discardsResults(current: session, restoring: target)
    }

    func back() {
        guard let session else { return }
        if let handed = MatchRecovery.handBack(current: session, undoStack: undoStack) {
            self.session = handed
            lastError = nil
            persist()
            return
        }
        guard let target = MatchRecovery.previousStep(current: session, undoStack: undoStack) else { return }
        let key = MatchStepKey(session)
        if let index = undoStack.lastIndex(where: { MatchStepKey($0) != key }) {
            undoStack = Array(undoStack.prefix(index))
        }
        self.session = target
        lastError = nil
        persist()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        session = previous
        lastError = nil
        persist()
    }

    func markTableReady() {
        mutate(.markTableReady)
    }

    func acknowledgeDeployment() {
        mutate(.acknowledgeDeployment)
    }

    /// Preference for the rest of this match. Not an undo step.
    func setDiceMode(_ mode: DiceMode) {
        guard session?.diceMode != mode else { return }
        mutate(.setDiceMode(mode), undoable: false)
    }

    func reviseMove(unitId: UUID, mode: MovementMode) {
        mutate(.reviseMovement(unitId: unitId, mode: mode))
    }

    func swapSides() {
        mutate(.swapSides)
    }

    func setInitiative(a1: Int, a2: Int, b1: Int, b2: Int) {
        guard let a = DiceRoll2D6.validated(die1: a1, die2: a2),
              let b = DiceRoll2D6.validated(die1: b1, die2: b2) else {
            lastErrorTitle = "Couldn’t use those dice"
            lastError = "Dice must be 1–6"
            return
        }
        mutate(.setInitiative(InitiativeRolls(lanceA: a, lanceB: b)))
    }

    /// Three or four sides: the finished rolls, with any tie-break rounds (§ 6.1).
    func setInitiative(rolls: InitiativeRolls) {
        mutate(.setInitiative(rolls), failureTitle: "Couldn’t use those dice")
    }

    /// Three or four sides: the players chose the whole order, first to move first (§ 6.1).
    func agreeInitiativeOrder(_ order: [SideId]) {
        mutate(.agreeInitiativeOrder(order), failureTitle: "Couldn’t start the turn")
    }

    /// The side gives up (§ 6.5). Its ’Mechs leave the table; Undo brings them back.
    func concede(side: SideId) {
        mutate(.concede(side: side), failureTitle: "Couldn’t concede")
    }

    /// Home edge for a side before placement (§ 6.4). The side that held the edge takes this side's old one.
    func assignHomeEdge(side: SideId, edge: TableEdge) {
        mutate(.assignHomeEdge(side: side, edge: edge), undoable: false, failureTitle: "Couldn’t change the edge")
    }

    /// Rolls every side for the app; ties re-roll among the tied sides only. The screen shows the dice, then
    /// calls `setInitiative(rolls:)`.
    func rollInitiativeEntry() -> InitiativeEntry? {
        guard let session else { return nil }
        var generator = SystemRandomNumberGenerator()
        let entry = InitiativeEntry.autoRolled(sides: session.sidesInGame, using: &generator)
        return entry.isComplete ? entry : nil
    }

    func setMini(unitId: UUID, mini: MiniMarker?) {
        mutate(.setMini(unitId: unitId, mini: mini), undoable: false)
    }

    /// Standing in water this turn: partial cover for shots at it, −1 heat in the End Phase.
    func setInWater(unitId: UUID, _ inWater: Bool) {
        mutate(.setInWater(unitId: unitId, inWater: inWater), undoable: false)
    }

    /// The players agreed who moves first, so no initiative dice.
    func agreeInitiative(firstToMove side: SideId) {
        mutate(.agreeInitiative(firstToMove: side), failureTitle: "Couldn’t start the turn")
    }

    /// Rolls both sides without changing the match. The battle screen shows the dice, then calls `setInitiative`.
    func previewAutoInitiative() -> InitiativeDicePreview? {
        for _ in 0..<20 {
            let preview = InitiativeDicePreview(
                a1: Int.random(in: 1...6),
                a2: Int.random(in: 1...6),
                b1: Int.random(in: 1...6),
                b2: Int.random(in: 1...6)
            )
            if preview.winner != nil { return preview }
        }
        lastErrorTitle = "Couldn’t roll initiative"
        lastError = "Could not break initiative tie"
        return nil
    }

    /// One-tap initiative: roll 2D6 each side, re-roll ties, then apply. Same rules as `previewAutoInitiative` plus `setInitiative`.
    func rollInitiative() {
        guard let preview = previewAutoInitiative() else { return }
        setInitiative(a1: preview.a1, a2: preview.a2, b1: preview.b1, b2: preview.b2)
    }

    func setMove(unitId: UUID, mode: MovementMode) {
        guard let session else { return }
        do {
            var next = try MatchReducer.reduce(session, .setMovementMode(unitId: unitId, mode: mode))
            next = try MatchReducer.reduce(next, .markMoved(unitId: unitId))
            pushUndo(session)
            self.session = next
            lastError = nil
            persist()
        } catch {
            lastErrorTitle = "Couldn’t record the move"
            lastError = error.localizedDescription
        }
    }

    func skipMovesAndAdvance() {
        guard let session else { return }
        do {
            var next = try MatchReducer.reduce(session, .skipRemainingMoves)
            next = try MatchReducer.reduce(next, .advancePhase)
            pushUndo(session)
            self.session = next
            lastError = nil
            persist()
        } catch {
            lastErrorTitle = "Couldn’t start shooting"
            lastError = error.localizedDescription
        }
    }

    func finishCombat() {
        mutate(.finishCombat, failureTitle: "Couldn’t finish shooting")
    }

    func resolveEnd() {
        mutate(.resolveEndPhase, failureTitle: "Couldn’t finish the turn")
    }

    /// The End Phase Score step and the end of the turn in one undoable change (PlayModeSpec § 8.5). `answers` holds
    /// each side's entries; a side with none scores nothing.
    func scoreObjectiveAndFinish(_ answers: [SideId: [ObjectiveScoreEntry]]) {
        guard let session else { return }
        do {
            var next = session
            for side in ObjectiveRules.sidesStillToScore(in: session) {
                next = try MatchReducer.reduce(next, .scoreObjective(side: side, entries: answers[side] ?? []))
            }
            next = try MatchReducer.reduce(next, .resolveEndPhase)
            pushUndo(session)
            self.session = next
            lastError = nil
            persist()
        } catch {
            lastErrorTitle = "Couldn’t score the turn"
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func applyAttack(
        attackerId: UUID,
        defenderId: UUID,
        range: RangeBracket,
        die1: Int,
        die2: Int,
        attackerMove: MovementMode,
        targetMove: TargetMoveModifier,
        woods: Bool = false,
        partialCover: Bool = false,
        rearHit: Bool = false,
        overheatUsed: Int = 0,
        attackKind: AttackKind = .weapon,
        minimalDie: Int? = nil
    ) -> Bool {
        guard let roll = DiceRoll2D6.validated(die1: die1, die2: die2) else {
            lastErrorTitle = "Couldn’t save the shot"
            lastError = "Dice must be 1–6"
            return false
        }
        let attack = SATORAttackCommand(
            attackerId: attackerId,
            defenderId: defenderId,
            range: range,
            roll: roll,
            attackerMove: attackerMove,
            targetMove: targetMove,
            woods: woods,
            partialCover: partialCover,
            rearHit: rearHit,
            overheatUsed: overheatUsed,
            attackKind: attackKind,
            minimalDie: minimalDie
        )
        let failureTitle = attackKind == .physical ? "Couldn’t save the attack" : "Couldn’t save the shot"
        // Combat Intuition (Clash of Steel): a shot in the Movement Phase, damage effects at once.
        if let formation = combatIntuitionFormation(for: attackerId) {
            mutateBoxRules(.combatIntuitionAttack(formationId: formation.id, attack: attack), failureTitle: failureTitle)
            return lastError == nil
        }
        mutate(.resolveSATOR(attack), failureTitle: failureTitle)
        return lastError == nil
    }

    @discardableResult
    func applyPendingCrit(unitId: UUID, die1: Int, die2: Int) -> Bool {
        guard let roll = DiceRoll2D6.validated(die1: die1, die2: die2) else {
            lastErrorTitle = "Couldn’t save the critical"
            lastError = "Invalid crit roll"
            return false
        }
        // Already resolved (e.g. a double tap): nothing to do, and no developer-speak alert.
        guard session?.units.first(where: { $0.id == unitId })?.pendingCritical == true else { return true }
        mutate(.applyCritical(unitId: unitId, roll: roll), failureTitle: "Couldn’t save the critical")
        settleCombatIntuition()
        return lastError == nil
    }

    #if DEBUG
    /// `-debug_damage` (DEBUG builds only): wear the last two ’Mechs of each side down so withdrawal,
    /// "Left the table" and condition lines can be checked on screen without playing several turns.
    func debugSeedDamage() {
        guard var next = session else { return }
        for side in next.sideIds {
            let ids = next.units.filter { $0.side == side }.map(\.id)
            guard ids.count >= 2, let crippled = next.units.firstIndex(where: { $0.id == ids[ids.count - 2] }),
                  let gone = next.units.firstIndex(where: { $0.id == ids[ids.count - 1] }) else { continue }
            next.units[crippled].armorDamage = next.units[crippled].armorCap
            next.units[crippled].structureDamage = next.units[crippled].structureCap / 2
            next.units[crippled].heat = 2
            next.units[crippled].crits.weaponHits = 1
            if side == .lanceB {
                next.units[gone].combatStatus = .removed
                next.units[gone].leftTable = true
            } else {
                next.units[gone].armorDamage = 1
            }
        }
        session = next
    }
    #endif

    /// Forced Withdrawal: the ’Mech drove off the table. It counts as destroyed. Undo puts it back.
    func leaveTable(unitId: UUID) {
        mutate(.leaveTable(unitId: unitId), failureTitle: "Couldn’t record that")
    }

    /// Autosave + dismiss — does not abandon.
    func leaveAndSave() {
        persist()
    }

    func abandon() {
        guard let session else { return }
        let id = session.id
        mutate(.abandonMatch, undoable: false)
        do {
            try repository.delete(id: id)
            self.session = nil
            undoStack.removeAll()
            lastError = nil
        } catch {
            lastErrorTitle = "Couldn’t discard the game"
            lastError = "Could not discard match: \(error.localizedDescription)"
        }
    }

    /// Leave a completed match without rewriting status to abandoned.
    func dismissCompleted() {
        guard let session, session.status == .completed else { return }
        do {
            try repository.delete(id: session.id)
            self.session = nil
            undoStack.removeAll()
            lastError = nil
        } catch {
            lastErrorTitle = "Couldn’t clear the game"
            lastError = "Could not clear match: \(error.localizedDescription)"
        }
    }

    private func mutate(_ command: MatchCommand, undoable: Bool = true, failureTitle: String = "Couldn’t update the game") {
        guard let session else { return }
        do {
            let next = try MatchReducer.reduce(session, command)
            if undoable {
                pushUndo(session)
            }
            self.session = next
            lastError = nil
            persist()
        } catch {
            lastErrorTitle = failureTitle
            lastError = error.localizedDescription
        }
    }

    /// Box rules (Battlefield Support, Formations, buildings). Same undo and save as `mutate`. Helpers that
    /// call it live in MatchStore+BoxRules.swift.
    func mutateBoxRules(_ command: BoxRulesCommand, undoable: Bool = true, failureTitle: String = "Couldn’t update the game") {
        guard let session else { return }
        do {
            let next = try BoxRulesReducer.reduce(session, command)
            if undoable { pushUndo(session) }
            self.session = next
            lastError = nil
            persist()
        } catch {
            lastErrorTitle = failureTitle
            lastError = error.localizedDescription
        }
    }

    /// Bumps on every undoable change so the battle screen can offer a short-lived Undo.
    private(set) var undoToken = 0

    /// Turn on which each coach step was first shown, keyed by game and step. Brief coaching explains
    /// a step in full on that turn only. Kept here, not in view state, so rotating doesn't re-explain
    /// it. Not saved: a resumed game explains each step once more.
    private(set) var coachFirstSeen: [String: Int] = [:]

    func noteCoachStep(_ key: String, turn: Int) {
        guard coachFirstSeen[key] == nil else { return }
        coachFirstSeen[key] = turn
    }

    private func pushUndo(_ snapshot: MatchSession) {
        undoToken += 1
        var trimmed = snapshot
        trimmed.recoverySnapshots = []
        undoStack.append(trimmed)
        if undoStack.count > 12 {
            undoStack.removeFirst()
        }
    }

    private func persist() {
        guard var session else { return }
        session.recoverySnapshots = undoStack
        self.session = session
        if session.status == .abandoned {
            do {
                try repository.delete(id: session.id)
            } catch {
                lastErrorTitle = "Couldn’t save the game"
                lastError = "Save failed: \(error.localizedDescription)"
            }
            return
        }
        do {
            try repository.save(session)
        } catch {
            lastErrorTitle = "Couldn’t save the game"
            lastError = "Save failed: \(error.localizedDescription)"
        }
    }

    private func adoptScenario(_ dto: GuidedScenarioDTO) {
        let steps = dto.tableSteps.isEmpty ? ScenarioPresentation.fallback.tableSteps : dto.tableSteps
        scenario = ScenarioPresentation(
            id: dto.scenarioId,
            title: dto.title,
            subtitle: dto.subtitle,
            tableSteps: steps,
            winningSummary: dto.winningSummary,
            introduces: dto.introduces ?? [],
            coachNotes: dto.coachNotes ?? [],
            layout: dto.layout
        )
        scenarioLoaded = true
    }

    private var undoActionName: String? {
        guard let session, let previous = undoStack.last else { return nil }
        var names: [String] = []
        for unit in session.units {
            guard let before = previous.units.first(where: { $0.id == unit.id }) else { continue }
            if unit.leftTable, !before.leftTable {
                names.append("left the table")
                continue
            }
            let moveChanged = unit.movementMode != before.movementMode && unit.movementMode != .unset
            let justMoved = unit.hasMovedThisTurn && !before.hasMovedThisTurn && unit.movementMode != .unset
            if moveChanged || justMoved {
                names.append(recordedMoveVerb(unit.movementMode))
            }
        }
        return names.count == 1 ? names[0] : nil
    }

    private func recordedMoveVerb(_ mode: MovementMode) -> String {
        switch mode {
        case .standstill: "Stood still"
        case .ground: "Walked"
        case .sprint: "Sprinted"
        case .jump: "Jumped"
        case .unset: "move"
        }
    }
}

#if DEBUG
@MainActor
enum BattlePreview {
    static func store(session: MatchSession = PreviewFixtures.session()) -> MatchStore {
        let store = MatchStore(repository: InMemoryMatchSessionRepository())
        store.resume(session)
        return store
    }
}
#endif

struct InitiativeDicePreview: Equatable, Sendable {
    var a1: Int
    var a2: Int
    var b1: Int
    var b2: Int

    var sideATotal: Int { a1 + a2 }
    var sideBTotal: Int { b1 + b2 }

    var winner: SideId? {
        if sideATotal > sideBTotal { return .lanceA }
        if sideBTotal > sideATotal { return .lanceB }
        return nil
    }

    /// The lower roll moves first.
    var firstToMove: SideId? {
        winner.map { $0 == .lanceA ? .lanceB : .lanceA }
    }
}
