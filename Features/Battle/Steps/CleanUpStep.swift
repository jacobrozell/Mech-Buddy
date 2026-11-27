import SwiftUI
import MechBuddyDomain

struct CleanUpStep: View {
    var session: MatchSession
    var coach: BattleCoach
    var showsUnits: Bool = true
    var onOpenUnit: (MatchUnitState) -> Void

    @State private var pickedUp: Set<UUID> = []

    private var wrecks: [MatchUnitState] {
        session.units.filter { $0.combatStatus == .destroyedPendingEnd }
    }

    private var standing: [MatchUnitState] {
        session.units.filter { $0.combatStatus == .active }
    }

    /// Forced Withdrawal: crippled this turn. Next turn they head for their own edge.
    private var crippled: [MatchUnitState] {
        session.newlyCrippled
    }

    private var message: String {
        if !wrecks.isEmpty {
            return "Take wrecked ’Mechs off the table."
        }
        if !crippled.isEmpty {
            return "Nothing was wrecked this turn. Crippled ’Mechs start to withdraw. Tap Next turn."
        }
        return "Nothing was wrecked this turn. Tap Next turn."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            CoachPrompt(
                title: "Clean up",
                message: message,
                accessibilityIdentifier: "as.battle.table"
            )
            if !wrecks.isEmpty {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    Eyebrow("Remove from the table")
                    ForEach(wrecks) { unit in
                        VStack(alignment: .leading, spacing: TMSpace.sm) {
                            if showsUnits {
                                UnitRowCard(
                                    unit: unit,
                                    isActiveSide: false,
                                    accessibilityIdentifier: "as.battle.unit.\(unit.id.uuidString)",
                                    shootingOver: true,
                                    action: { onOpenUnit(unit) }
                                )
                            } else {
                                Text(unit.name)
                                    .font(TMFont.cardTitle)
                            }
                            // A checklist row, not a state label posing as a button.
                            Button {
                                if pickedUp.contains(unit.id) {
                                    pickedUp.remove(unit.id)
                                } else {
                                    pickedUp.insert(unit.id)
                                }
                            } label: {
                                Label(
                                    "Picked up the \(unit.name) mini",
                                    systemImage: pickedUp.contains(unit.id) ? "checkmark.circle.fill" : "circle"
                                )
                                .font(TMFont.body)
                                .frame(minHeight: 44, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(pickedUp.contains(unit.id) ? .isSelected : [])
                        }
                    }
                }
            }
            if !crippled.isEmpty {
                crippledSection
            }
            if showsUnits, !standing.isEmpty {
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    Eyebrow("Standing")
                    ForEach(standing) { unit in
                        UnitRowCard(
                            unit: unit,
                            isActiveSide: false,
                            accessibilityIdentifier: "as.battle.unit.\(unit.id.uuidString)",
                            action: { onOpenUnit(unit) }
                        )
                    }
                }
            }
            // From turn 5 so players can plan the structure tiebreak, not only on the last turn.
            if coach.isLastTurn || session.ruleset.maxTurns.map({ session.turn >= $0 - 1 }) == true {
                scoreCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var crippledSection: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Crippled this turn")
            ForEach(crippled) { unit in
                FlowLayout(spacing: TMSpace.sm) {
                    Text(unit.name)
                        .font(TMFont.cardTitle)
                    StatusChip(kind: .withdrawing)
                }
                .accessibilityElement(children: .combine)
            }
            Text("From next turn they must move toward their own edge. They can still shoot. Off the table counts as destroyed.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("as.battle.crippled")
    }

    private func points(_ side: SideId) -> Int {
        // Play games break a turn-limit tie on PV left (PlayModeSpec § 7.3); missions on Structure.
        session.isPlayGame
            ? VictoryEvaluator.pvLeft(side: side, in: session)
            : VictoryEvaluator.remainingStructure(side: side, in: session)
    }

    private var scoreCard: some View {
        // Sides still in the game compete; a side that is out keeps its row only in the result.
        let sides = session.sides.count > 2 ? session.sidesInGame : session.sideIds
        let scores = sides.map { (side: $0, value: points($0)) }
        return VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow("Score if the game ended now")
            TMCard(edgeColor: TMColor.signal, isRaised: true) {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    if sides.count > 2 {
                        FlowLayout(spacing: TMSpace.lg) {
                            ForEach(scores, id: \.side) { score(value: $0.value, side: $0.side) }
                        }
                    } else {
                        HStack(spacing: TMSpace.lg) {
                            ForEach(Array(scores.enumerated()), id: \.element.side) { index, item in
                                if index > 0 {
                                    Text("vs")
                                        .font(TMFont.detail)
                                        .foregroundStyle(.secondary)
                                }
                                score(value: item.value, side: item.side)
                            }
                        }
                    }
                    Text(verdict(scores))
                        .font(TMFont.cardTitle)
                }
            }
        }
    }

    private func score(value: Int, side: SideId) -> some View {
        HStack(spacing: TMSpace.xs) {
            SideBadge(side: side)
            Text("\(value)")
                .font(TMFont.readoutM)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.displayName(of: side)) \(value) \(session.isPlayGame ? "PV left" : "structure")")
    }

    private func verdict(_ scores: [(side: SideId, value: Int)]) -> String {
        guard let best = scores.map(\.value).max() else { return "It would be a draw" }
        let leaders = scores.filter { $0.value == best }.map(\.side)
        if leaders.count == 1 { return "\(session.displayName(of: leaders[0])) would win" }
        return scores.count > 2 ? "\(leaders.map { session.displayName(of: $0) }.joined(separator: " and ")) would tie" : "It would be a draw"
    }
}

#if DEBUG
#Preview("Clean up") {
    ScrollView {
        CleanUpStep(
            session: cleanupSession(),
            coach: BattleCoach(session: cleanupSession()),
            onOpenUnit: { _ in }
        )
        .padding()
    }
}

private func cleanupSession() -> MatchSession {
    var session = PreviewFixtures.session(phase: .end, turn: 6)
    session.tableReady = true
    session.deploymentAcknowledged = true
    if session.units.count > 1 {
        session.units[1].combatStatus = .destroyedPendingEnd
        session.units[1].structureDamage = session.units[1].structureCap
    }
    return session
}
#endif
