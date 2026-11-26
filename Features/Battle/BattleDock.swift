import SwiftUI

struct BattleDockButton {
    var title: String
    var identifier: String
    var specIdentifier: String?
    var hint: String?
    var disabled: Bool = false
    var action: () -> Void
}

struct BattleDock: View {
    var primary: BattleDockButton?
    var secondary: BattleDockButton?
    /// Optional leading button, e.g. a short-lived Undo kept inside the dock row in landscape.
    var leading: BattleDockButton?
    var tint: Color = TMColor.signal

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if let primary {
            PhaseDock(
                primaryTitle: primary.title,
                primaryIdentifier: primary.identifier,
                primarySpecIdentifier: primary.specIdentifier ?? "as.battle.phaseDock.next",
                primaryDisabled: primary.disabled,
                primaryTint: tint,
                primaryHint: primary.hint,
                primaryAction: primary.action,
                secondaryTitle: secondary?.title,
                secondaryIdentifier: secondary?.identifier ?? "as.battle.doneShooting",
                secondarySpecIdentifier: secondary?.specIdentifier,
                secondaryHint: secondary?.hint,
                secondaryAction: secondary?.action,
                leadingTitle: leading?.title,
                leadingIdentifier: leading?.identifier,
                leadingHint: leading?.hint,
                leadingAction: leading?.action
            )
            .background {
                if primary.specIdentifier != nil, primary.specIdentifier != "as.battle.phaseDock.next" {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier("as.battle.phaseDock.next")
                        .accessibilityLabel(primary.title)
                        .allowsHitTesting(false)
                }
            }
        } else if let secondary {
            // Movement has no primary until every move is in: the skip is a quiet text button.
            HStack(spacing: TMSpace.md) {
                if let leading {
                    DockTextButton(
                        title: leading.title,
                        systemImage: "arrow.uturn.backward",
                        hint: leading.hint,
                        accessibilityIdentifier: leading.identifier,
                        action: leading.action
                    )
                }
                DockTextButton(
                    title: secondary.title,
                    hint: secondary.hint,
                    accessibilityIdentifier: secondary.identifier,
                    action: secondary.action
                )
            }
            .frame(maxWidth: .infinity)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .padding(.horizontal, TMSpace.lg)
            .padding(.vertical, verticalSizeClass == .compact ? TMSpace.xxs : TMSpace.xs)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("as.battle.phaseDock")
        }
    }
}

#if DEBUG
#Preview("Battle dock") {
    PreviewPair {
        BattleDock(
            primary: BattleDockButton(
                title: "Solve a shot",
                identifier: "as.battle.primary",
                specIdentifier: "as.battle.phaseDock.next",
                action: {}
            ),
            secondary: BattleDockButton(
                title: "Done shooting",
                identifier: "as.battle.doneShooting",
                specIdentifier: "as.battle.phaseDock.doneSide",
                action: {}
            ),
            tint: TMColor.sideA
        )
    }
}
#endif
