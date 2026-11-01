import SwiftUI

struct PipTrack: View {
    enum Kind: Sendable {
        case armor
        case structure

        var label: String {
            switch self {
            case .armor: "Armor"
            case .structure: "Structure"
            }
        }

        var fill: Color {
            switch self {
            case .armor: TMColor.pipArmor
            case .structure: TMColor.pipStructure
            }
        }
    }

    enum Size: Sendable {
        case compact
        case regular
        case large

        var width: CGFloat {
            switch self {
            case .compact: 10
            case .regular: 14
            case .large: 20
            }
        }

        var height: CGFloat {
            switch self {
            case .compact: 14
            case .regular: 18
            case .large: 26
            }
        }
    }

    var remaining: Int
    var capacity: Int
    var kind: Kind
    var size: Size = .regular
    var showsCount: Bool = true
    var accessibilityIdentifier: String?
    var accessibilityName: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flashing: Set<Int> = []

    var body: some View {
        let shown = clampedRemaining
        FlowLayout(spacing: TMSpace.xs) {
            if capacity <= 0 {
                Text("—")
                    .font(TMFont.stat)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(0..<capacity, id: \.self) { index in
                    pip(at: index, remaining: shown)
                        .animation(
                            reduceMotion ? nil : TMMotion.drain.delay(Double(index) * TMMotion.pipStagger),
                            value: remaining
                        )
                }
            }
            if showsCount, capacity > 0 {
                Text("\(shown)/\(capacity)")
                    .font(TMFont.stat)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName ?? kind.label)
        .accessibilityValue("\(shown) of \(capacity)")
        .accessibilityID(accessibilityIdentifier)
        .onChange(of: remaining) { old, new in
            guard new < old, !reduceMotion else { return }
            let upper = min(old, capacity)
            let lower = max(new, 0)
            guard lower < upper else { return }
            let lost = Set(lower..<upper)
            flashing.formUnion(lost)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(TMMotion.drainDuration))
                flashing.subtract(lost)
            }
        }
    }

    private var clampedRemaining: Int {
        min(max(remaining, 0), max(capacity, 0))
    }

    private func pip(at index: Int, remaining: Int) -> some View {
        let filled = index < remaining
        let isFlashing = flashing.contains(index)
        return ZStack {
            if filled || isFlashing {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isFlashing && !filled ? TMColor.damage : kind.fill)
            } else {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(TMColor.pipLost, lineWidth: 1.5)
                LostPipStrike()
                    .stroke(TMColor.pipLost, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }
}

private struct LostPipStrike: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY - rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.2))
        return path
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Item {
        var index: Int
        var size: CGSize
    }

    private struct Row {
        var items: [Item]
        var width: CGFloat
        var height: CGFloat
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var result: [Row] = []
        var items: [Item] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = items.isEmpty ? size.width : rowWidth + spacing + size.width
            if !items.isEmpty, nextWidth > maxWidth {
                result.append(Row(items: items, width: rowWidth, height: rowHeight))
                items = [Item(index: index, size: size)]
                rowWidth = size.width
                rowHeight = size.height
            } else {
                items.append(Item(index: index, size: size))
                rowWidth = nextWidth
                rowHeight = max(rowHeight, size.height)
            }
        }
        if !items.isEmpty {
            result.append(Row(items: items, width: rowWidth, height: rowHeight))
        }
        return result
    }
}

#if DEBUG
#Preview("Pips") {
    PreviewPair {
        PipTrackPreviewHost()
    }
}

#Preview("Pips AX5") {
    PipTrackPreviewHost()
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct PipTrackPreviewHost: View {
    @State private var armor = 3

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            PipTrack(remaining: armor, capacity: 8, kind: .armor, size: .regular, accessibilityIdentifier: "preview.armor")
            PipTrack(remaining: 2, capacity: 3, kind: .structure, size: .large)
            Button("Lose armor") { armor = max(0, armor - 1) }
                .buttonStyle(.bordered)
        }
    }
}
#endif
