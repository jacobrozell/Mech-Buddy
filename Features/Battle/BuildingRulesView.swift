import SwiftUI
import MechBuddyDomain

/// One building: CF, damage from moving through or shots, and collapse (Quick-Start p. 28).
struct BuildingRulesView: View {
    @Bindable var store: MatchStore
    let buildingId: String

    @State private var throughInches = 2
    @State private var attackerId: UUID?
    @State private var bracket: RangeBracket = .short
    @State private var d1: Int?
    @State private var d2: Int?
    @State private var inside: Set<UUID> = []
    @State private var onRoof: Set<UUID> = []

    private var session: MatchSession? { store.session }
    private var building: BuildingState? { session?.boxRules?.building(buildingId) }

    var body: some View {
        if let building, let session {
            List {
                summary(building)
                if !building.collapsed {
                    moveThrough(building)
                    if session.phase == .combat {
                        attack(building, session)
                    }
                }
                collapse(building, session)
            }
            .navigationTitle(building.name)
        }
    }

    private func summary(_ b: BuildingState) -> some View {
        Section {
            LabeledContent("CF", value: b.collapsed ? "Rubble" : "\(b.cf) of \(b.startingCF)")
                .accessibilityIdentifier("cos.building.cf")
            LabeledContent("Move through", value: "+\(b.type.moveCostPerInch)″ per inch")
            LabeledContent("Holds", value: "Size \(b.type.weightCapacity) on the roof")
            Stepper("Height \(b.heightInches)″", value: Binding(
                get: { b.heightInches }, set: { store.setBuildingHeight(b.id, inches: $0) }
            ), in: 1...12)
            LabeledContent("Collapse damage", value: "\(BuildingRules.collapseDamage(b.type, heightInches: b.heightInches, onRoof: false)), \(BuildingRules.collapseDamage(b.type, heightInches: b.heightInches, onRoof: true)) on the roof")
        } header: {
            Text(b.type.displayName)
        } footer: {
            Text(b.collapsed ? "Rubble: +1″ per inch to cross; no effect on line of sight or shots (p. 11)." : "A Heavy building stays Heavy however low its CF gets (p. 28).")
        }
    }

    private func moveThrough(_ b: BuildingState) -> some View {
        Section {
            Stepper("Inches inside: \(throughInches)", value: $throughInches, in: 1...12)
            Button("Apply \(throughInches) damage") { store.damageBuilding(b.id, amount: throughInches) }
                .accessibilityIdentifier("cos.building.through")
        } header: {
            Text("A ’Mech moved through it")
        } footer: {
            Text("1 damage to the building per inch. It costs the ’Mech \(BuildingRules.extraMoveCost(b.type, inches: throughInches))″ extra Move. It can’t end its move inside.")
        }
    }

    @ViewBuilder
    private func attack(_ b: BuildingState, _ session: MatchSession) -> some View {
        let shooters = session.units.filter(\.canAttackThisTurn)
        Section {
            Picker("Shooter", selection: $attackerId) {
                Text("Choose").tag(UUID?.none)
                ForEach(shooters) { Text($0.name).tag(Optional($0.id)) }
            }
            Picker("Range", selection: $bracket) {
                Text("Short").tag(RangeBracket.short)
                Text("Medium").tag(RangeBracket.medium)
                Text("Long").tag(RangeBracket.long)
            }
            .pickerStyle(.segmented)
            if let attacker = shooters.first(where: { $0.id == attackerId }) {
                let move = attacker.movementMode == .unset ? MovementMode.ground : attacker.movementMode
                if let tn = try? BuildingRules.attackTargetNumber(attacker: attacker, attackerMove: move, bracket: bracket) {
                    LabeledContent("Needs", value: "\(tn.value)+ (immobile −4)")
                    DieFacePicker(title: "Die 1", value: $d1, accessibilityIdentifier: "cos.building.d1")
                    DieFacePicker(title: "Die 2", value: $d2, accessibilityIdentifier: "cos.building.d2")
                    Button("Apply shot") {
                        guard let d1, let d2 else { return }
                        if store.attackBuilding(b.id, attackerId: attacker.id, bracket: bracket, die1: d1, die2: d2, attackerMove: move) {
                            self.d1 = nil
                            self.d2 = nil
                            attackerId = nil
                        }
                    }
                    .disabled(d1 == nil || d2 == nil)
                }
            }
        } header: {
            Text("Shoot at it")
        } footer: {
            Text("Resolved as an immobile target. A hit takes the shooter’s damage at that range off the CF. This is the shooter’s attack for the turn.")
        }
    }

    @ViewBuilder
    private func collapse(_ b: BuildingState, _ session: MatchSession) -> some View {
        let units = session.units.filter { $0.combatStatus != .removed }
        let roofSizes = units.filter { onRoof.contains($0.id) }.map(\.sz)
        Section {
            ForEach(units) { unit in
                Picker(unit.name, selection: Binding(
                    get: { onRoof.contains(unit.id) ? 2 : (inside.contains(unit.id) ? 1 : 0) },
                    set: { v in
                        inside.remove(unit.id)
                        onRoof.remove(unit.id)
                        if v == 1 { inside.insert(unit.id) }
                        if v == 2 { onRoof.insert(unit.id) }
                    }
                )) {
                    Text("Clear").tag(0)
                    Text("Moving through").tag(1)
                    Text("On the roof").tag(2)
                }
            }
            if !roofSizes.isEmpty {
                let total = roofSizes.reduce(0, +)
                Text(BuildingRules.isOverCapacity(b.type, sizes: roofSizes)
                     ? "Size \(total) on the roof is more than \(b.type.weightCapacity): it collapses."
                     : "Size \(total) of \(b.type.weightCapacity) on the roof: it holds.")
                    .font(.subheadline.weight(.semibold))
            }
            Button(b.collapsed ? "Apply collapse damage" : "Collapse it now", role: .destructive) {
                if store.collapseBuilding(b.id, inside: Array(inside), onRoof: Array(onRoof), minimalDice: [:]) {
                    inside = []
                    onRoof = []
                }
            }
            .disabled(b.collapsed && inside.isEmpty && onRoof.isEmpty)
            .accessibilityIdentifier("cos.building.collapse")
        } header: {
            Text("Collapse")
        } footer: {
            Text("It collapses at CF 0 or when the roof holds more than its capacity. Each ’Mech moving through or on it takes the collapse damage; +1 on the roof. Then it is rubble (p. 28).")
        }
    }
}
