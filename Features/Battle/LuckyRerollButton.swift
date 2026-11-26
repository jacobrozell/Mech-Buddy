import SwiftUI
import MechBuddyDomain

/// Battle Star Lucky (Clash of Steel, Quick-Start p. 32): after the attack roll and before Apply, a Star 'Mech
/// may spend one use to roll again. The second roll stands, so the button goes once it is used.
struct LuckyRerollButton: View {
    @Bindable var store: MatchStore
    let attackerId: UUID
    @Binding var used: Bool
    /// Clear the dice so the players enter the new roll.
    var onReroll: () -> Void

    private var formation: FormationState? {
        guard let session = store.session,
              let formation = session.boxRules?.formation(of: attackerId, kind: .battleStar),
              FormationRules.canUseLucky(formation, unitId: attackerId, units: session.units) else { return nil }
        return formation
    }

    var body: some View {
        if used {
            Label("Lucky reroll: this roll stands.", systemImage: "clover.fill")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
        } else if let formation {
            Button {
                store.useLucky(formationId: formation.id, unitId: attackerId)
                if store.lastError == nil {
                    used = true
                    onReroll()
                }
            } label: {
                Label("Lucky: roll again (\(formation.luckyUsesLeft) left)", systemImage: "clover")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("cos.lucky.reroll")
        }
    }
}
