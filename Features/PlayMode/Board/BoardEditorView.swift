import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// The terrain board builder (PlayModeSpec § 9). Pushed from Battlefield setup. It edits a copy of the board
/// and writes each finished change back through `onChange`, so Back keeps what was built.
struct BoardEditorView: View {
    @State private var model: BoardEditorModel
    @State private var showList = false
    @State private var dragging: (item: TerrainPaletteItem, location: CGPoint)?
    @State private var canvasFrame: CGRect = .zero
    @State private var showInspectorSheet = false
    @State private var showSave = false
    /// False when the builder opens a saved board from the Boards list, which saves each change itself.
    private let canSave: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(board: BoardLayout, sides: [MatchSide], palette: TerrainPaletteFile, canSave: Bool = true, onChange: @escaping (BoardLayout) -> Void) {
        self.canSave = canSave
        _model = State(initialValue: BoardEditorModel(board: board, sides: sides, palette: palette, onChange: onChange))
    }

    private var isRegular: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }
    private var isLandscapePhone: Bool { verticalSizeClass == .compact }

    var body: some View {
        content
            .coordinateSpace(name: "boardEditor")
            .overlay { ghost }
            .navigationTitle("Build a board")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .toolbar { toolbar }
            .sheet(isPresented: $showSave) {
                BoardSaveSheet(board: model.board) { model.linkToPreset($0) }
            }
            .sheet(isPresented: $showList, onDismiss: { model.selection = nil }) {
                BoardPieceListView(model: model)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: Binding(
                get: { model.selection != nil && !showList && !isRegular && !isLandscapePhone },
                set: { if !$0 { model.selection = nil } }
            )) {
                if let id = model.selection {
                    BoardInspectorView(model: model, pieceID: id)
                        .presentationDetents([.height(240), .medium, .large])
                        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                        .presentationDragIndicator(.visible)
                }
            }
            // An identifier on the container would replace the ones on the canvas and palette, so it sits on a marker.
            .background {
                Color.clear
                    .accessibilityElement()
                    .accessibilityLabel("Board builder")
                    .accessibilityIdentifier("as.board.editor")
                    .allowsHitTesting(false)
            }
    }

    @ViewBuilder
    private var content: some View {
        if isRegular {
            HStack(spacing: 0) {
                BoardPaletteView(items: model.palette.items, axis: .vertical, onTap: { model.add($0) }, onDrag: handleDrag)
                    .frame(width: 220)
                Divider()
                canvasColumn
                if let id = model.selection {
                    Divider()
                    BoardInspectorView(model: model, pieceID: id)
                        .frame(width: 340)
                }
            }
        } else if isLandscapePhone {
            HStack(spacing: 0) {
                canvasColumn
                Divider()
                VStack(spacing: 0) {
                    BoardPaletteView(items: model.palette.items, axis: .vertical, onTap: { model.add($0) }, onDrag: handleDrag)
                        .frame(maxHeight: model.selection == nil ? .infinity : 150)
                    if let id = model.selection {
                        Divider()
                        BoardInspectorView(model: model, pieceID: id)
                    }
                }
                .frame(width: 300)
            }
        } else {
            VStack(spacing: 0) {
                canvasColumn
                BoardPaletteView(items: model.palette.items, axis: .horizontal, onTap: { model.add($0) }, onDrag: handleDrag)
                    .frame(height: 84)
            }
        }
    }

    private var canvasColumn: some View {
        VStack(spacing: TMSpace.xs) {
            statusLine
            BoardCanvasView(model: model)
                .padding(.horizontal, TMSpace.sm)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("boardEditor")) } action: { canvasFrame = $0 }
        }
        .padding(.top, TMSpace.xs)
    }

    private var statusLine: some View {
        VStack(alignment: .leading, spacing: TMSpace.xxs) {
            HStack(spacing: TMSpace.sm) {
                Text(model.counterText)
                    .font(TMFont.stat)
                    .accessibilityIdentifier("as.board.counter")
                Spacer(minLength: TMSpace.sm)
                if model.isMeasuring {
                    Label(model.measureText ?? "Touch two points", systemImage: "ruler")
                        .font(TMFont.stat)
                        .foregroundStyle(TMColor.signal)
                        .accessibilityIdentifier("as.board.measure.readout")
                }
                Text("Snap \(model.snap.title)")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            if !model.warnings.isEmpty {
                Label("\(model.warnings.count) \(model.warnings.count == 1 ? "piece is" : "pieces are") inside a deployment zone.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(TMFont.detail)
                    .foregroundStyle(TMColor.warning)
                    .accessibilityIdentifier("as.board.zoneWarning")
            }
        }
        .padding(.horizontal, TMSpace.lg)
        .accessibilityElement(children: .contain)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }
                .accessibilityIdentifier("as.board.done")
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button { model.undo() } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)
            .keyboardShortcut("z", modifiers: .command)
            .accessibilityIdentifier("as.board.undo")
            Button { model.redo() } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!model.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .accessibilityIdentifier("as.board.redo")
            Spacer()
            Button {
                model.isMeasuring.toggle()
                model.clearMeasure()
            } label: {
                Label("Measure", systemImage: "ruler")
            }
            .accessibilityAddTraits(model.isMeasuring ? .isSelected : [])
            .accessibilityValue(model.isMeasuring ? "On" : "Off")
            .accessibilityIdentifier("as.board.measure")
            Button { model.snap = model.snap.next } label: {
                Label("Snap \(model.snap.title)", systemImage: "grid")
            }
            .accessibilityValue(model.snap.title)
            .accessibilityHint("Changes how far a piece jumps when you move it")
            .accessibilityIdentifier("as.board.snap")
            Button { showList = true } label: {
                Label("Pieces", systemImage: "list.bullet")
            }
            .accessibilityIdentifier("as.board.list")
            Menu {
                Toggle("Show placement bands", isOn: $model.showBands)
                    .accessibilityIdentifier("as.board.bands")
                Menu("Zone depth") {
                    ForEach([4.0, 6.0, 8.0, 12.0], id: \.self) { depth in
                        Button {
                            model.setZoneDepth(depth)
                        } label: {
                            if model.zoneDepth == depth {
                                Label("\(Int(depth))″", systemImage: "checkmark")
                            } else {
                                Text("\(Int(depth))″")
                            }
                        }
                    }
                }
                if canSave {
                    Button("Save board", systemImage: "square.and.arrow.down") { showSave = true }
                        .accessibilityIdentifier("as.board.save")
                }
                Button("Reset zones", systemImage: "arrow.counterclockwise") { model.resetZones() }
                    .accessibilityIdentifier("as.board.resetZones")
            } label: {
                Label("Board options", systemImage: "ellipsis.circle")
            }
            .accessibilityIdentifier("as.board.options")
        }
    }

    // MARK: Dragging from the palette

    private func handleDrag(_ item: TerrainPaletteItem, location: CGPoint, ended: Bool) {
        if ended {
            dragging = nil
            guard canvasFrame.contains(location) else { return }
            let point = canvasPoint(location)
            model.add(item, centredAt: point)
        } else {
            dragging = (item, location)
        }
    }

    /// Where a finger over the canvas is on the table, in inches, using the canvas's own zoom and pan.
    private func canvasPoint(_ location: CGPoint) -> BoardLayout.Point {
        let m = BoardCanvasView.mapping(size: canvasFrame.size, board: model.board, zoom: model.zoom, pan: model.pan)
        return .init(x: (location.x - canvasFrame.minX - m.origin.x) / m.scale, y: (location.y - canvasFrame.minY - m.origin.y) / m.scale)
    }

    @ViewBuilder
    private var ghost: some View {
        if let dragging {
            Image(systemName: dragging.item.glyph)
                .font(.title2)
                .foregroundStyle(BoardDrawing.color(for: dragging.item.kind))
                .padding(TMSpace.md)
                .background(.regularMaterial, in: Circle())
                .position(dragging.location)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
