import SwiftUI
import MechBuddyDomain

extension TMColor {
    /// Coolant, ember, cobalt, orchid (PlayModeSpec § 14). Colour is never the only cue: the badge also
    /// carries a letter and a shape.
    static func side(_ side: SideId) -> Color {
        switch side {
        case .lanceA: sideA
        case .lanceB: sideB
        case .lanceC: sideC
        case .lanceD: sideD
        }
    }

    static func sideFill(_ side: SideId) -> Color {
        switch side {
        case .lanceA: sideAFill
        case .lanceB: sideBFill
        case .lanceC: sideCFill
        case .lanceD: sideDFill
        }
    }

    /// Coolant (A), cobalt (C) and orchid (D) take `onSide` (white in light, near-black in dark; 5.5:1 or better).
    /// Ember (Side B) needs dark text in light mode.
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
    @Environment(\.sideNames) private var sideNames

    var body: some View {
        HStack(spacing: TMSpace.xs) {
            SideBadge(side: side)
            Text(sideNames(side))
                .font(TMFont.cardTitle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sideNames(side))
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
            SideTag(side: .lanceC)
            SideTag(side: .lanceD)
        }
    }
}
#endif
