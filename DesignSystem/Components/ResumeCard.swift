import SwiftUI
import MechBuddyDomain

struct ResumeCard: View {
    var title: String
    var turn: Int
    var maxTurns: Int?
    var phase: PhaseId
    var sideAStructureRemaining: Int
    var sideAStructureCapacity: Int
    var sideBStructureRemaining: Int
    var sideBStructureCapacity: Int
    var continueIdentifier: String? = "as.modeHome.resume"
    var onContinue: () -> Void

    var body: some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                Eyebrow("In progress")
                Text(title)
                    .font(TMFont.stepTitle)
                TurnCounter(turn: turn, maxTurns: maxTurns)
                PhaseTrack(current: phase, identifiesPhases: false, isCompact: true)
                structureBar(
                    side: .lanceA,
                    remaining: sideAStructureRemaining,
                    capacity: sideAStructureCapacity
                )
                structureBar(
                    side: .lanceB,
                    remaining: sideBStructureRemaining,
                    capacity: sideBStructureCapacity
                )
                PrimaryActionButton(
                    title: "Continue",
                    tint: TMColor.signal,
                    accessibilityIdentifier: continueIdentifier,
                    spokenLabel: continueSpoken,
                    action: onContinue
                )
            }
        }
    }

    private func structureBar(side: SideId, remaining: Int, capacity: Int) -> some View {
        let fraction = capacity > 0 ? CGFloat(remaining) / CGFloat(capacity) : 0
        return HStack(spacing: TMSpace.sm) {
            SideBadge(side: side)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TMColor.pipEmpty)
                    Capsule()
                        .fill(TMColor.side(side))
                        .frame(width: max(0, geo.size.width * min(1, fraction)))
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(side.displayName) structure \(remaining) of \(capacity)")
    }

    private var continueSpoken: String {
        let step: String
        switch phase {
        case .initiative: step = "Roll step"
        case .movement: step = "Move step"
        case .combat: step = "Shoot step"
        case .end: step = "Clean up step"
        }
        if let maxTurns {
            return "Continue \(title), turn \(turn) of \(maxTurns), \(step)"
        }
        return "Continue \(title), turn \(turn), \(step)"
    }
}

#if DEBUG
#Preview("Resume") {
    PreviewPair {
        ResumeCard(
            title: "Ridge Line",
            turn: 3,
            maxTurns: 6,
            phase: .combat,
            sideAStructureRemaining: 8,
            sideAStructureCapacity: 10,
            sideBStructureRemaining: 4,
            sideBStructureCapacity: 10,
            onContinue: {}
        )
    }
}
#endif
