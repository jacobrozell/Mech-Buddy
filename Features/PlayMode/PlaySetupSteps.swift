import SwiftUI
import MechBuddyData
import MechBuddyDomain

// Setup screens 1, 2, 4 and 5 (PlayModeSpec § 5.1, § 5.2, § 5.4, § 5.5).

// MARK: - 1. Players and sides

struct PlaySidesStep: View {
    @Binding var setup: PlaySetup
    @Environment(AppDependencies.self) private var dependencies
    @State private var showHouseRules = false

    private var multiSide: Bool { dependencies.releaseSurface.isEnabled(.playModeMultiSide) }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Text("Who is playing?")
                    .font(TMFont.stepTitle)
                    .accessibilityAddTraits(.isHeader)
                ForEach(TeamFormat.available(multiSide: multiSide)) { format in
                    presetTile(format)
                }
                if !multiSide {
                    Text("Three or four sides are coming in a later update.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if setup.usesHouseRules {
                houseRulesNote
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

    /// Free-for-all note with the house rules behind an info button (§ 5.1).
    private var houseRulesNote: some View {
        HStack(alignment: .top, spacing: TMSpace.sm) {
            Label {
                Text("[HOUSE] Three or more sides isn’t in the Quick-Start rules (p. 13). Mech Buddy uses house rules for turn order, targets and scoring.")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "house")
            }
            .font(TMFont.detail)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("as.play.setup.houseRules.note")
            Button {
                showHouseRules = true
            } label: {
                Image(systemName: "info.circle")
                    .symbolRenderingMode(.hierarchical)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .accessibilityLabel("About the house rules")
            .accessibilityIdentifier("as.play.setup.houseRules")
        }
        .sheet(isPresented: $showHouseRules) {
            PlayHouseRulesSheet()
        }
    }

    private func presetTile(_ format: TeamFormat) -> some View {
        let players: Int = format.players.reduce(0, +)
        let symbol: String = players > 2 ? "person.3" : "person.2"
        let badge: String? = format.isHouseRule ? "House rules" : nil
        return ChoiceTile(
            title: format.title,
            detail: Self.detail(for: format),
            systemImage: symbol,
            badge: badge,
            isSelected: setup.playerCounts == format.players,
            indicator: .single,
            accessibilityIdentifier: Self.presetID(format),
            action: { setup.setPlayerCounts(format.players) }
        )
    }

    /// `as.play.setup.preset.1v1`, `…1v1v1v1`.
    static func presetID(_ format: TeamFormat) -> String {
        let compact = format.title.replacingOccurrences(of: " ", with: "")
        return "as.play.setup.preset." + compact
    }

    static func detail(for format: TeamFormat) -> String {
        switch format.title {
        case "1 v 1 v 1": "Three players, one force each. Free-for-all [HOUSE]."
        case "1 v 1 v 2": "Three sides: two players alone and a team of two. [HOUSE]."
        case "1 v 1 v 1 v 1": "Four players, every one for themselves. Each side gets a smaller budget. [HOUSE]."
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
    @State private var showBuilder = false

    private static let terrainPalette: TerrainPaletteFile? = try? BundleContentCatalogRepository().terrainPalette()
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
                .disabled(hasBoard)
                .accessibilityIdentifier("as.play.setup.mapSource")
                if hasBoard {
                    Text("The table is the size of your board.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                } else if setup.battlefield.kind == .mat {
                    matControls
                } else {
                    sheetControls
                }
            }
            if boardsOn, Self.terrainPalette != nil {
                boardSection
            }
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow("Layout")
                MissionLayoutView(board: PlayLayout.board(for: setup.battlefield, sides: setup.sides))
                    .accessibilityIdentifier("as.play.setup.layout")
                Text(hasBoard
                     ? "\(setup.battlefield.summary) · \(boardCounter)."
                     : "\(setup.battlefield.summary) · each side deploys within 6″ of its home edge.")
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
                if hasBoard {
                    Label("Set up the table like the board above. At the table, each side still takes turns placing the terrain pieces.", systemImage: "tree")
                        .font(TMFont.detail)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(PlayLayout.tableSteps(for: setup).dropFirst().prefix(2), id: \.self) { line in
                        Label(line, systemImage: "tree")
                            .font(TMFont.detail)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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

    // MARK: Board builder (PM12, behind playBoards)

    private var boardsOn: Bool { dependencies.releaseSurface.isEnabled(.playBoards) }
    private var hasBoard: Bool { setup.battlefield.board != nil }

    private var boardCounter: String {
        guard let board = setup.battlefield.board else { return "" }
        return BoardRules.choiceSummary(board.features, sideCount: setup.sides.count)
    }

    private var boardSection: some View {
        PlaySetupSection(
            title: "Terrain board",
            footnote: "A plan of your table to set up by. The app never checks the real table."
        ) {
            if let board = setup.battlefield.board {
                Text("\(board.name ?? "Your board"): \(board.features.count) \(board.features.count == 1 ? "piece" : "pieces"), \(boardCounter).")
                    .font(TMFont.detail)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("as.play.setup.board.summary")
                HStack(spacing: TMSpace.md) {
                    Button { showBuilder = true } label: {
                        Label("Edit board", systemImage: "square.and.pencil").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TMColor.signal)
                    .accessibilityIdentifier("as.play.setup.board.edit")
                    Button(role: .destructive) { setup.battlefield.board = nil } label: {
                        Label("Remove", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("as.play.setup.board.remove")
                }
            } else {
                Button { startBoard(ridgeLine: false) } label: {
                    Label("Build a board", systemImage: "square.grid.3x3.topleft.filled").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(TMColor.signal)
                .accessibilityHint("Opens the terrain board builder with the table above")
                .accessibilityIdentifier("as.play.setup.board.build")
                Button { startBoard(ridgeLine: true) } label: {
                    Label("Start from Ridge Line", systemImage: "map").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Opens the builder with Ridge Line’s table and terrain")
                .accessibilityIdentifier("as.play.setup.board.ridgeLine")
            }
        }
        .navigationDestination(isPresented: $showBuilder) {
            if let board = setup.battlefield.board, let palette = Self.terrainPalette {
                BoardEditorView(board: board, sides: setup.sides, palette: palette) { setup.battlefield.board = $0 }
            }
        }
    }

    /// A blank board on the table chosen above, or Ridge Line's table and terrain (the starter board, § 9.7).
    private func startBoard(ridgeLine: Bool) {
        var board: BoardLayout
        if ridgeLine, let dto = try? dependencies.content.scenario(id: .ridgeLine).layout {
            board = BoardLayout(dto)
            board.name = "Ridge Line"
        } else {
            let table = PlayLayout.layout(for: setup.battlefield, sides: setup.sides)
            board = BoardLayout(width: table.width, depth: table.depth, sheets: BoardLayout(table).sheets, openTable: setup.battlefield.summary)
        }
        board.schemaVersion = BoardLayout.currentSchemaVersion
        board.id = UUID()
        board.createdAt = Date()
        board.updatedAt = board.createdAt
        setup.battlefield.board = board.clampedToTable().assigningIDs()
        showBuilder = true
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
    @Environment(AppDependencies.self) private var dependencies
    /// What "Roll for it" last rolled, so the screen can say so.
    @State private var rolledObjective: ObjectiveId?

    private var objectivesOn: Bool { dependencies.releaseSurface.isEnabled(.playObjectives) }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            PlaySetupSection(title: "How to win") {
                if objectivesOn {
                    objectivePicker
                } else {
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
                }
                Divider()
                PlaySetupRow(title: "Turn limit", detail: setup.turnLimit == nil
                    ? "Play until one side is left (p. 13)."
                    : (objectivesOn && (setup.objectiveId != nil || setup.perSideObjectives)
                        ? "[HOUSE] At the limit, most victory points wins; then most PV on the table."
                        : "At the limit, most PV still on the table wins.")) {
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
                Toggle(isOn: Binding(
                    get: { setup.rules.mechWarriorCards },
                    set: { on in
                        setup.rules.mechWarriorCards = on
                        if !on {
                            for side in setup.forces.keys { setup.forces[side] = setup.forces[side]?.map { var p = $0; p.pilotName = nil; return p } }
                            PlayUnits.resetSkills(&setup)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: TMSpace.xxs) {
                        Text("MechWarrior cards").font(TMFont.body)
                        Text(setup.rules.mechWarriorCards
                            ? "[HOUSE] One named pilot per side, set on the Forces step"
                            : "Off")
                            .font(TMFont.detail).foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .tint(TMColor.signal)
                .accessibilityIdentifier("as.play.setup.rules.mechWarriorCards")
                if setup.rules.mechWarriorCards {
                    Text("[HOUSE] A card gives one ’Mech a named pilot and replaces its skill. Give each side one card of equal cost; the opponent improves a skill by the same amount (p. 48, Alpha Strike box scenarios). The Forces step checks the cost.")
                        .font(TMFont.detail).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    // MARK: Objective (PM8, behind playObjectives)

    @ViewBuilder
    private var objectivePicker: some View {
        Toggle(isOn: Binding(
            get: { setup.perSideObjectives },
            set: { on in
                rolledObjective = nil
                if on { rollForEverySide() } else { setup.sideObjectives = [:] }
            }
        )) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text("Each side rolls its own").font(TMFont.body)
                Text("[HOUSE] Optional rule (p. 7): every side plays a different objective. Points are compared at the end.")
                    .font(TMFont.detail).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .tint(TMColor.signal)
        .accessibilityIdentifier("as.play.setup.objective.perSide")
        if setup.perSideObjectives {
            perSidePicker
        } else {
            sharedPicker
        }
    }

    /// One objective for every side (p. 7 default).
    @ViewBuilder
    private var sharedPicker: some View {
        objectiveTile(nil, title: "None: last side standing", detail: "Destroy every enemy ’Mech (p. 13). With Forced Withdrawal on, ’Mechs that leave count as destroyed.", id: "as.play.setup.objective")
        ForEach(ObjectiveId.built, id: \.self) { objective in
            objectiveTile(objective, title: objective.title, detail: objective.summary, id: "as.play.setup.objective.\(objective.rawValue)")
        }
        if setup.hasBuildingsForTargets {
            objectiveTile(.findTheTarget, title: ObjectiveId.findTheTarget.title, detail: ObjectiveId.findTheTarget.summary + " [HOUSE]", id: "as.play.setup.objective.findTheTarget")
        } else {
            HStack(spacing: TMSpace.md) {
                Image(systemName: "lock")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Find the Target needs at least \(ObjectiveId.minimumBuildings) buildings. Turn on Buildings below and add some.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("as.play.setup.objective.findTheTarget")
        }
        if setup.objectiveId == .findTheTarget, !setup.hasBuildingsForTargets {
            Label("Find the Target needs \(ObjectiveId.minimumBuildings) buildings. Without them the game plays as last side standing.", systemImage: "exclamationmark.triangle")
                .font(TMFont.detail)
                .foregroundStyle(TMColor.warning)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("as.play.setup.objective.needsBuildings")
        }
        Button {
            var generator = SystemRandomNumberGenerator()
            let rolled = ObjectiveId.roll(using: &generator, hasBuildings: setup.hasBuildingsForTargets)
            rolledObjective = rolled
            setup.objectiveId = rolled
        } label: {
            Label("Roll for it", systemImage: "dice")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Rolls 1D6: 1 Raid, 2 Control the Field, 3 Destroy the Enemy, 4 Hold the Fort, 5 Breakthrough, 6 Find the Target. A 6 rolls again unless there are buildings.")
        .accessibilityIdentifier("as.play.setup.objective.roll")
        Text(rolledObjective != nil && rolledObjective == setup.objectiveId
            ? "Rolled: \(rolledObjective?.title ?? ""). [HOUSE] The Quick-Start says to pick one at random (p. 7) without a table, so 1D6 follows the book’s list order: a 6 is Find the Target, which needs \(ObjectiveId.minimumBuildings) buildings, otherwise it rolls again."
            : "[HOUSE] Roll 1D6 in the book’s order: 1 Raid, 2 Control the Field, 3 Destroy the Enemy, 4 Hold the Fort, 5 Breakthrough, 6 Find the Target (needs \(ObjectiveId.minimumBuildings) buildings; otherwise a 6 rolls again).")
            .font(TMFont.detail)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("as.play.setup.objective.rolled")
        if let objective = setup.objectiveId {
            Divider()
            objectiveNotes(objective)
        }
    }

    /// Each side rolls its own objective (p. 7 optional rule), or picks one from the menu.
    @ViewBuilder
    private var perSidePicker: some View {
        ForEach(setup.sides) { side in
            HStack(spacing: TMSpace.md) {
                SideBadge(side: side.id)
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text(sideLabel(side)).font(TMFont.cardTitle)
                    Text(setup.objectiveId(for: side.id).map { "\($0.title) · to \(ObjectiveRules.format($0.baseThreshold))" } ?? "Not rolled")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("as.play.setup.objective.side.\(side.id.letter).value")
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: TMSpace.sm)
                Menu {
                    ForEach(ObjectiveId.allCases.filter { !$0.needsBuildings || setup.hasBuildingsForTargets }, id: \.self) { objective in
                        Button(objective.title) { setup.setObjective(objective, for: side.id) }
                    }
                } label: {
                    Text("Pick").frame(minHeight: 44)
                }
                .accessibilityLabel("Pick \(sideLabel(side))’s objective")
                .accessibilityIdentifier("as.play.setup.objective.side.\(side.id.letter).pick")
                Button {
                    var generator = SystemRandomNumberGenerator()
                    setup.setObjective(ObjectiveId.roll(using: &generator, hasBuildings: setup.hasBuildingsForTargets), for: side.id)
                } label: {
                    Image(systemName: "dice").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Roll \(sideLabel(side))’s objective")
                .accessibilityIdentifier("as.play.setup.objective.side.\(side.id.letter).roll")
            }
        }
        Button {
            rollForEverySide()
        } label: {
            Label("Roll for every side", systemImage: "dice")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("as.play.setup.objective.rollAll")
        Text("[HOUSE] Each side plays its own objective and wins at its own total (p. 7 optional rule). Raid tokens go out for every side when any side rolls Raid, so a Raid side has tokens to take. At the turn limit, most points wins; then most PV.")
            .font(TMFont.detail)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("as.play.setup.objective.perSide.notes")
    }

    private func sideLabel(_ side: MatchSide) -> String {
        side.name.trimmingCharacters(in: .whitespaces).isEmpty ? side.id.displayName : side.name
    }

    private func rollForEverySide() {
        var generator = SystemRandomNumberGenerator()
        for side in setup.sides {
            setup.setObjective(ObjectiveId.roll(using: &generator, hasBuildings: setup.hasBuildingsForTargets), for: side.id)
        }
    }

    private func objectiveTile(_ objective: ObjectiveId?, title: String, detail: String, id: String) -> some View {
        let selected = setup.objectiveId == objective
        return ChoiceTile(
            title: title,
            detail: detail,
            systemImage: objective == nil ? "flag.checkered" : "scope",
            isSelected: selected,
            indicator: .single,
            accessibilityIdentifier: id,
            action: {
                rolledObjective = nil
                setup.objectiveId = objective
            }
        )
    }

    /// Setup step, win line and house notes for the chosen objective (§ 7.1).
    @ViewBuilder
    private func objectiveNotes(_ objective: ObjectiveId) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Text("First side to \(ObjectiveRules.format(objective.baseThreshold)) points wins (\(objective.page)).")
                .font(TMFont.detail)
            if let step = objective.setupStep {
                Text("Setup: \(step)")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            if objective.usesClanMultiplier {
                Text(objective == .destroyTheEnemy
                    ? "A Clan force against the Inner Sphere scores 1.5 × Size and needs 12 (p. 7). Mixed forces use no multiplier [HOUSE]."
                    : "A Clan force against the Inner Sphere scores 1.5 × Size (p. 7). Mixed forces use no multiplier [HOUSE].")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            if setup.usesHouseRules {
                Text("[HOUSE] With three or four sides, “an enemy home edge” is any other side’s edge, and a ’Mech scores for the side whose attack crippled or destroyed it. Sides level at the top tie.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("as.play.setup.objective.notes")
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
