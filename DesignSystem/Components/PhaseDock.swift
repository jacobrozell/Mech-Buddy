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
    var leadingAction: (() -> Void)?

    var containerIdentifier: String = "as.battle.phaseDock"

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Accessibility text sizes stack the buttons: side by side, "Done shooting" broke mid-word.
    /// Landscape keeps the row, where height is scarcer than width.
    private var stacks: Bool {
        dynamicTypeSize.isAccessibilitySize && verticalSizeClass != .compact
    }

    var body: some View {
        GlassEffectContainer(spacing: TMSpace.md) {
            let layout = stacks
                ? AnyLayout(VStackLayout(spacing: TMSpace.sm))
                : AnyLayout(HStackLayout(spacing: TMSpace.md))
            layout {
                if let leadingTitle, let leadingAction {
                    SecondaryActionButton(
                        title: leadingTitle,
                        placement: .dock,
                        accessibilityIdentifier: leadingIdentifier,
                        action: leadingAction
                    )
                }
                if let secondaryTitle, let secondaryAction {
                    SecondaryActionButton(
                        title: secondaryTitle,
                        placement: .dock,
                        accessibilityHint: secondaryHint,
                        action: secondaryAction
                    )
                    .accessibilityIdentifiers(
                        primary: secondaryIdentifier,
                        extra: secondarySpecIdentifier,
                        label: secondaryTitle
                    )
                }
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
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, verticalSizeClass == .compact ? TMSpace.xs : TMSpace.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(containerIdentifier)
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
