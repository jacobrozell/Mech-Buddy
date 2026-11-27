import SwiftUI
import MechBuddyDomain

/// Initiative for three or four sides **[HOUSE]** (PlayModeSpec § 6.1). Every side rolls 2D6; lowest moves first,
/// highest moves last; tied sides roll again among themselves. Two-side games keep `InitiativeStep`.
struct MultiSideInitiativeStep: View {
    var sides: [SideId]
    /// Dice typed in, round by round (real dice).
    @Binding var rounds: [[SideId: InitiativeEntry.Dice]]
    /// Dice the app rolled, shown read-only (let the app roll).
    var autoEntry: InitiativeEntry?
    var diceMode: Binding<DiceMode>
    var onChooseOrder: (([SideId]) -> Void)?

    @Environment(\.sideNames) private var sideNames
    @State private var choosing = false
    @State private var chosen: [SideId] = []

    private var manual: Bool { diceMode.wrappedValue == .manual }
    private var entry: InitiativeEntry {
        manual ? InitiativeEntry(sides: sides, rounds: rounds) : (autoEntry ?? InitiativeEntry(sides: sides))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            CoachPrompt(
                title: "Roll for initiative",
                message: "[HOUSE] Every side rolls two dice. Lowest total moves first, highest moves last, as on p. 13. Sides that tie roll again, and only those sides.",
                help: "Three or more sides isn’t in the Quick-Start. The last side to move sees where everyone else went.",
                accessibilityIdentifier: "as.battle.table"
            )
            ForEach(entry.visibleRounds, id: \.round) { round in
                roundSection(round)
            }
            result
            DiceModeLink(mode: diceMode, accessibilityIdentifier: "as.battle.rollInit")
            if onChooseOrder != nil {
                chooseOrder
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Rounds

    @ViewBuilder
    private func roundSection(_ round: InitiativeEntry.Pending) -> some View {
        if round.round > 0 {
            let names = round.sides.map { sideNames($0) }.joined(separator: " and ")
            Eyebrow("Tie: \(names) roll again")
                .accessibilityIdentifier("as.initiative.tieHint")
        }
        ForEach(round.sides, id: \.self) { side in
            sideCard(side, round: round.round)
        }
    }

    private func sideCard(_ side: SideId, round: Int) -> some View {
        let dice = entry.dice(round: round, side: side)
        let prefix = round == 0 ? "as.initiative.\(side.rawValue)" : "as.initiative.reroll\(round).\(side.rawValue)"
        return TMCard(edgeColor: TMColor.side(side), isRaised: true) {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                HStack(alignment: .firstTextBaseline) {
                    SideTag(side: side)
                    Spacer(minLength: TMSpace.sm)
                    if let total = dice.total {
                        Text("\(total)")
                            .font(TMFont.readoutM)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .accessibilityLabel("Total \(total)")
                    }
                }
                if manual {
                    DieFacePicker(title: "First die", value: binding(round: round, side: side, die: 1), accessibilityIdentifier: "\(prefix).die1")
                    DieFacePicker(title: "Second die", value: binding(round: round, side: side, die: 2), accessibilityIdentifier: "\(prefix).die2")
                } else if let die1 = dice.die1, let die2 = dice.die2 {
                    DiceReadout(die1: die1, die2: die2)
                } else {
                    Text("Not rolled yet")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func binding(round: Int, side: SideId, die: Int) -> Binding<Int?> {
        Binding(
            get: {
                let dice = InitiativeEntry(sides: sides, rounds: rounds).dice(round: round, side: side)
                return die == 1 ? dice.die1 : dice.die2
            },
            set: { value in
                var next = InitiativeEntry(sides: sides, rounds: rounds)
                next.set(round: round, side: side, die: die, value: value)
                rounds = next.rounds
            }
        )
    }

    // MARK: Result

    @ViewBuilder
    private var result: some View {
        if let order = entry.order, let last = order.last {
            TMCard(edgeColor: TMColor.side(last), isRaised: true) {
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    Text("\(sideNames(last)) wins initiative · \(sideNames(order[0])) moves first")
                        .font(TMFont.cardTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: TMSpace.xs) {
                        ForEach(Array(order.enumerated()), id: \.element) { index, side in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            SideBadge(side: side)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Order: " + order.map { sideNames($0) }.joined(separator: ", then "))
                }
            }
            .accessibilityIdentifier("as.initiative.order")
        }
    }

    // MARK: Players choose the order

    @ViewBuilder
    private var chooseOrder: some View {
        if choosing {
            TMCard(isRaised: true) {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    Text("Put the sides in order, first to move at the top")
                        .font(TMFont.cardTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(chosen.enumerated()), id: \.element) { index, side in
                        HStack(spacing: TMSpace.sm) {
                            Text("\(index + 1)")
                                .font(TMFont.stat)
                                .monospacedDigit()
                                .frame(width: 24)
                            SideTag(side: side)
                            Spacer(minLength: TMSpace.sm)
                            moveButton("chevron.up", "Move \(sideNames(side)) up", disabled: index == 0) { chosen.swapAt(index, index - 1) }
                            moveButton("chevron.down", "Move \(sideNames(side)) down", disabled: index == chosen.count - 1) { chosen.swapAt(index, index + 1) }
                        }
                        .accessibilityIdentifier("as.initiative.choose.\(side.rawValue)")
                    }
                    Button {
                        onChooseOrder?(chosen)
                    } label: {
                        Text("Use this order").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TMColor.signal)
                    .foregroundStyle(TMColor.onSignal)
                    .accessibilityIdentifier("as.initiative.choose.confirm")
                    Button("Cancel") { choosing = false }
                        .frame(minHeight: 44)
                }
            }
        } else {
            Button {
                chosen = sides
                choosing = true
            } label: {
                Label("Skip the roll — we’ll choose the order", systemImage: "hand.raised")
                    .font(TMFont.detail.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("as.initiative.agree")
            .accessibilityHint("Drag-free: put the sides in order with the arrow buttons. Moving first gives the others the advantage.")
        }
    }

    private func moveButton(_ symbol: String, _ label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}
