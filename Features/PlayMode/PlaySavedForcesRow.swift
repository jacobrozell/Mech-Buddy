import SwiftUI
import MechBuddyData

/// The "Saved forces" row: count of saved forces and hand-entered cards, opening `PlaySavedForcesSheet`. Used on
/// Play home (PM9) and on the Force tab (PM11 follow-up). Callers gate it on the `playMode` flag.
struct PlaySavedForcesRow: View {
    var identifier: String
    var action: () -> Void
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        let count = dependencies.userContent.savedForces().count
        let cards = dependencies.cardLibrary.userFaces.count
        Button(action: action) {
            HStack(spacing: TMSpace.md) {
                Image(systemName: "tray.full")
                    .foregroundStyle(TMColor.signal)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text("Saved forces").font(TMFont.cardTitle)
                    Text("\(count) saved · \(cards) hand-entered \(cards == 1 ? "card" : "cards")")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: TMSpace.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
