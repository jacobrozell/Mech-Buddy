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
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            CoachPrompt(
                title: "\(session.activeSide.displayName) shoots",
                message: "Measure to the target, then solve a shot. \(otherSideLine)",
                side: session.activeSide,
                accessibilityIdentifier: "as.battle.table"
            )
            shotFeed
            if showsUnits {
                unitGroup(
                    title: "Shooters — \(session.activeSide.displayName)",
                    units: visible(session.activeSide),
                    offersShoot: true
                )
                unitGroup(
                    title: "Targets — \(session.activeSide.other.displayName) · \(otherSuffix)",
                    units: visible(session.activeSide.other),
                    offersShoot: false
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var otherSuffix: String {
        session.initiativeWinner == session.activeSide ? "already fired" : "fires next"
    }

    private var otherSideLine: String {
        "\(session.activeSide.other.displayName) \(otherSuffix)."
    }

    private func visible(_ side: SideId) -> [MatchUnitState] {
        session.units.filter { $0.side == side && $0.combatStatus != .removed }
    }

    @ViewBuilder
    private var shotFeed: some View {
        if !shots.isEmpty {
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
        if row.shot.hit {
            return "\(row.shooter) hit \(row.shot.targetName) for \(row.shot.damage)"
        }
        return "\(row.shooter) missed \(row.shot.targetName)"
    }

    private func unitGroup(title: String, units: [MatchUnitState], offersShoot: Bool) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow(title)
            ForEach(units) { unit in
                BattleUnitRow(
                    unit: unit,
                    isActiveSide: unit.side == session.activeSide,
                    offersShoot: offersShoot && unit.canAttackThisTurn,
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
