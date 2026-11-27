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

    /// "Close Quarters · Turn 1/8". Table setup and the result keep the plain mission name.
    static func navigationTitle(scenarioTitle: String, session: MatchSession, coach: BattleCoach) -> String {
        guard showsHeader(coach.step) else { return scenarioTitle }
        let turn = session.ruleset.maxTurns.map { "Turn \(session.turn)/\($0)" } ?? "Turn \(session.turn)"
        return "\(scenarioTitle) · \(turn)"
    }

    /// One key per game and step, so Brief coaching explains each step the first time it appears.
    static func coachKey(session: MatchSession, coach: BattleCoach) -> String {
        let step = coach.pendingCritical != nil ? "critical" : "\(coach.step)"
        return "\(session.id.uuidString)|\(step)"
    }

    /// Full the turn a step is first seen; after that Brief shows only the title and a "?".
    static func coachDisplay(level: CoachingLevel, scenario: ScenarioId?, firstSeenTurn: Int?, turn: Int) -> CoachDisplay {
        switch level.resolved(for: scenario) {
        case .automatic, .full:
            return .full
        case .off:
            return .off
        case .brief:
            guard let firstSeenTurn else { return .full }
            return firstSeenTurn == turn ? .full : .brief
        }
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
            return "Place the miniatures. \(session.displayName(of: session.otherSide(of: session.activeSide))) picks who places first."
        case .initiative:
            return "Turn \(session.turn), Roll."
        case .movement:
            return "Turn \(session.turn), Move. \(session.displayName(of: session.activeSide)) moves."
        case .combat:
            return "Turn \(session.turn), Shoot. Both sides shoot, in any order."
        case .end:
            return "Turn \(session.turn), Clean up."
        case .victory:
            return "Game over."
        }
    }
}

/// The battle header, folded down to one thin row under the nav bar: four step segments and the
/// current step's name. The turn moved into the nav title ("Close Quarters · Turn 1/8"); the old
/// TURN eyebrow, big numeral and progress ring took about a quarter of the screen. FUTURE-PLAN §1.3.
struct BattleStepStrip: View {
    var turn: Int
    var maxTurns: Int?
    var phase: PhaseId
    var activeSide: SideId?
    /// The session's name for the active side ("Side B" or the players' choice).
    var activeSideName: String?

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct Segment: Identifiable {
        var id: PhaseId
        var title: String
        var identifier: String
    }

    private static let segments: [Segment] = [
        Segment(id: .initiative, title: "Roll", identifier: "as.battle.phase.initiative"),
        Segment(id: .movement, title: "Move", identifier: "as.battle.phase.movement"),
        Segment(id: .combat, title: "Shoot", identifier: "as.battle.phase.combat"),
        Segment(id: .end, title: "Clean up", identifier: "as.battle.phase.end")
    ]

    private var currentIndex: Int {
        Self.segments.firstIndex { $0.id == phase } ?? 0
    }

    private var isLastTurn: Bool {
        guard let maxTurns else { return false }
        return turn >= maxTurns
    }

    var body: some View {
        HStack(alignment: .center, spacing: TMSpace.sm) {
            bar
            if let activeSide {
                SideBadge(side: activeSide)
                    .accessibilityLabel("Active side, \(activeSideName ?? activeSide.displayName)")
                    .accessibilityValue((activeSide ?? .lanceB).rawValue)
                    .accessibilityIdentifier("as.battle.activeSide")
            }
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
                .accessibilityHidden(true)
            if isLastTurn {
                StatusChip(kind: .lastTurn)
                    .fixedSize()
            }
        }
        // Chrome, not content: past AX2 the strip crowded out the step itself.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, verticalSizeClass == .compact ? TMSpace.xxs : TMSpace.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .tmAnimation(TMMotion.phase, value: phase)
    }

    private var bar: some View {
        HStack(spacing: 3) {
            ForEach(Array(Self.segments.enumerated()), id: \.element.id) { index, segment in
                Capsule()
                    .fill(fill(index))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    // One hidden element per step keeps the phase ids for UI tests and VoiceOver rotor.
                    .background {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityLabel(segment.title)
                            .accessibilityIdentifier(segment.identifier)
                            .accessibilityAddTraits(index == currentIndex ? .isSelected : [])
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier("as.battle.stepStrip")
    }

    /// Large text truncates the nav title before the turn, so the strip repeats it there.
    private var label: String {
        let step = Self.segments[currentIndex].title
        guard dynamicTypeSize.isAccessibilitySize else { return step }
        let turnText = maxTurns.map { "Turn \(turn)/\($0)" } ?? "Turn \(turn)"
        return "\(turnText) · \(step)"
    }

    private var spoken: String {
        let turnText = maxTurns.map { "Turn \(turn) of \($0)\(isLastTurn ? ", last turn" : "")" } ?? "Turn \(turn)"
        return "\(turnText). Step \(currentIndex + 1) of 4, \(Self.segments[currentIndex].title)"
    }

    private func fill(_ index: Int) -> Color {
        if index == currentIndex {
            // Movement belongs to one side, so its segment wears that side's colour.
            return activeSide.map(TMColor.side) ?? TMColor.signal
        }
        return index < currentIndex ? TMColor.signal.opacity(0.45) : Color.secondary.opacity(0.25)
    }
}

struct SidePassBanner: View {
    var side: SideId
    /// The session's name for the side.
    var name: String
    /// Who moves the side's next 'Mech on a team side (PlayModeSpec § 8.3). Nil = just the side.
    var controller: String?

    private var line: String {
        controller.map { "\(name) — \($0)’s turn. Pass the phone." } ?? "\(name)’s turn — pass the phone"
    }

    var body: some View {
        HStack(spacing: TMSpace.sm) {
            SideBadge(side: side)
            Text(line)
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
        .accessibilityLabel(controller.map { "\(name) — \($0)’s turn. Pass the phone." } ?? "\(name)’s turn. Pass the phone.")
    }
}

#if DEBUG
#Preview("Step strip") {
    PreviewPair {
        VStack(spacing: TMSpace.md) {
            BattleStepStrip(turn: 3, maxTurns: 6, phase: .combat, activeSide: nil)
            BattleStepStrip(turn: 6, maxTurns: 6, phase: .movement, activeSide: .lanceB)
        }
    }
}
#endif
