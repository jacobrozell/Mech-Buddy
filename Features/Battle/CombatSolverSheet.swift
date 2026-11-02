import SwiftUI
import MechBuddyDomain

struct CombatSolverSheet: View {
    let session: MatchSession
    @Bindable var store: MatchStore
    var initialAttackerId: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var attackerId: UUID?
    @State private var defenderId: UUID?
    @State private var insight = CombatTableInsight()
    @State private var d1: Int?
    @State private var d2: Int?
    @State private var showUnusual = false
    @State private var selectedLetter: String?
    /// Walk and sprint share one target modifier. This only chooses the word on screen.
    @State private var countedSprint = false

    init(session: MatchSession, store: MatchStore, initialAttackerId: UUID? = nil) {
        self.session = session
        self.store = store
        self.initialAttackerId = initialAttackerId
        let attacker = Self.openingAttacker(session: session, initial: initialAttackerId)
        let defender = Self.openingDefender(session: session)
        _attackerId = State(initialValue: attacker)
        _defenderId = State(initialValue: defender)
        _insight = State(initialValue: Self.openingInsight(session: session, defenderId: defender))
        _d1 = State(initialValue: nil)
        _d2 = State(initialValue: nil)
        _showUnusual = State(initialValue: false)
        _selectedLetter = State(initialValue: nil)
        _countedSprint = State(initialValue: Self.openingCountedSprint(session: session, defenderId: defender))
    }

    private var live: MatchSession { store.session ?? session }

    private var friendlies: [MatchUnitState] {
        live.units.filter { $0.side == live.activeSide && $0.combatStatus != .removed }
    }

    private var shooters: [MatchUnitState] {
        friendlies.filter(\.canAttackThisTurn)
    }

    private var defenders: [MatchUnitState] {
        live.units.filter { $0.side != live.activeSide && $0.combatStatus != .removed }
    }

    private var attacker: MatchUnitState? {
        attackerId.flatMap { id in live.units.first { $0.id == id } }
    }

    private var defender: MatchUnitState? {
        defenderId.flatMap { id in live.units.first { $0.id == id } }
    }

    private var roll: DiceRoll2D6? {
        guard let d1, let d2 else { return nil }
        return DiceRoll2D6.validated(die1: d1, die2: d2)
    }

    private var modeBinding: Binding<DiceMode> {
        Binding(
            get: { store.session?.diceMode ?? session.diceMode },
            set: { newMode in
                guard newMode != (store.session?.diceMode ?? session.diceMode) else { return }
                d1 = nil
                d2 = nil
                store.setDiceMode(newMode)
            }
        )
    }

    private var solve: CombatSolve? {
        guard let attacker, let defender else { return nil }
        return CombatSolver.solve(
            attacker: attacker,
            defender: defender,
            insight: insight,
            overheatAllowed: live.ruleset.overheatAllowed,
            roll: roll
        )
    }

    private var pairToken: String {
        "\(attackerId?.uuidString ?? "")|\(defenderId?.uuidString ?? "")"
    }

    private var pairColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [
            GridItem(.flexible(), spacing: TMSpace.sm),
            GridItem(.flexible(), spacing: TMSpace.sm)
        ]
    }

    var body: some View {
        NavigationStack {
            content
                .animation(reduceMotion ? TMMotion.reduced : TMMotion.reveal, value: pairToken)
                .navigationTitle("Solve a shot")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .onChange(of: defenderId) { _, _ in
                    d1 = nil
                    d2 = nil
                    selectedLetter = nil
                    syncTargetMoveFromDefender()
                }
                .onChange(of: attackerId) { _, _ in
                    d1 = nil
                    d2 = nil
                    selectedLetter = nil
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("as.sator.sheet")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
        }
        if attacker != nil, defender != nil {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Change") {
                    attackerId = nil
                    defenderId = nil
                }
                .accessibilityLabel("Different ’Mechs")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if shooters.isEmpty {
            noShotsLeft
        } else if let attacker, let defender, let solve {
            shotScreen(attacker: attacker, defender: defender, solve: solve)
        } else {
            pairPicker
        }
    }

    private var noShotsLeft: some View {
        VStack(spacing: TMSpace.lg) {
            Spacer()
            EmptyState(
                systemImage: "checkmark.circle",
                title: "\(live.activeSide.displayName) has fired everything",
                message: "Nothing left to shoot this turn.",
                actionTitle: "Done shooting",
                action: finishShooting
            )
            if let error = store.lastError {
                Text(error)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TMSpace.lg)
            }
            Spacer()
        }
    }

    private var pairPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    Eyebrow("Who’s shooting?") {
                        SideBadge(side: live.activeSide)
                    }
                    LazyVGrid(columns: pairColumns, spacing: TMSpace.sm) {
                        ForEach(friendlies) { unit in
                            shooterCard(unit)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("as.sator.attacker")
                .accessibilityLabel("Who’s shooting?")

                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    Eyebrow("At which target?") {
                        SideBadge(side: live.activeSide.other)
                    }
                    if defenders.isEmpty {
                        Text("No enemy ’Mechs left on the table.")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: pairColumns, spacing: TMSpace.sm) {
                            ForEach(defenders) { unit in
                                targetCard(unit)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("as.sator.target")
                .accessibilityLabel("At which target?")
            }
            .padding(TMSpace.lg)
        }
    }

    private func shooterCard(_ unit: MatchUnitState) -> some View {
        let reason = unavailableReason(unit)
        return VStack(alignment: .leading, spacing: TMSpace.xs) {
            UnitCard(
                unit: unit,
                isActiveSide: true,
                accessibilityIdentifier: "as.sator.pick.attacker.\(unit.id.uuidString)",
                isSelected: attackerId == unit.id,
                showsChevron: false,
                isEnabled: reason == nil,
                showsIdleStatus: false,
                hint: reason ?? "Choose this shooter",
                note: reason,
                action: { attackerId = unit.id }
            )
            if let reason {
                Text(reason)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func targetCard(_ unit: MatchUnitState) -> some View {
        let caption = targetCaption(unit)
        return VStack(alignment: .leading, spacing: TMSpace.xs) {
            UnitCard(
                unit: unit,
                isActiveSide: false,
                accessibilityIdentifier: "as.sator.pick.target.\(unit.id.uuidString)",
                isSelected: defenderId == unit.id,
                showsChevron: false,
                showsIdleStatus: false,
                hint: "Choose this target",
                note: caption,
                action: { defenderId = unit.id }
            )
            Text(caption)
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
        }
    }

    private var gaugeBesideDice: Bool { verticalSizeClass == .compact }

    private func shotScreen(attacker: MatchUnitState, defender: MatchUnitState, solve: CombatSolve) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.lg) {
                if let tn = solve.targetNumber {
                    breakdown(tn)
                }
                rangeControl
                targetMovedControl(defender)
                conditions
                if gaugeBesideDice {
                    compactRoll(solve)
                } else if solve.cannotShootReason == nil {
                    rollSection
                }
                if let isHit = solve.isHit, let roll = solve.roll, let tn = solve.targetNumber {
                    OutcomeBanner(hit: isHit, rolled: roll.total, targetNumber: tn.value)
                }
                if solve.cannotShootReason == nil, solve.targetNumber?.autoMiss != true {
                    DamagePreviewCard(solve: solve, defender: defender)
                }
            }
            .padding(TMSpace.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Text("\(attacker.name) → \(defender.name)")
                    .font(TMFont.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(attacker.name) shooting \(defender.name)")
                if !gaugeBesideDice {
                    gauge(for: solve)
                }
            }
            .padding(.horizontal, TMSpace.lg)
            .padding(.top, TMSpace.sm)
            .padding(.bottom, gaugeBesideDice ? TMSpace.sm : TMSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            applyBar(solve)
        }
    }

    private var rollSection: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Roll")
            DiceTray(
                mode: modeBinding,
                die1: $d1,
                die2: $d2,
                manualPrompt: "Tap the faces you rolled.",
                autoPrompt: "The app rolls.",
                identifierPrefix: "as.sator"
            )
        }
    }

    @ViewBuilder
    private func compactRoll(_ solve: CombatSolve) -> some View {
        if solve.cannotShootReason == nil {
            HStack(alignment: .top, spacing: TMSpace.md) {
                gauge(for: solve)
                    .frame(maxWidth: 280)
                rollSection
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            gauge(for: solve)
        }
    }

    @ViewBuilder
    private func gauge(for solve: CombatSolve) -> some View {
        if let reason = solve.cannotShootReason {
            TNGauge(targetNumber: 13, reason: reason, blockedTitle: "Can’t shoot")
        } else if let tn = solve.targetNumber {
            TNGauge(
                targetNumber: tn.value,
                rolledTotal: solve.roll?.total,
                reason: tn.autoMiss ? "Need \(tn.value) or higher. This shot always misses." : nil
            )
        }
    }

    @ViewBuilder
    private func breakdown(_ tn: TargetNumber) -> some View {
        let terms = SATORTerms.make(from: tn).map { term in
            guard countedSprint, term.letter == "T" else { return term }
            var sprint = term
            sprint.label = "Target sprinted"
            sprint.explanation = term.explanation.replacingOccurrences(of: "walked", with: "sprinted")
            return sprint
        }
        if terms.isEmpty {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Eyebrow("Summary")
                ForEach(tn.reasons, id: \.self) { line in
                    Text(line)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow("Summary")
                FlowLayout(spacing: TMSpace.sm) {
                    ForEach(terms) { term in
                        let selected = selectedLetter == term.letter
                        Button {
                            selectedLetter = selected ? nil : term.letter
                        } label: {
                            Text(SATORTerms.chipText(term))
                                .font(TMFont.stat)
                                .foregroundStyle(selected ? TMColor.onSignal : Color.primary)
                                .frame(minHeight: 44)
                                .padding(.horizontal, TMSpace.md)
                                .background(selected ? TMColor.signal : TMColor.readout, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(term.letter), \(term.label), \(term.delta), included")
                        .accessibilityHint(term.explanation)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityRemoveTraits(selected ? [] : .isSelected)
                    }
                }
                Text(SATORTerms.equation(terms, total: tn.value))
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Target number \(tn.value): \(tn.reasons.dropLast().joined(separator: ", "))")
                if let term = terms.first(where: { $0.letter == selectedLetter }) {
                    Text(term.explanation)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var rangeControl: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Range")
            if insight.rangeBracket == .outOfRange {
                Text("Past 42 inches, so the range bands are off.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("as.sator.range")
            } else {
                Picker("Range", selection: rangeBand) {
                    Text("Short ≤6″").tag(RangeBracket.short)
                    Text("Medium 7–24″").tag(RangeBracket.medium)
                    Text("Long 25–42″").tag(RangeBracket.long)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("as.sator.range")
            }
            Toggle(isOn: beyondRange) {
                Text(">42″")
            }
            .toggleStyle(.button)
            .accessibilityLabel("More than 42 inches")
        }
    }

    private var rangeBand: Binding<RangeBracket> {
        Binding(
            get: {
                insight.rangeBracket == .outOfRange ? .long : insight.rangeBracket
            },
            set: { newValue in
                switch newValue {
                case .short: insight.rangeInches = 6
                case .medium: insight.rangeInches = 24
                case .long: insight.rangeInches = 42
                case .outOfRange: insight.rangeInches = 43
                }
            }
        )
    }

    private var beyondRange: Binding<Bool> {
        Binding(
            get: { insight.rangeBracket == .outOfRange },
            set: { isBeyond in
                insight.rangeInches = isBeyond ? 43 : 42
            }
        )
    }

    private func targetMovedControl(_ defender: MatchUnitState) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Target moved")
            HStack(alignment: .center, spacing: TMSpace.md) {
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text(targetMoveTitle(defender))
                        .font(TMFont.cardTitle)
                    Text(targetMoveDetail(defender))
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: TMSpace.sm)
                Menu {
                    Button {
                        setTargetMove(.groundUsesTMM, sprint: false)
                    } label: {
                        targetMoveChoice("Walked", chosen: insight.targetMove == .groundUsesTMM && !countedSprint)
                    }
                    Button {
                        setTargetMove(.groundUsesTMM, sprint: true)
                    } label: {
                        targetMoveChoice("Sprinted", chosen: insight.targetMove == .groundUsesTMM && countedSprint)
                    }
                    Button {
                        setTargetMove(.standstill)
                    } label: {
                        targetMoveChoice("Stood still", chosen: insight.targetMove == .standstill)
                    }
                    Button {
                        setTargetMove(.jumpedUsesTMMPlus1)
                    } label: {
                        targetMoveChoice("Jumped", chosen: insight.targetMove == .jumpedUsesTMMPlus1)
                    }
                    Button {
                        setTargetMove(.immobile)
                    } label: {
                        targetMoveChoice("Can’t move", chosen: insight.targetMove == .immobile)
                    }
                } label: {
                    Text("Change")
                        .frame(minHeight: 44)
                }
                .disabled(defender.isImmobile)
                .accessibilityIdentifier("as.sator.tgtMove")
            }
        }
    }

    private var conditions: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Conditions")
            FlowLayout(spacing: TMSpace.sm) {
                chipToggle("Woods", isOn: $insight.woods)
                chipToggle("Partial cover", isOn: $insight.partialCover)
                chipToggle("Rear shot", isOn: $insight.rearHit)
            }
            Button {
                showUnusual.toggle()
            } label: {
                HStack(spacing: TMSpace.xs) {
                    Text("More…")
                        .font(TMFont.detail.weight(.semibold))
                    Image(systemName: showUnusual ? "chevron.up" : "chevron.down")
                        .font(TMFont.detail.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .accessibilityHint("Line of sight and front arc")
            if showUnusual {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    Text("Leave these off for a normal shot. Turn one on only when that shot is not allowed.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    chipToggle(
                        "Can’t see the target",
                        isOn: cannotSeeTarget,
                        hint: "Something blocks line of sight, so this ’Mech cannot shoot that target."
                    )
                    chipToggle(
                        "Behind the shooter",
                        isOn: behindShooter,
                        hint: "The target is outside the miniature’s front, so this shot is not allowed."
                    )
                }
                .padding(.top, TMSpace.sm)
            }
        }
    }

    private var cannotSeeTarget: Binding<Bool> {
        Binding(
            get: { !insight.canSeeTarget },
            set: { insight.canSeeTarget = !$0 }
        )
    }

    private var behindShooter: Binding<Bool> {
        Binding(
            get: { !insight.targetInFrontArc },
            set: { insight.targetInFrontArc = !$0 }
        )
    }

    @ViewBuilder
    private func chipToggle(_ title: String, isOn: Binding<Bool>, hint: String? = nil) -> some View {
        let toggle = Toggle(title, isOn: isOn)
            .toggleStyle(.button)
            .font(TMFont.detail)
        if let hint {
            toggle
                .buttonStyle(.borderless)
                .accessibilityHint(hint)
        } else {
            toggle
        }
    }

    private func applyBar(_ solve: CombatSolve) -> some View {
        let title = applyTitle(solve)
        return GlassEffectContainer(spacing: TMSpace.md) {
            PrimaryActionButton(
                title: title,
                placement: .dock,
                tint: TMColor.signal,
                isDisabled: !canApply(solve),
                accessibilityIdentifier: "as.sator.resolve",
                accessibilityHint: "Records this shot",
                action: applyShot
            )
            .background {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityIdentifier("as.sator.apply")
                    .accessibilityLabel(title)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, verticalSizeClass == .compact ? TMSpace.xs : TMSpace.sm)
    }

    private func applyTitle(_ solve: CombatSolve) -> String {
        if solve.cannotShootReason != nil { return "Can’t apply" }
        if solve.targetNumber?.autoMiss == true { return "Apply miss" }
        if solve.isHit == true {
            if solve.ifHit.zeroDamage { return "Apply hit" }
            return "Apply \(solve.ifHit.delivered) damage"
        }
        if solve.isHit == false { return "Apply miss" }
        return "Apply"
    }

    private var applyingFaces: (Int, Int)? {
        if let d1, let d2 { return (d1, d2) }
        if solve?.targetNumber?.autoMiss == true { return (1, 1) }
        return nil
    }

    private func canApply(_ solve: CombatSolve) -> Bool {
        applyingFaces != nil && attackerId != nil && defenderId != nil && solve.canApply
    }

    private func applyShot() {
        guard let attackerId, let defenderId, let attacker, let faces = applyingFaces else { return }
        let move = attacker.movementMode == .unset ? MovementMode.ground : attacker.movementMode
        if store.applyAttack(
            attackerId: attackerId,
            defenderId: defenderId,
            range: insight.rangeBracket,
            die1: faces.0,
            die2: faces.1,
            attackerMove: move,
            targetMove: insight.targetMove,
            woods: insight.woods,
            partialCover: insight.partialCover,
            rearHit: insight.rearHit
        ) {
            dismiss()
        }
    }

    private func finishShooting() {
        store.finishCombatSide()
        if store.lastError == nil {
            dismiss()
        }
    }

    private func setTargetMove(_ modifier: TargetMoveModifier, sprint: Bool = false) {
        insight.targetMove = modifier
        countedSprint = modifier == .groundUsesTMM && sprint
    }

    @ViewBuilder
    private func targetMoveChoice(_ title: String, chosen: Bool) -> some View {
        if chosen {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func syncTargetMoveFromDefender() {
        guard let defender else { return }
        countedSprint = defender.movementMode == .sprint
        if defender.isImmobile {
            insight.targetMove = .immobile
        } else {
            insight.targetMove = defender.movementMode.asTargetMoveModifier
        }
    }

    private func unavailableReason(_ unit: MatchUnitState) -> String? {
        if unit.canAttackThisTurn { return nil }
        if unit.hasAttackedThisTurn { return "Already shot" }
        if unit.movementMode == .sprint { return "Sprinted, can’t shoot" }
        return "Can’t shoot"
    }

    private func targetCaption(_ unit: MatchUnitState) -> String {
        if unit.isImmobile { return "Can’t move" }
        if unit.hasMovedThisTurn, unit.movementMode != .unset {
            return "Moved: \(unit.movementMode.displayName)"
        }
        return "Move not recorded"
    }

    private func targetMoveTitle(_ defender: MatchUnitState) -> String {
        switch insight.targetMove {
        case .immobile: "Can’t move"
        case .standstill: "Stood still"
        case .groundUsesTMM: countedSprint ? "Sprinted" : "Walked"
        case .jumpedUsesTMMPlus1: "Jumped"
        }
    }

    private func targetMoveDetail(_ defender: MatchUnitState) -> String {
        let recordedSprint = defender.movementMode == .sprint
        let matchesRecord = defender.hasMovedThisTurn
            && defender.movementMode != .unset
            && insight.targetMove == defender.movementMode.asTargetMoveModifier
            && (insight.targetMove != .groundUsesTMM || countedSprint == recordedSprint)
        if matchesRecord || defender.isImmobile {
            return defender.name
        }
        if !defender.hasMovedThisTurn || defender.movementMode == .unset {
            return "\(defender.name) · no move recorded"
        }
        return "\(defender.name) · changed for this shot"
    }

    private static func openingAttacker(session: MatchSession, initial: UUID?) -> UUID? {
        let attackers = session.units.filter { $0.side == session.activeSide && $0.canAttackThisTurn }
        if let initial, attackers.contains(where: { $0.id == initial }) {
            return initial
        }
        return attackers.count == 1 ? attackers[0].id : nil
    }

    private static func openingDefender(session: MatchSession) -> UUID? {
        let defenders = session.units.filter {
            $0.side != session.activeSide && $0.combatStatus != .removed
        }
        return defenders.count == 1 ? defenders[0].id : nil
    }

    private static func openingInsight(session: MatchSession, defenderId: UUID?) -> CombatTableInsight {
        var insight = CombatTableInsight()
        guard let defenderId, let defender = session.units.first(where: { $0.id == defenderId }) else {
            return insight
        }
        if defender.isImmobile {
            insight.targetMove = .immobile
        } else {
            insight.targetMove = defender.movementMode.asTargetMoveModifier
        }
        return insight
    }

    private static func openingCountedSprint(session: MatchSession, defenderId: UUID?) -> Bool {
        guard let defenderId, let defender = session.units.first(where: { $0.id == defenderId }) else {
            return false
        }
        return defender.movementMode == .sprint
    }
}

/// Chips from `TargetNumber.breakdown` (`S skill 4`, `A ground +0`, …). Does not recompute the target number.
private struct SATORTerm: Identifiable {
    var letter: String
    var label: String
    var delta: Int
    var explanation: String
    var id: String { letter }
}

private enum SATORTerms {
    static func make(from tn: TargetNumber) -> [SATORTerm] {
        tn.breakdown.compactMap { line in
            let tokens = line.split(separator: " ").map(String.init)
            guard let letter = tokens.first, letter.count == 1, "SATOR".contains(letter) else { return nil }
            let rawDelta = tokens.last ?? "0"
            let delta = Int(rawDelta.replacingOccurrences(of: "+", with: "")) ?? 0
            let token = tokens.count > 2 ? tokens[1] : ""
            return SATORTerm(
                letter: letter,
                label: label(letter: letter, token: token),
                delta: delta,
                explanation: explanation(letter: letter, reasons: tn.reasons)
            )
        }
    }

    static func chipText(_ term: SATORTerm) -> String {
        if term.letter == "S" { return "S \(term.delta)" }
        let signed = term.delta >= 0 ? "+\(term.delta)" : "\(term.delta)"
        return "\(term.letter) \(signed)"
    }

    static func equation(_ terms: [SATORTerm], total: Int) -> String {
        let parts = terms.enumerated().map { index, term in
            let number: String
            if index == 0 {
                number = "\(term.delta)"
            } else if term.delta < 0 {
                number = "− \(abs(term.delta))"
            } else {
                number = "+ \(term.delta)"
            }
            return "\(number) \(term.label.lowercased())"
        }
        return parts.joined(separator: " ") + " = \(total)"
    }

    private static func label(letter: String, token: String) -> String {
        switch letter {
        case "S": "Skill"
        case "A":
            switch token {
            case "standstill": "Stood still"
            case "jump": "Jumped"
            case "sprint": "Sprinted"
            default: "Walked"
            }
        case "T":
            switch token {
            case "immobile": "Can’t move"
            case "standstill": "Stood still"
            case "jumpedUsesTMMPlus1": "Target jumped"
            default: "Target walked"
            }
        case "R":
            switch token {
            case "medium": "Medium"
            case "long": "Long"
            case "outOfRange": "Too far"
            default: "Short"
            }
        default: "Other"
        }
    }

    private static func explanation(letter: String, reasons: [String]) -> String {
        switch letter {
        case "S":
            return reasons.first { $0.hasPrefix("Skill") } ?? "Skill"
        case "A":
            return reasons.first { $0.hasPrefix("Shooter") } ?? "Shooter"
        case "T":
            return reasons.first { $0.hasPrefix("Target") } ?? "Target"
        case "R":
            return reasons.last { $0.contains("range") || $0.contains("inch") || $0.contains("Too far") } ?? "Range"
        default:
            let others = reasons.filter { reason in
                !reason.hasPrefix("Skill")
                    && !reason.hasPrefix("Shooter")
                    && !reason.hasPrefix("Target")
                    && !reason.hasPrefix("Need")
                    && !reason.contains("range")
                    && !reason.contains("inch")
            }
            return others.isEmpty ? "No other penalty" : others.joined(separator: " · ")
        }
    }
}

private struct DamagePreviewCard: View {
    var solve: CombatSolve
    var defender: MatchUnitState

    private var missed: Bool { solve.isHit == false }
    private var landedHit: Bool { solve.isHit == true }
    private var boxcars: Bool { landedHit && solve.roll?.isNaturalTwelve == true }

    /// Damage numbers match a normal hit. A natural 12 only adds the critical.
    private var shown: CombatDamagePreview {
        boxcars ? solve.ifNaturalTwelve : solve.ifHit
    }

    private var cardEyebrow: String {
        if solve.ifHit.zeroDamage { return "This shot" }
        if landedHit { return "This hit" }
        return "If this hits"
    }

    private var statusLine: String? {
        if missed { return nil }
        if landedHit {
            if shown.wrecksThisTurn { return "This wrecks them." }
            if shown.needsCritical { return "A critical is owed." }
            return nil
        }
        if solve.ifHit.wrecksThisTurn { return "A hit wrecks them." }
        if solve.ifHit.needsCritical { return "A hit owes a critical." }
        return nil
    }

    private var whatHappensNext: String? {
        if missed { return nil }
        let preview = shown
        if preview.zeroDamage {
            if boxcars && preview.needsCritical {
                return "Two 6s: a critical happens even though this range deals 0 damage."
            }
            return nil
        }
        var parts: [String] = []
        if preview.wrecksThisTurn {
            let cleanup = "They can still shoot this turn; take the model off at Clean up."
            parts.append(landedHit ? "That wrecks them. \(cleanup)" : "If it hits, that wrecks them. \(cleanup)")
        } else if preview.needsCritical && preview.chipsStructure == 0 {
            parts.append("Two 6s: a critical happens even if armor stopped the damage.")
        } else if preview.needsCritical {
            parts.append(
                landedHit
                    ? "You’ll also roll a critical. Structure was hit."
                    : "If it hits structure, you’ll roll a critical."
            )
        } else if !boxcars {
            parts.append(
                landedHit
                    ? "Armor absorbs it."
                    : "Armor absorbs it. A critical only happens on two 6s."
            )
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " ")
    }

    var body: some View {
        let hit = solve.ifHit
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                Eyebrow(cardEyebrow)
                if hit.zeroDamage {
                    Text("0 damage at this range. Applying it still uses this ’Mech’s shot.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("\(hit.delivered) damage to \(solve.defenderName)")
                        .font(TMFont.cardTitle)
                    DamagePipCompare(
                        title: "Armor",
                        kind: .armor,
                        before: hit.armorBefore,
                        after: hit.armorAfter,
                        capacity: defender.armorCap
                    )
                    DamagePipCompare(
                        title: "Structure",
                        kind: .structure,
                        before: hit.structureBefore,
                        after: hit.structureAfter,
                        capacity: defender.structureCap
                    )
                }
                if let statusLine {
                    Text(statusLine)
                        .font(TMFont.detail)
                }
                if let whatHappensNext {
                    Text(whatHappensNext)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct DamagePipCompare: View {
    var title: String
    var kind: PipTrack.Kind
    var before: Int
    var after: Int
    var capacity: Int

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Text(title)
                .font(TMFont.statLabel)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: TMSpace.sm) {
                    beforeTrack
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    afterTrack
                }
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    beforeTrack
                    afterTrack
                }
            }
        }
    }

    private var beforeTrack: some View {
        PipTrack(
            remaining: before,
            capacity: capacity,
            kind: kind,
            size: .regular,
            accessibilityName: "\(title) before"
        )
    }

    private var afterTrack: some View {
        PipTrack(
            remaining: after,
            capacity: capacity,
            kind: kind,
            size: .regular,
            accessibilityName: "\(title) after"
        )
    }
}

#if DEBUG
#Preview("Solve a shot") {
    CombatSolverSheet(session: PreviewFixtures.session(), store: BattlePreview.store())
}
#endif
