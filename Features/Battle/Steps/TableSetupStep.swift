import SwiftUI
import MechBuddyDomain
import MechBuddyData

struct TableSetupStep: View {
    var session: MatchSession
    var scenario: ScenarioPresentation
    var canSwap: Bool
    var onSwap: () -> Void
    /// Tag a miniature's colour. Nil hides the control (previews).
    var onSetMini: ((UUID, MiniMarker?) -> Void)?

    @State private var checked: Set<Int> = []
    @Namespace private var sides
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow(session.isPlayGame ? "Game briefing" : "Mission briefing")
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
                if let skill = sharedSkill {
                    // Printed cards leave Skill blank; players asked what to write there.
                    Label("Every ’Mech uses Skill \(skill). Write it on the card’s blank Skill line.", systemImage: "pencil")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("as.mission.skill")
                } else if session.isPlayGame {
                    Label("Pilots differ. Write each ’Mech’s Skill on its card’s blank Skill line: "
                        + session.units.map { "\($0.name) \($0.skill)" }.joined(separator: ", ") + ".", systemImage: "pencil")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("as.mission.skill")
                }
            }

            if !scenario.introduces.isEmpty {
                newInThisMission
            }

            if let layout = scenario.layout {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    Eyebrow("Table layout")
                    MissionMapsSection(layout: layout, ownedMaps: nil, missionId: scenario.id.isEmpty ? nil : scenario.id)
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

    /// Missions after Ridge Line: what is new, plus the coach's tips for it.
    private var newInThisMission: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow("New in this mission")
            TMCard {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    Label {
                        Text(scenario.introduces.joined(separator: " · "))
                            .font(TMFont.cardTitle)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(TMColor.signal)
                    }
                    ForEach(Array(scenario.coachNotes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
                            Image(systemName: "lightbulb")
                                .font(TMFont.detail)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(note)
                                .font(TMFont.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("as.mission.newRules")
    }

    private var sharedSkill: Int? {
        let skills = Set(session.units.map(\.skill))
        return skills.count == 1 ? skills.first : nil
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
                            .fixedSize(horizontal: false, vertical: true)
                            .matchedGeometryEffect(id: unit.id, in: sides)
                        if let onSetMini {
                            MiniMarkerMenu(unitName: unit.name, marker: unit.mini) { onSetMini(unit.id, $0) }
                        }
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
        // Contain, not combine, once the mini menus are there: VoiceOver must reach them.
        .accessibilityElement(children: onSetMini == nil ? .combine : .contain)
        .accessibilityLabel(sideLabel(side, units: units))
    }

    private func sideLabel(_ side: SideId, units: [MatchUnitState]) -> String {
        let names = units.map(\.name).joined(separator: ", ")
        let title = session.displayName(of: side)
        return names.isEmpty ? title : "\(title). \(names)"
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
