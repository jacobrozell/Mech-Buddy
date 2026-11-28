import SwiftUI

struct PhaseDock: View {
    var primaryTitle: String
    var primaryIdentifier: String = "as.battle.primary"
    var primarySpecIdentifier: String? = "as.battle.phaseDock.next"
    var primaryDisabled: Bool = false
    var primaryTint: Color = TMColor.signal
    var primaryHint: String?
    var primaryAction: () -> Void

    var secondaryTitle: String?
    var secondaryIdentifier: String = "as.battle.doneShooting"
    var secondarySpecIdentifier: String? = "as.battle.phaseDock.doneSide"
    var secondaryHint: String?
    var secondaryAction: (() -> Void)?

    var leadingTitle: String?
    var leadingIdentifier: String?
    var leadingHint: String?
    var leadingAction: (() -> Void)?

    var containerIdentifier: String = "as.battle.phaseDock"

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// One primary button with the secondary as a text button beside it (FUTURE-PLAN §1.4): two
    /// full glass buttons took ~22% of the screen, and ~280 pt stacked at accessibility sizes.
    /// Accessibility sizes put the text button under the primary, where "Done shooting" has room.
    private var stacks: Bool {
        dynamicTypeSize.isAccessibilitySize && verticalSizeClass != .compact
    }

    private var primaryButton: some View {
        PrimaryActionButton(
            title: primaryTitle,
            placement: .dock,
            tint: primaryTint,
            isDisabled: primaryDisabled,
            accessibilityHint: primaryHint,
            action: primaryAction
        )
        .accessibilityIdentifiers(
            primary: primaryIdentifier,
            extra: primarySpecIdentifier,
            label: primaryTitle
        )
    }

    var body: some View {
        Group {
            if stacks {
                VStack(spacing: TMSpace.xxs) {
                    primaryButton
                    HStack(spacing: TMSpace.lg) {
                        leadingButton
                        secondaryButton
                    }
                }
            } else {
                // One row when it fits; in a narrow column (landscape table view) the text buttons sit above
                // the primary instead of squeezing it.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TMSpace.md) {
                        leadingButton
                        secondaryButton
                        primaryButton
                    }
                    VStack(spacing: TMSpace.xxs) {
                        HStack(spacing: TMSpace.lg) {
                            leadingButton
                            secondaryButton
                        }
                        primaryButton
                    }
                }
            }
        }
        // Chrome, not content: past AX2 the stacked dock took ~280 pt (FUTURE-PLAN §1.8).
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, verticalSizeClass == .compact ? TMSpace.xs : TMSpace.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(containerIdentifier)
    }

    @ViewBuilder
    private var leadingButton: some View {
        if let leadingTitle, let leadingAction {
            DockTextButton(
                title: leadingTitle,
                systemImage: "arrow.uturn.backward",
                hint: leadingHint,
                accessibilityIdentifier: leadingIdentifier,
                action: leadingAction
            )
            .layoutPriority(1)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var secondaryButton: some View {
        if let secondaryTitle, let secondaryAction {
            // Priority: the text keeps its width and the primary title scales down instead.
            DockTextButton(title: secondaryTitle, hint: secondaryHint, action: secondaryAction)
                .layoutPriority(1)
                .accessibilityIdentifiers(
                    primary: secondaryIdentifier,
                    extra: secondarySpecIdentifier,
                    label: secondaryTitle
                )
        }
    }
}

/// The dock's secondary action: a plain text button, 44 pt tall, so the primary keeps the width.
struct DockTextButton: View {
    var title: String
    var systemImage: String?
    var hint: String?
    var accessibilityIdentifier: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TMSpace.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(TMFont.cardTitle)
                .frame(minHeight: 44)
                .padding(.horizontal, TMSpace.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityID(accessibilityIdentifier)
        .accessibilityHint(hint ?? "")
    }
}

#if DEBUG
#Preview("Phase dock") {
    PreviewPair {
        PhaseDock(
            primaryTitle: "Use these rolls",
            primaryTint: TMColor.signal,
            primaryAction: {},
            secondaryTitle: "Done shooting",
            secondaryAction: {}
        )
    }
}
#endif
