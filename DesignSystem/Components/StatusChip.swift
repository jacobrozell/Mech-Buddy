import SwiftUI
import MechBuddyDomain

struct StatusChip: View {
    enum Kind: Sendable, Equatable {
        case critOwed(Int)
        case wrecked
        case immobile
        case sprinted
        case moved(MovementMode)
        case hit(target: String, damage: Int)
        case missed(target: String)
        case ready
        case waiting
        case lastTurn
        /// A critical already on the card, such as "Engine ×1".
        case recordedCrit(title: String, systemImage: String)

        var text: String {
            switch self {
            case .critOwed(let count):
                count > 1 ? "\(count) crits owed" : "Crit owed"
            case .wrecked:
                "Wrecked · still fires"
            case .immobile:
                "Can’t move"
            case .sprinted:
                "Sprinted · can’t fire"
            case .moved(let mode):
                switch mode {
                case .standstill: "Stood still"
                case .jump: "Jumped"
                case .ground: "Walked"
                case .sprint: "Sprinted"
                case .unset: "Moved"
                }
            case .hit(let target, let damage):
                "Hit \(target) · \(damage)"
            case .missed(let target):
                "Missed \(target)"
            case .ready:
                "Ready to fire"
            case .waiting:
                "Waits for other side"
            case .lastTurn:
                "Last turn"
            case .recordedCrit(let title, _):
                title
            }
        }

        var icon: String {
            switch self {
            case .critOwed, .lastTurn:
                "exclamationmark.triangle.fill"
            case .wrecked:
                "flame.fill"
            case .immobile:
                "figure.stand"
            case .sprinted:
                "figure.run"
            case .moved(let mode):
                switch mode {
                case .standstill: "figure.stand"
                case .jump: "arrow.up.forward"
                case .sprint: "figure.run"
                case .ground, .unset: "figure.walk"
                }
            case .hit:
                "checkmark.circle.fill"
            case .missed:
                "xmark.circle.fill"
            case .ready:
                "scope"
            case .waiting:
                "hourglass"
            case .recordedCrit(_, let systemImage):
                systemImage
            }
        }

        fileprivate var tone: Tone {
            switch self {
            case .critOwed, .ready, .lastTurn, .recordedCrit:
                .warning
            case .wrecked, .missed:
                .danger
            case .hit:
                .success
            case .immobile, .sprinted, .moved, .waiting:
                .secondary
            }
        }
    }

    fileprivate enum Tone {
        case warning
        case danger
        case success
        case secondary
    }

    var kind: Kind
    var accessibilityIdentifier: String?

    var body: some View {
        HStack(spacing: TMSpace.xs) {
            Image(systemName: kind.icon)
            Text(kind.text)
                .lineLimit(2)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, TMSpace.sm)
        .padding(.vertical, TMSpace.xs)
        .background(background, in: Capsule())
        .accessibilityLabel(kind.text)
        .accessibilityID(accessibilityIdentifier)
    }

    private var foreground: Color {
        switch kind.tone {
        case .warning:
            TMColor.onSignal
        case .danger, .success:
            TMColor.onSide
        case .secondary:
            Color.secondary
        }
    }

    private var background: Color {
        switch kind.tone {
        case .warning:
            TMColor.warning
        case .danger:
            TMColor.danger
        case .success:
            TMColor.success
        case .secondary:
            Color.secondary.opacity(0.15)
        }
    }
}

#if DEBUG
#Preview("Chips") {
    PreviewPair {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            StatusChip(kind: .critOwed(2))
            StatusChip(kind: .wrecked)
            StatusChip(kind: .sprinted)
            StatusChip(kind: .hit(target: "Locust", damage: 2))
            StatusChip(kind: .missed(target: "Locust"))
            StatusChip(kind: .ready)
            StatusChip(kind: .lastTurn)
        }
    }
}
#endif
