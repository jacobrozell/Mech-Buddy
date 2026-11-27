import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// Board presets, `as.play.board.list` (PlayModeSpec § 9.7): yours first, then the built-in starter boards.
/// Without `onPick` it manages: tap a saved board to edit it, the row's menu renames, duplicates or deletes.
/// With `onPick` a tap chooses the board for a game (the game gets its own copy).
struct PlayBoardsView: View {
    var onPick: ((BoardLayout) -> Void)?
    @Environment(AppDependencies.self) private var dependencies

    @State private var mine: [BoardLayout] = []
    @State private var starters: [BoardListEntry] = []
    @State private var renaming: BoardLayout?
    @State private var newName = ""
    @State private var deleting: BoardLayout?
    @State private var previewing: BoardListEntry?
    @State private var editing: UUID?
    @State private var message: String?

    private static let terrainPalette: TerrainPaletteFile? = try? BundleContentCatalogRepository().terrainPalette()
    private var isPicking: Bool { onPick != nil }

    var body: some View {
        List {
            if let message {
                Section { ErrorBanner(message: message) }
            }
            Section {
                if mine.isEmpty {
                    Text("No saved boards yet. In Play setup, build a board and choose Save board.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("as.play.board.empty")
                }
                ForEach(mine, id: \.id) { board in
                    myRow(board)
                }
            } header: {
                Text("Your boards")
            }
            Section {
                ForEach(starters) { entry in
                    starterRow(entry)
                }
            } header: {
                Text("Starter boards")
            } footer: {
                Text(isPicking
                     ? "Picking a board gives this game its own copy. Changing the saved board later doesn’t change a game."
                     : "Built in. Duplicate one to change it. A game keeps its own copy of a board.")
            }
        }
        .accessibilityIdentifier("as.play.board.list")
        .navigationTitle(isPicking ? "Choose a board" : "Boards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .alert("Rename board", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
                .accessibilityIdentifier("as.play.board.rename.name")
            Button("Save") { commitRename() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete “\(deleting?.name ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { commitDelete() }
                .accessibilityIdentifier("as.play.board.delete.confirm")
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This can’t be undone. Games already set up keep their own copy.")
        }
        .sheet(item: $previewing) { entry in
            starterPreview(entry)
        }
        .navigationDestination(item: $editing) { id in
            if let palette = Self.terrainPalette, let board = dependencies.userContent.boardPreset(id: id) {
                BoardEditorView(board: board, sides: PlaySetup.pickup().sides, palette: palette, canSave: false) { changed in
                    _ = try? dependencies.userContent.saveBoard(changed, name: changed.name ?? board.name ?? "Board")
                }
            }
        }
    }

    // MARK: Rows

    private func myRow(_ board: BoardLayout) -> some View {
        let id = board.id?.uuidString ?? ""
        return HStack(spacing: TMSpace.sm) {
            Button {
                if let onPick { onPick(board) } else { editing = board.id }
            } label: {
                rowText(name: board.name ?? "Board", detail: BoardPresets.summary(board), badge: isPicking ? "square.and.arrow.down" : nil)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isPicking ? "Uses this board for the game." : "Opens the builder.")
            .accessibilityIdentifier("as.play.board.row.\(id)")
            if !isPicking {
                Menu {
                    Button("Rename", systemImage: "pencil") {
                        newName = board.name ?? ""
                        renaming = board
                    }
                    .accessibilityIdentifier("as.play.board.rename")
                    Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(board) }
                        .accessibilityIdentifier("as.play.board.duplicate")
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = board }
                        .accessibilityIdentifier("as.play.board.delete")
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Actions for \(board.name ?? "board")")
                .accessibilityIdentifier("as.play.board.menu.\(id)")
            }
        }
        .swipeActions(edge: .trailing) {
            if !isPicking {
                Button("Delete", role: .destructive) { deleting = board }
                Button("Rename") {
                    newName = board.name ?? ""
                    renaming = board
                }
                .tint(TMColor.signal)
            }
        }
        .swipeActions(edge: .leading) {
            if !isPicking {
                Button("Duplicate") { duplicate(board) }
                    .tint(TMColor.signal)
            }
        }
    }

    private func starterRow(_ entry: BoardListEntry) -> some View {
        HStack(spacing: TMSpace.sm) {
            Button {
                if let onPick { onPick(entry.board) } else { previewing = entry }
            } label: {
                rowText(name: entry.name, detail: BoardPresets.summary(entry.board), badge: isPicking ? "square.and.arrow.down" : nil)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isPicking ? "Uses this board for the game." : "Shows the board.")
            .accessibilityIdentifier("as.play.board.row.\(entry.id)")
            if !isPicking {
                Menu {
                    Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(entry.board) }
                        .accessibilityIdentifier("as.play.board.duplicate")
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Actions for \(entry.name)")
                .accessibilityIdentifier("as.play.board.menu.\(entry.id)")
            }
        }
        .swipeActions(edge: .leading) {
            if !isPicking {
                Button("Duplicate") { duplicate(entry.board) }
                    .tint(TMColor.signal)
            }
        }
    }

    private func rowText(name: String, detail: String, badge: String?) -> some View {
        HStack(spacing: TMSpace.md) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(name).font(TMFont.cardTitle)
                Text(detail)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: TMSpace.sm)
            if let badge {
                Image(systemName: badge)
                    .foregroundStyle(TMColor.signal)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func starterPreview(_ entry: BoardListEntry) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TMSpace.lg) {
                    MissionLayoutView(board: PlayLayout.board(for: Battlefield(board: entry.board), sides: PlaySetup.pickup().sides))
                        .accessibilityIdentifier("as.play.board.preview.layout")
                    Text("\(BoardPresets.summary(entry.board)). Built in, so it can’t be changed. Duplicate it to make your own.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        duplicate(entry.board)
                        previewing = nil
                    } label: {
                        Label("Duplicate to edit", systemImage: "plus.square.on.square").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TMColor.signal)
                    .accessibilityIdentifier("as.play.board.preview.duplicate")
                }
                .padding(TMSpace.lg)
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { previewing = nil }
                        .accessibilityIdentifier("as.play.board.preview.done")
                }
            }
        }
        .accessibilityIdentifier("as.play.board.preview")
        .presentationDetents([.large])
    }

    // MARK: Actions

    private func reload() {
        mine = dependencies.userContent.boardPresets()
        if starters.isEmpty {
            let repo = BundleContentCatalogRepository()
            starters = StarterBoards.all(content: dependencies.content, open: (try? repo.starterBoards()) ?? [])
        }
    }

    private func duplicate(_ board: BoardLayout) {
        let copy = BoardPresets.duplicate(board, among: mine.compactMap(\.name))
        run { try dependencies.userContent.saveBoard(copy, name: copy.name ?? "Board") }
    }

    private func commitRename() {
        guard let board = renaming, let id = board.id else { return }
        renaming = nil
        do {
            try dependencies.userContent.renameBoard(id: id, to: newName)
            message = nil
        } catch UserContentStore.BoardError.nameInUse {
            message = "Another board already has that name."
        } catch UserContentStore.BoardError.emptyName {
            message = "A board needs a name."
        } catch {
            message = "Couldn’t rename that. Try again."
            dependencies.logger.error("rename board: \(error)", category: "persistence")
        }
        reload()
    }

    private func commitDelete() {
        guard let id = deleting?.id else { return }
        deleting = nil
        run { try dependencies.userContent.deleteBoard(id: id) }
    }

    private func run(_ work: () throws -> Void) {
        do {
            try work()
            message = nil
        } catch {
            message = "Couldn’t save that. Try again."
            dependencies.logger.error("boards: \(error)", category: "persistence")
        }
        reload()
    }
}
