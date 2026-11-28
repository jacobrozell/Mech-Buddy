import SwiftUI
import MechBuddyDomain

/// The selected piece (§ 9.1): size, position, rotation, level, building class, hints and the rules in plain
/// words. Everything here is a button or a stepper, so a piece can be built without dragging (§ 9.6).
struct BoardInspectorView: View {
    @Bindable var model: BoardEditorModel
    var pieceID: UUID
    @Environment(\.dismiss) private var dismiss

    private var index: Int? { model.board.features.firstIndex { $0.id == pieceID } }

    var body: some View {
        ScrollView {
            if let index {
                content(model.board.features[index], index: index)
                    .padding(TMSpace.lg)
            } else {
                Text("This piece is gone.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .padding(TMSpace.lg)
            }
        }
        .accessibilityIdentifier("as.board.inspector")
    }

    @ViewBuilder
    private func content(_ f: BoardLayout.Feature, index: Int) -> some View {
        let item = model.paletteItem(f)
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            header(f, index: index)
            hints(f, index: index)
            PlaySetupSection(title: "Piece") {
                TextField("Name (optional)", text: Binding(
                    get: { f.name ?? "" },
                    set: { model.setName(pieceID, $0) }
                ))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("as.board.inspector.name")
                if f.kind == .objectiveToken {
                    Picker("Owner", selection: Binding(
                        get: { f.side ?? "A" },
                        set: { model.setSide(pieceID, $0) }
                    )) {
                        ForEach(model.sideLetters, id: \.self) { Text("Side \($0)").tag($0) }
                    }
                    .accessibilityIdentifier("as.board.inspector.side")
                } else {
                    stepper("Width", value: f.area.width, range: 0.5...model.board.width, id: "width") {
                        model.resize(pieceID, width: $0, depth: f.area.depth)
                    }
                    stepper("Depth", value: f.area.depth, range: 0.5...model.board.depth, id: "depth") {
                        model.resize(pieceID, width: f.area.width, depth: $0)
                    }
                }
                if f.kind == .hill || f.kind == .building {
                    let top: Double = f.kind == .hill ? 4 : 12
                    stepper(f.kind == .hill ? "Level" : "Height", value: f.level ?? 1, range: 1...top, id: "level", step: 1) {
                        model.setLevel(pieceID, $0)
                    }
                }
                if f.kind == .building {
                    Picker("Class", selection: Binding(
                        get: { f.buildingClass ?? .medium },
                        set: { model.setBuildingClass(pieceID, $0) }
                    )) {
                        ForEach(BoardLayout.BuildingClass.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("as.board.inspector.class")
                    Text("CF \(f.cf ?? (f.buildingClass ?? .medium).defaultCF). The app doesn’t track building damage from the board yet; this is for your reference (p. 28).")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            PlaySetupSection(title: "Position and turn") {
                stepper("Centre from left", value: f.area.midX, range: 0...model.board.width, id: "x", step: model.step) {
                    model.setPosition(pieceID, x: $0 - f.area.width / 2)
                }
                stepper("Centre from top", value: f.area.midY, range: 0...model.board.depth, id: "y", step: model.step) {
                    model.setPosition(pieceID, y: $0 - f.area.depth / 2)
                }
                if f.kind != .objectiveToken {
                HStack {
                    Text("Turned \(BoardRules.plain(f.degrees))°")
                        .font(TMFont.body)
                        .monospacedDigit()
                        .accessibilityIdentifier("as.board.inspector.rotation")
                    Spacer()
                    Button { model.rotate(pieceID, by: -15) } label: {
                        Label("Turn back 15°", systemImage: "rotate.left").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityIdentifier("as.board.inspector.rotate.minus")
                    Button { model.rotate(pieceID, by: 15) } label: {
                        Label("Turn 15°", systemImage: "rotate.right").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityIdentifier("as.board.inspector.rotate.plus")
                }
                .buttonStyle(.bordered)
                }
                nudgePad
            }
            HStack(spacing: TMSpace.md) {
                Button { model.duplicate(pieceID) } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("as.board.inspector.duplicate")
                Button(role: .destructive) {
                    model.delete(pieceID)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("as.board.inspector.delete")
            }
            if f.kind == .objectiveToken {
                tokenNote(f)
            } else if let item { rules(item) }
        }
    }

    private func header(_ f: BoardLayout.Feature, index: Int) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Text(f.name.flatMap { $0.isEmpty ? nil : $0 } ?? BoardRules.name(of: f.kind))
                .font(TMFont.stepTitle)
                .accessibilityAddTraits(.isHeader)
            Text("\(BoardRules.plain(f.area.width)) × \(BoardRules.plain(f.area.depth))″, centre \(BoardRules.plain(f.area.midX))″ from the left and \(BoardRules.plain(f.area.midY))″ from the top")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("as.board.inspector.position")
        }
    }

    /// Placement hints, not blocks (§ 9.4).
    @ViewBuilder
    private func hints(_ f: BoardLayout.Feature, index: Int) -> some View {
        let sides = BoardRules.zoneWarnings(for: f, zones: model.zones)
        let near = BoardRules.neighbours(of: index, in: model.board.features)
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            if !sides.isEmpty {
                Label("Inside " + sides.map { "Side \($0)’s zone" }.joined(separator: " and "), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(TMColor.warning)
                    .accessibilityIdentifier("as.board.inspector.zoneWarning")
            }
            ForEach(Array(model.tokenWarnings(f).enumerated()), id: \.offset) { _, text in
                Label(text, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(TMColor.warning)
                    .accessibilityIdentifier("as.board.inspector.tokenWarning")
            }
            ForEach(near, id: \.index) { neighbour in
                let other = model.board.features[neighbour.index]
                Label("\(BoardRules.inches(neighbour.gap)) from \(BoardRules.name(of: other.kind).lowercased())"
                      + (model.sideCount > 2 ? " [HOUSE] Keep 4″ apart unless they form one woods area." : ""),
                      systemImage: "arrow.left.and.right")
                    .foregroundStyle(.secondary)
            }
            if model.showBands, model.sideCount == 2, f.kind.isTerrain {
                Label(BoardRules.band(of: f, tableWidth: model.board.width).text, systemImage: "ruler")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("as.board.inspector.band")
            }
        }
        .font(TMFont.detail)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var nudgePad: some View {
        let step = model.step
        return VStack(spacing: TMSpace.xs) {
            Text("Move \(BoardRules.plain(step))″")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
            HStack(spacing: TMSpace.sm) {
                nudge("arrow.left", "Move left", "left", dx: -step, dy: 0)
                nudge("arrow.up", "Move up", "up", dx: 0, dy: -step)
                nudge("arrow.down", "Move down", "down", dx: 0, dy: step)
                nudge("arrow.right", "Move right", "right", dx: step, dy: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func nudge(_ symbol: String, _ label: String, _ id: String, dx: Double, dy: Double) -> some View {
        Button { model.nudge(pieceID, dx: dx, dy: dy) } label: {
            Image(systemName: symbol).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
        .accessibilityIdentifier("as.board.inspector.nudge.\(id)")
    }

    private func stepper(_ title: String, value: Double, range: ClosedRange<Double>, id: String, step: Double? = nil, set: @escaping (Double) -> Void) -> some View {
        let amount = step ?? model.snap.step ?? 0.5
        return Stepper(
            value: Binding(get: { value }, set: { set($0) }),
            in: range,
            step: amount
        ) {
            Text("\(title) \(BoardRules.plain(value))″").monospacedDigit()
        }
        .accessibilityIdentifier("as.board.inspector.\(id)")
    }

    /// What a token is for, from the game's objective when the setup has one (§ 7.1).
    private func tokenNote(_ f: BoardLayout.Feature) -> some View {
        let spec = BoardTokens.spec(for: f, plan: model.tokenPlan)
        let text = spec.map { "\($0.objective.title): " + ($0.objective.setupStep ?? "") }
            ?? "A marker for an objective token. It has no effect on the board. Raid and Hold the Fort name theirs from the game’s objective."
        return PlaySetupSection(title: "Objective token", footnote: "Quick-Start p. 7.") {
            Text(text).font(TMFont.detail).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("as.board.inspector.tokenNote")
    }

    /// What the piece does in play, in plain words, with the page (§ 9.3).
    private func rules(_ item: TerrainPaletteItem) -> some View {
        PlaySetupSection(title: "What it does in play", footnote: "Quick-Start \(item.pages). \(item.choices).") {
            ruleRow("Movement", item.movement)
            ruleRow("Line of sight", item.lineOfSight)
            ruleRow("Attacks", item.attack)
            if let note = item.note { ruleRow("Note", note) }
        }
        .accessibilityIdentifier("as.board.inspector.rules")
    }

    private func ruleRow(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xxs) {
            Text(title).font(TMFont.eyebrow).textCase(.uppercase).foregroundStyle(.secondary)
            Text(text).font(TMFont.detail).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
