import SwiftUI
import MechBuddyData
import MechBuddyDomain

// Setup screen 3, the unit picker and Review (PlayModeSpec § 5.3, § 5.6).

// MARK: - 3. Forces

struct PlayForcesStep: View {
    @Binding var setup: PlaySetup
    @Binding var side: SideId
    var onAdd: (SideId) -> Void
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            sidePicker
            PlayBudgetBar(check: setup.budgetCheck(side), side: side)
            let picks = setup.force(side)
            if picks.isEmpty {
                Text("No ’Mechs yet. Add one from your minis or the cards in the app.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(picks) { pick in
                unitRow(pick)
            }
            PrimaryActionButton(
                title: "Add ’Mech",
                systemImage: "plus",
                tint: TMColor.side(side),
                isDisabled: picks.count >= PlaySetup.maxUnitsPerSide,
                accessibilityIdentifier: "as.play.setup.forces.add.\(side.letter)",
                action: { onAdd(side) }
            )
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TMSpace.lg) { extraActions }
                VStack(alignment: .leading, spacing: TMSpace.sm) { extraActions }
            }
        }
    }

    private var sidePicker: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: TMSpace.sm))
            : AnyLayout(HStackLayout(spacing: TMSpace.sm))
        return layout {
            ForEach(setup.sides) { item in
                Button {
                    side = item.id
                } label: {
                    HStack(spacing: TMSpace.xs) {
                        SideBadge(side: item.id)
                        Text(item.name)
                            .font(TMFont.detail.weight(.semibold))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Text("\(setup.force(item.id).count)")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous)
                            .strokeBorder(item.id == side ? TMColor.side(item.id) : Color.secondary.opacity(0.3), lineWidth: item.id == side ? 2 : 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.name), \(setup.force(item.id).count) ’Mechs")
                .accessibilityAddTraits(item.id == side ? .isSelected : [])
                .accessibilityIdentifier("as.play.setup.forces.side.\(item.id.letter)")
            }
        }
    }

    @ViewBuilder
    private var extraActions: some View {
        if let other = setup.sides.first(where: { $0.id != side }), !setup.force(other.id).isEmpty {
            Button("Copy from \(other.name)") {
                setup.forces[side] = setup.force(other.id).map { pick in
                    var copy = pick
                    copy.id = UUID()
                    return copy
                }
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("as.play.setup.forces.copy.\(side.letter)")
        }
        if !setup.force(side).isEmpty {
            Button("Clear", role: .destructive) { setup.forces[side] = [] }
                .frame(minHeight: 44)
                .accessibilityIdentifier("as.play.setup.forces.clear.\(side.letter)")
        }
    }

    private func unitRow(_ pick: ForcePick) -> some View {
        let range = PlayUnits.skillRange(for: pick, setup: setup)
        let otherFaces = otherFaces(of: pick)
        return TMCard {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                (dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMSpace.xs))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: TMSpace.sm))) {
                    VStack(alignment: .leading, spacing: TMSpace.xxs) {
                        Text(pick.name).font(TMFont.cardTitle)
                        Text("Size \(pick.size) · card \(pick.basePV) PV\(pick.isClan ? " · Clan" : "")")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: TMSpace.sm) }
                    Text("\(pick.adjustedPV) PV")
                        .font(TMFont.stat)
                        .monospacedDigit()
                }
                if range.count > 1 {
                    Stepper(value: skillBinding(pick), in: range) {
                        Text("Skill \(pick.skill)").monospacedDigit()
                    }
                    .accessibilityValue("Skill \(pick.skill), \(pick.adjustedPV) PV")
                    .accessibilityIdentifier("as.play.setup.forces.unit.\(pick.id.uuidString).skill")
                } else {
                    Text("Skill \(pick.skill)")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                if isStandIn(pick) {
                    Label("Uses a stand-in", systemImage: "arrow.triangle.swap")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: TMSpace.lg) {
                    if !otherFaces.isEmpty {
                        Menu {
                            ForEach(otherFaces) { face in
                                Button(face.name) { replace(pick, with: face) }
                            }
                        } label: {
                            Label("Other face", systemImage: "arrow.left.arrow.right")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("as.play.setup.forces.unit.\(pick.id.uuidString).face")
                    }
                    Spacer(minLength: 0)
                    Button(role: .destructive) {
                        setup.forces[side]?.removeAll { $0.id == pick.id }
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .frame(minHeight: 44)
                    }
                    .accessibilityLabel("Remove \(pick.name)")
                    .accessibilityIdentifier("as.play.setup.forces.unit.\(pick.id.uuidString).remove")
                }
                .font(TMFont.detail)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("as.play.setup.forces.unit.\(pick.id.uuidString)")
    }

    private func skillBinding(_ pick: ForcePick) -> Binding<Int> {
        Binding(
            get: { pick.skill },
            set: { value in
                guard let index = setup.forces[side]?.firstIndex(where: { $0.id == pick.id }) else { return }
                setup.forces[side]?[index].skill = value
            }
        )
    }

    /// Checked faces on the same printed card ("Locust LCT-7V ⇄ LCT-3M").
    private func otherFaces(of pick: ForcePick) -> [CardFaceDTO] {
        guard let face = dependencies.cardLibrary.face(id: pick.cardId) else { return [] }
        return dependencies.cardLibrary.faces(printedCard: face.printedCard).filter { $0.id != face.id && $0.isChecked }
    }

    private func replace(_ pick: ForcePick, with face: CardFaceDTO) {
        guard let next = PlayUnits.switchFace(pick, to: face),
              let index = setup.forces[side]?.firstIndex(where: { $0.id == pick.id }) else { return }
        setup.forces[side]?[index] = next
    }

    /// Picked more times than owned, counting every side in seat order (§ 5.3).
    private func isStandIn(_ pick: ForcePick) -> Bool {
        guard setup.pool == .owned, let collection = dependencies.preferences.collection else { return false }
        let owned = CollectionMath.chassisCounts(collection, boxes: dependencies.boxSets)[UnitChassis.key(pick.name)] ?? 0
        let all = setup.sides.flatMap { setup.force($0.id) }.filter { UnitChassis.matches($0.name, pick.name) }
        guard let index = all.firstIndex(where: { $0.id == pick.id }) else { return false }
        return index >= owned
    }
}

/// "212 of 250 PV · 38 PV left". Signal under budget, warning over; the text always says which.
struct PlayBudgetBar: View {
    var check: BudgetCheck
    var side: SideId
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            (dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMSpace.xs))
                : AnyLayout(HStackLayout())) {
                Text(usedText)
                    .font(TMFont.stat)
                    .monospacedDigit()
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: TMSpace.sm) }
                Label(check.text, systemImage: check.isOver ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .font(TMFont.detail.weight(.semibold))
                    .foregroundStyle(check.isOver ? TMColor.warning : .secondary)
            }
            ProgressView(value: Double(min(check.used, check.limit)), total: Double(max(check.limit, 1)))
                .tint(check.isOver ? TMColor.warning : TMColor.signal)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("as.play.setup.forces.budget.\(side.letter)")
    }

    private var usedText: String {
        if check.sizeCap != nil || check.sizeUsed != nil {
            return "\(check.used) of \(check.limit) ’Mechs"
        }
        return "\(check.used) of \(check.limit) PV"
    }
}

// MARK: - Unit picker

struct PlayUnitPickerSheet: View {
    @Binding var setup: PlaySetup
    var side: SideId
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var size: Int?
    @State private var techBase: CardTechBase?
    @State private var showAll = false
    @State private var toast: String?

    private var library: CardLibrary { dependencies.cardLibrary }
    private var usesOwned: Bool { setup.pool == .owned && !(dependencies.preferences.collection?.isEmpty ?? true) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Search ’Mechs", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("as.play.setup.unitPicker.search")
                    filters
                    if usesOwned {
                        Toggle("Show all cards", isOn: $showAll)
                            .accessibilityIdentifier("as.play.setup.unitPicker.showAll")
                    }
                }
                if usesOwned {
                    ForEach(ownedChassis) { chassis in
                        let left = PlayPicker.left(of: chassis.chassis, owned: chassis.owned, setup: setup)
                        let faces = chassis.faces.filter(matches)
                        if !faces.isEmpty {
                            Section {
                                ForEach(faces) { row($0) }
                            } header: {
                                Text("\(chassis.chassis) · \(left > 0 ? "\(left) left" : "uses a stand-in")")
                            }
                        }
                    }
                }
                if !usesOwned || showAll {
                    ForEach(PlayPicker.allCards(boxes: dependencies.boxSets, library: library), id: \.box.id) { group in
                        let faces = group.faces.filter(matches)
                        if !faces.isEmpty {
                            Section(group.box.title) {
                                ForEach(faces) { row($0) }
                            }
                        }
                    }
                }
                Section {
                    Text("A mini with no card here? Entering a card by hand is coming in a later update.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("as.play.setup.unitPicker")
            .navigationTitle("Add to \(sideName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("as.play.setup.unitPicker.done")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let toast {
                    Text(toast)
                        .font(TMFont.detail.weight(.semibold))
                        .padding(.horizontal, TMSpace.lg)
                        .padding(.vertical, TMSpace.sm)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, TMSpace.sm)
                        .accessibilityIdentifier("as.play.setup.unitPicker.toast")
                        .transition(.opacity)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var sideName: String {
        setup.sides.first { $0.id == side }?.name ?? side.displayName
    }

    private var ownedChassis: [OwnedChassis] {
        PlayPicker.ownedChassis(collection: dependencies.preferences.collection, boxes: dependencies.boxSets, library: library)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Picker("Size", selection: $size) {
                Text("Any size").tag(Int?.none)
                ForEach(1...4, id: \.self) { Text("Size \($0)").tag(Int?.some($0)) }
            }
            .accessibilityIdentifier("as.play.setup.unitPicker.size")
            Picker("Tech", selection: $techBase) {
                Text("All").tag(CardTechBase?.none)
                Text("Inner Sphere").tag(CardTechBase?.some(.innerSphere))
                Text("Clan").tag(CardTechBase?.some(.clan))
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("as.play.setup.unitPicker.tech")
        }
    }

    private func matches(_ face: CardFaceDTO) -> Bool {
        PlayPicker.matches(face, query: query, size: size, techBase: techBase)
    }

    private var isFull: Bool {
        setup.force(side).count >= PlaySetup.maxUnitsPerSide || setup.unitCount >= PlaySetup.maxUnitsPerGame
    }

    private func row(_ face: CardFaceDTO) -> some View {
        let pick = PlayUnits.pick(face)
        return Button {
            add(face)
        } label: {
            HStack(spacing: TMSpace.md) {
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text(face.name).font(TMFont.body)
                    Text(pick.map { "Size \(face.sz) · \(face.mv ?? "—") · \($0.adjustedPV) PV at Skill \($0.skill)" }
                        ?? "Size \(face.sz) · numbers not checked yet")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: TMSpace.sm)
                Image(systemName: pick == nil ? "lock" : "plus.circle.fill")
                    .foregroundStyle(pick == nil ? Color.secondary : TMColor.side(side))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pick == nil || isFull)
        .accessibilityHint(pick == nil ? "Its numbers aren’t checked yet, so it can’t be played." : "Adds it to \(sideName).")
        .accessibilityIdentifier("as.play.setup.unitPicker.card.\(face.id)")
    }

    private func add(_ face: CardFaceDTO) {
        guard var pick = PlayUnits.pick(face), !isFull else { return }
        let range = PlayUnits.skillRange(for: pick, setup: setup)
        pick.skill = min(max(pick.skill, range.lowerBound), range.upperBound)
        setup.forces[side, default: []].append(pick)
        withAnimation { toast = "Added \(face.name) to \(sideName)" }
        UIAccessibility.post(notification: .announcement, argument: "Added \(face.name)")
    }
}

// MARK: - 6. Review

struct PlayReviewStep: View {
    var setup: PlaySetup
    var onEdit: (PlaySetupStep) -> Void
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            Text("\(setup.formatName) · \(setup.budget.summary)")
                .font(TMFont.stepTitle)
                .accessibilityAddTraits(.isHeader)
            ForEach(setup.sides) { side in
                sideCard(side)
            }
            section("Battlefield", edit: .map) {
                MissionLayoutView(layout: PlayLayout.layout(for: setup.battlefield))
                    .accessibilityIdentifier("as.play.setup.review.layout")
                Text(setup.battlefield.summary).font(TMFont.detail)
            }
            section("Rules", edit: .rules) {
                Text(rulesLine)
                    .font(TMFont.detail)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let line = minisLine {
                section("Your minis", edit: .forces) {
                    Text(line)
                        .font(TMFont.detail)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("as.play.setup.review.minis")
                }
            }
            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    ForEach(warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(TMFont.detail)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("as.play.setup.review.warnings")
            }
        }
    }

    private func sideCard(_ side: MatchSide) -> some View {
        let check = setup.budgetCheck(side.id)
        return section(side.name, edit: .forces, badge: side.id) {
            if let player = side.players.first, !player.isEmpty {
                Text(player).font(TMFont.detail).foregroundStyle(.secondary)
            }
            Text("\(setup.totalPV(side.id)) PV · \(PlayModeText.mechs(setup.force(side.id).count)) · \(check.text)")
                .font(TMFont.stat)
                .monospacedDigit()
                .foregroundStyle(check.isOver ? TMColor.warning : .primary)
            Text(setup.force(side.id).map { "\($0.name) (\($0.skill))" }.joined(separator: ", "))
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("as.play.setup.review.side.\(side.id.letter)")
    }

    private func section<Content: View>(
        _ title: String,
        edit: PlaySetupStep,
        badge: SideId? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                HStack(spacing: TMSpace.sm) {
                    if let badge { SideBadge(side: badge) }
                    Text(title).font(TMFont.cardTitle)
                    Spacer(minLength: TMSpace.sm)
                    Button("Edit") { onEdit(edit) }
                        .frame(minHeight: 44)
                        .accessibilityLabel("Edit \(title)")
                        .accessibilityIdentifier("as.play.setup.review.edit.\(edit.rawValue + 1)")
                }
                content()
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var rulesLine: String {
        var on: [String] = ["Last side standing"]
        on.append(setup.turnLimit.map { "\($0)-turn limit" } ?? "No turn limit")
        if setup.rules.overheat { on.append("Overheat") }
        if setup.rules.physicalAttacks { on.append("Punches and kicks") }
        if setup.rules.forcedWithdrawal { on.append("Forced Withdrawal") }
        on.append(setup.rules.startOnTable ? "Start on the table" : "Enter on Turn 1")
        on.append(setup.diceMode == .auto ? "App rolls" : "Real dice")
        return on.joined(separator: " · ")
    }

    private var minisLine: String? {
        guard setup.pool == .owned else { return nil }
        return PlayPicker.miniCheck(
            setup: setup,
            collection: dependencies.preferences.collection,
            boxes: dependencies.boxSets,
            standIns: dependencies.standIns
        )?.summary
    }

    private var warnings: [String] {
        var list: [String] = []
        for side in setup.sides where setup.budgetCheck(side.id).isOver {
            list.append("\(side.name) is \(setup.budgetCheck(side.id).text).")
        }
        let pv: Int? = { if case .pointValue(let value) = setup.budget { return value } else { return nil } }()
        if let advice = setup.battlefield.advice(sides: setup.sides.count, budgetPV: pv) {
            list.append(advice)
        }
        return list
    }
}
