import SwiftUI

/// Big tappable answer card for one-question screens (onboarding). A symbol, a title, an optional
/// detail and badge, and extra content below. Selection shows as a signal border plus a check, never color alone.
struct ChoiceTile<Extra: View>: View {
    enum Indicator {
        /// Pick one (radio).
        case single
        /// Pick any (checkbox).
        case multiple
    }

    var title: String
    var detail: String?
    var systemImage: String
    var badge: String?
    var badgeTint: Color = TMColor.readout
    var isSelected: Bool
    var indicator: Indicator = .multiple
    var accessibilityIdentifier: String?
    var accessibilityHint: String?
    var action: () -> Void
    @ViewBuilder var extra: () -> Extra

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                header
                extra()
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(background)
            .overlay {
                RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 2.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous))
        }
        .buttonStyle(ChoiceTilePressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityID(accessibilityIdentifier)
        .modifier(ChoiceTileHint(hint: accessibilityHint))
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                HStack(alignment: .top) {
                    symbol
                    Spacer(minLength: TMSpace.sm)
                    check
                }
                copy
            }
        } else {
            HStack(alignment: .top, spacing: TMSpace.md) {
                symbol
                copy
                Spacer(minLength: TMSpace.sm)
                check
            }
        }
    }

    private var symbol: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(isSelected ? TMColor.onSignal : TMColor.signal)
            .frame(width: 52, height: 52)
            .background(
                isSelected ? TMColor.signal : TMColor.signal.opacity(0.14),
                in: RoundedRectangle(cornerRadius: TMRadius.chip + 4, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Text(title)
                .font(TMFont.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let badge {
                Text(badge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, TMSpace.sm)
                    .padding(.vertical, TMSpace.xs)
                    .background(badgeTint, in: Capsule())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
    }

    private var check: some View {
        Image(systemName: checkSymbol)
            .font(.title3)
            .foregroundStyle(isSelected ? TMColor.signal : Color.secondary)
            .accessibilityHidden(true)
    }

    private var checkSymbol: String {
        switch indicator {
        case .single: isSelected ? "checkmark.circle.fill" : "circle"
        case .multiple: isSelected ? "checkmark.square.fill" : "square"
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
            .fill(isSelected ? TMColor.signal.opacity(0.10) : TMColor.surfaceCard)
    }

    private var borderColor: Color {
        if isSelected { return TMColor.signal }
        return colorScheme == .light ? Color(.separator).opacity(0.6) : Color(.separator)
    }
}

extension ChoiceTile where Extra == EmptyView {
    init(
        title: String,
        detail: String? = nil,
        systemImage: String,
        badge: String? = nil,
        badgeTint: Color = TMColor.readout,
        isSelected: Bool,
        indicator: Indicator = .multiple,
        accessibilityIdentifier: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            detail: detail,
            systemImage: systemImage,
            badge: badge,
            badgeTint: badgeTint,
            isSelected: isSelected,
            indicator: indicator,
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityHint: accessibilityHint,
            action: action,
            extra: { EmptyView() }
        )
    }
}

/// Sinks slightly while pressed. A plain dim with Reduce Motion.
private struct ChoiceTilePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .snappy(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ChoiceTileHint: ViewModifier {
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

#if DEBUG
#Preview("Choice tiles") {
    PreviewPair {
        VStack(spacing: TMSpace.md) {
            ChoiceTile(
                title: "Alpha Strike",
                detail: "Quick and card-based",
                systemImage: "rectangle.portrait.on.rectangle.portrait",
                badge: "Play now",
                badgeTint: TMColor.success.opacity(0.22),
                isSelected: true,
                indicator: .single,
                action: {}
            )
            ChoiceTile(title: "Two six-sided dice", detail: "No dice? The app can roll.", systemImage: "dice", isSelected: false) {}
        }
    }
}
#endif
