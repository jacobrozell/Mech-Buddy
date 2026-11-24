import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// Mission summary used by the Up next card and the mission sheet:
/// what it unlocks, who fights, and the play button.
struct MissionBrief: View {
    struct Link {
        var title: String
        var identifier: String
        var action: () -> Void
    }

    var stop: MissionStop
    var mission: GuidedScenarioDTO?
    /// The mission sheet: adds Objective and Tips, and labels Forces. The Up next card stays compact.
    var showsDetails: Bool = false
    /// Bordered-prominent when true; bordered when a game in progress owns the screen.
    var prominent: Bool = true
    var hasGameInProgress: Bool = false
    var onPlay: (() -> Void)?
    var links: [Link] = []

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Eyebrow("Mission \(stop.number) · \(stop.statusText)")
                Text(stop.title)
                    .font(TMFont.stepTitle)
                    .accessibilityAddTraits(.isHeader)
                if let meta = metaLine {
                    Text(meta)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if showsDetails, let mission {
                objective(mission)
            }
            if !stop.unlocks.isEmpty {
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    Text(showsDetails || stop.number == 1 ? "You’ll learn" : "Unlocks")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    UnlockChips(rules: stop.unlocks)
                }
            }
            if showsDetails, let notes = mission?.coachNotes, !notes.isEmpty {
                tips(notes)
            }
            if let mission {
                if showsDetails {
                    sectionTitle("Forces")
                }
                let sideA = mission.sides.lanceA.map { PlayForceMath.shortName($0.name) }
                let sideB = mission.sides.lanceB.map { PlayForceMath.shortName($0.name) }
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: TMSpace.sm) {
                        roster(.lanceA, names: sideA)
                        roster(.lanceB, names: sideB)
                    }
                } else {
                    HStack(alignment: .top, spacing: TMSpace.md) {
                        roster(.lanceA, names: sideA)
                        Text("vs")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                        roster(.lanceB, names: sideB)
                    }
                }
            }
            if stop.state == .locked, let soon = stop.comingSoon {
                Text(soon)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let onPlay, stop.state != .locked {
                playButton(onPlay)
            }
            if !links.isEmpty {
                HStack(spacing: TMSpace.lg) {
                    ForEach(links, id: \.identifier) { link in
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
                        .accessibilityIdentifier(link.identifier)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaLine: String? {
        guard let mission else { return nil }
        let size = "\(mission.sides.lanceA.count) vs \(mission.sides.lanceB.count)"
        var parts = [size]
        if let minutes = mission.estimatedMinutes { parts.append("about \(minutes) min") }
        if let turns = mission.ruleset.maxTurns { parts.append("\(turns) turns") }
        return parts.joined(separator: " · ")
    }

    private var playTitle: String {
        if hasGameInProgress { return "Start new \(stop.title)" }
        switch stop.state {
        case .cleared: return "Play again"
        // Playable but not the one the path points at: starting it out of order is fine.
        case .open: return "Skip ahead to \(stop.title)"
        case .next, .locked: return "Play \(stop.title)"
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func objective(_ mission: GuidedScenarioDTO) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            sectionTitle("Objective")
            if let summary = mission.winningSummary {
                Text(summary)
                    .font(TMFont.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label(
                mission.ruleset.maxTurns.map { "Turn limit: \($0) turns" } ?? "No turn limit",
                systemImage: "hourglass"
            )
            .font(TMFont.detail)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("as.modeHome.missionSheet.objective")
    }

    private func tips(_ notes: [String]) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            sectionTitle("Tips")
            ForEach(notes, id: \.self) { note in
                HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
                    Image(systemName: "lightbulb")
                        .font(.caption)
                        .foregroundStyle(TMColor.signal)
                        .accessibilityHidden(true)
                    Text(note)
                        .font(TMFont.detail)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("as.modeHome.missionSheet.tips")
    }

    private var playIdentifier: String {
        stop.id == ScenarioId.ridgeLine.rawValue ? "as.modeHome.ridgeLine" : "as.modeHome.mission.\(stop.id)"
    }

    @ViewBuilder
    private func playButton(_ action: @escaping () -> Void) -> some View {
        if prominent && !hasGameInProgress {
            PrimaryActionButton(
                title: playTitle,
                tint: TMColor.signal,
                accessibilityIdentifier: playIdentifier,
                action: action
            )
        } else {
            SecondaryActionButton(
                title: playTitle,
                accessibilityIdentifier: playIdentifier,
                action: action
            )
        }
    }

    private func roster(_ side: SideId, names: [String]) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            SideTag(side: side)
            Text(names.joined(separator: " · "))
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The Up next card that hangs under the current node, with a small pointer up to it.
struct UpNextCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(TMSpace.lg)
            .background(TMColor.surfaceCard, in: RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                    .strokeBorder(TMColor.signal.opacity(0.55), lineWidth: 1.5)
            }
            .overlay(alignment: .top) {
                Pointer()
                    .fill(TMColor.surfaceCard)
                    .overlay(Pointer().stroke(TMColor.signal.opacity(0.55), lineWidth: 1.5))
                    .frame(width: 22, height: 11)
                    .offset(y: -10)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("as.modeHome.upNext")
    }

    /// Open-bottomed triangle so the card's border doesn't cut across it.
    private struct Pointer: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            return path
        }
    }
}

/// Sheet for any node on the path: cleared (play again), open, or coming soon.
struct MissionDetailSheet: View {
    var stop: MissionStop
    var mission: GuidedScenarioDTO?
    var hasGameInProgress: Bool
    var onPlay: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TMSpace.lg) {
                    MissionNode(stop: stop)
                        .accessibilityHidden(true)
                    MissionBrief(
                        stop: stop,
                        mission: mission,
                        showsDetails: true,
                        hasGameInProgress: hasGameInProgress,
                        onPlay: mission == nil ? nil : {
                            dismiss()
                            onPlay()
                        }
                    )
                }
                .padding(TMSpace.lg)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("as.modeHome.missionSheet")
    }
}
