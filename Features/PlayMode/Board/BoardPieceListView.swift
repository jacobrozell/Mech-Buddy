import SwiftUI
import MechBuddyDomain

/// The list editor (§ 9.6): every piece as a row, with the same actions as the canvas. It builds a board with
/// no dragging at all: Add, then set size and position in the inspector.
struct BoardPieceListView: View {
    @Bindable var model: BoardEditorModel
    @Environment(\.dismiss) private var dismiss
    @State private var path = NavigationPath()
    /// A mapsheet row's destination.
    private struct SheetRoute: Hashable { var index: Int }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !model.board.sheets.isEmpty {
                    Section("Mapsheets") {
                        ForEach(Array(model.board.sheets.enumerated()), id: \.offset) { index, sheet in
                            sheetRow(sheet, index: index)
                        }
                    }
                }
                Section {
                    if model.board.features.isEmpty {
                        Text("No pieces yet. Use Add piece to place the first one.")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(model.board.features.enumerated()), id: \.offset) { index, feature in
                        if let id = feature.id {
                            row(feature, id: id, index: index)
                        }
                    }
                } header: {
                    Text(model.counterText)
                        .accessibilityIdentifier("as.board.pieceList.counter")
                }
            }
            .navigationTitle("Pieces")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SheetRoute.self) { route in
                BoardSheetInspectorView(model: model, index: route.index)
                    .navigationTitle("Mapsheet")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationDestination(for: UUID.self) { id in
                BoardInspectorView(model: model, pieceID: id)
                    .navigationTitle("Piece")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(model.paletteItems) { item in
                            Button {
                                model.add(item)
                                if let id = model.selection { path = NavigationPath([id]) }
                            } label: {
                                Label(item.title, systemImage: item.glyph)
                            }
                            .accessibilityIdentifier("as.board.pieceList.add.\(item.id)")
                        }
                    } label: {
                        Label("Add piece", systemImage: "plus")
                    }
                    .accessibilityIdentifier("as.board.pieceList.add")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("as.board.pieceList.done")
                }
            }
        }
        .accessibilityIdentifier("as.board.pieceList")
    }

    private func row(_ f: BoardLayout.Feature, id: UUID, index: Int) -> some View {
        NavigationLink(value: id) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                HStack(spacing: TMSpace.sm) {
                    Image(systemName: model.paletteItem(f)?.glyph ?? "square")
                        .foregroundStyle(BoardDrawing.color(for: f.kind))
                        .accessibilityHidden(true)
                    Text(f.name.flatMap { $0.isEmpty ? nil : $0 } ?? BoardRules.name(of: f.kind))
                        .font(TMFont.body)
                }
                Text(detail(f, index: index))
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.spoken(f))
        .accessibilityAction(named: "Move left") { model.nudge(id, dx: -model.step, dy: 0) }
        .accessibilityAction(named: "Move right") { model.nudge(id, dx: model.step, dy: 0) }
        .accessibilityAction(named: "Move up") { model.nudge(id, dx: 0, dy: -model.step) }
        .accessibilityAction(named: "Move down") { model.nudge(id, dx: 0, dy: model.step) }
        .accessibilityAction(named: "Duplicate") { model.duplicate(id) }
        .accessibilityAction(named: "Delete") { model.delete(id) }
        .accessibilityIdentifier("as.board.pieceList.row.\(index)")
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { model.delete(id) } label: { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .leading) {
            Button { model.duplicate(id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                .tint(TMColor.coolant)
        }
        .contextMenu {
            Button { model.duplicate(id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Button(role: .destructive) { model.delete(id) } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func sheetRow(_ sheet: BoardLayout.Sheet, index: Int) -> some View {
        NavigationLink(value: SheetRoute(index: index)) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Label(sheet.name, systemImage: "rectangle.dashed")
                    .font(TMFont.body)
                Text("\(BoardRules.plain(sheet.area.width)) × \(BoardRules.plain(sheet.area.depth))″ · top left \(BoardRules.plain(sheet.area.x)) from left, \(BoardRules.plain(sheet.area.y)) from top"
                     + ((sheet.rotation ?? 0) % 360 != 0 ? " · turned \(sheet.rotation ?? 0)°" : ""))
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(BoardRules.spoken(sheet, in: model.board))
        .accessibilityAction(named: "Move left") { model.nudgeSheet(index, dx: -model.step, dy: 0) }
        .accessibilityAction(named: "Move right") { model.nudgeSheet(index, dx: model.step, dy: 0) }
        .accessibilityAction(named: "Move up") { model.nudgeSheet(index, dx: 0, dy: -model.step) }
        .accessibilityAction(named: "Move down") { model.nudgeSheet(index, dx: 0, dy: model.step) }
        .accessibilityAction(named: "Turn 90 degrees") { model.rotateSheet(index) }
        .accessibilityIdentifier("as.board.pieceList.sheet.\(index)")
    }

    /// "5 × 5″ · centre 14 from left, 9 from top · turned 30° · level 2″".
    private func detail(_ f: BoardLayout.Feature, index: Int) -> String {
        var parts = ["\(BoardRules.plain(f.area.width)) × \(BoardRules.plain(f.area.depth))″",
                     "centre \(BoardRules.plain(f.area.midX)) from left, \(BoardRules.plain(f.area.midY)) from top"]
        if f.degrees != 0 { parts.append("turned \(BoardRules.plain(f.degrees))°") }
        if let level = BoardRules.hillLevel(at: index, in: model.board.features) {
            parts.append("level \(BoardRules.plain(level))″")
        } else if f.kind == .building, let level = f.level {
            parts.append("height \(BoardRules.plain(level))″")
        }
        return parts.joined(separator: " · ")
    }
}
