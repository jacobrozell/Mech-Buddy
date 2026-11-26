import SwiftUI
import MechBuddyDomain

extension TMColor {
    // Sides C and D get their own tokens (cobalt, orchid) in PM7, after the contrast checks in
    // PlayModeSpec § 14. No screen shows them before then.
    static func side(_ side: SideId) -> Color {
        side == .lanceA ? sideA : sideB
    }

    static func sideFill(_ side: SideId) -> Color {
        side == .lanceA ? sideAFill : sideBFill
    }

    /// Coolant (Side A) needs light text. Ember (Side B) needs dark text in light mode.
    static func badgeText(for side: SideId, scheme: ColorScheme) -> Color {
        if scheme == .light && side == .lanceB {
            return onSignal
        }
        return onSide
    }
}

struct SideBadge: View {
    var side: SideId
    var accessibilityIdentifier: String?

    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 22
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(letter)
            .font(.system(size: diameter * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(TMColor.badgeText(for: side, scheme: colorScheme))
            .frame(width: diameter, height: diameter)
            .background {
                switch side {
                case .lanceA: Circle().fill(TMColor.side(side))
                case .lanceB: Diamond().fill(TMColor.side(side))
                case .lanceC: SideTriangle().fill(TMColor.side(side))
                case .lanceD: Rectangle().fill(TMColor.side(side))
                }
            }
            .accessibilityLabel(side.displayName)
            .accessibilityID(accessibilityIdentifier)
    }

    private var letter: String { side.letter }
}

struct SideTag: View {
    var side: SideId

    var body: some View {
        HStack(spacing: TMSpace.xs) {
            SideBadge(side: side)
            Text(side.displayName)
                .font(TMFont.cardTitle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(side.displayName)
    }
}

/// Side C's shape (PlayModeSpec § 14).
struct SideTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Side badge") {
    PreviewPair {
        HStack(spacing: TMSpace.lg) {
            SideTag(side: .lanceA)
            SideTag(side: .lanceB)
        }
    }
}
#endif
