import SwiftUI
import MechBuddyDomain

struct PlaceMiniaturesStep: View {
    var session: MatchSession

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            CoachPrompt(
                title: "Place the miniatures",
                message: "Each side sets its ’Mechs within 6″ of its own short edge. \(session.activeSide.displayName) places first.",
                side: session.activeSide,
                accessibilityIdentifier: "as.battle.table"
            )
            DeploymentSchematic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DeploymentSchematic: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                .fill(TMColor.surfaceCard)
            HStack(spacing: 0) {
                edge(.lanceA)
                Spacer(minLength: 0)
                edge(.lanceB)
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Table. Each side stays within 6 inches of its own short edge. Side A on the left, Side B on the right.")
    }

    private func edge(_ side: SideId) -> some View {
        VStack(spacing: TMSpace.xs) {
            SideBadge(side: side)
            Text("6″")
                .font(TMFont.detail.weight(.semibold))
        }
        .frame(maxHeight: .infinity)
        .frame(width: 72)
        .background(TMColor.sideFill(side))
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Place miniatures") {
    ScrollView {
        PlaceMiniaturesStep(session: placingSession())
            .padding()
    }
}

private func placingSession() -> MatchSession {
    var session = PreviewFixtures.session(phase: .movement, turn: 1)
    session.tableReady = true
    session.deploymentAcknowledged = false
    return session
}
#endif
