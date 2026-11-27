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
        PlayHomeRow(
            systemImage: "tray.full",
            title: "Saved forces",
            detail: "\(count) saved · \(cards) hand-entered \(cards == 1 ? "card" : "cards")",
            identifier: identifier,
            action: action
        )
    }
}
