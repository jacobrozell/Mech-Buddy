import SwiftUI
import MechBuddyDomain

struct TableSetupStep: View {
    var session: MatchSession
    var scenario: ScenarioPresentation
    var canSwap: Bool
    var onSwap: () -> Void

    @State private var checked: Set<Int> = []
    @Namespace private var sides
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow("Mission briefing")
                Text("Set up the table, pick sides, then start.")
                    .font(TMFont.body)
                if let subtitle = scenario.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: TMSpace.md) {
                HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
                    Text("Who’s who")
                        .font(TMFont.eyebrow)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: TMSpace.sm)
                    if canSwap {
                        Button(action: swap) {
                            Label("Swap", systemImage: "arrow.left.arrow.right")
                                .labelStyle(.titleAndIcon)
                                .font(TMFont.detail.weight(.semibold))
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Swap sides")
                        .accessibilityHint("Trades which player has which ’Mechs")
                        .accessibilityIdentifier("as.battle.swapSides")
                    }
                }
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: TMSpace.md) {
                        sideCard(.lanceA)
                        sideCard(.lanceB)
                    }
                } else {
                    HStack(alignment: .top, spacing: TMSpace.md) {
                        sideCard(.lanceA)
                        sideCard(.lanceB)
                    }
                }
            }

            VStack(alignment: .leading, spacing: TMSpace.md) {
                Eyebrow("Set the table") {
                    Text("\(checked.count) of \(scenario.tableSteps.count)")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                TMCard {
                    VStack(alignment: .leading, spacing: TMSpace.sm) {
                        ForEach(Array(scenario.tableSteps.enumerated()), id: \.offset) { index, step in
                            ChecklistRow(
                                title: "\(index + 1). \(step)",
                                isChecked: checked.contains(index),
                                onToggle: { toggle(index) }
                            )
                        }
                    }
                }
            }

            if let winning = scenario.winningSummary, !winning.isEmpty {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    Eyebrow("How you win")
                    TMCard {
                        HStack(alignment: .top, spacing: TMSpace.sm) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(TMColor.signal)
                                .accessibilityHidden(true)
                            Text(winning)
                                .font(TMFont.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sideCard(_ side: SideId) -> some View {
        let units = session.units.filter { $0.side == side }
        return TMCard(edgeColor: TMColor.side(side), isRaised: true) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                SideTag(side: side)
                if units.isEmpty {
                    Text("No ’Mechs")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                ForEach(units) { unit in
                    VStack(alignment: .leading, spacing: TMSpace.xs) {
                        Text(unit.name)
                            .font(TMFont.cardTitle)
                            .matchedGeometryEffect(id: unit.id, in: sides)
                        HealthReadout(
                            armorRemaining: unit.remainingArmor,
                            armorCapacity: unit.armorCap,
                            structureRemaining: unit.remainingStructure,
                            structureCapacity: unit.structureCap,
                            size: .compact
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sideLabel(side, units: units))
    }

    private func sideLabel(_ side: SideId, units: [MatchUnitState]) -> String {
        let names = units.map(\.name).joined(separator: ", ")
        return names.isEmpty ? side.displayName : "\(side.displayName). \(names)"
    }

    private func toggle(_ index: Int) {
        if checked.contains(index) {
            checked.remove(index)
        } else {
            checked.insert(index)
        }
    }

    private func swap() {
        if reduceMotion {
            onSwap()
        } else {
            withAnimation(TMMotion.state) {
                onSwap()
            }
        }
    }
}

#if DEBUG
#Preview("Table setup") {
    ScrollView {
        TableSetupStep(
            session: {
                var session = PreviewFixtures.session()
                session.tableReady = false
                return session
            }(),
            scenario: ScenarioPresentation(
                title: "Ridge Line",
                subtitle: "Beginner mission",
                tableSteps: [
                    "Put both maps grassland-side up",
                    "Keep a tape measure nearby"
                ],
                winningSummary: "Knock out both enemy ’Mechs."
            ),
            canSwap: true,
            onSwap: {}
        )
        .padding()
    }
}
#endif
