import SwiftUI
import MechBuddyDomain

struct CriticalPendingStep: View {
    var unit: MatchUnitState
    /// The side that rolls the critical: the side that hit it (rulebook p. 23).
    /// Nil with three or four sides: the attacker isn't recorded, so the prompt says "the side that hit it".
    var rollingSide: SideId?
    @Environment(\.sideNames) private var sideNames
    var count: Int
    var diceMode: DiceMode
    var landingUnitID: UUID?
    var showsUnit: Bool = true
    var onOpenUnit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            HStack(alignment: .top, spacing: TMSpace.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(TMColor.warning)
                    .accessibilityHidden(true)
                CoachPrompt(
                    title: "Critical hit",
                    message: message,
                    side: unit.side,
                    accessibilityIdentifier: "as.battle.table"
                )
                // Always in full, whatever Settings → Coaching says: it names who rolls and says it is
                // not a shot (playtest P1-4). That is game state, not teaching text.
                .environment(\.coachDisplay, .full)
            }
            if count > 1 {
                Text("1 of \(count)")
                    .font(TMFont.detail.weight(.semibold))
                    .padding(.horizontal, TMSpace.sm)
                    .padding(.vertical, TMSpace.xs)
                    .background(TMColor.warning, in: Capsule())
                    .foregroundStyle(TMColor.onSignal)
                    .accessibilityLabel("Critical 1 of \(count)")
            }
            if showsUnit {
                UnitCard(
                    unit: unit,
                    isActiveSide: true,
                    accessibilityIdentifier: "as.battle.unit.\(unit.id.uuidString)",
                    action: onOpenUnit
                )
                .id(unit.id)
                .overlay {
                    if landingUnitID == unit.id {
                        RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                            .strokeBorder(TMColor.damage, lineWidth: 3)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var message: String {
        // Name the roller and say it is not a shot: players read "Roll two dice" as their attack.
        // The attacker rolls the critical (rulebook p. 23), so the other side picks up the dice.
        guard let rollingSide else {
            return "\(unit.name) took a critical hit. The side that hit it rolls two dice for the critical check — this is not a shot."
        }
        let who = sideNames(rollingSide)
        return "\(unit.name) took a critical hit. \(who), the side that hit it, rolls two dice for the critical check — this is not a shot."
    }
}

#if DEBUG
#Preview("Critical pending") {
    ScrollView {
        CriticalPendingStep(
            unit: owedLocust(),
            rollingSide: .lanceB,
            count: 2,
            diceMode: .manual,
            landingUnitID: nil,
            onOpenUnit: {}
        )
        .padding()
    }
}

private func owedLocust() -> MatchUnitState {
    var unit = PreviewFixtures.locust
    unit.criticalsOwed = 2
    return unit
}
#endif
