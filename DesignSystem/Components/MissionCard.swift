import SwiftUI
import MechBuddyDomain

struct MissionFact: Identifiable, Sendable {
    var id: String
    var systemImage: String
    var text: String
}

struct MissionCard: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var facts: [MissionFact]
    var sideANames: [String]
    var sideBNames: [String]
    var primaryTitle: String
    var primaryIdentifier: String?
    /// Bordered-prominent when true. Bordered when a resume card already owns the screen.
    var primaryProminent: Bool = true
    var primaryAction: () -> Void
    var secondaryLinks: [(title: String, identifier: String?, action: () -> Void)]

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow(eyebrow)
            Text(title)
                .font(TMFont.stepTitle)
            Text(subtitle)
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TMSpace.md) { factRow }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: TMSpace.sm) {
                    factRow
                }
            }
            .accessibilityElement(children: .combine)
            HStack(alignment: .top, spacing: TMSpace.md) {
                roster(side: .lanceA, names: sideANames)
                Text("vs")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                roster(side: .lanceB, names: sideBNames)
            }
            primaryButton
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TMSpace.lg) { linkButtons }
                VStack(alignment: .leading, spacing: TMSpace.xs) { linkButtons }
            }
        }
        .padding(TMSpace.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TMColor.surfaceCard, in: RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous))
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [TMColor.signal.opacity(0.35), TMColor.signal.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 72)
            .clipShape(RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous))
            .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var factRow: some View {
        ForEach(facts) { fact in
            Label(fact.text, systemImage: fact.systemImage)
                .font(TMFont.detail)
                .labelStyle(.titleAndIcon)
        }
    }

    private func roster(side: SideId, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            SideTag(side: side)
            Text(names.joined(separator: " · "))
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var primaryButton: some View {
        if primaryProminent {
            PrimaryActionButton(
                title: primaryTitle,
                tint: TMColor.signal,
                accessibilityIdentifier: primaryIdentifier,
                action: primaryAction
            )
        } else {
            SecondaryActionButton(
                title: primaryTitle,
                accessibilityIdentifier: primaryIdentifier,
                action: primaryAction
            )
        }
    }

    @ViewBuilder
    private var linkButtons: some View {
        ForEach(Array(secondaryLinks.enumerated()), id: \.offset) { _, link in
            Button(action: link.action) {
                HStack(spacing: TMSpace.xs) {
                    Text(link.title)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
            .font(TMFont.detail)
            .buttonStyle(.borderless)
            .accessibilityID(link.identifier)
        }
    }
}

#if DEBUG
#Preview("Mission") {
    PreviewPair {
        MissionCard(
            eyebrow: "Alpha Strike · beginner mission",
            title: "Ridge Line",
            subtitle: "Beginner mission · 2 vs 2 · about 40 minutes",
            facts: [
                MissionFact(id: "players", systemImage: "person.2", text: "2 players"),
                MissionFact(id: "time", systemImage: "clock", text: "40 min"),
                MissionFact(id: "dice", systemImage: "dice", text: "2D6"),
                MissionFact(id: "range", systemImage: "ruler", text: "Tape")
            ],
            sideANames: ["Shadow Hawk", "Wolverine"],
            sideBNames: ["Locust", "Wasp"],
            primaryTitle: "Play Ridge Line",
            primaryIdentifier: "as.modeHome.ridgeLine",
            primaryAction: {},
            secondaryLinks: [
                (title: "How to play", identifier: "as.modeHome.howToPlay", action: {}),
                (title: "New here?", identifier: "as.modeHome.gettingStarted", action: {})
            ]
        )
    }
}
#endif
