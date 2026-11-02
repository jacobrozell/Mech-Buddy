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

    func startRidgeLine(from catalog: any ContentCatalogRepository, replaceActive: Bool) {
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
            let dto = try catalog.ridgeLineScenario()
            adoptScenario(dto)
            let ruleset = RidgeLineFactory.mapRuleset(dto.ruleset)
            let units = RidgeLineFactory.makeUnits(from: dto)
            session = try MatchReducer.reduce(
                MatchSession(ruleset: ruleset),
                .startMission(scenarioId: .ridgeLine, ruleset: ruleset, units: units)
            )
            undoStack.removeAll()
            lastError = nil
            persist()
        } catch {
            lastErrorTitle = "Couldn’t start the mission"
            lastError = error.localizedDescription
        }
    }

    /// Resume path. `startRidgeLine` already cached the briefing, so this is a no-op then.
    func ensureScenario(from catalog: any ContentCatalogRepository) {
        guard !scenarioLoaded else { return }
        scenarioLoaded = true
        guard let dto = try? catalog.ridgeLineScenario() else { return }
        adoptScenario(dto)
    }

    func rematch(from catalog: any ContentCatalogRepository) {
        if let session, session.status == .completed {
            try? repository.delete(id: session.id)
        }
        startRidgeLine(from: catalog, replaceActive: false)
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

    func finishCombatSide() {
        mutate(.finishCombatSide, failureTitle: "Couldn’t finish shooting")
    }

    func resolveEnd() {
        mutate(.resolveEndPhase, failureTitle: "Couldn’t finish the turn")
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
        rearHit: Bool = false
    ) -> Bool {
        guard let roll = DiceRoll2D6.validated(die1: die1, die2: die2) else {
            lastErrorTitle = "Couldn’t save the shot"
            lastError = "Dice must be 1–6"
            return false
        }
        mutate(
            .resolveSATOR(
                SATORAttackCommand(
                    attackerId: attackerId,
                    defenderId: defenderId,
                    range: range,
                    roll: roll,
                    attackerMove: attackerMove,
                    targetMove: targetMove,
                    woods: woods,
                    partialCover: partialCover,
                    rearHit: rearHit
                )
            ),
            failureTitle: "Couldn’t save the shot"
        )
        return lastError == nil
    }

    @discardableResult
    func applyPendingCrit(unitId: UUID, die1: Int, die2: Int) -> Bool {
        guard let roll = DiceRoll2D6.validated(die1: die1, die2: die2) else {
            lastErrorTitle = "Couldn’t save the critical"
            lastError = "Invalid crit roll"
            return false
        }
        mutate(.applyCritical(unitId: unitId, roll: roll), failureTitle: "Couldn’t save the critical")
        return lastError == nil
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

    private func pushUndo(_ snapshot: MatchSession) {
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

    private func adoptScenario(_ dto: RidgeLineScenarioDTO) {
        let steps = dto.tableSteps.isEmpty ? ScenarioPresentation.fallback.tableSteps : dto.tableSteps
        scenario = ScenarioPresentation(
            title: dto.title,
            subtitle: dto.subtitle,
            tableSteps: steps,
            winningSummary: dto.winningSummary
        )
        scenarioLoaded = true
    }

    private var undoActionName: String? {
        guard let session, let previous = undoStack.last else { return nil }
        var names: [String] = []
        for unit in session.units {
            guard let before = previous.units.first(where: { $0.id == unit.id }) else { continue }
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
}
