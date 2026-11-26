import SwiftUI
import MechBuddyDomain

/// "Standing in water" for one ’Mech this turn (Quick-Start Rulebook 3rd printing, pp. 10, 19, 24):
/// attackers count partial cover (+1) and the ’Mech cools 1 extra heat level in the End Phase.
/// Bind it to `MatchUnitState.inWater` through a reducer command or store method (see report).
struct InWaterToggle: View {
    var unitName: String
    @Binding var isInWater: Bool

    var body: some View {
        Toggle(isOn: $isInWater) {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Text("\(unitName) is standing in water")
                Text("Shots at it get partial cover (+1). It cools 1 extra heat in the End Phase.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("unit.inWater")
    }
}
