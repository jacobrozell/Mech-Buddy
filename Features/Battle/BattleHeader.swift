import SwiftUI
import MechBuddyDomain

enum BattleChrome {
    static func showsHeader(_ step: BattleCoach.Step) -> Bool {
        step != .tableSetup && step != .victory
    }

    static func showsActiveSide(_ step: BattleCoach.Step) -> Bool {
        // Only movement has one side up. Both sides shoot in any order, and both place miniatures in turns
        // (the roll winner picks who starts), so "Side B is up" there was wrong.
        step == .movement
    }

    static func dockTint(session: MatchSession, coach: BattleCoach) -> Color {
        if coach.pendingCritical != nil {
            return TMColor.warning
        }
        switch coach.step {
        case .movement:
            if coach.movementComplete {
                return TMColor.signal
            }
            return TMColor.side(session.activeSide)
        case .placeMiniatures, .combat, .initiative, .end, .tableSetup, .victory:
            return TMColor.signal
        }
    }

    static func announcement(session: MatchSession, coach: BattleCoach) -> String {
        if let owed = coach.pendingCritical {
            let waiting = owed.count > 1 ? " \(owed.count) criticals are waiting." : ""
            return "Critical hit. \(owed.unitName) took a serious hit.\(waiting)"
        }
        switch coach.step {
        case .tableSetup:
            return "Set the table."
        case .placeMiniatures:
            return "Place the miniatures. \(session.activeSide.other.displayName) picks who places first."
        case .initiative:
            return "Turn \(session.turn), Roll."
        case .movement:
            return "Turn \(session.turn), Move. \(session.activeSide.displayName) moves."
        case .combat:
            return "Turn \(session.turn), Shoot. Both sides shoot, in any order."
        case .end:
            return "Turn \(session.turn), Clean up."
        case .victory:
            return "Game over."
        }
    }
}

struct BattleHeader: View {
    var turn: Int
    var maxTurns: Int?
    var phase: PhaseId
    var activeSide: SideId?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                compactHeight
            } else if dynamicTypeSize.isAccessibilitySize {
                accessible
                    // Chrome, not content: past AX2 the header crowded out the step itself.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            } else if sizeClass == .compact {
                stacked
            } else {
                horizontal
            }
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, verticalSizeClass == .compact ? TMSpace.xxs : TMSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var compactHeight: some View {
        HStack(alignment: .center, spacing: TMSpace.sm) {
            TurnCounter(turn: turn, maxTurns: maxTurns)
            Spacer(minLength: TMSpace.sm)
            PhaseTrack(current: phase, isCompact: true)
            if let activeSide {
                // One line in landscape: every point of height goes to the step content.
                SideTag(side: activeSide)
                    .accessibilityLabel("Active side, \(activeSide.displayName)")
                    .accessibilityIdentifier("as.battle.activeSide")
            }
        }
    }

    /// Accessibility sizes: "Turn 1 / 8" and the side on one line, the step label under it, both small.
    private var accessible: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
                TurnCounter(turn: turn, maxTurns: maxTurns, isInline: true)
                Spacer(minLength: TMSpace.sm)
                if let activeSide {
                    SideTag(side: activeSide)
                        .accessibilityLabel("Active side, \(activeSide.displayName)")
                        .accessibilityValue(activeSide == .lanceA ? "lanceA" : "lanceB")
                        .accessibilityIdentifier("as.battle.activeSide")
                }
            }
            PhaseTrack(current: phase, isCompact: true)
        }
    }

    private var horizontal: some View {
        HStack(alignment: .center, spacing: TMSpace.md) {
            TurnCounter(turn: turn, maxTurns: maxTurns)
            Spacer(minLength: TMSpace.sm)
            PhaseTrack(current: phase, isCompact: true)
            if let activeSide {
                sideMark(activeSide)
            }
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            HStack(alignment: .center, spacing: TMSpace.md) {
                TurnCounter(turn: turn, maxTurns: maxTurns)
                Spacer(minLength: TMSpace.sm)
                if let activeSide {
                    sideMark(activeSide)
                }
            }
            PhaseTrack(current: phase)
        }
    }

    private func sideMark(_ side: SideId) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            SideTag(side: side)
            Text("is up")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active side, \(side.displayName)")
        .accessibilityValue(side == .lanceA ? "lanceA" : "lanceB")
        .accessibilityIdentifier("as.battle.activeSide")
    }
}

struct SidePassBanner: View {
    var side: SideId

    var body: some View {
        HStack(spacing: TMSpace.sm) {
            SideBadge(side: side)
            Text("\(side.displayName)’s turn — pass the phone")
                .font(TMFont.cardTitle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, TMSpace.sm)
        // Opaque: the pill floats over the step title, which used to show through it.
        .background(TMColor.sideFill(side), in: Capsule())
        .background(Color(.systemBackground), in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .padding(.horizontal, TMSpace.lg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("\(side.displayName)’s turn. Pass the phone.")
    }
}

#if DEBUG
#Preview("Battle header") {
    PreviewPair {
        BattleHeader(turn: 3, maxTurns: 6, phase: .combat, activeSide: .lanceA)
    }
}
#endif
