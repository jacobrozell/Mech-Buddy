import SwiftUI
import MechBuddyDomain

struct CombatStep: View {
    var session: MatchSession
    var landingUnitID: UUID?
    var showsUnits: Bool = true
    var onOpenUnit: (MatchUnitState) -> Void
    var onShoot: (MatchUnitState) -> Void

    @State private var showEarlierShots = false

    private var shots: [ShotFeed.Row] {
        ShotFeed.rows(in: session)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            CoachPrompt(
                title: "Both sides shoot",
                message: session.ruleset.physicalAttacksAllowed
                    ? "Roll together, in any order. Within 1″ of an enemy, a ’Mech can punch or kick instead of shooting. Damage lands at the end of the phase."
                    : "Roll together, in any order. Damage lands at the end of the phase, so a ’Mech wrecked now still fires.",
                accessibilityIdentifier: "as.battle.table"
            )
            // The ’Mechs first, so a 4 vs 4 fits above the fold; each row's chip already shows its
            // own hit or miss, and the feed with the rolls follows below.
            if showsUnits {
                ForEach(sideOrder, id: \.self) { side in
                    unitGroup(side: side, units: visible(side))
                }
            }
            shotFeed
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The side that lost initiative first, as the rulebook lists it. Either may shoot first.
    private var sideOrder: [SideId] {
        let first = session.firstToMove ?? session.activeSide
        return [first] + session.sideIds.filter { $0 != first }
    }

    private func visible(_ side: SideId) -> [MatchUnitState] {
        session.units.filter { $0.side == side && $0.combatStatus != .removed }
    }

    @ViewBuilder
    private var shotFeed: some View {
        let crits = ShotFeed.crits(in: session)
        if !shots.isEmpty || !crits.isEmpty {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow("Shot feed")
                let visibleShots = showEarlierShots || shots.count <= 3 ? shots : Array(shots.suffix(3))
                ForEach(visibleShots) { row in
                    shotRow(row)
                }
                if shots.count > 3 && !showEarlierShots {
                    Button("Show earlier shots") {
                        showEarlierShots = true
                    }
                    .font(TMFont.detail.weight(.semibold))
                    .frame(minHeight: 44)
                }
                ForEach(Array(crits.enumerated()), id: \.offset) { _, crit in
                    Label("Critical: \(crit)", systemImage: "exclamationmark.triangle.fill")
                        .font(TMFont.detail)
                        .foregroundStyle(TMColor.warning)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("as.battle.shot.crit")
                }
            }
        }
    }

    private func shotRow(_ row: ShotFeed.Row) -> some View {
        HStack(alignment: .center, spacing: TMSpace.sm) {
            Image(systemName: row.shot.hit ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(row.shot.hit ? TMColor.success : TMColor.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text("\(row.shot.total) vs \(row.shot.targetNumber)+")
                    .font(TMFont.stat)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(shotLine(row))
                    .font(TMFont.detail)
            }
            Spacer(minLength: TMSpace.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shotLine(row)). \(row.shot.rowDetail)")
        .accessibilityIdentifier(row.shot.hit ? "as.battle.shot.hit" : "as.battle.shot.miss")
    }

    private func shotLine(_ row: ShotFeed.Row) -> String {
        let how = row.shot.isPhysical ? " (punch or kick)" : ""
        if row.shot.hit {
            return "\(row.shooter) hit \(row.shot.targetName) for \(row.shot.damage)\(how)"
        }
        return "\(row.shooter) missed \(row.shot.targetName)\(how)"
    }

    private func unitGroup(side: SideId, units: [MatchUnitState]) -> some View {
        let left = units.filter(\.canAttackThisTurn).count
        return VStack(alignment: .leading, spacing: TMSpace.xs) {
            Eyebrow(side.displayName) {
                Text(left == 0 ? "All fired" : "\(left) to fire")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityIdentifier("as.battle.shooters.\(side.rawValue)")
            ForEach(units) { unit in
                BattleUnitRow(
                    unit: unit,
                    isActiveSide: unit.canAttackThisTurn,
                    offersShoot: unit.canAttackThisTurn,
                    landingUnitID: landingUnitID,
                    onOpenUnit: { onOpenUnit(unit) },
                    onShoot: { onShoot(unit) }
                )
            }
        }
    }

}

#if DEBUG
#Preview("Combat") {
    ScrollView {
        CombatStep(
            session: combatSession(),
            landingUnitID: nil,
            onOpenUnit: { _ in },
            onShoot: { _ in }
        )
        .padding()
    }
}

private func combatSession() -> MatchSession {
    var session = PreviewFixtures.session(phase: .combat)
    session.initiativeWinner = .lanceB
    session.units[0].turnShot = TurnShot(targetName: "Locust LCT-1V", hit: true, total: 9, targetNumber: 6, damage: 2)
    return session
}
#endif
