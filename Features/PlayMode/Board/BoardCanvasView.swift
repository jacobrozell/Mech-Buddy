import SwiftUI
import MechBuddyDomain

/// The builder's canvas (PlayModeSpec § 9.2, § 9.4): the table, a 1″ grid, rulers, zones, pieces and handles.
/// Drag a piece to move it, drag empty space to pan, pinch to zoom, double-tap to fit, twist to rotate.
/// Every action also has a non-drag path: the inspector, the list editor and VoiceOver custom actions (§ 9.6).
struct BoardCanvasView: View {
    @Bindable var model: BoardEditorModel

    @State private var baseZoom: CGFloat = 1
    @State private var drag: DragKind?
    @State private var handleActive = false
    @State private var twistBase: Double?
    @State private var measureStartedFresh = false
    @Environment(\.colorSchemeContrast) private var contrast

    private enum DragKind {
        case move(id: UUID, grab: BoardLayout.Point)
        /// Dragging empty space pans; a tap on a sheet (no drag) selects it.
        case pan(start: CGSize, sheet: Int?)
        /// A selected mapsheet follows the finger (§ 9.2).
        case moveSheet(index: Int, grab: BoardLayout.Point)
        case measure
    }

    private var zoom: CGFloat {
        get { model.zoom }
        nonmutating set { model.zoom = newValue }
    }

    private var pan: CGSize {
        get { model.pan }
        nonmutating set { model.pan = newValue }
    }

    static let margin: CGFloat = 22
    static let zoomRange: ClosedRange<CGFloat> = 0.5...4

    private struct Transform {
        var scale: CGFloat
        var origin: CGPoint

        func point(_ p: BoardLayout.Point) -> CGPoint { CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale) }
        func inches(_ p: CGPoint) -> BoardLayout.Point { .init(x: (p.x - origin.x) / scale, y: (p.y - origin.y) / scale) }
        var frame: BoardDrawing.Frame { .init(scale: scale, origin: origin) }
    }

    private func transform(in size: CGSize) -> Transform {
        let m = Self.mapping(size: size, board: model.board, zoom: zoom, pan: pan)
        return Transform(scale: m.scale, origin: m.origin)
    }

    /// Where the table sits in a canvas of `size`: points per inch and the top-left corner. Shared with the
    /// editor, which turns a palette drop into inches.
    static func mapping(size: CGSize, board: BoardLayout, zoom: CGFloat, pan: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        let fit = max(1, min((size.width - 2 * margin) / board.width, (size.height - 2 * margin) / board.depth))
        let scale = fit * zoom
        let w = board.width * scale
        let h = board.depth * scale
        let limitX = max(w, size.width) / 2
        let limitY = max(h, size.height) / 2
        let px = min(max(pan.width, -limitX), limitX)
        let py = min(max(pan.height, -limitY), limitY)
        return (scale, CGPoint(x: (size.width - w) / 2 + px, y: (size.height - h) / 2 + py))
    }

    var body: some View {
        GeometryReader { proxy in
            let t = transform(in: proxy.size)
            ZStack {
                Canvas { context, size in
                    draw(&context, size: size, t: t)
                }
                .gesture(canvasGesture(t))
                .simultaneousGesture(
                    MagnifyGesture()
                        .onChanged { zoom = min(max(baseZoom * $0.magnification, Self.zoomRange.lowerBound), Self.zoomRange.upperBound) }
                        .onEnded { _ in baseZoom = zoom }
                )
                .simultaneousGesture(
                    RotateGesture()
                        .onChanged { twist($0.rotation.degrees) }
                        .onEnded { _ in
                            if twistBase != nil { model.endGesture() }
                            twistBase = nil
                        }
                )
                .simultaneousGesture(TapGesture(count: 2).onEnded { fit() })

                accessibilityPieces(t)
                edgeHandles(t)
                handles(t)
                hudOverlay
            }
            .coordinateSpace(name: "boardCanvas")
            .clipped()
            .contentShape(Rectangle())
        }
        .background(TMColor.readout, in: RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.summary)
        .accessibilityIdentifier("as.board.canvas")
    }

    func fit() {
        zoom = 1
        baseZoom = 1
        pan = .zero
    }

    // MARK: Gestures

    private func canvasGesture(_ t: Transform) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let moved = hypot(value.translation.width, value.translation.height) > 6
                if drag == nil { begin(at: value.startLocation, t: t) }
                switch drag {
                case .move(let id, let grab):
                    let p = t.inches(value.location)
                    model.place(id, x: p.x - grab.x, y: p.y - grab.y)
                case .moveSheet(let index, let grab):
                    let p = t.inches(value.location)
                    model.placeSheet(index, x: p.x - grab.x, y: p.y - grab.y)
                case .pan(let start, _):
                    pan = CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height)
                case .measure:
                    if moved || !measureStartedFresh { model.measureB = snapped(t.inches(value.location)) }
                case nil:
                    break
                }
            }
            .onEnded { value in
                let moved = hypot(value.translation.width, value.translation.height) > 6
                switch drag {
                case .move:
                    model.endGesture()
                case .moveSheet:
                    model.endGesture()
                case .pan(_, let sheet):
                    if !moved { sheet.map { model.selectSheet($0) } ?? model.clearSelection() }
                case .measure:
                    if measureStartedFresh && !moved { model.measureB = nil }
                case nil:
                    break
                }
                drag = nil
            }
    }

    private func begin(at point: CGPoint, t: Transform) {
        let p = t.inches(point)
        if model.isMeasuring {
            measureStartedFresh = model.measureA == nil || model.measureB != nil
            if measureStartedFresh {
                model.measureA = snapped(p)
                model.measureB = nil
            }
            drag = .measure
            return
        }
        if let index = pieceIndex(at: p, scale: t.scale), let id = model.board.features[index].id {
            let area = model.board.features[index].area
            model.select(id)
            model.beginGesture()
            drag = .move(id: id, grab: .init(x: p.x - area.x, y: p.y - area.y))
        } else if let sheet = BoardRules.sheetHit(model.board.sheets, at: p) {
            // Sheets cover most of a mapsheet table, so a drag only moves one that is already selected.
            if model.sheetSelection == sheet {
                let area = model.board.sheets[sheet].area
                model.beginGesture()
                drag = .moveSheet(index: sheet, grab: .init(x: p.x - area.x, y: p.y - area.y))
            } else {
                drag = .pan(start: pan, sheet: sheet)
            }
        } else {
            drag = .pan(start: pan, sheet: nil)
        }
    }

    /// The topmost piece under the touch, with some slack so a 0.5″ wall or a tree is easy to hit.
    private func pieceIndex(at p: BoardLayout.Point, scale: CGFloat) -> Int? {
        let features = model.board.features
        if let exact = BoardRules.hit(features, at: p) { return exact }
        let slack = 14 / Double(scale)
        return features.indices.reversed().first { i in
            let b = BoardRules.bounds(of: features[i])
            return p.x >= b.x - slack && p.x <= b.maxX + slack && p.y >= b.y - slack && p.y <= b.maxY + slack
        }
    }

    private func snapped(_ p: BoardLayout.Point) -> BoardLayout.Point {
        .init(x: min(max(BoardRules.snap(p.x, to: model.snap), 0), model.board.width),
              y: min(max(BoardRules.snap(p.y, to: model.snap), 0), model.board.depth))
    }

    private func twist(_ degrees: Double) {
        guard let id = model.selection, let feature = model.board.features.first(where: { $0.id == id }) else { return }
        if twistBase == nil {
            twistBase = feature.degrees
            model.beginGesture()
        }
        model.setRotation(id, (twistBase ?? 0) + degrees)
    }

    // MARK: Drawing

    private func draw(_ context: inout GraphicsContext, size: CGSize, t: Transform) {
        let board = model.board
        let table = CGRect(x: t.origin.x, y: t.origin.y, width: board.width * t.scale, height: board.depth * t.scale)
        let high = contrast == .increased

        context.fill(Path(table), with: .color(Color(.systemBackground)))
        drawGrid(&context, table: table, t: t)

        let selected = model.selection.map { Set([$0]) } ?? []
        let warned = Set(model.warnings.keys)
        BoardDrawing.drawTable(board, zones: model.zones, in: &context, frame: t.frame, highContrast: high, warned: warned, selected: selected)
        context.stroke(Path(table), with: .color(Color.primary.opacity(0.6)), lineWidth: high ? 2 : 1)
        if let sheet = model.selectedSheet {
            context.stroke(Path(roundedRect: t.frame.rect(sheet.area), cornerRadius: 4), with: .color(TMColor.signal), lineWidth: 3)
        }

        if model.showBands, model.sideCount == 2 { drawBands(&context, t: t) }
        drawRulers(&context, table: table, t: t)
        drawMeasure(&context, t: t)
    }

    private func drawGrid(_ context: inout GraphicsContext, table: CGRect, t: Transform) {
        let board = model.board
        var clipped = context
        clipped.clip(to: Path(table))
        let fine = t.scale >= 5
        let thin = Color.primary.opacity(0.08)
        let heavy = Color.primary.opacity(contrast == .increased ? 0.4 : 0.2)
        var inch = 0
        while Double(inch) <= board.width {
            let heavyLine = inch % 6 == 0
            if fine || heavyLine {
                var p = Path()
                p.move(to: CGPoint(x: t.origin.x + CGFloat(inch) * t.scale, y: table.minY))
                p.addLine(to: CGPoint(x: t.origin.x + CGFloat(inch) * t.scale, y: table.maxY))
                clipped.stroke(p, with: .color(heavyLine ? heavy : thin), lineWidth: heavyLine ? 1 : 0.5)
            }
            inch += 1
        }
        inch = 0
        while Double(inch) <= board.depth {
            let heavyLine = inch % 6 == 0
            if fine || heavyLine {
                var p = Path()
                p.move(to: CGPoint(x: table.minX, y: t.origin.y + CGFloat(inch) * t.scale))
                p.addLine(to: CGPoint(x: table.maxX, y: t.origin.y + CGFloat(inch) * t.scale))
                clipped.stroke(p, with: .color(heavyLine ? heavy : thin), lineWidth: heavyLine ? 1 : 0.5)
            }
            inch += 1
        }
    }

    /// Inches every 6″ along the top and left edges.
    private func drawRulers(_ context: inout GraphicsContext, table: CGRect, t: Transform) {
        let board = model.board
        let label = Font.system(size: 9, weight: .medium, design: .monospaced)
        var inch = 0
        while Double(inch) <= board.width {
            context.draw(Text("\(inch)").font(label).foregroundStyle(.secondary), at: CGPoint(x: t.origin.x + CGFloat(inch) * t.scale, y: table.minY - 9))
            inch += 6
        }
        inch = 6
        while Double(inch) <= board.depth {
            context.draw(Text("\(inch)").font(label).foregroundStyle(.secondary), at: CGPoint(x: table.minX - 10, y: t.origin.y + CGFloat(inch) * t.scale))
            inch += 6
        }
    }

    /// The p. 8 bands for two sides: the centre line, 6″ and 24″ either side of it.
    private func drawBands(_ context: inout GraphicsContext, t: Transform) {
        let board = model.board
        let mid = board.width / 2
        var clipped = context
        clipped.clip(to: Path(CGRect(x: t.origin.x, y: t.origin.y, width: board.width * t.scale, height: board.depth * t.scale)))
        let near = BoardLayout.Rect(x: mid - 6, y: 0, width: 12, depth: board.depth)
        clipped.fill(Path(t.frame.rect(near)), with: .color(TMColor.info.opacity(0.15)))
        for offset in [-24.0, 0.0, 24.0] {
            var line = Path()
            line.move(to: t.point(.init(x: mid + offset, y: 0)))
            line.addLine(to: t.point(.init(x: mid + offset, y: board.depth)))
            clipped.stroke(line, with: .color(TMColor.info.opacity(offset == 0 ? 0.9 : 0.6)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        }
    }

    private func drawMeasure(_ context: inout GraphicsContext, t: Transform) {
        guard let a = model.measureA else { return }
        let pa = t.point(a)
        context.fill(Path(ellipseIn: CGRect(x: pa.x - 4, y: pa.y - 4, width: 8, height: 8)), with: .color(TMColor.signal))
        guard let b = model.measureB else { return }
        let pb = t.point(b)
        var line = Path()
        line.move(to: pa)
        line.addLine(to: pb)
        context.stroke(line, with: .color(TMColor.signal), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: pb.x - 4, y: pb.y - 4, width: 8, height: 8)), with: .color(TMColor.signal))
        if let text = model.measureText {
            BoardDrawing.drawLabel(Text(text).font(.caption.weight(.bold)).foregroundStyle(.primary),
                                   at: CGPoint(x: (pa.x + pb.x) / 2, y: (pa.y + pb.y) / 2 - 12), in: &context)
        }
    }

    // MARK: Overlays

    private var hudOverlay: some View {
        VStack {
            if let hud = model.hud {
                Text(hud)
                    .font(TMFont.stat)
                    .padding(.horizontal, TMSpace.md)
                    .padding(.vertical, TMSpace.xs)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityIdentifier("as.board.hud")
            }
            Spacer()
        }
        .padding(TMSpace.sm)
        .allowsHitTesting(false)
    }

    /// One VoiceOver element per piece, placed over the piece, with the move, rotate, resize and delete actions (§ 9.6).
    private func accessibilityPieces(_ t: Transform) -> some View {
        ZStack {
            ForEach(Array(model.board.sheets.enumerated()), id: \.offset) { index, sheet in
                sheetElement(index, sheet, t)
            }
            ForEach(Array(model.board.features.enumerated()), id: \.offset) { index, feature in
                let box = BoardRules.bounds(of: feature)
                let center = t.point(feature.area.center)
                if let id = feature.id {
                    Color.clear
                        .frame(width: max(box.width * t.scale, 44), height: max(box.depth * t.scale, 44))
                        .position(center)
                        .allowsHitTesting(false)
                        .accessibilityElement()
                        .accessibilityLabel(model.spoken(feature))
                        .accessibilityValue(model.selection == id ? "Selected" : "")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("as.board.piece.\(index)")
                        .accessibilityAdjustableAction { direction in
                            model.rotate(id, by: direction == .increment ? 15 : -15)
                        }
                        .accessibilityAction { model.select(id) }
                        .accessibilityAction(named: "Move left") { model.nudge(id, dx: -model.step, dy: 0) }
                        .accessibilityAction(named: "Move right") { model.nudge(id, dx: model.step, dy: 0) }
                        .accessibilityAction(named: "Move up") { model.nudge(id, dx: 0, dy: -model.step) }
                        .accessibilityAction(named: "Move down") { model.nudge(id, dx: 0, dy: model.step) }
                        .accessibilityAction(named: "Rotate 15 degrees") { model.rotate(id, by: 15) }
                        .accessibilityAction(named: "Bigger") { model.bigger(id) }
                        .accessibilityAction(named: "Smaller") { model.smaller(id) }
                        .accessibilityAction(named: "Delete") { model.delete(id) }
                }
            }
        }
    }

    /// One VoiceOver element per mapsheet: select, move by the snap step, turn 90° (§ 9.6).
    private func sheetElement(_ index: Int, _ sheet: BoardLayout.Sheet, _ t: Transform) -> some View {
        let frame = t.frame.rect(sheet.area)
        return Color.clear
            .frame(width: max(frame.width, 44), height: max(frame.height, 44))
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(BoardRules.spoken(sheet, in: model.board))
            .accessibilityValue(model.sheetSelection == index ? "Selected" : "")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("as.board.sheet.\(index)")
            .accessibilityAdjustableAction { _ in model.rotateSheet(index) }
            .accessibilityAction { model.selectSheet(index) }
            .accessibilityAction(named: "Move left") { model.nudgeSheet(index, dx: -model.step, dy: 0) }
            .accessibilityAction(named: "Move right") { model.nudgeSheet(index, dx: model.step, dy: 0) }
            .accessibilityAction(named: "Move up") { model.nudgeSheet(index, dx: 0, dy: -model.step) }
            .accessibilityAction(named: "Move down") { model.nudgeSheet(index, dx: 0, dy: model.step) }
            .accessibilityAction(named: "Turn 90 degrees") { model.rotateSheet(index) }
    }

    /// Zone depth handles on each zone's inner edge, and the sheet turn button. They stay 44 pt at every zoom.
    @ViewBuilder
    private func edgeHandles(_ t: Transform) -> some View {
        ForEach(model.zones, id: \.side) { zone in
            zoneHandle(zone, t)
        }
        if let index = model.sheetSelection, model.board.sheets.indices.contains(index) {
            let box = t.frame.rect(model.board.sheets[index].area)
            handle(systemImage: "rotate.right", at: CGPoint(x: box.maxX - 22, y: box.minY + 22), label: "Turn 90°", id: "as.board.handle.sheet.rotate")
                .onTapGesture { model.rotateSheet(index) }
                .accessibilityHidden(true)
        }
    }

    /// The handle on a zone's inner edge: drag to change its depth (snapped); VoiceOver adjusts by 1″ (§ 9.2, § 9.6).
    private func zoneHandle(_ zone: BoardLayout.Zone, _ t: Transform) -> some View {
        let board = model.board
        let edge = BoardRules.homeEdge(of: zone, width: board.width, depth: board.depth)
        let point = t.point(BoardRules.innerEdgeMidpoint(of: zone, width: board.width, depth: board.depth))
        let depth = BoardRules.depth(of: zone, width: board.width, depth: board.depth)
        let vertical = edge == .west || edge == .east
        return handleGlyph(vertical ? "arrow.left.and.right" : "arrow.up.and.down")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Side \(zone.side) deployment zone depth")
            .accessibilityValue("\(BoardRules.plain(depth)) inches")
            .accessibilityHint("Swipe up or down to change the depth by 1 inch.")
            .accessibilityAdjustableAction { direction in
                model.nudgeZoneDepth(zone.side, by: direction == .increment ? 1 : -1)
            }
            .accessibilityIdentifier("as.board.handle.zone.\(zone.side)")
            .position(point)
            .gesture(handleDrag { location in
                model.liveZoneDepth(zone.side, toward: t.inches(location))
            })
    }

    /// Rotate and resize handles on the selected piece. They stay 44 pt at every zoom.
    @ViewBuilder
    private func handles(_ t: Transform) -> some View {
        if let id = model.selection, let feature = model.board.features.first(where: { $0.id == id }) {
            let center = t.point(feature.area.center)
            let w = feature.area.width * t.scale
            let h = feature.area.depth * t.scale
            let angle = feature.degrees * .pi / 180
            let rotatePoint = rotated(CGPoint(x: center.x, y: center.y - (h / 2 + 30)), by: angle, about: center)
            let resizePoint = rotated(CGPoint(x: center.x + w / 2, y: center.y + h / 2), by: angle, about: center)

            handle(systemImage: "arrow.clockwise", at: rotatePoint, label: "Rotate", id: "as.board.handle.rotate")
                .gesture(handleDrag { location in
                    let degrees = atan2(location.y - center.y, location.x - center.x) * 180 / .pi + 90
                    model.setRotation(id, degrees)
                })
            handle(systemImage: "arrow.up.left.and.arrow.down.right", at: resizePoint, label: "Resize", id: "as.board.handle.resize")
                .gesture(handleDrag { location in
                    let local = rotated(location, by: -angle, about: center)
                    let lx = (local.x - center.x) / t.scale
                    let ly = (local.y - center.y) / t.scale
                    model.liveResize(id, width: 2 * Double(lx), depth: 2 * Double(ly))
                })
        }
    }

    private func handle(systemImage: String, at point: CGPoint, label: String, id: String) -> some View {
        handleGlyph(systemImage)
            .position(point)
            .accessibilityHidden(true)
            .accessibilityIdentifier(id)
    }

    private func handleGlyph(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(TMColor.onSignal)
            .frame(width: 20, height: 20)
            .background(TMColor.signal, in: Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private func handleDrag(_ update: @escaping (CGPoint) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("boardCanvas"))
            .onChanged { value in
                if !handleActive {
                    handleActive = true
                    model.beginGesture()
                }
                update(value.location)
            }
            .onEnded { _ in
                handleActive = false
                model.endGesture()
            }
    }

    private func rotated(_ p: CGPoint, by angle: Double, about c: CGPoint) -> CGPoint {
        let dx = p.x - c.x
        let dy = p.y - c.y
        return CGPoint(x: c.x + dx * cos(angle) - dy * sin(angle), y: c.y + dx * sin(angle) + dy * cos(angle))
    }
}
