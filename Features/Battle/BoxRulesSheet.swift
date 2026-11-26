import SwiftUI
import MechBuddyDomain

/// Scenario rules for Clash of Steel: Battlefield Support, Formations and buildings (Quick-Start pp. 28–32).
/// Opened from the battle toolbar when the mission uses them.
struct BoxRulesSheet: View {
    @Bindable var store: MatchStore
    /// A Combat Intuition 'Mech is ready to shoot: close this sheet and open the shot sheet for it.
    var onCombatIntuitionAttack: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let session = store.session, let rules = session.boxRules {
                    if !rules.support.isEmpty {
                        supportSection(session, rules)
                    }
                    ForEach(rules.formations) { formation in
                        FormationSection(store: store, session: session, formation: formation) { id in
                            dismiss()
                            onCombatIntuitionAttack(id)
                        }
                    }
                    if !rules.buildings.isEmpty {
                        buildingsSection(rules)
                    }
                    moveCostSection
                }
            }
            .navigationTitle("Scenario rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("cos.rules.done")
                }
            }
        }
    }

    private func supportSection(_ session: MatchSession, _ rules: BoxRulesState) -> some View {
        Section {
            ForEach(session.sideIds.filter { rules.support[$0] != nil }, id: \.self) { side in
                let inventory = rules.support[side]!
                NavigationLink {
                    BattlefieldSupportView(store: store, side: side)
                } label: {
                    LabeledContent(session.displayName(of: side)) {
                        Text(inventory.locked ? "\(inventory.available.count) left" : "Not chosen yet")
                    }
                }
                .accessibilityIdentifier("cos.support.\(side.letter)")
            }
        } header: {
            Text("Battlefield Support")
        } footer: {
            Text("Each side secretly buys \(rules.support.values.first?.budget ?? 5) points before play and calls them in the Combat Phase. 2D6 against the number, no modifiers. Each is used once (pp. 29–30).")
        }
    }

    private func buildingsSection(_ rules: BoxRulesState) -> some View {
        Section {
            ForEach(rules.buildings) { building in
                NavigationLink {
                    BuildingRulesView(store: store, buildingId: building.id)
                } label: {
                    LabeledContent(building.name) {
                        Text(building.collapsed ? "Rubble" : "\(building.type.displayName) · CF \(building.cf)/\(building.startingCF)")
                            .monospacedDigit()
                    }
                }
                .accessibilityIdentifier("cos.building.\(building.id)")
            }
        } header: {
            Text("Buildings")
        } footer: {
            Text("No ’Mech may end its move inside a building. Going through costs extra Move and does 1 damage per inch to the building. Buildings block line of sight and give partial cover like hills (pp. 10, 28).")
        }
    }

    private var moveCostSection: some View {
        Section("Move cost per inch (p. 15)") {
            LabeledContent("Woods", value: "+1″ (Recon Lance +0″)")
            LabeledContent("Rubble or rough", value: "+1″")
            LabeledContent("Small building (Medium)", value: "+2″")
            LabeledContent("Large building (Heavy)", value: "+3″")
            LabeledContent("Level change, up or down", value: "+\(MovementCost.levelChangePerInch)″ per inch, 2″ most")
        }
        .font(TMFont.detail)
    }
}

/// One Formation's bonus and what it has left.
private struct FormationSection: View {
    @Bindable var store: MatchStore
    let session: MatchSession
    let formation: FormationState
    var onAttack: (UUID) -> Void

    @State private var rerollD1: Int?
    @State private var rerollD2: Int?

    private var active: Bool { FormationRules.isActive(formation, units: session.units) }

    private func name(_ id: UUID?) -> String {
        id.flatMap { id in session.units.first { $0.id == id }?.name } ?? "—"
    }

    var body: some View {
        Section {
            if !active {
                Label("Fewer than three of its ’Mechs are left, so the bonus is gone (p. 37).", systemImage: "exclamationmark.triangle")
                    .font(TMFont.detail)
            }
            switch formation.kind {
            case .commandLance: commandLance
            case .reconLance:
                Text("Maneuvering Ace: woods cost 1″ less per inch, so they cost nothing extra.")
                    .font(TMFont.detail)
            case .battleStar:
                LabeledContent("Lucky rerolls left", value: "\(formation.luckyUsesLeft)")
                    .accessibilityIdentifier("cos.lucky.left")
                Text("After a Star ’Mech’s attack roll, tap Lucky on the shot result to roll again. The second roll stands. Not for criticals or Initiative.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("\(formation.name) · \(session.displayName(of: FormationRules.side(of: formation, units: session.units) ?? .lanceA))")
        } footer: {
            Text(formation.memberIds.map(name).joined(separator: ", "))
        }
    }

    @ViewBuilder
    private var commandLance: some View {
        if formation.combatIntuitionIds.isEmpty {
            NavigationLink("Choose Combat Intuition ’Mechs") {
                CombatIntuitionPicker(store: store, session: session, formation: formation)
            }
            .accessibilityIdentifier("cos.ci.choose")
        } else {
            ForEach(formation.combatIntuitionIds, id: \.self) { id in
                combatIntuitionRow(id)
            }
        }
        Text("Combat Intuition: when this side wins Initiative, the ’Mech may move and then attack in the Movement Phase. Damage lands at once, before the target acts. Once every 3 turns (p. 32).")
            .font(TMFont.detail)
            .foregroundStyle(.secondary)
        initiativeReroll
    }

    @ViewBuilder
    private func combatIntuitionRow(_ id: UUID) -> some View {
        let unit = session.units.first { $0.id == id }
        let ready = store.combatIntuitionShooters.contains { $0.id == id }
        HStack {
            VStack(alignment: .leading) {
                Text(name(id)).font(.body.weight(.semibold))
                Text(status(id, unit: unit)).font(TMFont.detail).foregroundStyle(.secondary)
            }
            Spacer()
            if ready {
                Button("Attack now") { onAttack(id) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("cos.ci.attack")
            }
        }
    }

    private func status(_ id: UUID, unit: MatchUnitState?) -> String {
        guard let unit else { return "" }
        if let reason = FormationRules.combatIntuitionBlockReason(formation, unit: unit, session: session) {
            return reason
        }
        return "Ready: attack before the Combat Phase."
    }

    @ViewBuilder
    private var initiativeReroll: some View {
        let can = FormationRules.canRerollInitiative(formation, session: session)
        let beforeMoves = session.phase == .movement && session.initiativeRolls != nil
            && !session.units.contains(where: \.hasMovedThisTurn)
        if can, beforeMoves {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Text("Reroll Initiative").font(.headline)
                Text("While the \(name(formation.commandUnitId)) stands, once a turn. Roll both dice again; the new roll stands, even if it is worse.")
                    .font(TMFont.detail)
                DieFacePicker(title: "Die 1", value: $rerollD1, accessibilityIdentifier: "cos.reroll.d1")
                DieFacePicker(title: "Die 2", value: $rerollD2, accessibilityIdentifier: "cos.reroll.d2")
                Button("Use this roll") {
                    if let a = rerollD1, let b = rerollD2, store.rerollInitiative(formationId: formation.id, die1: a, die2: b) {
                        rerollD1 = nil
                        rerollD2 = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(rerollD1 == nil || rerollD2 == nil)
                .accessibilityIdentifier("cos.reroll.apply")
            }
        } else {
            Text(rerollNote(can: can))
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
        }
    }

    private func rerollNote(can: Bool) -> String {
        if formation.initiativeRerollTurn == session.turn { return "Initiative reroll used this turn." }
        if !can { return "No Initiative reroll: the \(name(formation.commandUnitId)) is destroyed or the lance is broken." }
        return "Initiative reroll: once a turn, after the roll and before anyone moves."
    }
}

/// Pick the two Command Lance 'Mechs with Combat Intuition, at the start of the scenario (p. 32).
private struct CombatIntuitionPicker: View {
    @Bindable var store: MatchStore
    let session: MatchSession
    let formation: FormationState
    @State private var chosen: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                ForEach(formation.memberIds.filter { $0 != formation.commandUnitId }, id: \.self) { id in
                    let unit = session.units.first { $0.id == id }
                    Toggle(unit?.name ?? "", isOn: Binding(
                        get: { chosen.contains(id) },
                        set: { on in if on { chosen.insert(id) } else { chosen.remove(id) } }
                    ))
                    .disabled(!chosen.contains(id) && chosen.count >= formation.combatIntuitionCount)
                }
            } footer: {
                Text("Choose \(formation.combatIntuitionCount). Not the command ’Mech. They can’t change once play starts.")
            }
            Button("Save") {
                store.designateCombatIntuition(formationId: formation.id, unitIds: Array(chosen))
                if store.lastError == nil { dismiss() }
            }
            .disabled(chosen.count != formation.combatIntuitionCount)
            .accessibilityIdentifier("cos.ci.save")
        }
        .navigationTitle("Combat Intuition")
    }
}
