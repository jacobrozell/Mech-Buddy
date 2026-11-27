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

    private var scoreCard: some View {
        // Play games break a turn-limit tie on PV left (PlayModeSpec § 7.3); missions on Structure.
        let sideA = session.isPlayGame
            ? VictoryEvaluator.pvLeft(side: .lanceA, in: session)
            : VictoryEvaluator.remainingStructure(side: .lanceA, in: session)
        let sideB = session.isPlayGame
            ? VictoryEvaluator.pvLeft(side: .lanceB, in: session)
            : VictoryEvaluator.remainingStructure(side: .lanceB, in: session)
        return VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow("Score if the game ended now")
            TMCard(edgeColor: TMColor.signal, isRaised: true) {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    HStack(spacing: TMSpace.lg) {
                        score(value: sideA, side: .lanceA)
                        Text("vs")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                        score(value: sideB, side: .lanceB)
                    }
                    Text(verdict(sideA: sideA, sideB: sideB))
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

    private func verdict(sideA: Int, sideB: Int) -> String {
        if sideA > sideB { return "\(session.displayName(of: .lanceA)) would win" }
        if sideB > sideA { return "\(session.displayName(of: .lanceB)) would win" }
        return "It would be a draw"
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
