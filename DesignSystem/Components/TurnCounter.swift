import SwiftUI

struct TurnCounter: View {
    var turn: Int
    var maxTurns: Int?

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLastTurn: Bool {
        guard let maxTurns else { return false }
        return turn >= maxTurns
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            // Landscape phones: drop the eyebrow line so the counter fits on one row.
            if verticalSizeClass != .compact {
                Eyebrow("Turn")
            }
            HStack(alignment: .firstTextBaseline, spacing: TMSpace.xs) {
                if verticalSizeClass == .compact {
                    Text("Turn")
                        .font(TMFont.detail.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("\(turn)")
                    .font(TMFont.readoutM)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let maxTurns {
                    Text("/ \(maxTurns)")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                if let maxTurns, maxTurns > 0 {
                    progressRing(turn: turn, maxTurns: maxTurns)
                }
            }
            if isLastTurn {
                StatusChip(kind: .lastTurn)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken)
    }

    private var spoken: String {
        if let maxTurns {
            let last = isLastTurn ? ", last turn" : ""
            return "Turn \(turn) of \(maxTurns)\(last)"
        }
        return "Turn \(turn)"
    }

    private func progressRing(turn: Int, maxTurns: Int) -> some View {
        let fraction = min(1, max(0, Double(turn) / Double(maxTurns)))
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(TMColor.signal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Turn") {
    PreviewPair {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            TurnCounter(turn: 3, maxTurns: 6)
            TurnCounter(turn: 6, maxTurns: 6)
        }
    }
}
#endif
