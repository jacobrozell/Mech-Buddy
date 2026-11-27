import SwiftUI
import MechBuddyData

/// Where the house rules for three or four sides live (PlayModeSpec § 6, § 13).
enum PlayHouseRules {
    /// The Rules tab topic in `as-rules-topics.json`. Setup shows the same page, so the copy exists once.
    static let topicId = "play-house-rules"

    static func topic() -> RulesTopicDTO? {
        try? BundleContentCatalogRepository().rulesTopics().topics.first { $0.id == topicId }
    }
}

/// The info sheet behind the free-for-all note in Players and sides (`as.play.setup.houseRules`).
struct PlayHouseRulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let topic = PlayHouseRules.topic() {
                    RulesTopicDetailView(topic: topic)
                } else {
                    ContentUnavailableView(
                        "House rules unavailable",
                        systemImage: "house",
                        description: Text("Open Rules and look for “More than two sides”.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("as.play.setup.houseRules.done")
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("as.play.setup.houseRules.sheet")
    }
}
