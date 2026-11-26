import SwiftUI
import MechBuddyData
import MechBuddyDomain

// Setup screens 1, 2, 4 and 5 (PlayModeSpec § 5.1, § 5.2, § 5.4, § 5.5).

// MARK: - 1. Players and sides

struct PlaySidesStep: View {
    @Binding var setup: PlaySetup

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Text("How many sides?")
                    .font(TMFont.stepTitle)
                    .accessibilityAddTraits(.isHeader)
                ChoiceTile(
                    title: "1 v 1",
                    detail: "Two players, one force each. The Quick-Start game.",
                    systemImage: "person.2",
                    isSelected: true,
                    indicator: .single,
                    accessibilityIdentifier: "as.play.setup.preset.1v1",
                    action: {}
                )
                Text("Teams (1 v 2, 2 v 2) and three or four sides are coming in a later update.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach($setup.sides) { $side in
                sideRow($side)
            }
        }
    }

    private func sideRow(_ side: Binding<MatchSide>) -> some View {
        let letter = side.wrappedValue.id.letter
        return TMCard {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                HStack(spacing: TMSpace.sm) {
                    SideBadge(side: side.wrappedValue.id)
                    Text(side.wrappedValue.id.displayName)
                        .font(TMFont.cardTitle)
                }
                TextField(side.wrappedValue.id.displayName, text: Binding(
                    get: { side.wrappedValue.name == side.wrappedValue.id.displayName ? "" : side.wrappedValue.name },
                    set: { side.wrappedValue.name = String($0.prefix(20)) }
                ))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("\(side.wrappedValue.id.displayName) name")
                .accessibilityIdentifier("as.play.setup.side.\(letter)")
                TextField("Player name (optional)", text: Binding(
                    get: { side.wrappedValue.players.first ?? "" },
                    set: { side.wrappedValue.players = [String($0.prefix(20))] }
                ))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("as.play.setup.side.\(letter).player.1")
            }
        }
    }
}

// MARK: - 2. Game size

struct PlaySizeStep: View {
    @Binding var setup: PlaySetup
    var hasCollection: Bool

    private var isCount: Bool {
        if case .count = setup.budget { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            PlaySetupSection(title: "Budget per side", footnote: estimate) {
                Picker("Budget by", selection: Binding(
                    get: { isCount },
                    set: { count in
                        setup.budget = count ? .count(units: 4, sizeCap: 11) : .pointValue(ForceBudget.defaultPV(sides: setup.sides.count))
                    }
                )) {
                    Text("Point Value").tag(false)
                    Text("Number of ’Mechs").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("as.play.setup.budgetKind")
                switch setup.budget {
                case .pointValue(let pv):
                    pvControls(pv)
                case .count(let units, let sizeCap):
                    countControls(units: units, sizeCap: sizeCap)
                }
            }
            PlaySetupSection(
                title: "Pilot skills",
                footnote: "Better pilots cost more PV (p. 35). Clan ’Mechs start at Skill 3 and pay for it."
            ) {
                Toggle("Allow better skills", isOn: Binding(
                    get: { setup.allowImprovedSkills },
                    set: {
                        setup.allowImprovedSkills = $0
                        PlayUnits.resetSkills(&setup)
                    }
                ))
                .accessibilityIdentifier("as.play.setup.skills")
                if setup.allowImprovedSkills {
                    Stepper(value: Binding(
                        get: { setup.minimumSkill },
                        set: {
                            setup.minimumSkill = $0
                            PlayUnits.resetSkills(&setup)
                        }
                    ), in: 0...4) {
                        Text("Best skill: \(setup.minimumSkill)")
                            .monospacedDigit()
                    }
                    .accessibilityIdentifier("as.play.setup.minimumSkill")
                }
            }
            PlaySetupSection(
                title: "Which ’Mechs",
                footnote: hasCollection ? nil : "No collection recorded yet, so every card in the app is offered."
            ) {
                Picker("Which ’Mechs", selection: $setup.pool) {
                    Text("Minis I own").tag(UnitPool.owned)
                    Text("Any card").tag(UnitPool.anyCard)
                }
                .pickerStyle(.segmented)
                .disabled(!hasCollection)
                .accessibilityIdentifier("as.play.setup.pool")
            }
        }
    }

    private func pvControls(_ pv: Int) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Stepper(value: Binding(
                get: { pv },
                set: { setup.budget = .pointValue($0) }
            ), in: ForceBudget.pvRange, step: ForceBudget.pvStep) {
                Text("\(pv) PV")
                    .font(TMFont.readoutM)
                    .monospacedDigit()
            }
            .accessibilityIdentifier("as.play.setup.budget")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TMSpace.sm) { presets(pv) }
                VStack(alignment: .leading, spacing: TMSpace.sm) { presets(pv) }
            }
        }
    }

    @ViewBuilder
    private func presets(_ pv: Int) -> some View {
        ForEach(ForceBudget.pvPresets, id: \.self) { preset in
            Button("\(preset)") { setup.budget = .pointValue(preset) }
                .buttonStyle(.bordered)
                .tint(preset == pv ? TMColor.signal : .secondary)
                .accessibilityLabel("\(preset) PV")
                .accessibilityAddTraits(preset == pv ? .isSelected : [])
                .accessibilityIdentifier("as.play.setup.budget.\(preset)")
        }
    }

    private func countControls(units: Int, sizeCap: Int?) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Stepper(value: Binding(
                get: { units },
                set: { setup.budget = .count(units: $0, sizeCap: sizeCap) }
            ), in: 1...PlaySetup.maxUnitsPerSide) {
                Text(units == 1 ? "1 ’Mech" : "\(units) ’Mechs").monospacedDigit()
            }
            .accessibilityIdentifier("as.play.setup.budget")
            Toggle("Size cap", isOn: Binding(
                get: { sizeCap != nil },
                set: { setup.budget = .count(units: units, sizeCap: $0 ? max(units * 2, 11) : nil) }
            ))
            if let sizeCap {
                Stepper(value: Binding(
                    get: { sizeCap },
                    set: { setup.budget = .count(units: units, sizeCap: $0) }
                ), in: units...(units * 4)) {
                    Text("Sizes total at most \(sizeCap)").monospacedDigit()
                }
            }
            Text("PV is still shown but not enforced.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
        }
    }

    private var estimate: String {
        let perSide: Int
        switch setup.budget {
        case .pointValue(let pv): perSide = max(1, pv / 60)
        case .count(let units, _): perSide = units
        }
        let minutes = PlayUnits.estimatedMinutes(units: perSide * setup.sides.count)
        return "About \(minutes) minutes. A guide, not a rule."
    }
}

// MARK: - 4. Battlefield

struct PlayMapStep: View {
    @Binding var setup: PlaySetup
    @Environment(AppDependencies.self) private var dependencies

    private static let catalogMaps: [String] = (try? BundleContentCatalogRepository().mapCatalog().allMaps) ?? []

    private var ownedMaps: [String] {
        guard let collection = dependencies.preferences.collection else { return [] }
        return CollectionMath.ownedMaps(collection, boxes: dependencies.boxSets).map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            PlaySetupSection(title: "What are you playing on?") {
                Picker("Battlefield", selection: Binding(
                    get: { setup.battlefield.kind },
                    set: { kind in
                        setup.battlefield.kind = kind
                        if kind == .mapsheets { fillSheets() }
                    }
                )) {
                    Text("Mat or table").tag(Battlefield.Kind.mat)
                    Text("Mapsheets").tag(Battlefield.Kind.mapsheets)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("as.play.setup.mapSource")
                if setup.battlefield.kind == .mat {
                    matControls
                } else {
                    sheetControls
                }
            }
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow("Layout")
                MissionLayoutView(layout: PlayLayout.layout(for: setup.battlefield))
                    .accessibilityIdentifier("as.play.setup.layout")
                Text("\(setup.battlefield.summary) · each side deploys within 6″ of its home edge.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let advice = setup.battlefield.advice(sides: setup.sides.count, budgetPV: budgetPV) {
                    Label(advice, systemImage: "info.circle")
                        .font(TMFont.detail)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("as.play.setup.mapAdvice")
                }
            }
            PlaySetupSection(title: "Terrain") {
                ForEach(PlayLayout.tableSteps(for: setup).dropFirst().prefix(2), id: \.self) { line in
                    Label(line, systemImage: "tree")
                        .font(TMFont.detail)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Buildings block sight and slow movement. The app doesn’t track their damage yet.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var budgetPV: Int? {
        if case .pointValue(let pv) = setup.budget { return pv }
        return nil
    }

    private var matControls: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TMSpace.sm) { matPresets }
                VStack(alignment: .leading, spacing: TMSpace.sm) { matPresets }
            }
            Stepper(value: $setup.battlefield.matWidth, in: 24...96, step: 6) {
                Text("Width \(Int(setup.battlefield.matWidth))″").monospacedDigit()
            }
            .accessibilityIdentifier("as.play.setup.matWidth")
            Stepper(value: $setup.battlefield.matDepth, in: 24...96, step: 6) {
                Text("Depth \(Int(setup.battlefield.matDepth))″").monospacedDigit()
            }
            .accessibilityIdentifier("as.play.setup.matDepth")
        }
    }

    @ViewBuilder
    private var matPresets: some View {
        ForEach(Battlefield.matPresets, id: \.title) { preset in
            let selected = setup.battlefield.matWidth == preset.width && setup.battlefield.matDepth == preset.depth
            Button(preset.title) {
                setup.battlefield.matWidth = preset.width
                setup.battlefield.matDepth = preset.depth
            }
            .buttonStyle(.bordered)
            .tint(selected ? TMColor.signal : .secondary)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private var sheetControls: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Picker("Arrangement", selection: Binding(
                get: { setup.battlefield.arrangement },
                set: {
                    setup.battlefield.arrangement = $0
                    fillSheets()
                }
            )) {
                ForEach(MapArrangement.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("as.play.setup.arrangement")
            ForEach(0..<setup.battlefield.arrangement.sheetCount, id: \.self) { index in
                PlaySetupRow(title: "Sheet \(index + 1)") {
                    Menu {
                        if !ownedMaps.isEmpty {
                            Section("Your maps") {
                                ForEach(ownedMaps, id: \.self) { name in
                                    Button(name) { setSheet(index, name) }
                                }
                            }
                        }
                        Section("Any map") {
                            ForEach(Self.catalogMaps.filter { !ownedMaps.contains($0) }, id: \.self) { name in
                                Button(name) { setSheet(index, name) }
                            }
                        }
                    } label: {
                        Text(sheetName(index))
                            .lineLimit(2)
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("as.play.setup.sheet.\(index + 1)")
                }
            }
        }
    }

    private func sheetName(_ index: Int) -> String {
        setup.battlefield.sheets.indices.contains(index) ? setup.battlefield.sheets[index] : "Pick a map"
    }

    private func setSheet(_ index: Int, _ name: String) {
        while setup.battlefield.sheets.count <= index { setup.battlefield.sheets.append("") }
        setup.battlefield.sheets[index] = name
    }

    /// Owned maps first, then the catalog, for empty slots.
    private func fillSheets() {
        let count = setup.battlefield.arrangement.sheetCount
        var sheets = Array(setup.battlefield.sheets.prefix(count)).filter { !$0.isEmpty }
        for name in ownedMaps + Self.catalogMaps where sheets.count < count && !sheets.contains(name) {
            sheets.append(name)
        }
        setup.battlefield.sheets = sheets
    }
}

// MARK: - 5. Rules and options

struct PlayRulesStep: View {
    @Binding var setup: PlaySetup

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            PlaySetupSection(title: "How to win") {
                PlaySetupRow(title: "Last side standing", detail: "Destroy every enemy ’Mech (p. 13). With Forced Withdrawal on, ’Mechs that leave count as destroyed.") {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TMColor.signal)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("as.play.setup.objective")
                Text("Objectives (Raid, Hold the Fort and more) are coming in a later update.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                PlaySetupRow(title: "Turn limit", detail: setup.turnLimit == nil
                    ? "Play until one side is left (p. 13)."
                    : "At the limit, most PV still on the table wins.") {
                    Picker("Turn limit", selection: $setup.turnLimit) {
                        Text("None").tag(Int?.none)
                        ForEach([6, 8, 10, 12], id: \.self) { Text("\($0) turns").tag(Int?.some($0)) }
                    }
                    .accessibilityIdentifier("as.play.setup.turnLimit")
                }
            }
            PlaySetupSection(title: "Optional rules", footnote: "All on is the full game. Turn one off to keep things simple.") {
                toggle("Overheat", detail: "Add heat for extra damage, up to OV", id: "overheat", isOn: $setup.rules.overheat)
                toggle("Punches and kicks", detail: "Physical attacks against an adjacent ’Mech", id: "physical", isOn: $setup.rules.physicalAttacks)
                toggle("Forced Withdrawal", detail: "Crippled ’Mechs head for home (p. 12)", id: "forcedWithdrawal", isOn: $setup.rules.forcedWithdrawal)
                toggle("Start on the table", detail: setup.rules.startOnTable
                    ? "Deploy within 6″ of your edge before Turn 1"
                    : "Enter from your home edge on Turn 1 (p. 11)", id: "startOnTable", isOn: $setup.rules.startOnTable)
            }
            PlaySetupSection(title: "Always in the game", footnote: "These come from the cards, so there is nothing to switch.") {
                always("Skill and PV", detail: "Set in Game size; better pilots pay PV (p. 35)", id: "skillPV")
                always("Minimal damage (0*)", detail: "Read from the card; the app rolls or asks", id: "minimalDamage")
                always("Rear-firing weapons (REAR)", detail: "Offered when the card has REAR", id: "rear")
                always("Heat abilities (HT)", detail: "Applied in the shot sheet", id: "heat")
                always("Water", detail: "Mark a ’Mech in water on its unit sheet", id: "water")
            }
            PlaySetupSection(title: "Coming with Clash of Steel") {
                comingSoon("Buildings", id: "buildings")
                comingSoon("Battlefield Support", id: "battlefieldSupport")
                comingSoon("Formations", id: "formations")
                comingSoon("MechWarrior cards", id: "mechWarriorCards")
            }
            PlaySetupSection(title: "Dice") {
                Picker("Dice", selection: $setup.diceMode) {
                    Text("Real dice").tag(DiceMode.manual)
                    Text("Let the app roll").tag(DiceMode.auto)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("as.play.setup.dice")
                Text("You can change this during the game.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggle(_ title: String, detail: String, id: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(title).font(TMFont.body)
                Text(detail).font(TMFont.detail).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .tint(TMColor.signal)
        .accessibilityIdentifier("as.play.setup.rules.\(id)")
    }

    private func always(_ title: String, detail: String, id: String) -> some View {
        PlaySetupRow(title: title, detail: detail) {
            Text("On")
                .font(TMFont.detail.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("as.play.setup.rules.\(id)")
    }

    private func comingSoon(_ title: String, id: String) -> some View {
        Toggle(isOn: .constant(false)) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(title).font(TMFont.body)
                Text("Coming with Clash of Steel").font(TMFont.detail).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(true)
        .accessibilityIdentifier("as.play.setup.rules.\(id)")
    }
}
