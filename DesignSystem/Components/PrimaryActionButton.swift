import SwiftUI

struct PrimaryActionButton: View {
    enum Placement {
        case dock
        case content
    }

    var title: String
    var systemImage: String?
    var placement: Placement = .content
    var role: ButtonRole?
    var tint: Color?
    var isDisabled: Bool = false
    var accessibilityIdentifier: String?
    var accessibilityHint: String?
    /// Replaces the button’s spoken name when the visible title is not enough.
    var spokenLabel: String?
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isShort: Bool { verticalSizeClass == .compact }

    var body: some View {
        styled(button)
    }

    /// Gold buttons take the dark `onSignal` label: white on the gold was about 2.9:1 in light mode and
    /// 1.8:1 on the brighter dark-mode gold. Side-coloured buttons keep the system's white label.
    private var labelStyle: AnyShapeStyle? {
        guard role != .destructive else { return nil }
        // Side colours are dark in light mode (white reads) and light in dark mode (white didn't).
        if tint == nil || tint == TMColor.signal || colorScheme == .dark {
            return AnyShapeStyle(TMColor.onSignal)
        }
        return nil
    }

    private var button: some View {
        Button(role: role, action: action) {
            label
                .frame(maxWidth: .infinity, minHeight: isShort ? 36 : 50)
                .modifier(OptionalForeground(style: isDisabled ? nil : labelStyle))
        }
        .controlSize(isShort ? .regular : .large)
        .disabled(isDisabled)
        .tint(tint)
        .accessibilityID(accessibilityIdentifier)
        .modifier(OptionalHint(hint: accessibilityHint))
        .modifier(OptionalSpokenLabel(label: spokenLabel))
    }

    @ViewBuilder
    private func styled<V: View>(_ view: V) -> some View {
        switch placement {
        case .dock:
            view.buttonStyle(.glassProminent)
        case .content:
            view.buttonStyle(.borderedProminent)
        }
    }

    private var label: some View {
        HStack(spacing: TMSpace.sm) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
        }
    }
}

struct SecondaryActionButton: View {
    enum Placement {
        case dock
        case content
    }

    var title: String
    var systemImage: String?
    var placement: Placement = .content
    var role: ButtonRole?
    var isDisabled: Bool = false
    var accessibilityIdentifier: String?
    var accessibilityHint: String?
    var action: () -> Void

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    private var isShort: Bool { verticalSizeClass == .compact }

    var body: some View {
        styled(button)
    }

    private var button: some View {
        Button(role: role, action: action) {
            HStack(spacing: TMSpace.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .multilineTextAlignment(.center)
                    // Glass buttons keep one line; at accessibility sizes "Done shooting" was cut to "Done shooti…".
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: isShort ? 36 : 50)
        }
        .controlSize(isShort ? .regular : .large)
        .disabled(isDisabled)
        .accessibilityID(accessibilityIdentifier)
        .modifier(OptionalHint(hint: accessibilityHint))
    }

    @ViewBuilder
    private func styled<V: View>(_ view: V) -> some View {
        switch placement {
        case .dock:
            view.buttonStyle(.glass)
        case .content:
            view.buttonStyle(.bordered)
        }
    }
}

private struct OptionalHint: ViewModifier {
    var hint: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

private struct OptionalSpokenLabel: ViewModifier {
    var label: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let label, !label.isEmpty {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

#if DEBUG
#Preview("Buttons") {
    PreviewPair {
        VStack(spacing: TMSpace.md) {
            PrimaryActionButton(title: "Use these rolls", tint: TMColor.signal) {}
            SecondaryActionButton(title: "Done shooting") {}
            PrimaryActionButton(title: "Next", placement: .dock, tint: TMColor.sideA) {}
        }
    }
}
#endif

private struct OptionalForeground: ViewModifier {
    var style: AnyShapeStyle?

    func body(content: Content) -> some View {
        if let style {
            content.foregroundStyle(style)
        } else {
            content
        }
    }
}
