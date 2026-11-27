import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// Name and save a board as a preset (`as.play.board.save`, PlayModeSpec § 9.7). Saving under a name you already
/// use replaces that board, and the sheet says so.
struct BoardSaveSheet: View {
    var board: BoardLayout
    /// Called with the stored preset.
    var onSaved: (BoardLayout) -> Void
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var failure: String?

    init(board: BoardLayout, onSaved: @escaping (BoardLayout) -> Void) {
        self.board = board
        self.onSaved = onSaved
        _name = State(initialValue: board.name ?? "")
    }

    private var clean: String { BoardPresets.cleanName(name) }

    /// Another saved board already has this name.
    private var replaces: Bool {
        dependencies.userContent.boardPresets().contains {
            $0.id != board.presetID && ($0.name ?? "").caseInsensitiveCompare(clean) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onChange(of: name) { _, new in
                            if new.count > BoardPresets.nameLimit { name = String(new.prefix(BoardPresets.nameLimit)) }
                        }
                        .accessibilityIdentifier("as.play.board.save.name")
                } header: {
                    Text("Board name")
                } footer: {
                    VStack(alignment: .leading, spacing: TMSpace.xs) {
                        Text("\(BoardPresets.summary(board)). Up to \(BoardPresets.nameLimit) characters.")
                        if replaces && !clean.isEmpty {
                            Text("A saved board is already called “\(clean)”. Saving replaces it.")
                                .foregroundStyle(TMColor.warning)
                                .accessibilityIdentifier("as.play.board.save.replaces")
                        }
                        if let failure {
                            Text(failure)
                                .foregroundStyle(TMColor.warning)
                                .accessibilityIdentifier("as.play.board.save.error")
                        }
                    }
                }
            }
            .navigationTitle("Save board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("as.play.board.save.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(clean.isEmpty)
                        .accessibilityIdentifier("as.play.board.save.confirm")
                }
            }
        }
        .accessibilityIdentifier("as.play.board.save")
        .presentationDetents([.medium])
    }

    private func save() {
        var toSave = board
        // A copy made from a saved board updates that board when the name is unchanged; anything else is a new board.
        if let source = board.presetID,
           let preset = dependencies.userContent.boardPreset(id: source),
           (preset.name ?? "").caseInsensitiveCompare(clean) == .orderedSame {
            toSave.id = source
        } else {
            toSave.id = UUID()
        }
        toSave.createdAt = nil
        do {
            let stored = try dependencies.userContent.saveBoard(toSave, name: clean)
            onSaved(stored)
            dismiss()
        } catch {
            failure = "Couldn’t save that. Try again."
            dependencies.logger.error("save board: \(error)", category: "persistence")
        }
    }
}
