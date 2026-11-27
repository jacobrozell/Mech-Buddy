import SwiftUI
import MechBuddyDomain

struct InitiativeStep: View {
    var preview: InitiativeDicePreview?
    @Binding var a1: Int?
    @Binding var a2: Int?
    @Binding var b1: Int?
    @Binding var b2: Int?
    var diceMode: Binding<DiceMode>
    var onClear: () -> Void
    /// Skip the roll: players pick who moves first.
    var onAgree: ((SideId) -> Void)?

    private var manual: Bool { diceMode.wrappedValue == .manual }

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.sideNames) private var sideNames

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            CoachPrompt(
                title: "Roll for initiative",
                message: "Each side rolls two dice. Higher total moves last — that’s the advantage.",
                help: "The side that rolls lower moves first. Winning the roll means you move after you’ve seen where they went.",
                accessibilityIdentifier: "as.battle.table"
            )
            // Landscape: both sides side by side, so all four dice fit without scrolling.
            let layout = verticalSizeClass == .compact
                ? AnyLayout(HStackLayout(alignment: .top, spacing: TMSpace.md))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: TMSpace.lg))
            layout {
                sideCard(.lanceA, first: manual ? $a1 : .constant(preview?.a1), second: manual ? $a2 : .constant(preview?.a2))
                sideCard(.lanceB, first: manual ? $b1 : .constant(preview?.b1), second: manual ? $b2 : .constant(preview?.b2))
            }
            result
            DiceModeLink(mode: diceMode, accessibilityIdentifier: "as.battle.rollInit")
            if let onAgree {
                Menu {
                    Section("Moving first gives the other side the advantage") {
                        Button("\(sideNames(.lanceA)) moves first") { onAgree(.lanceA) }
                        Button("\(sideNames(.lanceB)) moves first") { onAgree(.lanceB) }
                    }
                } label: {
                    Label("Skip the roll — we’ll choose who moves first", systemImage: "hand.raised")
                        .font(TMFont.detail.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("as.initiative.agree")
                .accessibilityHint("For learning games. Pick which side moves first without rolling.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var result: some View {
        if manual, let tieTotal = tieTotal {
            TMCard(edgeColor: TMColor.warning, isRaised: true) {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(TMColor.warning)
                            .accessibilityHidden(true)
                        Text("Tie at \(tieTotal) — both sides roll again")
                            .font(TMFont.cardTitle)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("as.initiative.tieHint")
                    Button("Clear dice", action: onClear)
                        .buttonStyle(.bordered)
                }
            }
        } else if let winner = shownWinner {
            TMCard(edgeColor: TMColor.side(winner), isRaised: true) {
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    Text("\(sideNames(winner)) wins initiative · \(shownFirstToMove.map { sideNames($0) } ?? "") moves first")
                        .font(TMFont.cardTitle)
                }
            }
        }
    }

    private var tieTotal: Int? {
        guard InitiativeDice.isTie(a1: a1, a2: a2, b1: b1, b2: b2), let a1, let a2 else { return nil }
        return a1 + a2
    }

    private var shownFirstToMove: SideId? {
        if manual {
            return InitiativeDice.firstToMove(a1: a1, a2: a2, b1: b1, b2: b2)
        }
        return preview?.firstToMove
    }

    private var shownWinner: SideId? {
        if manual {
            return InitiativeDice.winner(a1: a1, a2: a2, b1: b1, b2: b2)
        }
        return preview?.winner
    }

    private func sideCard(_ side: SideId, first: Binding<Int?>, second: Binding<Int?>) -> some View {
        let total = total(first.wrappedValue, second.wrappedValue)
        let diePrefix = side == .lanceA ? "as.initiative.lanceA" : "as.initiative.lanceB"
        return TMCard(edgeColor: TMColor.side(side), isRaised: true) {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                HStack(alignment: .firstTextBaseline) {
                    SideTag(side: side)
                    Spacer(minLength: TMSpace.sm)
                    if let total {
                        Text("\(total)")
                            .font(TMFont.readoutM)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .accessibilityLabel("Total \(total)")
                    }
                }
                if manual {
                    pickers(prefix: diePrefix, first: first, second: second)
                } else if let die1 = first.wrappedValue, let die2 = second.wrappedValue {
                    DiceReadout(die1: die1, die2: die2)
                        .tmSymbolBounce(value: die1 + die2)
                } else {
                    Text("Not rolled yet")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func pickers(prefix: String, first: Binding<Int?>, second: Binding<Int?>) -> some View {
        DieFacePicker(title: "First die", value: first, accessibilityIdentifier: "\(prefix).die1")
        DieFacePicker(title: "Second die", value: second, accessibilityIdentifier: "\(prefix).die2")
    }

    private func total(_ first: Int?, _ second: Int?) -> Int? {
        guard let first, let second else { return nil }
        return first + second
    }
}

#if DEBUG
#Preview("Initiative") {
    InitiativePreviewHost()
}

private struct InitiativePreviewHost: View {
    @State private var a1: Int? = 6
    @State private var a2: Int? = 5
    @State private var b1: Int? = 2
    @State private var b2: Int? = 2
    @State private var mode: DiceMode = .manual

    var body: some View {
        ScrollView {
            InitiativeStep(
                preview: nil,
                a1: $a1,
                a2: $a2,
                b1: $b1,
                b2: $b2,
                diceMode: $mode,
                onClear: {
                    a1 = nil
                    a2 = nil
                    b1 = nil
                    b2 = nil
                }
            )
            .padding()
        }
    }
}
#endif
