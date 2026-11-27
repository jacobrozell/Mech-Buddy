import Foundation
import SwiftData
import MechBuddyDomain

/// A named force saved from one Play side (PlayModeSpec § 12). `cards` holds copies of any hand-entered
/// cards it uses, so loading it still works after a card was deleted.
public struct SavedForce: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var updatedAt: Date
    public var picks: [ForcePick]
    public var cards: [CardFaceDTO]

    public init(id: UUID = UUID(), name: String, updatedAt: Date = Date(), picks: [ForcePick], cards: [CardFaceDTO] = []) {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
        self.picks = picks
        self.cards = cards
    }

    public var totalPV: Int { picks.reduce(0) { $0 + $1.adjustedPV } }
}

/// JSON inside `SDSavedForce.payload`. Versioned so the shape can grow.
struct SavedForcePayload: Codable {
    var schemaVersion = 1
    var picks: [ForcePick]
    var cards: [CardFaceDTO]
}

/// Saved forces and hand-entered cards, in SwiftData (SchemaV2). Rows that fail to decode are skipped, not deleted.
@MainActor
public final class UserContentStore {
    private let context: ModelContext

    public init(container: ModelContainer) {
        context = ModelContext(container)
    }

    // MARK: Cards

    public func userCards() -> [CardFaceDTO] {
        let rows = (try? context.fetch(FetchDescriptor<SDUserCard>(sortBy: [SortDescriptor(\.name)]))) ?? []
        return rows.compactMap { try? JSONDecoder().decode(CardFaceDTO.self, from: $0.payload) }
    }

    public func saveUserCard(_ face: CardFaceDTO, now: Date = Date()) throws {
        let data = try JSONEncoder().encode(face)
        if let row = try fetchCard(face.id) {
            row.name = face.name
            row.payload = data
            row.updatedAt = now
        } else {
            context.insert(SDUserCard(id: face.id, name: face.name, updatedAt: now, payload: data))
        }
        try context.save()
    }

    public func deleteUserCard(id: String) throws {
        if let row = try fetchCard(id) {
            context.delete(row)
            try context.save()
        }
    }

    private func fetchCard(_ id: String) throws -> SDUserCard? {
        try context.fetch(FetchDescriptor<SDUserCard>(predicate: #Predicate { $0.id == id })).first
    }

    // MARK: Saved forces

    /// Newest first.
    public func savedForces() -> [SavedForce] {
        let rows = (try? context.fetch(FetchDescriptor<SDSavedForce>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
        return rows.compactMap { row in
            guard let payload = try? JSONDecoder().decode(SavedForcePayload.self, from: row.payload) else { return nil }
            return SavedForce(id: row.id, name: row.name, updatedAt: row.updatedAt, picks: payload.picks, cards: payload.cards)
        }
    }

    /// Saves under the force's id. A different force with the same name (ignoring case) is replaced, so a name
    /// is one force.
    public func save(_ force: SavedForce) throws {
        let name = force.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = try JSONEncoder().encode(SavedForcePayload(picks: force.picks, cards: force.cards))
        let rows = try context.fetch(FetchDescriptor<SDSavedForce>())
        for row in rows where row.id != force.id && row.name.caseInsensitiveCompare(name) == .orderedSame {
            context.delete(row)
        }
        if let row = rows.first(where: { $0.id == force.id }) {
            row.name = name
            row.payload = data
            row.updatedAt = force.updatedAt
        } else {
            context.insert(SDSavedForce(id: force.id, name: name, updatedAt: force.updatedAt, payload: data))
        }
        try context.save()
    }

    public func rename(id: UUID, to name: String, now: Date = Date()) throws {
        guard var force = savedForces().first(where: { $0.id == id }) else { return }
        force.name = name
        force.updatedAt = now
        try save(force)
    }

    public func deleteSavedForce(id: UUID) throws {
        let rows = try context.fetch(FetchDescriptor<SDSavedForce>(predicate: #Predicate { $0.id == id }))
        rows.forEach(context.delete)
        try context.save()
    }

    // MARK: Board presets (PM13, PlayModeSpec § 9.7)

    public enum BoardError: Error, Equatable {
        case nameInUse
        case emptyName
        case notFound
    }

    /// Your boards, newest first. A row that no longer decodes is skipped, not deleted.
    public func boardPresets() -> [BoardLayout] {
        let rows = (try? context.fetch(FetchDescriptor<SDBoardPreset>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
        return rows.compactMap(Self.board(from:))
    }

    public func boardPreset(id: UUID) -> BoardLayout? {
        (try? context.fetch(FetchDescriptor<SDBoardPreset>(predicate: #Predicate { $0.id == id })))?.first.flatMap(Self.board(from:))
    }

    private static func board(from row: SDBoardPreset) -> BoardLayout? {
        guard var board = try? JSONDecoder().decode(BoardLayout.self, from: row.payload) else { return nil }
        board.id = row.id
        board.name = row.name
        board.updatedAt = row.updatedAt
        board.isStarter = false
        board.presetID = nil
        board.presetUpdatedAt = nil
        return board
    }

    /// Saves under the board's id (a new id makes a new preset). Another preset with the same name (ignoring
    /// case) is replaced, so a name is one board. Returns what was stored.
    @discardableResult
    public func saveBoard(_ board: BoardLayout, name: String, now: Date = Date()) throws -> BoardLayout {
        let clean = BoardPresets.cleanName(name)
        guard !clean.isEmpty else { throw BoardError.emptyName }
        var stored = board
        let id = board.id ?? UUID()
        stored.id = id
        stored.name = clean
        stored.updatedAt = now
        stored.createdAt = board.createdAt ?? now
        stored.isStarter = nil
        stored.presetID = nil
        stored.presetUpdatedAt = nil
        stored.schemaVersion = BoardLayout.currentSchemaVersion
        stored = stored.assigningIDs()
        let data = try JSONEncoder().encode(stored)
        let rows = try context.fetch(FetchDescriptor<SDBoardPreset>())
        for row in rows where row.id != id && row.name.caseInsensitiveCompare(clean) == .orderedSame {
            context.delete(row)
        }
        if let row = rows.first(where: { $0.id == id }) {
            row.name = clean
            row.payload = data
            row.updatedAt = now
        } else {
            context.insert(SDBoardPreset(id: id, name: clean, updatedAt: now, payload: data))
        }
        try context.save()
        return stored
    }

    public func renameBoard(id: UUID, to name: String, now: Date = Date()) throws {
        let clean = BoardPresets.cleanName(name)
        guard !clean.isEmpty else { throw BoardError.emptyName }
        let boards = boardPresets()
        guard let board = boards.first(where: { $0.id == id }) else { throw BoardError.notFound }
        if boards.contains(where: { $0.id != id && ($0.name ?? "").caseInsensitiveCompare(clean) == .orderedSame }) {
            throw BoardError.nameInUse
        }
        try saveBoard(board, name: clean, now: now)
    }

    /// A copy under a new id named "Name copy", "Name copy 2", and so on.
    @discardableResult
    public func duplicateBoard(id: UUID, now: Date = Date()) throws -> BoardLayout {
        let boards = boardPresets()
        guard let board = boards.first(where: { $0.id == id }) else { throw BoardError.notFound }
        let copy = BoardPresets.duplicate(board, among: boards.compactMap(\.name), now: now)
        return try saveBoard(copy, name: copy.name ?? "Board", now: now)
    }

    public func deleteBoard(id: UUID) throws {
        let rows = try context.fetch(FetchDescriptor<SDBoardPreset>(predicate: #Predicate { $0.id == id }))
        rows.forEach(context.delete)
        try context.save()
    }

    public func deleteAll() {
        try? context.delete(model: SDBoardPreset.self)
        try? context.delete(model: SDSavedForce.self)
        try? context.delete(model: SDUserCard.self)
        try? context.save()
    }
}
