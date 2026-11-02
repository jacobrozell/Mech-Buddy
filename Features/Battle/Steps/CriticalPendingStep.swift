import SwiftUI
import MechBuddyDomain

struct CriticalPendingStep: View {
    var unit: MatchUnitState
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
        if diceMode == .auto {
            return "\(unit.name) took a serious hit. The app rolls before anyone else shoots."
        }
        return "\(unit.name) took a serious hit. Roll two dice before anyone else shoots."
    }
}

#if DEBUG
#Preview("Critical pending") {
    ScrollView {
        CriticalPendingStep(
            unit: owedLocust(),
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
