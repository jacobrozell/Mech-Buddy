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

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            CoachPrompt(
                title: "Clean up",
                message: wrecks.isEmpty
                    ? "Nothing was wrecked this turn. Tap Next turn."
                    : "Take wrecked ’Mechs off the table.",
                accessibilityIdentifier: "as.battle.table"
            )
            if !wrecks.isEmpty {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    Eyebrow("Remove from the table")
                    ForEach(wrecks) { unit in
                        VStack(alignment: .leading, spacing: TMSpace.sm) {
                            if showsUnits {
                                UnitCard(
                                    unit: unit,
                                    isActiveSide: false,
                                    accessibilityIdentifier: "as.battle.unit.\(unit.id.uuidString)",
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
            if showsUnits, !standing.isEmpty {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    Eyebrow("Standing")
                    ForEach(standing) { unit in
                        UnitCard(
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

    private var scoreCard: some View {
        let sideA = VictoryEvaluator.remainingStructure(side: .lanceA, in: session)
        let sideB = VictoryEvaluator.remainingStructure(side: .lanceB, in: session)
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
        .accessibilityLabel("\(side.displayName) \(value) structure")
    }

    private func verdict(sideA: Int, sideB: Int) -> String {
        if sideA > sideB { return "Side A would win" }
        if sideB > sideA { return "Side B would win" }
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
