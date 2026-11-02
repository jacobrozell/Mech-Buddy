import SwiftUI
import MechBuddyDomain

/// Visual walkthrough for Ridge Line. Game math stays in the Rules tab.
struct HowToPlayRidgeLineView: View {
    var onPlay: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                TMCard {
                    Text("Two players · four ’Mechs · about 40 minutes. The phone tells you the next tap.")
                        .font(TMFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                tabs
                steps
                winning
                leaving
                if let onPlay {
                    PrimaryActionButton(title: "Play Ridge Line", tint: TMColor.signal, action: onPlay)
                }
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("How to play")
        .accessibilityIdentifier("as.howToPlay.screen")
    }

    private var tabs: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("The four tabs")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TMSpace.md) {
                tabTile("Play", "flag.checkered", "Start Ridge Line, or resume the game you left.")
                tabTile("Force", "shield.lefthalf.filled", "The four ’Mechs and the numbers on their cards.")
                tabTile("Rules", "book", "Plain-language reminders if you get stuck.")
                tabTile("Settings", "gearshape", "Dice, haptics, appearance, and legal.")
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow("A turn has four steps")
            Text("The button at the bottom of the battle screen is the next action. Pass the phone when it says to.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            PhaseTrack(current: .initiative, identifiesPhases: false)
            stepCard(
                title: "Roll dice",
                symbol: "dice",
                copy: "Each side rolls two dice on the table and types the numbers. The higher total goes last this turn, so they can react. Same total? Roll again."
            ) {
                SampleDice()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            stepCard(
                title: "Move",
                symbol: "figure.walk",
                copy: "The side that lost moves a miniature first. Measure with the tape, then record Stood still, Walked, Sprinted, or Jumped. Then the other side, until every ’Mech has a move."
            ) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TMSpace.sm) {
                        sampleChip("Stood still")
                        sampleChip("Walked")
                        sampleChip("Jumped")
                    }
                    VStack(spacing: TMSpace.sm) {
                        sampleChip("Stood still")
                        sampleChip("Walked")
                        sampleChip("Jumped")
                    }
                }
                .accessibilityHidden(true)
            }
            stepCard(
                title: "Shoot",
                symbol: "scope",
                copy: "Measure to the target, then tap Solve a shot. The app shows the number to beat. Type what you rolled and it applies the damage. A wreck can still shoot until Clean up."
            ) {
                TNGauge(
                    targetNumber: 7,
                    previewIdentifier: "as.howToPlay.sampleTN",
                    gaugeIdentifier: nil
                )
                .allowsHitTesting(false)
            }
            stepCard(
                title: "Clean up",
                symbol: "checklist",
                copy: "Pick up any ’Mech whose Structure hit 0, then tap the button. If nobody has won, the next turn starts at Roll dice. Ridge Line lasts at most 6 turns."
            ) {
                UnitCard(
                    unit: Self.wreckedSample,
                    isActiveSide: false,
                    showsStats: true,
                    accessibilityIdentifier: "as.howToPlay.sampleWreck",
                    action: {}
                )
                .allowsHitTesting(false)
            }
        }
    }

    private var winning: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("How you win")
            TMCard {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    Label("Knock them out, or last 6 turns", systemImage: "trophy")
                        .font(TMFont.cardTitle)
                    Text("Knock out both enemy ’Mechs. After turn 6, the side with more structure left wins. Equal structure is a draw.")
                        .font(TMFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                    TurnCounter(turn: 6, maxTurns: 6)
                    Text("Then you can rematch, or go back to Play.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var leaving: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Leave and come back")
            Text("Leave saves the game. Play shows Continue, with the turn and the step.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ResumeCard(
                title: "Ridge Line",
                turn: 3,
                maxTurns: 6,
                phase: .combat,
                sideAStructureRemaining: 8,
                sideAStructureCapacity: 10,
                sideBStructureRemaining: 4,
                sideBStructureCapacity: 10,
                continueIdentifier: "as.howToPlay.sampleResume",
                onContinue: {}
            )
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Example. Continue Ridge Line, turn 3 of 6, Shoot step")
            Text("Discard this game, in the ••• menu, throws that progress away.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tabTile(_ title: String, _ symbol: String, _ detail: String) -> some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(TMFont.cardTitle)
                Text(detail)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stepCard<Sample: View>(
        title: String,
        symbol: String,
        copy: String,
        @ViewBuilder sample: @escaping () -> Sample
    ) -> some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                Label(title, systemImage: symbol)
                    .font(TMFont.cardTitle)
                Text(copy)
                    .font(TMFont.body)
                    .fixedSize(horizontal: false, vertical: true)
                sample()
            }
        }
    }

    private func sampleChip(_ title: String) -> some View {
        Text(title)
            .font(TMFont.detail.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous))
    }

    private static let wreckedSample = MatchUnitState(
        name: "Locust LCT-1V",
        side: .lanceB,
        pv: 18,
        sz: 1,
        mv: "16\"",
        tmm: 3,
        s: 1,
        m: 1,
        l: 0,
        ov: 0,
        armorCap: 2,
        structureCap: 2,
        armorDamage: 2,
        structureDamage: 2,
        combatStatus: .destroyedPendingEnd
    )
}

private struct SampleDice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            DieFacePicker(title: "First die", value: .constant(Int?(4)))
            DieFacePicker(title: "Second die", value: .constant(Int?(3)))
        }
    }
}

#if DEBUG
#Preview("How to play") {
    NavigationStack {
        HowToPlayRidgeLineView(onPlay: {})
    }
}
#endif
