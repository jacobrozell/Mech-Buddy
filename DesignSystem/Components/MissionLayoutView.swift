import SwiftUI
import MechBuddyData

// Top-down table diagram for a mission, like the scenario map layouts in A Game of Armored Combat:
// mapsheets, each side's setup zone, and suggested terrain. Spec: specs/features/GuidedMissionSpec.md § Maps.

struct MissionLayoutView: View {
    var layout: MissionLayoutDTO


    private var aspect: CGFloat { CGFloat(layout.width / max(layout.depth, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(TMColor.readout, in: RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous))
            HStack(spacing: TMSpace.md) {
                legendItem(color: TMColor.sideA, text: "Side A sets up")
                legendItem(color: TMColor.sideB, text: "Side B sets up")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MissionLayoutDescription.spoken(layout))
        .accessibilityIdentifier("mission.layout")
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: TMSpace.xs) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.45)).frame(width: 14, height: 10)
            Text(text)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / layout.width, size.height / layout.depth)
        func rect(_ r: MissionLayoutDTO.Rect) -> CGRect {
            CGRect(x: r.x * scale, y: r.y * scale, width: r.width * scale, height: r.depth * scale)
        }
        let line = Color.primary.opacity(0.35)

        // Mapsheets: outlined (names go on last, above the zones).
        for sheet in layout.sheets {
            let frame = rect(sheet.area).insetBy(dx: 1, dy: 1)
            context.stroke(Path(roundedRect: frame, cornerRadius: 4), with: .color(line), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }

        // Setup zones in side colours.
        for zone in layout.zones {
            let color = zone.side == "A" ? TMColor.sideA : TMColor.sideB
            let frame = rect(zone.area)
            context.fill(Path(frame), with: .color(color.opacity(0.3)))
            context.draw(
                Text(zone.side).font(.headline.weight(.bold)).foregroundStyle(color),
                at: CGPoint(x: frame.midX, y: frame.midY)
            )
        }

        // Terrain.
        let woods = Color(red: 0.25, green: 0.55, blue: 0.3)
        let hill = Color(red: 0.6, green: 0.47, blue: 0.3)
        for feature in layout.features {
            let frame = rect(feature.area)
            switch feature.kind {
            case .hill:
                context.fill(Path(ellipseIn: frame), with: .color(hill.opacity(0.35)))
                context.stroke(Path(ellipseIn: frame.insetBy(dx: frame.width * 0.2, dy: frame.height * 0.2)),
                               with: .color(hill.opacity(0.6)), lineWidth: 1)
                Self.drawLabel(Text("Hill").font(.caption2).foregroundStyle(hill), at: CGPoint(x: frame.midX, y: frame.midY), in: &context)
            case .woods:
                context.fill(Path(roundedRect: frame, cornerRadius: min(frame.width, frame.height) / 2),
                             with: .color(woods.opacity(0.4)))
                context.draw(Text(Image(systemName: "tree.fill")).font(.caption).foregroundStyle(woods),
                             at: CGPoint(x: frame.midX, y: frame.midY))
            case .tree:
                let dot = CGRect(x: frame.midX - 5, y: frame.midY - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: dot), with: .color(woods.opacity(0.8)))
            case .wall:
                var path = Path()
                if frame.width >= frame.height {
                    path.move(to: CGPoint(x: frame.minX, y: frame.midY))
                    path.addLine(to: CGPoint(x: frame.maxX, y: frame.midY))
                } else {
                    path.move(to: CGPoint(x: frame.midX, y: frame.minY))
                    path.addLine(to: CGPoint(x: frame.midX, y: frame.maxY))
                }
                context.stroke(path, with: .color(Color.primary.opacity(0.55)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
        }

        // Map names, centred at the top of each sheet.
        for sheet in layout.sheets {
            let frame = rect(sheet.area)
            Self.drawLabel(
                Text(sheet.name).font(.caption2.weight(.semibold)).foregroundStyle(.secondary),
                at: CGPoint(x: frame.midX, y: frame.minY + 10),
                in: &context
            )
        }

        // Scale bar: 6 inches, bottom centre (clear of both setup zones).
        let bar = 6 * scale
        let y = layout.depth * scale - 8
        let x = (layout.width * scale - bar) / 2
        var scalePath = Path()
        scalePath.move(to: CGPoint(x: x, y: y))
        scalePath.addLine(to: CGPoint(x: x + bar, y: y))
        context.stroke(scalePath, with: .color(Color.primary.opacity(0.5)), lineWidth: 2)
        Self.drawLabel(Text("6″").font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: x + bar / 2, y: y - 8), in: &context)
    }

    /// Draws a label on a small pill so a mapsheet seam or terrain edge never runs through the letters
    /// (the seam between two maps crossed "Hill" and "6″").
    private static func drawLabel(_ text: Text, at point: CGPoint, in context: inout GraphicsContext) {
        let resolved = context.resolve(text)
        let size = resolved.measure(in: CGSize(width: 200, height: 50))
        let pill = CGRect(
            x: point.x - size.width / 2 - 4,
            y: point.y - size.height / 2 - 1,
            width: size.width + 8,
            height: size.height + 2
        )
        context.fill(Path(roundedRect: pill, cornerRadius: pill.height / 2), with: .color(Color(.systemBackground).opacity(0.85)))
        context.draw(resolved, at: point)
    }
}

/// The diagram in words, for VoiceOver and the printed guide.
enum MissionLayoutDescription {
    static func spoken(_ layout: MissionLayoutDTO) -> String {
        var parts = ["Table \(inches(layout.width)) by \(inches(layout.depth)) inches."]
        if !layout.sheets.isEmpty {
            parts.append("Maps, left to right: \(layout.sheetNames.joined(separator: ", ")).")
        }
        for zone in layout.zones {
            let edge = zone.area.x < layout.width / 2 ? "left" : "right"
            let depth = inches(zone.area.width)
            parts.append("Side \(zone.side) sets up within \(depth) inches of the \(edge) edge.")
        }
        let counts = Dictionary(grouping: layout.features, by: \.kind).mapValues(\.count)
        let terrain = MissionLayoutDTO.FeatureKind.allCases.compactMap { kind -> String? in
            guard let n = counts[kind], n > 0 else { return nil }
            switch kind {
            case .hill: return n == 1 ? "a hill in the middle" : "\(n) hills"
            case .woods: return n == 1 ? "one patch of woods" : "\(n) patches of woods"
            case .wall: return n == 1 ? "a low wall" : "\(n) low walls"
            case .tree: return n == 1 ? "a single tree" : "\(n) single trees"
            }
        }
        if !terrain.isEmpty {
            parts.append("Terrain: \(terrain.joined(separator: ", ")).")
        }
        return parts.joined(separator: " ")
    }

    private static func inches(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

/// "Maps needed": which mapsheets to lay out, whether the player has them, the open-table fallback,
/// and the diagram. Used by the mission sheet and the table setup step.
/// With a `missionId`, an experienced player can swap any sheet for a map they own; the choice is kept per mission.
struct MissionMapsSection: View {
    var layout: MissionLayoutDTO
    /// The player's maps; `nil` when they haven't told the app what they own.
    var ownedMaps: [String]?
    /// Scenario id. `nil` hides the swap controls (previews).
    var missionId: String? = nil

    @Environment(AppDependencies.self) private var dependencies
    @State private var swapping = false
    @State private var typingIndex: Int?
    @State private var typedName = ""

    private var chosen: [String]? { missionId.flatMap { dependencies.preferences.mapSwaps[$0] } }
    private var shown: MissionLayoutDTO { MapSwap.applying(chosen, to: layout) }
    private var isSwapped: Bool { shown.sheetNames != layout.sheetNames }

    private var missing: [String] {
        guard let ownedMaps else { return [] }
        let owned = Set(ownedMaps.map { $0.lowercased() })
        return shown.sheetNames.filter { !owned.contains($0.lowercased()) }
    }

    /// Maps the player has: from owned boxes and ones added by hand.
    private var collectionMaps: [String] {
        guard let owned = dependencies.preferences.collection else { return [] }
        return CollectionMath.ownedMaps(owned, boxes: dependencies.boxSets).map(\.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            if layout.sheets.isEmpty {
                Text(layout.openTable)
                    .font(TMFont.detail)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("\(CollectionMath.naturalList(shown.sheetNames)), side by side.")
                    .font(TMFont.detail.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("mission.maps.names")
                if isSwapped {
                    Text("Suggested: \(CollectionMath.naturalList(layout.sheetNames)).")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if ownedMaps != nil {
                    Label(
                        missing.isEmpty ? "You have these maps." : "You don’t have \(CollectionMath.naturalList(missing)).",
                        systemImage: missing.isEmpty ? "checkmark.circle.fill" : "map"
                    )
                    .font(TMFont.detail)
                    .foregroundStyle(missing.isEmpty ? TMColor.success : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Text(layout.openTable)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if missionId != nil {
                    swapControls
                }
            }
            MissionLayoutView(layout: shown)
            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mission.maps")
        .alert("Map name", isPresented: Binding(get: { typingIndex != nil }, set: { if !$0 { typingIndex = nil } })) {
            TextField("Map name", text: $typedName)
            Button("Use map") {
                if let index = typingIndex { choose(typedName, at: index) }
                typingIndex = nil
            }
            Button("Cancel", role: .cancel) { typingIndex = nil }
        }
    }

    private var footnote: String {
        if layout.sheets.isEmpty {
            return "Terrain spots are a guide. Place pieces as the setup steps say."
        }
        if isSwapped {
            return "The zones and terrain spots are a guide for the suggested maps. On your own maps, use their woods and hills and keep the setup zones."
        }
        return "On printed maps, use the map’s own woods and hills. The shapes show where to add terrain on an open table."
    }

    @ViewBuilder
    private var swapControls: some View {
        Button {
            swapping.toggle()
        } label: {
            Label(swapping ? "Done swapping" : "Swap a map", systemImage: "arrow.triangle.swap")
                .font(TMFont.detail.weight(.semibold))
                .frame(minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.borderless)
        .accessibilityHint("Use a map you own instead of a suggested one")
        .accessibilityIdentifier("mission.maps.swap")
        if swapping {
            ForEach(Array(shown.sheets.enumerated()), id: \.offset) { index, sheet in
                Menu {
                    ForEach(MapSwap.options(owned: collectionMaps, suggested: layout.sheets[index].name, current: sheet.name), id: \.self) { name in
                        Button {
                            choose(name, at: index)
                        } label: {
                            if name.lowercased() == sheet.name.lowercased() {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                    Button("Another map…") {
                        typedName = ""
                        typingIndex = index
                    }
                } label: {
                    HStack {
                        Text("\(Self.position(index, of: shown.sheets.count)): \(sheet.name)")
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: TMSpace.sm)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    .font(TMFont.detail)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(Self.position(index, of: shown.sheets.count)) map, \(sheet.name)")
                .accessibilityHint("Choose a different map")
                .accessibilityIdentifier("mission.maps.sheet.\(index)")
            }
            if isSwapped, let missionId {
                Button("Use the suggested maps") {
                    dependencies.preferences.useSuggestedMaps(mission: missionId)
                    dependencies.logger.info("map swap reset mission=\(missionId)", category: "maps")
                }
                .font(TMFont.detail.weight(.semibold))
                .buttonStyle(.borderless)
                .frame(minHeight: 44)
                .accessibilityIdentifier("mission.maps.reset")
            }
        }
    }

    private func choose(_ name: String, at index: Int) {
        guard let missionId else { return }
        dependencies.preferences.swapMap(mission: missionId, index: index, to: name, layout: layout)
        dependencies.logger.info("map swap mission=\(missionId) sheet=\(index)", category: "maps")
    }

    private static func position(_ index: Int, of count: Int) -> String {
        if count == 2 { return index == 0 ? "Left" : "Right" }
        return "Map \(index + 1)"
    }
}
