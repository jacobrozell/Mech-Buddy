import SwiftUI
import MechBuddyDomain
import MechBuddyData

struct PlaceMiniaturesStep: View {
    var session: MatchSession
    /// The mission's map and setup zones. Missions without one get the plain two-edge schematic.
    var layout: MissionLayoutDTO? = nil
    /// Three or four sides: take an edge, swapping with whoever holds it (§ 6.4). Nil hides the menus (previews).
    var onAssignEdge: ((SideId, TableEdge) -> Void)?

    @Environment(\.sideNames) private var sideNames

    private var isFreeForAll: Bool { session.sides.count > 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            // No side badge: every side places, taking turns.
            CoachPrompt(
                title: "Place the miniatures",
                message: message,
                side: nil,
                accessibilityIdentifier: "as.battle.table"
            )
            if isFreeForAll {
                freeForAllLayout
            } else if let layout {
                MissionLayoutView(layout: layout)
            } else {
                DeploymentSchematic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var message: String {
        guard isFreeForAll else {
            return "Each side sets its ’Mechs within 6″ of its own short edge. \(session.displayName(of: session.otherSide(of: session.activeSide))) won the roll and picks who places first; then take turns, one ’Mech at a time."
        }
        let winner = session.initiativeWinner.map { sideNames($0) } ?? "The highest roll"
        return "[HOUSE] Each side takes one edge and sets its ’Mechs within 6″ of it, in the middle 3/8 of the edge. \(winner) won the roll and picks an edge and who places first; then place in the same order, one ’Mech at a time."
    }

    /// Zones from the sides' home edges, with an edge menu per side.
    private var freeForAllLayout: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            if let play = session.play {
                MissionLayoutView(board: PlayLayout.board(for: play.battlefield, sides: session.sides))
            }
            ForEach(session.sides) { side in
                HStack(spacing: TMSpace.sm) {
                    SideTag(side: side.id)
                    Spacer(minLength: TMSpace.sm)
                    if let onAssignEdge {
                        Menu {
                            ForEach(PlaySetup.defaultHomeEdges(sideCount: 4), id: \.self) { edge in
                                Button(Self.title(edge)) { onAssignEdge(side.id, edge) }
                            }
                        } label: {
                            Label(side.homeEdge.map(Self.title) ?? "Pick an edge", systemImage: "rectangle.dashed")
                                .font(TMFont.detail.weight(.semibold))
                                .frame(minHeight: 44)
                        }
                        .accessibilityLabel("\(sideNames(side.id)) edge")
                        .accessibilityValue(side.homeEdge.map(Self.title) ?? "None")
                        .accessibilityIdentifier("as.battle.edge.\(side.id.rawValue)")
                    } else if let edge = side.homeEdge {
                        Text(Self.title(edge)).font(TMFont.detail).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    static func title(_ edge: TableEdge) -> String {
        switch edge {
        case .west: "Left edge"
        case .east: "Right edge"
        case .north: "Top edge"
        case .south: "Bottom edge"
        }
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
