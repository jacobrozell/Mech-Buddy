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
                Text("Who is playing?")
                    .font(TMFont.stepTitle)
                    .accessibilityAddTraits(.isHeader)
                ForEach(TeamFormat.all) { format in
                    ChoiceTile(
                        title: format.title,
                        detail: Self.detail(for: format),
                        systemImage: format.players.reduce(0, +) > 2 ? "person.3" : "person.2",
                        isSelected: setup.playerCounts == format.players,
                        indicator: .single,
                        accessibilityIdentifier: "as.play.setup.preset.\(format.title.replacingOccurrences(of: " ", with: ""))",
                        action: { setup.setPlayerCounts(format.players) }
                    )
                }
                Text("Three or four sides are coming in a later update.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if setup.playerCounts.contains(where: { $0 > 1 }) {
                Label(
                    "A team is one side (Quick-Start p. 13). It rolls one initiative, shares one budget and moves as one side. Any player on it may move any of its ’Mechs.",
                    systemImage: "person.2.badge.gearshape"
                )
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("as.play.setup.team.note")
            }
            ForEach($setup.sides) { $side in
                sideRow($side)
            }
            if let issue = setup.teamIssues.first {
                Label(Self.text(for: issue), systemImage: "exclamationmark.triangle")
                    .font(TMFont.detail)
                    .foregroundStyle(TMColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("as.play.setup.team.issue")
            }
        }
    }

    static func detail(for format: TeamFormat) -> String {
        switch format.title {
        case "1 v 1": "Two players, one force each. The Quick-Start game."
        case "1 v 2": "One player against a team of two. Each side has the same budget."
        case "2 v 2": "Two teams of two. Each team shares one force."
        default: "One player against a team of three. Each side has the same budget."
        }
    }

    static func text(for issue: TeamIssue) -> String {
        switch issue {
        case .sideWithoutPlayer: "Every side needs at least one player."
        case .tooManyPlayers: "Up to \(PlaySetup.maxPlayers) players in all."
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
                    if side.wrappedValue.players.count > 1 {
                        Spacer(minLength: TMSpace.sm)
                        Text("Team of \(side.wrappedValue.players.count)")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("as.play.setup.team.size.\(letter)")
                    }
                }
                TextField(side.wrappedValue.id.displayName, text: Binding(
                    get: { side.wrappedValue.name == side.wrappedValue.id.displayName ? "" : side.wrappedValue.name },
                    set: { side.wrappedValue.name = String($0.prefix(20)) }
                ))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("\(side.wrappedValue.id.displayName) name")
                .accessibilityIdentifier("as.play.setup.side.\(letter)")
                ForEach(side.wrappedValue.players.indices, id: \.self) { index in
                    TextField("Player \(index + 1) name (optional)", text: Binding(
                        get: { side.wrappedValue.players.indices.contains(index) ? side.wrappedValue.players[index] : "" },
                        set: { if side.wrappedValue.players.indices.contains(index) { side.wrappedValue.players[index] = String($0.prefix(20)) } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("as.play.setup.side.\(letter).player.\(index + 1)")
                }
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
                MissionLayoutView(layout: PlayLayout.layout(for: setup.battlefield, sides: setup.sides))
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
            PlaySetupSection(title: "Battlefield Support", footnote: "Each side secretly buys air and artillery strikes (pp. 29–30). Call them from the shield button in battle.") {
                Toggle(isOn: Binding(
                    get: { setup.rules.battlefieldSupport != nil },
                    set: { setup.rules.battlefieldSupport = $0 ? 5 : nil }
                )) {
                    VStack(alignment: .leading, spacing: TMSpace.xxs) {
                        Text("Battlefield Support").font(TMFont.body)
                        Text(setup.rules.battlefieldSupport.map { "\($0) points per side" } ?? "Off")
                            .font(TMFont.detail).foregroundStyle(.secondary)
                    }
                }
                .tint(TMColor.signal)
                .accessibilityIdentifier("as.play.setup.support")
                if setup.rules.battlefieldSupport != nil {
                    Picker("Points", selection: Binding(
                        get: { setup.rules.battlefieldSupport ?? 5 },
                        set: { setup.rules.battlefieldSupport = $0 }
                    )) {
                        Text("5").tag(5)
                        Text("12").tag(12)
                        if let p = setup.rules.battlefieldSupport, p == 0 { Text("0").tag(0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("as.play.setup.support.points")
                    Button("Roll 1D6 (1–2: 0, 3–4: 5, 5–6: 12)") {
                        setup.rules.battlefieldSupport = PlayRules.supportPoints(forRoll: Int.random(in: 1...6))
                    }
                    .accessibilityIdentifier("as.play.setup.support.roll")
                }
            }
            PlaySetupSection(title: "Always in the game", footnote: "These come from the cards, so there is nothing to switch.") {
                always("Skill and PV", detail: "Set in Game size; better pilots pay PV (p. 35)", id: "skillPV")
                always("Minimal damage (0*)", detail: "Read from the card; the app rolls or asks", id: "minimalDamage")
                always("Rear-firing weapons (REAR)", detail: "Offered when the card has REAR", id: "rear")
                always("Heat abilities (HT)", detail: "Applied in the shot sheet", id: "heat")
                always("Water", detail: "Mark a ’Mech in water on its unit sheet", id: "water")
            }
            PlaySetupSection(title: "Buildings", footnote: "Buildings block sight and slow movement; shots and walking through them wear down their CF (p. 28). Track them from the shield button in battle.") {
                Toggle(isOn: Binding(
                    get: { !setup.rules.buildings.isEmpty },
                    set: { setup.rules.buildings = $0 ? [BuildingState(id: "B1", name: "Building 1", type: .medium)] : [] }
                )) {
                    VStack(alignment: .leading, spacing: TMSpace.xxs) {
                        Text("Buildings").font(TMFont.body)
                        Text(setup.rules.buildings.isEmpty ? "Off" : "\(setup.rules.buildings.count) on the table")
                            .font(TMFont.detail).foregroundStyle(.secondary)
                    }
                }
                .tint(TMColor.signal)
                .accessibilityIdentifier("as.play.setup.buildings")
                ForEach(setup.rules.buildings) { b in
                    HStack {
                        Text(b.name).font(TMFont.body)
                        Spacer()
                        Text("\(b.type.displayName), CF \(b.cf)").font(TMFont.detail).foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            setup.rules.buildings.removeAll { $0.id == b.id }
                        } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel("Remove \(b.name)")
                        .accessibilityIdentifier("as.play.setup.buildings.remove.\(b.id)")
                    }
                }
                if !setup.rules.buildings.isEmpty {
                    Menu("Add a building") {
                        ForEach(BuildingType.allCases, id: \.self) { type in
                            Button("\(type.displayName) (CF \(type.defaultCF))") {
                                let n = (setup.rules.buildings.compactMap { Int($0.id.dropFirst()) }.max() ?? 0) + 1
                                setup.rules.buildings.append(BuildingState(id: "B\(n)", name: "Building \(n)", type: type))
                            }
                        }
                    }
                    .accessibilityIdentifier("as.play.setup.buildings.add")
                }
            }
            PlaySetupSection(title: "Formations", footnote: "Each side with 3 or more ’Mechs becomes one Formation. Its bonus works while 3 of its ’Mechs survive (pp. 32, 37).") {
                Toggle(isOn: Binding(
                    get: { setup.rules.formation != nil },
                    set: { setup.rules.formation = $0 ? .commandLance : nil }
                )) {
                    VStack(alignment: .leading, spacing: TMSpace.xxs) {
                        Text("Formations").font(TMFont.body)
                        Text(setup.rules.formation?.displayName ?? "Off")
                            .font(TMFont.detail).foregroundStyle(.secondary)
                    }
                }
                .tint(TMColor.signal)
                .accessibilityIdentifier("as.play.setup.formations")
                if let kind = setup.rules.formation {
                    Picker("Formation", selection: Binding(get: { kind }, set: { setup.rules.formation = $0 })) {
                        ForEach(FormationKind.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .accessibilityIdentifier("as.play.setup.formations.kind")
                    Text(kind == .commandLance ? "Initiative reroll while the command ’Mech stands, plus Combat Intuition on two ’Mechs (p. 32)."
                        : kind == .reconLance ? "Maneuvering Ace: woods cost 1″ less per inch (p. 32)."
                        : "Seven Lucky attack rerolls shared by the Formation (p. 32).")
                        .font(TMFont.detail).foregroundStyle(.secondary)
                }
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
