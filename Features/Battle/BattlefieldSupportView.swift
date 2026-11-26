import SwiftUI
import MechBuddyDomain

/// One side's secret Battlefield Support: buy before play, then call each once in the Combat Phase (pp. 29–30).
struct BattlefieldSupportView: View {
    @Bindable var store: MatchStore
    let side: SideId

    @State private var counts: [BattlefieldSupportType: Int] = [:]
    @State private var revealed = false

    private var session: MatchSession? { store.session }
    private var inventory: SupportInventory? { session?.boxRules?.support[side] }

    private var picks: [BattlefieldSupportType] {
        BattlefieldSupportType.allCases.flatMap { Array(repeating: $0, count: counts[$0] ?? 0) }
    }

    var body: some View {
        List {
            if let inventory {
                if inventory.locked {
                    lockedView(inventory)
                } else {
                    shop(inventory)
                }
            }
        }
        .navigationTitle(session?.displayName(of: side) ?? side.displayName)
    }

    @ViewBuilder
    private func shop(_ inventory: SupportInventory) -> some View {
        let spent = BattlefieldSupportRules.cost(of: picks)
        Section {
            ForEach(BattlefieldSupportType.allCases, id: \.self) { type in
                Stepper(value: Binding(get: { counts[type] ?? 0 }, set: { counts[type] = $0 }), in: 0...6) {
                    VStack(alignment: .leading) {
                        Text("\(type.displayName) ×\(counts[type] ?? 0)").font(.body.weight(.semibold))
                        Text(describe(type)).font(TMFont.detail).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("cos.support.buy.\(type.rawValue)")
            }
        } header: {
            Text("Hand the phone to this side · \(spent) of \(inventory.budget) points")
                .monospacedDigit()
        } footer: {
            Text("Keep it secret. Points you don’t spend are lost. You can’t change it after you write it down.")
        }
        Button("Write it down") {
            store.setSupportPicks(side: side, picks: picks)
            if store.lastError == nil { store.lockSupportPicks(side: side) }
        }
        .disabled(spent > inventory.budget || picks.isEmpty)
        .accessibilityIdentifier("cos.support.lock")
    }

    private func describe(_ type: BattlefieldSupportType) -> String {
        let target = type.isArtillery ? "a point" : (type.usesTemplate ? "a ’Mech or a point" : "a ’Mech")
        let area = type.usesTemplate ? ", template, scatters on a miss" : ""
        return "\(type.cost) pts · hits on \(type.targetNumber)+ · \(type.damage) damage · \(target)\(area)"
    }

    @ViewBuilder
    private func lockedView(_ inventory: SupportInventory) -> some View {
        if revealed {
            Section {
                ForEach(inventory.picks) { pick in
                    if pick.isUsed {
                        LabeledContent(pick.type.displayName, value: "Used turn \(pick.usedOnTurn ?? 0)")
                            .foregroundStyle(.secondary)
                    } else if session?.phase == .combat {
                        NavigationLink {
                            UseSupportView(store: store, side: side, pickId: pick.id)
                        } label: {
                            LabeledContent(pick.type.displayName, value: "Call it")
                        }
                        .accessibilityIdentifier("cos.support.use.\(pick.type.rawValue)")
                    } else {
                        LabeledContent(pick.type.displayName, value: "Combat Phase")
                    }
                }
            } footer: {
                Text("Declared in the Combat Phase. Say which type you use; the rest stay secret.")
            }
            Button("Hide") { revealed = false }
        } else {
            Section {
                Button("Show this side’s support") { revealed = true }
                    .accessibilityIdentifier("cos.support.reveal")
            } footer: {
                Text("\(inventory.available.count) still to use. Only this side should look.")
            }
        }
    }
}

/// Call one support: 2D6 against its number, then who is hit (pp. 29–30).
private struct UseSupportView: View {
    @Bindable var store: MatchStore
    let side: SideId
    let pickId: UUID

    @State private var d1: Int?
    @State private var d2: Int?
    @State private var direction: Int?
    @State private var distance: Int?
    @State private var hitIds: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss

    private var pick: SupportPick? { store.session?.boxRules?.support[side]?.picks.first { $0.id == pickId } }

    private var isHit: Bool? {
        guard let pick, let d1, let d2 else { return nil }
        return d1 + d2 >= pick.type.targetNumber
    }

    var body: some View {
        if let pick, let session = store.session {
            let type = pick.type
            List {
                Section {
                    Text("Roll 2D6. \(type.targetNumber) or more hits. No modifiers.")
                    DieFacePicker(title: "Die 1", value: $d1, accessibilityIdentifier: "cos.support.d1")
                    DieFacePicker(title: "Die 2", value: $d2, accessibilityIdentifier: "cos.support.d2")
                    if let isHit {
                        Text(isHit ? "Hit" : (type.scattersOnMiss ? "Missed: it scatters" : "Missed: nothing happens"))
                            .font(.headline)
                            .accessibilityIdentifier("cos.support.result")
                    }
                } header: {
                    Text("\(type.displayName) · \(type.damage) damage")
                }
                if isHit == false, type.scattersOnMiss {
                    Section {
                        DieFacePicker(title: "Direction (1 is north)", value: $direction, accessibilityIdentifier: "cos.support.dir")
                        DieFacePicker(title: "Distance die", value: $distance, accessibilityIdentifier: "cos.support.dist")
                        if let direction, let distance {
                            Text("It lands \(distance * 2)″ from the aim point, toward \(direction) on the template.")
                                .font(.subheadline.weight(.semibold))
                        }
                    } header: {
                        Text("Scatter")
                    }
                }
                if let isHit, isHit || type.scattersOnMiss {
                    Section {
                        ForEach(session.units.filter { $0.combatStatus != .removed }) { unit in
                            Toggle(unit.name, isOn: Binding(
                                get: { hitIds.contains(unit.id) },
                                set: { on in
                                    if !type.usesTemplate { hitIds = [] }
                                    if on { hitIds.insert(unit.id) } else { hitIds.remove(unit.id) }
                                }
                            ))
                        }
                    } header: {
                        Text(type.usesTemplate ? "’Mechs the template touches (friend or foe)" : "Target ’Mech")
                    }
                }
                Button("Apply") {
                    guard let d1, let d2 else { return }
                    let hit = isHit == true
                    let ids = (hit || type.scattersOnMiss) ? Array(hitIds) : []
                    if store.useSupport(side: side, pickId: pickId, die1: d1, die2: d2,
                                        scatterDirection: hit ? nil : direction, scatterDistance: hit ? nil : distance,
                                        unitsHit: ids) {
                        dismiss()
                    }
                }
                .disabled(!canApply(type))
                .accessibilityIdentifier("cos.support.apply")
            }
            .navigationTitle(type.displayName)
        }
    }

    private func canApply(_ type: BattlefieldSupportType) -> Bool {
        guard let isHit else { return false }
        if isHit { return type.usesTemplate || hitIds.count == 1 }
        return !type.scattersOnMiss || (direction != nil && distance != nil)
    }
}
