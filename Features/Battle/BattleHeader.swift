import SwiftUI
import MechBuddyDomain

enum BattleChrome {
    static func showsHeader(_ step: BattleCoach.Step) -> Bool {
        step != .tableSetup && step != .victory
    }

    static func showsActiveSide(_ step: BattleCoach.Step) -> Bool {
        step == .placeMiniatures || step == .movement || step == .combat
    }

    static func dockTint(session: MatchSession, coach: BattleCoach) -> Color {
        if coach.pendingCritical != nil {
            return TMColor.warning
        }
        switch coach.step {
        case .placeMiniatures, .combat:
            return TMColor.side(session.activeSide)
        case .movement:
            if coach.movementComplete {
                let shooter = session.initiativeWinner?.other ?? session.activeSide
                return TMColor.side(shooter)
            }
            return TMColor.side(session.activeSide)
        case .initiative, .end, .tableSetup, .victory:
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
            return "Place the miniatures. \(session.activeSide.displayName) places first."
        case .initiative:
            return "Turn \(session.turn), Roll."
        case .movement:
            return "Turn \(session.turn), Move. \(session.activeSide.displayName) moves."
        case .combat:
            return "Turn \(session.turn), Shoot. \(session.activeSide.displayName) shoots."
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
            } else if dynamicTypeSize.isAccessibilitySize || sizeClass == .compact {
                stacked
            } else {
                horizontal
            }
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, TMSpace.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }

    private var compactHeight: some View {
        HStack(alignment: .center, spacing: TMSpace.sm) {
            TurnCounter(turn: turn, maxTurns: maxTurns)
            Spacer(minLength: TMSpace.sm)
            PhaseTrack(current: phase, isCompact: true)
            if let activeSide {
                sideMark(activeSide)
            }
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
        .background(TMColor.sideFill(side), in: Capsule())
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
