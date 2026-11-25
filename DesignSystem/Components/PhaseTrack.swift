import SwiftUI
import MechBuddyDomain

struct PhaseTrack: View {
    var current: PhaseId
    var identifiesPhases: Bool = true
    var isCompact: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private struct Segment: Identifiable {
        var id: PhaseId
        var title: String
        var icon: String
        var identifier: String
    }

    private let segments: [Segment] = [
        Segment(id: .initiative, title: "Roll", icon: "dice", identifier: "as.battle.phase.initiative"),
        Segment(id: .movement, title: "Move", icon: "figure.walk", identifier: "as.battle.phase.movement"),
        Segment(id: .combat, title: "Shoot", icon: "scope", identifier: "as.battle.phase.combat"),
        Segment(id: .end, title: "Clean up", icon: "checklist", identifier: "as.battle.phase.end")
    ]

    var body: some View {
        // Phones: the four chips wrapped mid-word ("Shoo/t", "Clea/n up"). The one-line summary reads cleanly.
        if dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact || UIDevice.current.userInterfaceIdiom == .phone {
            accessibleSummary
        } else {
            track
        }
    }

    private var accessibleSummary: some View {
        let index = (PhaseId.allCases.firstIndex(of: current) ?? 0) + 1
        let name = segments.first { $0.id == current }?.title ?? ""
        return VStack(alignment: .leading, spacing: TMSpace.xs) {
            // Non-breaking spaces keep "3 of 4 ·" together when it wraps at large text.
            Text("Step \(index)\u{00A0}of\u{00A0}4\u{00A0}· \(name)")
                .font(isCompact ? TMFont.detail.weight(.semibold) : TMFont.cardTitle)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 0) {
                ForEach(segments) { segment in
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityLabel(segment.title)
                        .accessibilityID(identifiesPhases ? segment.identifier : nil)
                        .accessibilityAddTraits(segment.id == current ? .isSelected : [])
                }
            }
        }
    }

    private var track: some View {
        HStack(spacing: TMSpace.xs) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                if index > 0 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(height: 1)
                        .frame(maxWidth: isCompact ? 8 : 16)
                        .accessibilityHidden(true)
                }
                segmentView(segment)
            }
        }
        .tmAnimation(TMMotion.phase, value: current)
    }

    private func segmentView(_ segment: Segment) -> some View {
        let state = phaseState(segment.id)
        return HStack(spacing: TMSpace.xs) {
            Image(systemName: state == .done ? "checkmark" : segment.icon)
            if !isCompact || state == .current {
                Text(segment.title)
            }
        }
        .font(isCompact ? .caption.weight(state == .current ? .bold : .semibold) : .subheadline.weight(state == .current ? .bold : .semibold))
        .foregroundStyle(foreground(state))
        .padding(.horizontal, isCompact ? TMSpace.xs : TMSpace.sm)
        .padding(.vertical, TMSpace.xs)
        .background {
            if state == .current {
                Capsule().fill(TMColor.signal)
            } else if state == .upcoming {
                Capsule().strokeBorder(Color.secondary.opacity(0.45), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(segment.title)
        .accessibilityID(identifiesPhases ? segment.identifier : nil)
        .accessibilityAddTraits(state == .current ? .isSelected : [])
    }

    private enum PhaseState {
        case done
        case current
        case upcoming
    }

    private func phaseState(_ phase: PhaseId) -> PhaseState {
        let order = Array(PhaseId.allCases)
        let index = order.firstIndex(of: phase) ?? 0
        let currentIndex = order.firstIndex(of: current) ?? 0
        if index < currentIndex { return .done }
        if index == currentIndex { return .current }
        return .upcoming
    }

    private func foreground(_ state: PhaseState) -> Color {
        switch state {
        case .current:
            TMColor.onSignal
        case .done, .upcoming:
            Color.secondary
        }
    }
}

#if DEBUG
#Preview("Phase track") {
    PreviewPair {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            PhaseTrack(current: .combat)
            PhaseTrack(current: .movement, identifiesPhases: false, isCompact: true)
        }
    }
}

#Preview("Phase track AX5") {
    PhaseTrack(current: .combat)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}
#endif
