import SwiftUI

/// One stop on the training path.
struct MissionStop: Identifiable, Equatable {
    enum State: Equatable {
        case cleared
        /// The first mission not cleared yet. Gets the Up next card.
        case next
        /// Playable, but not the one the path points at.
        case open
        /// Coming soon: no pack yet.
        case locked
    }

    var id: String
    var number: Int
    var title: String
    var icon: String
    /// Rules this mission unlocks (the catalog's `introduces`).
    var unlocks: [String]
    var comingSoon: String?
    var state: State
    /// Section after the training path (the catalog's `stage`), shown instead of "Mission N".
    var stage: String? = nil

    /// "Mission 3", or the section name for book scenarios.
    var label: String { stage ?? "Mission \(number)" }

    var statusText: String {
        switch state {
        case .cleared: "Cleared"
        case .next: "Up next"
        case .open: "Ready"
        case .locked: "Coming soon"
        }
    }
}

/// Training path in the style of a lesson track: nodes snake down the screen and the line between them
/// fills in as missions are cleared. A trophy waits at the end.
struct MissionPathView<UpNext: View>: View {
    var stops: [MissionStop]
    /// The trophy at the end. Off for the sections after the training path.
    var showsFinish = true
    var onSelect: (MissionStop) -> Void
    @ViewBuilder var upNext: (MissionStop) -> UpNext

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static var finishID: String { "finish" }
    /// Where the line leaves a stop: under its label, or under the Up next card.
    private static func exit(_ id: String) -> String { "\(id).exit" }
    /// Where the line enters a stop: the top of its node.
    private static func entry(_ id: String) -> String { "\(id).entry" }

    var body: some View {
        VStack(spacing: 52) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                VStack(spacing: TMSpace.lg) {
                    // The exit anchor is taken before the snake's padding: after it, the padded frame's
                    // bottom-centre is the screen centre, so a line left an off-centre stop from mid-screen.
                    stopView(stop)
                        .transformAnchorPreference(key: PathNodeKey.self, value: .bottom) { $0[Self.exit(stop.id)] = $1 }
                        .padding(.leading, max(0, shift(index)) * 2)
                        .padding(.trailing, max(0, -shift(index)) * 2)
                    if stop.state == .next {
                        upNext(stop)
                            .transformAnchorPreference(key: PathNodeKey.self, value: .bottom) { $0[Self.exit(stop.id)] = $1 }
                    }
                }
            }
            if showsFinish {
                finish
            }
        }
        .frame(maxWidth: .infinity)
        .backgroundPreferenceValue(PathNodeKey.self) { anchors in
            GeometryReader { proxy in
                connectors(anchors: anchors, in: proxy)
            }
            .accessibilityHidden(true)
        }
    }

    /// Sideways offset for the snake: centre, right, centre, left. Straight line at accessibility sizes.
    private func shift(_ index: Int) -> CGFloat {
        guard !dynamicTypeSize.isAccessibilitySize else { return 0 }
        let pattern: [CGFloat] = [0, 1, 0, -1]
        return pattern[index % pattern.count] * 56
    }

    private func stopView(_ stop: MissionStop) -> some View {
        VStack(spacing: TMSpace.sm) {
            if stop.state == .next {
                UpNextTag()
                    .anchorPreference(key: PathNodeKey.self, value: .top) { [Self.entry(stop.id): $0] }
            }
            Button {
                onSelect(stop)
            } label: {
                MissionNode(stop: stop)
            }
            .buttonStyle(NodePressStyle())
            .transformAnchorPreference(key: PathNodeKey.self, value: .top) { value, anchor in
                // The current stop's line ends at its START tag instead.
                if stop.state != .next { value[Self.entry(stop.id)] = anchor }
            }
            .accessibilityLabel(spokenLabel(stop))
            .accessibilityHint(nodeHint(stop))
            .accessibilityIdentifier("as.modeHome.ladder.\(stop.id)")
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: TMSpace.xs) {
                    stopLabel(stop)
                    infoButton(stop)
                }
            } else {
                HStack(spacing: TMSpace.xs) {
                    // Balances the info button so the title stays centred under the node.
                    Color.clear.frame(width: 44, height: 1)
                        .accessibilityHidden(true)
                    stopLabel(stop)
                    infoButton(stop)
                }
            }
        }
    }

    private func stopLabel(_ stop: MissionStop) -> some View {
        VStack(spacing: TMSpace.xxs) {
            Text(stop.title)
                .font(TMFont.cardTitle)
                .foregroundStyle(stop.state == .locked ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
            if stop.state == .cleared {
                // Cleared missions stay replayable; replaying never un-clears them.
                Label("Cleared · Replay", systemImage: "arrow.counterclockwise")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TMColor.signal)
            } else {
                Text(stop.state == .next ? stop.label : stop.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 200)
        .accessibilityHidden(true)
    }

    /// "What you'll learn" button beside every stop's label. Opens the same mission sheet as the node.
    private func infoButton(_ stop: MissionStop) -> some View {
        Button {
            onSelect(stop)
        } label: {
            Image(systemName: "list.bullet.clipboard")
                .font(.body.weight(.semibold))
                .foregroundStyle(stop.state == .locked ? AnyShapeStyle(.secondary) : AnyShapeStyle(TMColor.signal))
                .frame(width: 44, height: 44)
                .background(TMColor.signal.opacity(stop.state == .locked ? 0.06 : 0.12), in: Circle().inset(by: 4))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("What you’ll learn in \(stop.title)")
        .accessibilityHint("Shows the objective, new rules, and tips")
        .accessibilityIdentifier("as.modeHome.ladder.info.\(stop.id)")
    }

    private func nodeHint(_ stop: MissionStop) -> String {
        switch stop.state {
        case .locked: "Shows what’s coming"
        case .cleared: "Shows the mission. You can play it again"
        case .open: "Shows the mission. You can skip ahead to it"
        case .next: "Shows the mission"
        }
    }

    private func spokenLabel(_ stop: MissionStop) -> String {
        var parts = ["\(stop.label), \(stop.title)", stop.statusText]
        if !stop.unlocks.isEmpty {
            parts.append("Unlocks \(stop.unlocks.joined(separator: ", "))")
        }
        return parts.joined(separator: ". ")
    }

    private var allCleared: Bool {
        !stops.isEmpty && stops.allSatisfy { $0.state == .cleared }
    }

    private var finish: some View {
        VStack(spacing: TMSpace.sm) {
            ZStack {
                Circle()
                    .fill(allCleared ? TMColor.signal : TMColor.readout)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(allCleared ? AnyShapeStyle(TMColor.onSignal) : AnyShapeStyle(.tertiary))
            }
            .frame(width: 64, height: 64)
            .anchorPreference(key: PathNodeKey.self, value: .top) { [Self.entry(Self.finishID): $0] }
            VStack(spacing: TMSpace.xxs) {
                Text("Trained pilot")
                    .font(TMFont.cardTitle)
                    .foregroundStyle(allCleared ? .primary : .secondary)
                Text(allCleared ? "Every mission cleared" : "Clear every mission")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, TMSpace.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("as.modeHome.ladder.finish")
    }

    /// Curved segments from under one stop to the top of the next, so the line never crosses a label:
    /// solid once the earlier mission is cleared, dotted otherwise.
    @ViewBuilder
    private func connectors(anchors: [String: Anchor<CGPoint>], in proxy: GeometryProxy) -> some View {
        let ids = stops.map(\.id) + (showsFinish ? [Self.finishID] : [])
        ForEach(Array(zip(ids, ids.dropFirst())), id: \.0) { from, to in
            if let a = anchors[Self.exit(from)], let b = anchors[Self.entry(to)] {
                let start = proxy[a].applying(CGAffineTransform(translationX: 0, y: TMSpace.xs))
                let end = proxy[b].applying(CGAffineTransform(translationX: 0, y: -TMSpace.xs))
                let cleared = stops.first { $0.id == from }?.state == .cleared
                Path { path in
                    path.move(to: start)
                    let midY = (start.y + end.y) / 2
                    path.addCurve(
                        to: end,
                        control1: CGPoint(x: start.x, y: midY),
                        control2: CGPoint(x: end.x, y: midY)
                    )
                }
                .stroke(
                    cleared ? AnyShapeStyle(TMColor.signal) : AnyShapeStyle(TMColor.readout),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: cleared ? [] : [0.1, 16])
                )
            }
        }
    }
}

/// A raised round button: coloured face over a darker lip, like a pressable token.
struct MissionNode: View {
    var stop: MissionStop

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var diameter: CGFloat { stop.state == .next ? 84 : 70 }
    private static let lip: CGFloat = 6

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(face.mix(with: .black, by: 0.32))
                .frame(width: diameter, height: diameter)
                .offset(y: Self.lip)
            Circle()
                .fill(face)
                .frame(width: diameter, height: diameter)
                .overlay {
                    if stop.state == .open {
                        Circle().strokeBorder(TMColor.signal.opacity(0.7), lineWidth: 3)
                    }
                }
                .overlay {
                    Image(systemName: stop.state == .locked ? "lock.fill" : stop.icon)
                        .font(.system(size: diameter * 0.36, weight: .bold))
                        .foregroundStyle(iconStyle)
                }
        }
        .frame(width: diameter, height: diameter + Self.lip, alignment: .top)
        .background(alignment: .top) {
            if stop.state == .next {
                // Glow centred on the face (not the lip): a filled, blurred disc that
                // runs under the face edge, so there is no dark gap or halo.
                Circle()
                    .fill(TMColor.signal.opacity(0.4))
                    .frame(width: diameter + 12, height: diameter + 12)
                    .blur(radius: 5)
                    .offset(y: -6)
                    .scaleEffect(pulse ? 1.22 : 1)
                    .opacity(pulse ? 0 : 1)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if stop.state == .cleared {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(TMColor.onSignal, TMColor.success)
                    .background(Circle().fill(Color(.systemBackground)).padding(2))
                    .offset(x: 4, y: 2)
            }
        }
        .onAppear {
            guard stop.state == .next, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    private var face: Color {
        switch stop.state {
        case .cleared, .next: TMColor.signal
        case .open: TMColor.surfaceCardRaised
        case .locked: TMColor.readout
        }
    }

    private var iconStyle: AnyShapeStyle {
        switch stop.state {
        case .cleared, .next: AnyShapeStyle(TMColor.onSignal)
        case .open: AnyShapeStyle(TMColor.signal)
        case .locked: AnyShapeStyle(.tertiary)
        }
    }
}

/// Small bobbing "Start" flag above the current node.
private struct UpNextTag: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        Text("START")
            .font(.caption.weight(.heavy))
            .tracking(1)
            .foregroundStyle(TMColor.signal)
            .padding(.horizontal, TMSpace.md)
            .padding(.vertical, TMSpace.xs)
            .background(TMColor.surfaceCardRaised, in: Capsule())
            .overlay(Capsule().strokeBorder(TMColor.signal.opacity(0.5), lineWidth: 1.5))
            .offset(y: bob ? -3 : 0)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    bob = true
                }
            }
    }
}

/// Presses the node down onto its lip.
private struct NodePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

private struct PathNodeKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGPoint>] = [:]
    static func reduce(value: inout [String: Anchor<CGPoint>], nextValue: () -> [String: Anchor<CGPoint>]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Header above the path: title plus a segmented progress bar.
struct MissionPathHeader: View {
    var cleared: Int
    var total: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Alpha Strike training")
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    title
                    count
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    title
                    Spacer(minLength: TMSpace.sm)
                    count
                }
            }
            HStack(spacing: TMSpace.xs) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < cleared ? TMColor.signal : TMColor.readout)
                        .frame(height: 8)
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("as.modeHome.ladder.progress")
    }

    private var title: some View {
        Text("Mission path")
            .font(TMFont.stepTitle)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var count: some View {
        Text("\(cleared) of \(total) cleared")
            .font(TMFont.stat)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Wrapping row layout that can centre each row (FlowLayout only leading-aligns).
private struct CenteredWrap: Layout {
    var spacing: CGFloat
    var centered: Bool

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [[(index: Int, size: CGSize)]] {
        var result: [[(index: Int, size: CGSize)]] = [[]]
        var width: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let next = result[result.count - 1].isEmpty ? size.width : width + spacing + size.width
            if !result[result.count - 1].isEmpty, next > maxWidth {
                result.append([(index, size)])
                width = size.width
            } else {
                result[result.count - 1].append((index, size))
                width = next
            }
        }
        return result
    }

    private func rowWidth(_ row: [(index: Int, size: CGSize)]) -> CGFloat {
        row.reduce(0) { $0 + $1.size.width } + spacing * CGFloat(max(row.count - 1, 0))
    }

    private func rowHeight(_ row: [(index: Int, size: CGSize)]) -> CGFloat {
        row.map(\.size.height).max() ?? 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map(rowWidth).max() ?? 0
        let height = rows.reduce(0) { $0 + rowHeight($1) } + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX + (centered ? max(bounds.width - rowWidth(row), 0) / 2 : 0)
            for item in row {
                subviews[item.index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += rowHeight(row) + spacing
        }
    }
}

/// "What you get" chips: the rules a mission unlocks.
struct UnlockChips: View {
    var rules: [String]
    /// Centre every wrapped row (for centred cards).
    var centered = false

    var body: some View {
        CenteredWrap(spacing: TMSpace.xs, centered: centered) {
            ForEach(rules, id: \.self) { rule in
                Label(rule, systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, TMSpace.sm)
                    .padding(.vertical, TMSpace.xs)
                    .background(TMColor.signal.opacity(0.16), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unlocks \(rules.joined(separator: ", "))")
    }
}

#if DEBUG
#Preview("Mission path") {
    ScrollView {
        VStack(spacing: TMSpace.xl) {
            MissionPathHeader(cleared: 2, total: 5)
            MissionPathView(
                stops: [
                    MissionStop(id: "a", number: 1, title: "Ridge Line", icon: "scope", unlocks: ["Moving", "Shooting"], state: .cleared),
                    MissionStop(id: "b", number: 2, title: "Broken Ground", icon: "mountain.2.fill", unlocks: ["Hills"], state: .cleared),
                    MissionStop(id: "c", number: 3, title: "Running Hot", icon: "flame.fill", unlocks: ["Overheat", "Shutdown"], state: .next),
                    MissionStop(id: "d", number: 4, title: "Close Quarters", icon: "hand.raised.fill", unlocks: ["Physical attacks"], state: .locked),
                    MissionStop(id: "e", number: 5, title: "Full Lances", icon: "shield.lefthalf.filled", unlocks: ["Forced Withdrawal"], state: .locked)
                ],
                onSelect: { _ in },
                upNext: { stop in
                    TMCard { Text("Up next: \(stop.title)") }
                }
            )
        }
        .padding()
    }
}
#endif
