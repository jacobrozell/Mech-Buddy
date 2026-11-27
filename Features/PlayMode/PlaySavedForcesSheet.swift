import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// Saved forces and hand-entered cards (PlayModeSpec § 4, § 5.3). With `onLoad` a tap loads the force into a side;
/// without it the sheet is for managing (rename, delete, edit cards).
struct PlaySavedForcesSheet: View {
    /// Name of the side a tap will fill, when loading.
    var loadingInto: String?
    var onLoad: ((SavedForce) -> Void)?
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var forces: [SavedForce] = []
    @State private var renaming: SavedForce?
    @State private var newName = ""
    @State private var editingCard: CardFaceDTO?
    @State private var enteringCard = false
    @State private var failure: String?

    private var isLoading: Bool { onLoad != nil }

    var body: some View {
        NavigationStack {
            List {
                if let failure {
                    Section { ErrorBanner(message: failure) }
                }
                Section {
                    if forces.isEmpty {
                        Text("No saved forces yet. On the Forces step, choose Save this force.")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("as.play.forces.saved.empty")
                    }
                    ForEach(forces) { force in
                        forceRow(force)
                    }
                } header: {
                    Text("Saved forces")
                } footer: {
                    if let loadingInto { Text("Loading one replaces \(loadingInto)’s force.") }
                }
                if !isLoading {
                    Section {
                        ForEach(dependencies.cardLibrary.userFaces) { face in
                            Button { editingCard = face } label: { cardRow(face) }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button("Delete", role: .destructive) { deleteCard(face) }
                                }
                                .accessibilityIdentifier("as.card.entry.row.\(face.id)")
                        }
                        Button {
                            enteringCard = true
                        } label: {
                            Label("Enter a card by hand", systemImage: "square.and.pencil").frame(minHeight: 44)
                        }
                        .accessibilityIdentifier("as.card.entry.new")
                    } header: {
                        Text("Your cards")
                    } footer: {
                        Text("Games already started keep their own copy of a card.")
                    }
                }
            }
            .accessibilityIdentifier("as.play.forces.saved.sheet")
            .navigationTitle(isLoading ? "Load a saved force" : "Saved forces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("as.play.forces.saved.done")
                }
            }
            .onAppear(perform: reload)
            .alert("Rename force", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                    .accessibilityIdentifier("as.play.forces.saved.rename.name")
                Button("Save") { commitRename() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $editingCard) { face in
                PlayCardEntrySheet(draft: UserCardDraft(face: face), editingId: face.id, onSave: saveCard)
            }
            .sheet(isPresented: $enteringCard) {
                PlayCardEntrySheet(onSave: saveCard)
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func forceRow(_ force: SavedForce) -> some View {
        let content = HStack(spacing: TMSpace.md) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(force.name).font(TMFont.cardTitle)
                Text("\(PlayModeText.mechs(force.picks.count)) · \(force.totalPV) PV")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(force.picks.map(\.name).joined(separator: ", "))
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: TMSpace.sm)
            if isLoading {
                Image(systemName: "square.and.arrow.down")
                    .foregroundStyle(TMColor.signal)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        Group {
            if let onLoad {
                Button { onLoad(force) } label: { content }
                    .buttonStyle(.plain)
                    .accessibilityHint("Loads it into \(loadingInto ?? "this side").")
            } else {
                content.accessibilityElement(children: .combine)
            }
        }
        .swipeActions {
            Button("Delete", role: .destructive) { delete(force) }
            Button("Rename") {
                newName = force.name
                renaming = force
            }
            .tint(TMColor.signal)
        }
        .accessibilityIdentifier("as.play.forces.saved.row.\(force.id.uuidString)")
    }

    private func cardRow(_ face: CardFaceDTO) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xxs) {
            Text(face.name).font(TMFont.body)
            Text("Size \(face.sz) · \(face.mv ?? "—") · \(face.pv ?? 0) PV · Your numbers")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func reload() { forces = dependencies.userContent.savedForces() }

    private func commitRename() {
        guard let force = renaming else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        renaming = nil
        guard !name.isEmpty else { return }
        run { try dependencies.userContent.rename(id: force.id, to: name) }
    }

    private func delete(_ force: SavedForce) {
        run { try dependencies.userContent.deleteSavedForce(id: force.id) }
    }

    private func deleteCard(_ face: CardFaceDTO) {
        run { try dependencies.userContent.deleteUserCard(id: face.id) }
        dependencies.reloadUserCards()
    }

    private func saveCard(_ face: CardFaceDTO) {
        run { try dependencies.userContent.saveUserCard(face) }
        dependencies.reloadUserCards()
    }

    private func run(_ work: () throws -> Void) {
        do {
            try work()
            failure = nil
        } catch {
            failure = "Couldn’t save that. Try again."
            dependencies.logger.error("saved forces: \(error)", category: "persistence")
        }
        reload()
    }
}
