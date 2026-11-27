import SwiftUI
import MechBuddyDomain

/// The selected mapsheet (§ 9.2): where it is, turn it 90°, move it by buttons. Everything is a button or a
/// stepper, so sheets can be arranged without dragging (§ 9.6).
struct BoardSheetInspectorView: View {
    @Bindable var model: BoardEditorModel
    var index: Int

    var body: some View {
        ScrollView {
            if model.board.sheets.indices.contains(index) {
                content(model.board.sheets[index])
                    .padding(TMSpace.lg)
            } else {
                Text("This mapsheet is gone.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .padding(TMSpace.lg)
            }
        }
        .accessibilityIdentifier("as.board.sheet.inspector")
    }

    private func content(_ sheet: BoardLayout.Sheet) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Text(sheet.name)
                    .font(TMFont.stepTitle)
                    .accessibilityAddTraits(.isHeader)
                Text("\(BoardRules.plain(sheet.area.width)) × \(BoardRules.plain(sheet.area.depth))″, top left \(BoardRules.plain(sheet.area.x))″ from the left and \(BoardRules.plain(sheet.area.y))″ from the top")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("as.board.sheet.inspector.position")
            }
            if let warning = model.sheetWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(TMFont.detail)
                    .foregroundStyle(TMColor.warning)
                    .accessibilityIdentifier("as.board.sheet.inspector.warning")
            }
            PlaySetupSection(title: "Position and turn") {
                stepper("Left edge", value: sheet.area.x, range: 0...96, id: "x") { model.setSheetPosition(index, x: $0) }
                stepper("Top edge", value: sheet.area.y, range: 0...96, id: "y") { model.setSheetPosition(index, y: $0) }
                HStack {
                    Text("Turned \((sheet.rotation ?? 0))°")
                        .font(TMFont.body)
                        .monospacedDigit()
                        .accessibilityIdentifier("as.board.sheet.inspector.rotation")
                    Spacer()
                    Button { model.rotateSheet(index) } label: {
                        Label("Turn 90°", systemImage: "rotate.right").frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("as.board.sheet.inspector.rotate")
                }
                nudgePad
            }
            Text("A sheet snaps edge to edge with its neighbours and the table’s edges when Snap is on. Sheets may reach past the table; use Fit table to sheets to size the table to them [HOUSE].")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Fit table to sheets", systemImage: "arrow.up.left.and.arrow.down.right") { model.fitTableToSheets() }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("as.board.sheet.inspector.fitTable")
        }
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
        Button { model.nudgeSheet(index, dx: dx, dy: dy) } label: {
            Image(systemName: symbol).frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
        .accessibilityIdentifier("as.board.sheet.inspector.nudge.\(id)")
    }

    private func stepper(_ title: String, value: Double, range: ClosedRange<Double>, id: String, set: @escaping (Double) -> Void) -> some View {
        Stepper(value: Binding(get: { value }, set: { set($0) }), in: range, step: model.step) {
            Text("\(title) \(BoardRules.plain(value))″").monospacedDigit()
        }
        .accessibilityIdentifier("as.board.sheet.inspector.\(id)")
    }
}

/// The inspector for whatever is selected: a piece or a mapsheet.
struct BoardSelectionInspector: View {
    @Bindable var model: BoardEditorModel

    var body: some View {
        if let id = model.selection {
            BoardInspectorView(model: model, pieceID: id)
        } else if let index = model.sheetSelection {
            BoardSheetInspectorView(model: model, index: index)
        }
    }
}
