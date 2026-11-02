import SwiftUI
import UIKit
import MechBuddyDomain

struct BattleFlowView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Bindable var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showSATOR = false
    @State private var showCrit: MatchUnitState?
    @State private var focusUnit: MatchUnitState?
    @State private var prefillAttackerId: UUID?
    @State private var a1: Int?
    @State private var a2: Int?
    @State private var b1: Int?
    @State private var b2: Int?
    @State private var autoPreview: InitiativeDicePreview?

    @State private var showAbandonConfirm = false
    @State private var showSkipConfirm = false
    @State private var showEventLog = false
    @State private var showBackConfirm = false
    @State private var showDoneShootingConfirm = false
    @State private var focusFollowUp: FocusFollowUp?

    @State private var passSide: SideId?
    @State private var passToken = 0
    @State private var healthBefore: [UUID: Int] = [:]
    @State private var landingUnitID: UUID?
    @State private var wreckToken = 0

    var body: some View {
        screen
            .navigationTitle("Ridge Line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { battleToolbar }
            .onAppear { openMatch() }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: store.session?.status) { _, status in
                if status == .abandoned || store.session == nil {
                    dismiss()
                }
            }
            .onChange(of: store.session?.phase) { _, phase in
                if phase == .initiative {
                    clearDice()
                }
            }
            .onChange(of: cue) { previous, next in
                handleCue(previous: previous, next: next)
            }
            .onChange(of: showSATOR) { _, showing in
                handleSolver(showing)
            }
            .tmHaptic(.phaseAdvance, trigger: passToken, when: { $0 > 0 })
            .tmHaptic(.criticalOwed, trigger: cue?.criticalID, when: { $0 != nil })
            .tmHaptic(.unitWrecked, trigger: wreckToken, when: { $0 > 0 })
            .confirmationDialog("Discard this game?", isPresented: $showAbandonConfirm, titleVisibility: .visible) {
                Button("Discard game", role: .destructive) {
                    store.abandon()
                }
                Button("Keep playing", role: .cancel) {}
            } message: {
                Text("You’ll lose this game’s progress. You can start Ridge Line again from Play.")
            }
            .confirmationDialog("Go back a step?", isPresented: $showBackConfirm, titleVisibility: .visible) {
                Button("Go back", role: .destructive) {
                    store.back()
                }
                Button("Stay here", role: .cancel) {}
            } message: {
                Text("This undoes shots, damage, or recorded moves from this step. The rest of the game stays saved.")
            }
            .confirmationDialog("Some ’Mechs have not shot", isPresented: $showDoneShootingConfirm, titleVisibility: .visible) {
                Button("Done shooting anyway") {
                    store.finishCombatSide()
                }
                Button("Keep shooting", role: .cancel) {}
            } message: {
                Text("They can still fire. Skipping means this side fires nothing else.")
            }
            .confirmationDialog(
                "Some ’Mechs have no move recorded",
                isPresented: $showSkipConfirm,
                titleVisibility: .visible
            ) {
                Button("Start shooting anyway") {
                    store.skipMovesAndAdvance()
                }
                Button("Keep recording moves", role: .cancel) {}
            } message: {
                Text("Unrecorded moves will count as Walk when they shoot. Prefer recording Stand still / Walk / Sprint / Jump for each ’Mech.")
            }
            .sheet(isPresented: $showEventLog) {
                EventLogSheet(store: store)
            }
            .sheet(isPresented: $showSATOR) {
                if let session = store.session {
                    CombatSolverSheet(
                        session: session,
                        store: store,
                        initialAttackerId: prefillAttackerId
                    )
                }
            }
            .sheet(item: $showCrit) { unit in
                CritSheet(unit: unit, store: store)
            }
            .sheet(item: $focusUnit, onDismiss: {
                switch focusFollowUp {
                case .shot(let id):
                    prefillAttackerId = id
                    showSATOR = true
                case .crit(let unit):
                    showCrit = unit
                case nil:
                    break
                }
                focusFollowUp = nil
            }) { unit in
                if let session = store.session {
                    UnitFocusSheet(
                        unit: unit,
                        session: session,
                        isReadOnly: false,
                        onResolveAttack: { focusFollowUp = .shot(unit.id) },
                        onRollCrit: { focusFollowUp = .crit(unit) }
                    )
                }
            }
            .alert(store.lastErrorTitle, isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } }
            )) {
                Button("OK", role: .cancel) { store.lastError = nil }
            } message: {
                Text(store.lastError ?? "")
            }
    }

    @ViewBuilder
    private var screen: some View {
        if let session = store.session {
            let coach = BattleCoach(session: session)
            if coach.step == .victory {
                VictoryView(
                    session: session,
                    onRematch: { store.rematch(from: dependencies.content) },
                    onDone: {
                        store.dismissCompleted()
                        dismiss()
                    },
                    onBack: { attemptBack() }
                )
            } else {
                battle(session, coach: coach)
            }
        } else {
            loadingSkeleton
        }
    }

    private func battle(_ session: MatchSession, coach: BattleCoach) -> some View {
        stage(session, coach: coach)
            .accessibilityIdentifier(coach.step == .tableSetup ? "as.ridge.tablePrep" : "as.battle.screen")
            .background {
                if coach.step == .tableSetup {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier("as.mission.setup")
                        .accessibilityLabel("Mission setup")
                        .allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private func stage(_ session: MatchSession, coach: BattleCoach) -> some View {
        switch stageLayout {
        case .stacked:
            toolColumn(session, coach: coach, showsUnits: true)
        case .phoneLandscape:
            HStack(alignment: .top, spacing: 0) {
                BattleRoster(
                    session: session,
                    coach: coach,
                    layout: .phoneLandscape,
                    landingUnitID: landingUnitID,
                    onOpenUnit: { focusUnit = $0 },
                    onShoot: openShot
                )
                .frame(width: BattleStageLayout.unitStripWidth, alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                Divider()
                toolColumn(session, coach: coach, showsUnits: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        case .padColumns:
            HStack(alignment: .top, spacing: 0) {
                toolColumn(session, coach: coach, showsUnits: false)
                Divider()
                BattleRoster(
                    session: session,
                    coach: coach,
                    layout: .padColumns,
                    landingUnitID: landingUnitID,
                    onOpenUnit: { focusUnit = $0 },
                    onShoot: openShot
                )
                .frame(width: BattleStageLayout.rosterColumnWidth)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func toolColumn(_ session: MatchSession, coach: BattleCoach, showsUnits: Bool) -> some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(alignment: .leading, spacing: TMSpace.md) {
                    step(session, coach: coach, showsUnits: showsUnits)
                }
                .padding(TMSpace.lg)
                .onChange(of: landingUnitID) { _, id in
                    guard showsUnits, let id else { return }
                    if reduceMotion {
                        proxy.scrollTo(id, anchor: .center)
                    } else {
                        withAnimation(TMMotion.drain) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .top, spacing: 0) {
            headerInset(session, coach: coach)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            dockInset(session, coach: coach)
        }
    }

    @ViewBuilder
    private func headerInset(_ session: MatchSession, coach: BattleCoach) -> some View {
        if BattleChrome.showsHeader(coach.step) {
            VStack(spacing: TMSpace.sm) {
                BattleHeader(
                    turn: session.turn,
                    maxTurns: session.ruleset.maxTurns,
                    phase: session.phase,
                    activeSide: BattleChrome.showsActiveSide(coach.step) ? session.activeSide : nil
                )
                if let passSide {
                    SidePassBanner(side: passSide)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? TMMotion.reduced : TMMotion.reveal, value: passSide)
        }
    }

    @ViewBuilder
    private func dockInset(_ session: MatchSession, coach: BattleCoach) -> some View {
        let primary = primaryButton(session, coach: coach)
        let secondary = secondaryButton(session, coach: coach)
        if primary != nil || secondary != nil {
            BattleDock(
                primary: primary,
                secondary: secondary,
                tint: BattleChrome.dockTint(session: session, coach: coach)
            )
        }
    }

    private var stageLayout: BattleStageLayout {
        BattleStageLayout.resolve(
            idiom: UIDevice.current.userInterfaceIdiom,
            horizontal: horizontalSizeClass,
            vertical: verticalSizeClass
        )
    }

    private func openShot(_ unit: MatchUnitState) {
        prefillAttackerId = unit.id
        showSATOR = true
    }

    @ViewBuilder
    private func step(_ session: MatchSession, coach: BattleCoach, showsUnits: Bool) -> some View {
        if coach.step == .tableSetup {
            TableSetupStep(
                session: session,
                scenario: store.scenario,
                canSwap: coach.canSwapSides,
                onSwap: { store.swapSides() }
            )
        } else if let owed = coach.pendingCritical,
                  let unit = session.units.first(where: { $0.id == owed.unitId }) {
            CriticalPendingStep(
                unit: unit,
                count: owed.count,
                diceMode: session.diceMode,
                landingUnitID: landingUnitID,
                showsUnit: showsUnits,
                onOpenUnit: { focusUnit = unit }
            )
        } else {
            switch coach.step {
            case .placeMiniatures:
                PlaceMiniaturesStep(session: session)
            case .initiative:
                InitiativeStep(
                    preview: autoPreview,
                    a1: $a1,
                    a2: $a2,
                    b1: $b1,
                    b2: $b2,
                    diceMode: diceModeBinding,
                    onClear: clearDice
                )
            case .movement:
                MovementStep(
                    session: session,
                    coach: coach,
                    showsUnits: showsUnits,
                    onSetMove: { store.setMove(unitId: $0, mode: $1) },
                    onReviseMove: { store.reviseMove(unitId: $0, mode: $1) },
                    onOpenUnit: { focusUnit = $0 }
                )
            case .combat:
                CombatStep(
                    session: session,
                    landingUnitID: landingUnitID,
                    showsUnits: showsUnits,
                    onOpenUnit: { focusUnit = $0 },
                    onShoot: openShot
                )
            case .end:
                CleanUpStep(
                    session: session,
                    coach: coach,
                    showsUnits: showsUnits,
                    onOpenUnit: { focusUnit = $0 }
                )
            case .tableSetup, .victory:
                EmptyView()
            }
        }
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            HStack {
                TurnCounter(turn: 1, maxTurns: 6)
                Spacer()
                PhaseTrack(current: .initiative, identifiesPhases: false)
            }
            TMCard(edgeColor: TMColor.sideA) {
                Text("First ’Mech")
                    .font(TMFont.cardTitle)
                Text("Armor and structure")
                    .font(TMFont.detail)
            }
            TMCard(edgeColor: TMColor.sideB) {
                Text("Second ’Mech")
                    .font(TMFont.cardTitle)
                Text("Armor and structure")
                    .font(TMFont.detail)
            }
        }
        .padding(TMSpace.lg)
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading the mission")
    }

    @ToolbarContentBuilder
    private var battleToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Leave") {
                if store.session?.status == .completed {
                    store.dismissCompleted()
                } else {
                    store.leaveAndSave()
                }
                dismiss()
            }
            .accessibilityIdentifier("as.battle.leave")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showEventLog = true
            } label: {
                Image(systemName: "list.bullet.rectangle")
            }
            .accessibilityLabel("What just happened")
            Menu {
                if store.canUndo {
                    Button(store.undoMenuTitle, systemImage: "arrow.uturn.backward") {
                        store.undo()
                    }
                }
                if store.canBack {
                    Button("Go back a step", systemImage: "chevron.backward") {
                        attemptBack()
                    }
                    .accessibilityIdentifier("as.battle.back")
                }
                if let session = store.session {
                    let coach = BattleCoach(session: session)
                    if coach.canSwapSides {
                        Button("Swap sides", systemImage: "arrow.left.arrow.right") {
                            store.swapSides()
                        }
                    }
                    if coach.step == .movement, !coach.movementComplete, coach.pendingCritical == nil {
                        Button("Skip remaining moves", systemImage: "forward.end") {
                            showSkipConfirm = true
                        }
                    }
                }
                Divider()
                Button("Discard this game", role: .destructive) {
                    showAbandonConfirm = true
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityIdentifier("as.battle.more")
            .accessibilityLabel("More")
        }
    }

    private func primaryButton(_ session: MatchSession, coach: BattleCoach) -> BattleDockButton? {
        if coach.step == .tableSetup {
            return BattleDockButton(
                title: "Start battle",
                identifier: "as.ridge.tableReady",
                specIdentifier: "as.mission.startBattle",
                hint: "Starts the battle.",
                action: { store.markTableReady() }
            )
        }
        if coach.step == .movement, !coach.movementComplete, coach.pendingCritical == nil {
            return nil
        }
        guard let primary = coach.primary else { return nil }
        switch primary {
        case .acknowledgeDeployment:
            return BattleDockButton(
                title: "Miniatures placed",
                identifier: "as.battle.primary",
                hint: "Records that the miniatures are placed.",
                action: { store.acknowledgeDeployment() }
            )
        case .useInitiativeRolls:
            let winner = InitiativeDice.winner(a1: a1, a2: a2, b1: b1, b2: b2)
            return BattleDockButton(
                title: winner.map { "\($0.displayName) wins — start moving" } ?? "Enter all four dice",
                identifier: "as.battle.primary",
                specIdentifier: "as.initiative.confirm",
                hint: winner.map { "\($0.displayName) won initiative. \($0.other.displayName) moves first." }
                    ?? "Enter all four dice. Higher total moves last.",
                disabled: winner == nil,
                action: applyManualInitiative
            )
        case .rollInitiative:
            if let autoPreview, let winner = autoPreview.winner {
                return BattleDockButton(
                    title: "\(winner.displayName) wins — start moving",
                    identifier: "as.battle.primary",
                    specIdentifier: "as.initiative.confirm",
                    hint: "\(winner.displayName) won initiative. \(winner.other.displayName) moves first.",
                    action: applyAutoPreview
                )
            }
            return BattleDockButton(
                title: "Roll both sides",
                identifier: "as.battle.primary",
                specIdentifier: "as.initiative.confirm",
                hint: "Rolls both sides. The higher total moves last.",
                action: { autoPreview = store.previewAutoInitiative() }
            )
        case .startShooting:
            return BattleDockButton(
                title: "Start shooting",
                identifier: "as.battle.primary",
                hint: "Ends movement and starts shooting.",
                action: { store.skipMovesAndAdvance() }
            )
        case .solveShot:
            return BattleDockButton(
                title: "Solve a shot",
                identifier: "as.battle.primary",
                hint: "Opens the shot solver.",
                action: {
                    prefillAttackerId = nil
                    showSATOR = true
                }
            )
        case .rollCritical(let count):
            let title = count > 1 ? "Roll critical (1 of \(count))" : "Roll critical"
            let hint = count > 1
                ? "Opens the next critical roll. \(count) are waiting."
                : "Opens the critical roll."
            return BattleDockButton(
                title: title,
                identifier: "as.battle.primary",
                hint: hint,
                action: { openCritical(session, coach: coach) }
            )
        case .resolveEnd:
            let finishes = coach.endWouldFinishMatch
            return BattleDockButton(
                title: finishes ? "See result" : "Next turn",
                identifier: "as.battle.primary",
                hint: finishes
                    ? "Ends the game and shows the result."
                    : "Finishes cleanup and starts the next turn.",
                action: { store.resolveEnd() }
            )
        }
    }

    private func secondaryButton(_ session: MatchSession, coach: BattleCoach) -> BattleDockButton? {
        guard coach.pendingCritical == nil else { return nil }
        if coach.step == .combat {
            return BattleDockButton(
                title: "Done shooting",
                identifier: "as.battle.doneShooting",
                specIdentifier: "as.battle.phaseDock.doneSide",
                hint: "\(session.activeSide.displayName) is done shooting",
                action: { finishShooting(coach) }
            )
        }
        if coach.step == .movement, !coach.movementComplete {
            return BattleDockButton(
                title: "Skip remaining",
                identifier: "as.battle.skipRemaining",
                hint: "Unrecorded moves will count as Walk.",
                action: { showSkipConfirm = true }
            )
        }
        return nil
    }

    private var diceModeBinding: Binding<DiceMode> {
        Binding(
            get: { store.session?.diceMode ?? .manual },
            set: { newMode in
                clearDice()
                store.setDiceMode(newMode)
            }
        )
    }

    private var cue: BattleCue? {
        guard let session = store.session else { return nil }
        let coach = BattleCoach(session: session)
        return BattleCue(
            step: coach.step,
            side: session.activeSide,
            turn: session.turn,
            criticalID: coach.pendingCritical?.unitId,
            criticalCount: coach.pendingCritical?.count ?? 0
        )
    }

    private func openMatch() {
        UIApplication.shared.isIdleTimerDisabled = true
        let already = store.session != nil
        if store.session == nil {
            do {
                if try store.resumeActive() == false {
                    store.startRidgeLine(from: dependencies.content, replaceActive: false)
                }
            } catch {
                store.lastErrorTitle = "Couldn’t open the game"
                store.lastError = error.localizedDescription
            }
        }
        store.ensureScenario(from: dependencies.content)
        if already, let session = store.session {
            let coach = BattleCoach(session: session)
            AccessibilityNotification.Announcement(BattleChrome.announcement(session: session, coach: coach)).post()
        }
    }

    private func handleCue(previous: BattleCue?, next: BattleCue?) {
        guard let next, let session = store.session else { return }
        let coach = BattleCoach(session: session)
        let sideChanged = previous?.side != next.side
        let stepChanged = previous?.step != next.step
        let sideOwned = next.step == .movement || next.step == .combat
        if let previous, sideChanged, sideOwned, next.criticalID == nil {
            presentPassBanner(next.side)
            if !stepChanged && previous.criticalID == next.criticalID {
                AccessibilityNotification.Announcement("\(next.side.displayName)’s turn — pass the phone").post()
                return
            }
        }
        AccessibilityNotification.Announcement(BattleChrome.announcement(session: session, coach: coach)).post()
    }

    private func presentPassBanner(_ side: SideId) {
        passToken += 1
        let token = passToken
        passSide = side
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard token == passToken else { return }
            passSide = nil
        }
    }

    private func handleSolver(_ showing: Bool) {
        guard let session = store.session else { return }
        if showing {
            healthBefore = Dictionary(uniqueKeysWithValues: session.units.map {
                ($0.id, $0.armorDamage + $0.structureDamage)
            })
            return
        }
        guard let hit = damagedUnit(in: session) else { return }
        landingUnitID = hit.id
        if hit.combatStatus == .destroyedPendingEnd || hit.combatStatus == .removed {
            wreckToken += 1
        }
        let hitID = hit.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.9))
            if landingUnitID == hitID {
                landingUnitID = nil
            }
        }
    }

    private func damagedUnit(in session: MatchSession) -> MatchUnitState? {
        session.units
            .map { unit -> (MatchUnitState, Int) in
                let before = healthBefore[unit.id] ?? 0
                return (unit, (unit.armorDamage + unit.structureDamage) - before)
            }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?
            .0
    }

    private func openCritical(_ session: MatchSession, coach: BattleCoach) {
        guard let pending = coach.pendingCritical,
              let unit = session.units.first(where: { $0.id == pending.unitId }) else { return }
        showCrit = unit
    }

    private func applyManualInitiative() {
        guard let a1, let a2, let b1, let b2 else { return }
        guard InitiativeDice.winner(a1: a1, a2: a2, b1: b1, b2: b2) != nil else { return }
        store.setInitiative(a1: a1, a2: a2, b1: b1, b2: b2)
        if store.lastError == nil {
            clearDice()
        }
    }

    private func applyAutoPreview() {
        guard let autoPreview else { return }
        store.setInitiative(a1: autoPreview.a1, a2: autoPreview.a2, b1: autoPreview.b1, b2: autoPreview.b2)
        if store.lastError == nil {
            clearDice()
        }
    }

    private func clearDice() {
        a1 = nil
        a2 = nil
        b1 = nil
        b2 = nil
        autoPreview = nil
    }

    private func attemptBack() {
        if store.backNeedsConfirm {
            showBackConfirm = true
        } else {
            store.back()
        }
    }

    private func finishShooting(_ coach: BattleCoach) {
        if coach.finishCombatNeedsConfirm {
            showDoneShootingConfirm = true
        } else {
            store.finishCombatSide()
        }
    }
}

private struct BattleCue: Equatable {
    var step: BattleCoach.Step
    var side: SideId
    var turn: Int
    var criticalID: UUID?
    var criticalCount: Int
}

private enum FocusFollowUp {
    case shot(UUID)
    case crit(MatchUnitState)
}
