import SwiftUI
import MechBuddyDomain

/// One die for a hit at a "0*" band (Quick-Start Rulebook 3rd printing, p. 21): 4 or higher deals 1 damage.
/// Drop it into the solver sheet when `CombatSolve.needsMinimalRoll` is true and pass `die` as
/// `SATORAttackCommand.minimalDie` when applying the hit.
struct MinimalDamageRoll: View {
    @Binding var die: Int?
    var identifierPrefix: String = "combat.minimal"

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Text("Minimal damage")
                .font(.headline)
            Text("This range shows 0*. A hit rolls one die: 4 or higher deals 1 damage.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DieFacePicker(title: "Damage die", value: $die, accessibilityIdentifier: "\(identifierPrefix).die")
            if let die {
                let damage = MinimalDamage.damage(forDie: die)
                Text(damage > 0 ? "Deals 1 damage." : "Hit, but no damage and no critical.")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("\(identifierPrefix).result")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
