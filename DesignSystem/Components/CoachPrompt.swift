import SwiftUI
import MechBuddyDomain

struct CoachPrompt: View {
    var title: String
    var message: String
    var side: SideId?
    var help: String?
    var accessibilityIdentifier: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            HStack(alignment: .center, spacing: TMSpace.sm) {
                if let side {
                    SideBadge(side: side)
                }
                Text(title)
                    .font(TMFont.stepTitle)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityID(accessibilityIdentifier)
            }
            Text(message)
                .font(TMFont.body)
                .fixedSize(horizontal: false, vertical: true)
            if let help {
                InlineHelp(label: "Why?", text: help)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Coach") {
    PreviewPair {
        CoachPrompt(
            title: "Side B shoots",
            message: "Pick a ’Mech, then solve the shot.",
            side: .lanceB,
            help: "The other side already shot this turn.",
            accessibilityIdentifier: "preview.coach"
        )
    }
}
#endif
