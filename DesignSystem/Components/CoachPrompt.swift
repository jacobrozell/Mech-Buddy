import SwiftUI
import MechBuddyDomain

/// How much of a coach prompt to show. The battle screen sets it from Settings → Coaching
/// and from whether this step has already been explained in this game. FUTURE-PLAN §1.1.
enum CoachDisplay: Sendable, Equatable {
    /// Title and the whole paragraph.
    case full
    /// Title and a "?" that expands the paragraph. Players who know the turn get the space back.
    case brief
    /// Title only.
    case off
}

extension EnvironmentValues {
    @Entry var coachDisplay: CoachDisplay = .full
}

struct CoachPrompt: View {
    var title: String
    var message: String
    var side: SideId?
    var help: String?
    var accessibilityIdentifier: String?

    @Environment(\.coachDisplay) private var display
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private var showsMessage: Bool {
        display == .full || (display == .brief && expanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: display == .full ? TMSpace.sm : TMSpace.xs) {
            HStack(alignment: .center, spacing: TMSpace.sm) {
                if let side {
                    SideBadge(side: side)
                }
                Text(title)
                    .font(TMFont.stepTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityID(accessibilityIdentifier)
                if display == .brief {
                    Spacer(minLength: TMSpace.sm)
                    moreButton
                }
            }
            if showsMessage {
                Text(message)
                    .font(TMFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
                if let help {
                    InlineHelp(label: "Why?", text: help)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moreButton: some View {
        Button {
            if reduceMotion {
                expanded.toggle()
            } else {
                withAnimation(TMMotion.reveal) {
                    expanded.toggle()
                }
            }
        } label: {
            Image(systemName: expanded ? "questionmark.circle.fill" : "questionmark.circle")
                .font(.title3)
                .frame(minWidth: 44, minHeight: 30)
                // 44 pt to tap without making the title row taller.
                .contentShape(Rectangle().inset(by: -7))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(expanded ? "Hide how this step works" : "How this step works")
        .accessibilityAddTraits(expanded ? .isSelected : [])
        .accessibilityIdentifier("as.battle.coachMore")
    }
}

#if DEBUG
#Preview("Coach") {
    PreviewPair {
        VStack(spacing: TMSpace.lg) {
            CoachPrompt(
                title: "Side B shoots",
                message: "Pick a ’Mech, then solve the shot.",
                side: .lanceB,
                help: "The other side already shot this turn.",
                accessibilityIdentifier: "preview.coach"
            )
            CoachPrompt(
                title: "Both sides shoot",
                message: "Roll together, in any order.",
                accessibilityIdentifier: "preview.coach.brief"
            )
            .environment(\.coachDisplay, .brief)
        }
    }
}
#endif
