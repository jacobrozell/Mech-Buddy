import SwiftUI
import MechBuddyData
import MechBuddyDomain

// Top-down table diagram for a mission, like the scenario map layouts in A Game of Armored Combat:
// mapsheets, each side's setup zone, and suggested terrain. Spec: specs/features/GuidedMissionSpec.md § Maps.

struct MissionLayoutView: View {
    var board: BoardLayout
    @Environment(\.colorSchemeContrast) private var contrast

    init(layout: MissionLayoutDTO) {
        board = BoardLayout(layout)
    }

    /// A board, with zones already chosen for the game (`PlayLayout.board(for:sides:)`).
    init(board: BoardLayout) {
        self.board = board
    }

    private var aspect: CGFloat { CGFloat(board.width / max(board.depth, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(TMColor.readout, in: RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous))
            HStack(spacing: TMSpace.md) {
                ForEach(board.zones.map(\.side), id: \.self) { letter in
                    legendItem(color: Self.color(forZone: letter), text: "Side \(letter) sets up")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MissionLayoutDescription.spoken(board))
        .accessibilityIdentifier("mission.layout")
    }

    /// Zones name their side by letter ("A" to "D").
    static func color(forZone letter: String) -> Color { BoardDrawing.color(forZone: letter) }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: TMSpace.xs) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.45)).frame(width: 14, height: 10)
            Text(text)
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let scale = min(size.width / board.width, size.height / board.depth)
        BoardDrawing.drawTable(
            board,
            zones: board.zones,
            in: &context,
            frame: .init(scale: scale),
            highContrast: contrast == .increased
        )

        // Scale bar: 6 inches, bottom centre (clear of both setup zones).
        let bar = 6 * scale
        let y = board.depth * scale - 8
        // Three or four zones: the bottom edge may hold one, so the bar moves to the corner (zones there are narrow).
        let x = board.zones.count > 2 ? 8 : (board.width * scale - bar) / 2
        var scalePath = Path()
        scalePath.move(to: CGPoint(x: x, y: y))
        scalePath.addLine(to: CGPoint(x: x + bar, y: y))
        context.stroke(scalePath, with: .color(Color.primary.opacity(0.5)), lineWidth: 2)
        BoardDrawing.drawLabel(Text("6″").font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: x + bar / 2, y: y - 8), in: &context)
    }
}

/// The diagram in words, for VoiceOver and the printed guide.
enum MissionLayoutDescription {
    static func spoken(_ layout: MissionLayoutDTO) -> String {
        spoken(BoardLayout(layout))
    }

    static func spoken(_ layout: BoardLayout) -> String {
        var parts = ["Table \(inches(layout.width)) by \(inches(layout.depth)) inches."]
        if !layout.sheets.isEmpty {
            parts.append("Maps, left to right: \(layout.sheets.map(\.name).joined(separator: ", ")).")
        }
        for zone in layout.zones {
            let vertical = zone.area.depth > zone.area.width
            let edge: String
            if vertical {
                edge = zone.area.x < layout.width / 2 ? "left" : "right"
            } else {
                edge = zone.area.y < layout.depth / 2 ? "top" : "bottom"
            }
            let depth = inches(vertical ? zone.area.width : zone.area.depth)
            parts.append("Side \(zone.side) sets up within \(depth) inches of the \(edge) edge.")
        }
        let counts = Dictionary(grouping: layout.features, by: \.kind).mapValues(\.count)
        let terrain = BoardLayout.FeatureKind.allCases.compactMap { kind -> String? in
            guard let n = counts[kind], n > 0 else { return nil }
            switch kind {
            case .hill: return n == 1 ? "a hill in the middle" : "\(n) hills"
            case .woods: return n == 1 ? "one patch of woods" : "\(n) patches of woods"
            case .wall: return n == 1 ? "a low wall" : "\(n) low walls"
            case .tree: return n == 1 ? "a single tree" : "\(n) single trees"
            case .building: return n == 1 ? "a building" : "\(n) buildings"
            case .water: return n == 1 ? "a water feature" : "\(n) water features"
            case .rough: return n == 1 ? "a patch of rough ground" : "\(n) patches of rough ground"
            case .rubble: return n == 1 ? "a patch of rubble" : "\(n) patches of rubble"
            case .objectiveToken: return n == 1 ? "an objective marker" : "\(n) objective markers"
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
