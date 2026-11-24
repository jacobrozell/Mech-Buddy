import SwiftUI
import MechBuddyDomain

struct StatusChip: View {
    enum Kind: Sendable, Equatable {
        case critOwed(Int)
        case wrecked
        /// Wrecked and already fired (or shooting is over): "still fires" no longer applies.
        case wreckedDone
        case immobile
        /// Heat 4: no move, no shot this turn.
        case shutdown
        case sprinted
        case moved(MovementMode)
        case hit(target: String, damage: Int)
        case missed(target: String)
        case ready
        case waiting
        case lastTurn
        /// A critical already on the card, such as "Engine ×1".
        case recordedCrit(title: String, systemImage: String)

        /// "Wolverine WVR-6M" → "Wolverine": the chip has no room for the variant.
        static func short(_ name: String) -> String {
            let parts = name.split(separator: " ")
            guard parts.count > 1, let last = parts.last, last.contains(where: \.isNumber) else { return name }
            return parts.dropLast().joined(separator: " ")
        }

        var text: String {
            switch self {
            case .critOwed(let count):
                count > 1 ? "\(count) crits owed" : "Crit owed"
            case .wrecked:
                "Wrecked · still fires"
            case .wreckedDone:
                "Wrecked"
            case .immobile:
                "Can’t move"
            case .shutdown:
                "Shut down · heat"
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
                "Hit \(Self.short(target)) · \(damage)"
            case .missed(let target):
                "Missed \(Self.short(target))"
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
            case .wrecked, .wreckedDone:
                "flame.fill"
            case .immobile:
                "figure.stand"
            case .shutdown:
                "thermometer.high"
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
            case .critOwed, .ready, .lastTurn, .recordedCrit, .shutdown:
                .warning
            case .wrecked, .wreckedDone, .missed:
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
