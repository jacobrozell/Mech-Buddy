import SwiftUI
import MechBuddyData

// "Your collection" on the Force tab, its edit sheet, and the rows onboarding shares.
// Spec: specs/features/RosterSpec.md § Your collection

// MARK: - Force tab section

struct ForceCollectionSection: View {
    /// `nil` until the player has answered "Which boxes do you own?".
    var collection: OwnedCollection?
    var boxes: [BoxSetDTO]
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Your collection") {
                if collection != nil {
                    Button("Edit", action: onEdit)
                        .font(TMFont.detail.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Edit collection")
                        .accessibilityHint("Add or remove boxes and ’Mechs")
                        .accessibilityIdentifier("force.collection.edit")
                }
            }
            if let collection {
                let groups = CollectionMath.groups(collection, boxes: boxes)
                if groups.isEmpty {
                    TMCard {
                        Text("No minis yet. Coins or any minis work as stand-ins. Add boxes or ’Mechs when you get them.")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("force.collection.empty")
                } else {
                    ForEach(groups) { group in
                        CollectionGroupCard(group: group, copies: copies(of: group, in: collection))
                    }
                }
            } else {
                startCard
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("force.collection")
    }

    private func copies(of group: CollectionGroup, in collection: OwnedCollection) -> Int {
        if case .box(let box) = group.source { return collection.copies(ofBox: box.id) }
        return 0
    }

    private var startCard: some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    Text("Which boxes do you own?")
                        .font(TMFont.cardTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Add them and each mission will say which minis you have.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                SecondaryActionButton(
                    title: "Add your boxes",
                    systemImage: "shippingbox",
                    accessibilityIdentifier: "force.collection.start",
                    action: onEdit
                )
            }
        }
    }
}

/// One box (or Singles): what you have, then what's missing.
private struct CollectionGroupCard: View {
    var group: CollectionGroup
    /// Boxes owned; 0 for Singles.
    var copies: Int

    private var have: [CollectionUnit] { group.units.filter { $0.have > 0 } }
    private var missing: [CollectionUnit] { group.units.filter { $0.have < $0.listed } }

    private var unconfirmed: Bool {
        if case .box(let box) = group.source { return !box.contentsConfirmed }
        return false
    }

    var body: some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
                    Text(group.title)
                        .font(TMFont.cardTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    if copies > 1 {
                        Text("×\(copies)")
                            .font(TMFont.stat)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(copies) copies")
                    }
                }
                if unconfirmed {
                    Text("List not confirmed yet. Add its ’Mechs as singles.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !have.isEmpty {
                    Text(have.map(label).joined(separator: " · "))
                        .font(TMFont.detail)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !missing.isEmpty {
                    Label(
                        "Missing: \(CollectionMath.naturalList(missing.map { PlayForceMath.shortName($0.name) }))",
                        systemImage: "circle.dashed"
                    )
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("force.collection.\(group.id)")
    }

    private func label(_ unit: CollectionUnit) -> String {
        unit.have > 1 ? "\(unit.name) ×\(unit.have)" : unit.name
    }
}

// MARK: - Edit sheet

struct CollectionEditSheet: View {
    var boxes: [BoxSetDTO]
    var onSave: (OwnedCollection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: OwnedCollection

    init(boxes: [BoxSetDTO], initial: OwnedCollection?, onSave: @escaping (OwnedCollection) -> Void) {
        self.boxes = boxes
        self.onSave = onSave
        _draft = State(initialValue: initial ?? .empty)
    }

    private var owned: [BoxSetDTO] { boxes.filter { draft.owns(box: $0.id) } }

    private var singles: [CollectionUnit] {
        CollectionMath.groups(OwnedCollection(singles: draft.singles), boxes: []).first?.units ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(boxes) { box in
                        boxRow(box)
                    }
                } header: {
                    Text("Boxes")
                } footer: {
                    Text("Set how many of each box you own.")
                }
                ForEach(owned) { box in
                    Section {
                        if box.contentsConfirmed {
                            ForEach(uniqueUnits(box), id: \.self) { unit in
                                Toggle(isOn: unitBinding(unit, in: box)) {
                                    Text(unitLabel(unit, in: box))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("force.collection.unit.\(box.id).\(unit)")
                            }
                        } else {
                            CollectionUnconfirmedNote(identifier: "force.collection.unconfirmed.\(box.id)")
                        }
                    } header: {
                        Text(box.title)
                    } footer: {
                        if box.contentsConfirmed {
                            Text("Turn off any you’re missing.")
                        }
                    }
                }
                Section {
                    ForEach(singles) { unit in
                        Stepper(value: singleBinding(unit.name), in: 0...20) {
                            Text(unit.have > 1 ? "\(unit.name) ×\(unit.have)" : unit.name)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("force.collection.single.\(unit.name)")
                    }
                    .onDelete { offsets in
                        for offset in offsets {
                            draft.setSingle(singles[offset].name, copies: 0)
                        }
                    }
                    CollectionAddField(idPrefix: "force.collection", boxed: false) { draft.addSingle($0) }
                } header: {
                    Text("Singles")
                } footer: {
                    Text("’Mechs you have outside a box. Just the name is fine: “Atlas” covers any Atlas.")
                }
            }
            .navigationTitle("Your collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("force.collection.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(draft)
                        dismiss()
                    }
                    .accessibilityIdentifier("force.collection.done")
                }
            }
        }
        .accessibilityIdentifier("force.collection.sheet")
    }

    private func boxRow(_ box: BoxSetDTO) -> some View {
        let copies = draft.copies(ofBox: box.id)
        return Stepper(value: copiesBinding(box), in: 0...9) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(box.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(ownedText(copies)) · \(box.game.badge) · \(box.miniCount) minis")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("force.collection.sheet.box.\(box.id)")
    }

    private func ownedText(_ copies: Int) -> String {
        switch copies {
        case 0: "Not owned"
        case 1: "Owned"
        default: "\(copies) owned"
        }
    }

    private func unitLabel(_ unit: String, in box: BoxSetDTO) -> String {
        let listed = box.units.filter { $0 == unit }.count * draft.copies(ofBox: box.id)
        return listed > 1 ? "\(unit) ×\(listed)" : unit
    }

    private func uniqueUnits(_ box: BoxSetDTO) -> [String] {
        var seen = Set<String>()
        return box.units.filter { seen.insert($0).inserted }
    }

    private func copiesBinding(_ box: BoxSetDTO) -> Binding<Int> {
        Binding(
            get: { draft.copies(ofBox: box.id) },
            set: { draft.setCopies($0, ofBox: box.id) }
        )
    }

    private func unitBinding(_ unit: String, in box: BoxSetDTO) -> Binding<Bool> {
        Binding(
            get: { draft.have(unit, in: box) > 0 },
            set: { draft.setUnit(unit, in: box, owned: $0) }
        )
    }

    private func singleBinding(_ name: String) -> Binding<Int> {
        Binding(
            get: { draft.singles[name] ?? 0 },
            set: { draft.setSingle(name, copies: $0) }
        )
    }
}

// MARK: - Shared rows

/// Tick row for one box unit. Ticked = you have it; unticked = missing.
struct CollectionCheckRow: View {
    var title: String
    var isOn: Bool
    var accessibilityIdentifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TMSpace.md) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isOn ? TMColor.signal : Color.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(TMFont.body)
                    .foregroundStyle(isOn ? Color.primary : Color.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Have it" : "Missing")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(isOn ? "Marks it as missing" : "Marks it as yours")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// A single you added, with a remove button.
struct CollectionSingleRow: View {
    var unit: CollectionUnit
    var idPrefix: String
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: TMSpace.md) {
            Image(systemName: "figure.stand")
                .foregroundStyle(TMColor.signal)
                .accessibilityHidden(true)
            Text(unit.have > 1 ? "\(unit.name) ×\(unit.have)" : unit.name)
                .font(TMFont.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: TMSpace.sm)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(unit.name)")
            .accessibilityIdentifier("\(idPrefix).single.remove.\(unit.name)")
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("\(idPrefix).single.\(unit.name)")
    }
}

/// Text field plus Add. Stacks at accessibility sizes.
struct CollectionAddField: View {
    var idPrefix: String
    /// Rounded field background for scroll screens; off inside a Form.
    var boxed: Bool = true
    var onAdd: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMSpace.sm))
            : AnyLayout(HStackLayout(spacing: TMSpace.sm))
        layout {
            TextField("’Mech name, like Atlas", text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focused)
                .onSubmit(add)
                .padding(.horizontal, boxed ? TMSpace.md : 0)
                .frame(minHeight: 44)
                .background {
                    if boxed {
                        RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous)
                            .fill(TMColor.readout)
                    }
                }
                .accessibilityLabel("’Mech name")
                .accessibilityIdentifier("\(idPrefix).addField")
            Button(action: add) {
                Label("Add", systemImage: "plus")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(trimmed.isEmpty)
            .accessibilityLabel("Add ’Mech")
            .accessibilityIdentifier("\(idPrefix).addButton")
        }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        text = ""
    }
}

/// A box whose list isn't confirmed (Mercenaries): say so and point at Add a ’Mech.
struct CollectionUnconfirmedNote: View {
    var identifier: String

    var body: some View {
        Label {
            Text("We haven’t confirmed what’s in this box yet. Add its ’Mechs by hand.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle")
                .foregroundStyle(TMColor.info)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

#if DEBUG
#Preview("Collection section") {
    PlayPreviewHost {
        ScrollView {
            ForceCollectionSection(
                collection: OwnedCollection(
                    boxes: ["agoac": 1, "mercenaries-box": 1],
                    missing: ["agoac": ["Catapult CPLT-C1": 1]],
                    singles: ["Atlas": 2]
                ),
                boxes: (try? BundleContentCatalogRepository().boxSets().boxes) ?? [],
                onEdit: {}
            )
            .padding(TMSpace.lg)
        }
    }
}

#Preview("Collection sheet") {
    CollectionEditSheet(
        boxes: (try? BundleContentCatalogRepository().boxSets().boxes) ?? [],
        initial: OwnedCollection(boxes: ["agoac": 1], singles: ["Atlas": 1]),
        onSave: { _ in }
    )
}
#endif
