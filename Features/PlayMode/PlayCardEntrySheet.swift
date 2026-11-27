import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// Card entry by hand (PlayModeSpec § 5.3): the numbers printed on a card, validated, saved as a user card.
struct PlayCardEntrySheet: View {
    @State private var draft: UserCardDraft
    @State private var showIssues = false
    /// The id of the card being edited; nil for a new card.
    private let editingId: String?
    var onSave: (CardFaceDTO) -> Void
    @Environment(\.dismiss) private var dismiss

    init(draft: UserCardDraft = UserCardDraft(), editingId: String? = nil, onSave: @escaping (CardFaceDTO) -> Void) {
        _draft = State(initialValue: draft)
        self.editingId = editingId
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field("Name", "e.g. Raven RVN-3L", $draft.name, .name, keyboard: .default)
                    Picker("Size", selection: $draft.size) {
                        ForEach(1...4, id: \.self) { Text("Size \($0)").tag($0) }
                    }
                    .accessibilityIdentifier("as.card.entry.size")
                    Picker("Tech", selection: $draft.isClan) {
                        Text("Inner Sphere").tag(false)
                        Text("Clan").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("as.card.entry.clan")
                } footer: {
                    Text("Clan cards start at Skill 3 and pay for it (p. 35).")
                }
                Section("Numbers") {
                    field("PV", "Printed at Skill 4", $draft.pv, .pv)
                    field("Move", "10\"  10\"j  10\"/6\"j", $draft.move, .move, keyboard: .numbersAndPunctuation)
                    field("TMM", "0 to 8", $draft.tmm, .tmm)
                    field("Armor", "", $draft.armor, .armor)
                    field("Structure", "", $draft.structure, .structure)
                    field("Overheat (OV)", "0 to 4", $draft.overheat, .overheat)
                }
                Section {
                    field("Short (S)", "0 to 30, or 0*", $draft.short, .short, keyboard: .numbersAndPunctuation)
                    field("Medium (M)", "0 to 30, or 0*", $draft.medium, .medium, keyboard: .numbersAndPunctuation)
                    field("Long (L)", "0 to 30, or 0*", $draft.long, .long, keyboard: .numbersAndPunctuation)
                } header: {
                    Text("Damage")
                } footer: {
                    Text("Type 0* for minimal damage (p. 41).")
                }
                Section("Specials") {
                    TextField("ECM, EW, IF1 …", text: $draft.specials, axis: .vertical)
                        .lineLimit(1...4)
                        .accessibilityIdentifier("as.card.entry.specials")
                    issueText(.specials)
                }
                Section {
                    if let url = URL(string: "https://masterunitlist.battletech.com") {
                        Link(destination: url) {
                            Label("Look it up on the Master Unit List", systemImage: "safari")
                                .frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("as.card.entry.mul")
                    }
                } footer: {
                    Text("Saved on this device and marked “Your numbers”. Never uploaded.")
                }
            }
            .accessibilityIdentifier("as.card.entry")
            .navigationTitle(editingId == nil ? "Enter a card" : "Edit card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("as.card.entry.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .accessibilityIdentifier("as.card.entry.save")
                }
            }
        }
        .presentationDetents([.large])
    }

    private func field(
        _ label: String,
        _ prompt: String,
        _ text: Binding<String>,
        _ field: UserCardDraft.Field,
        keyboard: UIKeyboardType = .numberPad
    ) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xxs) {
            LabeledContent(label) {
                TextField(prompt, text: text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(field == .name ? .words : .never)
                    .autocorrectionDisabled()
                    .accessibilityLabel(label)
                    .accessibilityIdentifier("as.card.entry.\(field.rawValue)")
            }
            .frame(minHeight: 44)
            issueText(field)
        }
    }

    @ViewBuilder
    private func issueText(_ field: UserCardDraft.Field) -> some View {
        if showIssues, let issue = draft.issue(for: field) {
            Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                .font(TMFont.detail)
                .foregroundStyle(TMColor.warning)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("as.card.entry.error.\(field.rawValue)")
        }
    }

    private func save() {
        guard let face = draft.makeFace(id: editingId) else {
            showIssues = true
            UIAccessibility.post(notification: .announcement, argument: draft.issues().first?.message ?? "Check the card")
            return
        }
        onSave(face)
        dismiss()
    }
}
