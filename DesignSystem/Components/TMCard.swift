import SwiftUI

struct TMCard<Content: View>: View {
    var edgeColor: Color?
    var isRaised: Bool = false
    /// Tighter padding for dense battle rows, where eight ’Mechs share one screen.
    var isCompact: Bool = false
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if let edgeColor {
                Rectangle()
                    .fill(edgeColor)
                    .frame(width: 4)
            }
            content()
                .padding(.horizontal, isCompact ? TMSpace.md : TMSpace.lg)
                .padding(.vertical, isCompact ? TMSpace.sm : TMSpace.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous))
        .overlay {
            if colorScheme == .light {
                RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 1)
            }
        }
    }

    private var cardBackground: Color {
        isRaised ? TMColor.surfaceCardRaised : TMColor.surfaceCard
    }
}

#if DEBUG
#Preview("Card") {
    PreviewPair {
        VStack(spacing: TMSpace.md) {
            TMCard {
                Text("Flat card")
                    .font(TMFont.cardTitle)
            }
            TMCard(edgeColor: TMColor.sideA, isRaised: true) {
                Text("Raised, Side A")
                    .font(TMFont.cardTitle)
            }
        }
    }
}
#endif
