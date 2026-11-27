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
    @State private var savingForce = false
    @State private var forceName = ""
    @State private var loadingForce = false
    @State private var savedNotice: String?

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
        .alert("Save this force", isPresented: $savingForce) {
            TextField("Name", text: $forceName)
                .accessibilityIdentifier("as.play.forces.saved.name")
            Button("Save", action: saveForce)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saving under an existing name replaces that force.")
        }
        .sheet(isPresented: $loadingForce) {
            PlaySavedForcesSheet(
                loadingInto: setup.sides.first { $0.id == side }?.name ?? side.displayName,
                onLoad: load
            )
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
        savedForceActions
    }

    // MARK: Saved forces (PM9)

    @ViewBuilder
    private var savedForceActions: some View {
        if !setup.force(side).isEmpty {
            Button {
                forceName = ""
                savingForce = true
            } label: {
                Label("Save this force", systemImage: "square.and.arrow.down").frame(minHeight: 44)
            }
            .accessibilityIdentifier("as.play.forces.saved.save")
        }
        Button {
            loadingForce = true
        } label: {
            Label("Load a saved force", systemImage: "tray.full").frame(minHeight: 44)
        }
        .accessibilityIdentifier("as.play.forces.saved.load")
        if let savedNotice {
            Text(savedNotice)
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("as.play.forces.saved.notice")
        }
    }

    private func saveForce() {
        let name = forceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let force = SavedForces.make(name: name, setup: setup, side: side, library: dependencies.cardLibrary)
        do {
            try dependencies.userContent.save(force)
            savedNotice = "Saved “\(name)”."
        } catch {
            savedNotice = "Couldn’t save that force. Try again."
            dependencies.logger.error("save force: \(error)", category: "persistence")
        }
    }

    private func load(_ force: SavedForce) {
        // Bring back hand-entered cards that were deleted since, then rebuild the library.
        let known = Set(dependencies.cardLibrary.userFaces.map(\.id))
        for card in force.cards where !known.contains(card.id) {
            try? dependencies.userContent.saveUserCard(card)
        }
        dependencies.reloadUserCards()
        let result = SavedForces.load(force, into: &setup, side: side, library: dependencies.cardLibrary)
        loadingForce = false
        savedNotice = result.skipped == 0
            ? "Loaded “\(force.name)”."
            : "Loaded “\(force.name)”. \(result.skipped) left out: card unavailable or no room."
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
                if setup.rules.mechWarriorCards {
                    cardControls(pick)
                }
                if dependencies.cardLibrary.face(id: pick.cardId)?.isUserCard == true {
                    Label("Your numbers", systemImage: "square.and.pencil")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("as.play.setup.forces.unit.\(pick.id.uuidString).yourNumbers")
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
                    if players.count > 1 {
                        controllerMenu(pick)
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

    /// MechWarrior card (PM11 **[HOUSE]**): one named pilot a side. Its skill is the stepper above.
    @ViewBuilder
    private func cardControls(_ pick: ForcePick) -> some View {
        let hasCard = pick.pilotName != nil
        Toggle(isOn: Binding(
            get: { hasCard },
            set: { on in
                PlayCards.setCard(on ? "" : nil, on: pick.id, side: side, in: &setup)
                if !on { clampSkill(pick.id) }
            }
        )) {
            Text("MechWarrior card").font(TMFont.body)
        }
        .tint(TMColor.signal)
        .accessibilityIdentifier("as.play.setup.forces.unit.\(pick.id.uuidString).card")
        if hasCard {
            TextField("Pilot name", text: Binding(
                get: { pick.pilotName ?? "" },
                set: { PlayCards.setCard($0, on: pick.id, side: side, in: &setup) }
            ))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .frame(minHeight: 44)
            .accessibilityIdentifier("as.play.setup.forces.unit.\(pick.id.uuidString).pilot")
            Text("Card costs +\(PlayCards.cost(pick)) PV. The other side improves a skill by \(PlayCards.improvement(pick)) in return (p. 48).")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func clampSkill(_ id: UUID) {
        guard let index = setup.forces[side]?.firstIndex(where: { $0.id == id }), let pick = setup.forces[side]?[index] else { return }
        let range = PlayUnits.skillRange(for: pick, setup: setup)
        setup.forces[side]?[index].skill = min(max(pick.skill, range.lowerBound), range.upperBound)
    }

    private var players: [String] { setup.sides.first { $0.id == side }?.players ?? [] }

    /// Who moves this 'Mech on a team side (§ 5.3). Only names pass-the-phone lines.
    private func controllerMenu(_ pick: ForcePick) -> some View {
        let current = pick.controllerIndex.map { setup.playerLabel(side: side, index: $0) } ?? "Anyone"
        return Menu {
            Button("Anyone") { setController(nil, for: pick) }
            ForEach(players.indices, id: \.self) { index in
                Button(setup.playerLabel(side: side, index: index)) { setController(index, for: pick) }
            }
        } label: {
            Label("Moved by \(current)", systemImage: "person")
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("as.play.setup.team.controller.\(pick.id.uuidString)")
    }

    private func setController(_ index: Int?, for pick: ForcePick) {
        guard let at = setup.forces[side]?.firstIndex(where: { $0.id == pick.id }) else { return }
        setup.forces[side]?[at].controllerIndex = index
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

struct CardEntryRequest: Identifiable {
    let id = UUID()
    var draft: UserCardDraft
}

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
    @State private var entryDraft: CardEntryRequest?

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
                if !library.userFaces.isEmpty {
                    let mine = library.userFaces.filter(matches)
                    if !mine.isEmpty {
                        Section("Your cards") {
                            ForEach(mine) { row($0) }
                        }
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
                    Button {
                        entryDraft = CardEntryRequest(draft: UserCardDraft())
                    } label: {
                        Label("Enter a card by hand", systemImage: "square.and.pencil").frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("as.play.setup.cardEntry")
                } footer: {
                    Text("A mini with no card here? Type the numbers from its card. Saved for later games.")
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
        .sheet(item: $entryDraft) { item in
            PlayCardEntrySheet(draft: item.draft) { face in
                do {
                    try dependencies.userContent.saveUserCard(face)
                    dependencies.reloadUserCards()
                    add(face)
                } catch {
                    dependencies.logger.error("save card: \(error)", category: "persistence")
                }
            }
        }
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
            if pick == nil {
                var draft = UserCardDraft()
                draft.name = face.name
                draft.size = face.sz
                draft.isClan = face.techBase == .clan
                entryDraft = CardEntryRequest(draft: draft)
            } else {
                add(face)
            }
        } label: {
            HStack(spacing: TMSpace.md) {
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text(face.name).font(TMFont.body)
                    Text(pick.map { "Size \(face.sz) · \(face.mv ?? "—") · \($0.adjustedPV) PV at Skill \($0.skill)\(face.isUserCard ? " · Your numbers" : "")" }
                        ?? "Size \(face.sz) · numbers not checked yet · enter numbers from your card")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: TMSpace.sm)
                Image(systemName: pick == nil ? "square.and.pencil" : "plus.circle.fill")
                    .foregroundStyle(pick == nil ? Color.secondary : TMColor.side(side))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(pick != nil && isFull)
        .accessibilityHint(pick == nil ? "Its numbers aren’t checked yet. Opens card entry so you can type them from your card." : "Adds it to \(sideName).")
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
                MissionLayoutView(board: PlayLayout.board(for: setup.battlefield, sides: setup.sides))
                    .accessibilityIdentifier("as.play.setup.review.layout")
                Text(setup.battlefield.summary).font(TMFont.detail)
            }
            section("Rules", edit: .rules) {
                if setup.usesHouseRules {
                    Label("[HOUSE] Initiative order, move order, targets, home edges and scoring for three or four sides are Mech Buddy’s house rules, not the Quick-Start’s.", systemImage: "house")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("as.play.setup.review.houseRules")
                }
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
            let names = side.players.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !names.isEmpty {
                Text(names.joined(separator: ", ")).font(TMFont.detail).foregroundStyle(.secondary)
            }
            Text("\(setup.totalPV(side.id)) PV · \(PlayModeText.mechs(setup.force(side.id).count)) · \(check.text)")
                .font(TMFont.stat)
                .monospacedDigit()
                .foregroundStyle(check.isOver ? TMColor.warning : .primary)
            Text(setup.force(side.id).map { pick in
                    let pilot = setup.rules.mechWarriorCards ? pick.pilotName.flatMap { PlayCards.trimmedPilot($0) ?? "unnamed" } : nil
                    return "\(pick.name) (\(pick.skill)\(pilot.map { ", \($0)" } ?? ""))"
                }.joined(separator: ", "))
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
        var on: [String] = [setup.usesHouseRules ? "Last side standing [HOUSE]" : "Last side standing"]
        if setup.perSideObjectives {
            on = [setup.sides.compactMap { side in
                setup.objectiveId(for: side.id).map { "\(side.id.letter): \($0.title) to \(ObjectiveRules.format($0.baseThreshold))" }
            }.joined(separator: ", ") + " (own objectives [HOUSE])"]
        } else if let objective = setup.objectiveId, objective.isBuilt {
            on = ["\(objective.title) to \(ObjectiveRules.format(objective.baseThreshold)) (\(objective.page))" + (setup.usesHouseRules ? " [HOUSE]" : "")]
        }
        on.append(setup.turnLimit.map { "\($0)-turn limit" } ?? "No turn limit")
        if setup.rules.overheat { on.append("Overheat") }
        if setup.rules.physicalAttacks { on.append("Punches and kicks") }
        if setup.rules.forcedWithdrawal { on.append("Forced Withdrawal") }
        if setup.rules.mechWarriorCards { on.append("MechWarrior cards [HOUSE]") }
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
        list.append(contentsOf: PlayCards.warnings(setup: setup))
        if setup.objectiveId == .findTheTarget || setup.sideObjectives.values.contains(ObjectiveId.findTheTarget.rawValue), !setup.hasBuildingsForTargets {
            list.append("Find the Target needs \(ObjectiveId.minimumBuildings) buildings. Without them it plays as last side standing.")
        }
        if setup.perSideObjectives {
            let missing = setup.sides.filter { setup.objectiveId(for: $0.id) == nil }
            if !missing.isEmpty {
                list.append("\(missing.map(\.label).joined(separator: ", ")) hasn’t rolled an objective. Until every side has one, everyone plays the same objective, or last side standing.")
            }
        }
        if let advice = setup.battlefield.advice(sides: setup.sides.count, budgetPV: pv) {
            list.append(advice)
        }
        return list
    }
}
