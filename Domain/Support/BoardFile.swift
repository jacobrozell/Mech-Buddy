import Foundation

/// `.mechboard` files (PlayModeSpec § 9.7, owner decision D26): a board as JSON, shared through the share sheet
/// and Files. A file is data only. It is checked against the schema, sizes are clamped, pieces of a kind this
/// build doesn't know are dropped with a notice, and an import is always a new board (a name already in use
/// gets a number). No network.
public enum BoardFile {
    public static let fileExtension = "mechboard"
    /// Largest file read, bytes. A busy board is a few tens of KB.
    public static let maxBytes = 256 * 1024
    /// Most pieces a file may carry.
    public static let maxPieces = 200
    public static let maxSheets = 12

    public enum ImportError: Error, Equatable {
        case tooLarge
        case notABoard
        case newerVersion
        case tooManyPieces

        /// What the player reads.
        public var message: String {
            switch self {
            case .tooLarge: "That file is too big to be a board."
            case .notABoard: "That file isn’t a Mech Buddy board."
            case .newerVersion: "That board was made with a newer version of the app. Update the app to open it."
            case .tooManyPieces: "That board has too many pieces to open."
            }
        }
    }

    public struct Imported: Equatable {
        public var board: BoardLayout
        /// Pieces of a kind this build doesn't know, left out.
        public var droppedPieces: Int
        /// The table or some pieces were outside what the builder allows and were pulled in.
        public var wasClamped: Bool

        /// A line for the player after the board is added, or nil when nothing was changed.
        public var notice: String? {
            var sentences: [String] = []
            if droppedPieces > 0 {
                sentences.append("\(droppedPieces) \(droppedPieces == 1 ? "piece" : "pieces") of a kind this version doesn’t know \(droppedPieces == 1 ? "was" : "were") left out.")
            }
            if wasClamped { sentences.append("Some sizes were fitted to the table.") }
            return sentences.isEmpty ? nil : sentences.joined(separator: " ")
        }
    }

    /// The board as file data. Ids of the preset, dates and the game link are left out.
    public static func export(_ board: BoardLayout) throws -> Data {
        var copy = board
        copy.id = nil
        copy.createdAt = nil
        copy.updatedAt = nil
        copy.isStarter = nil
        copy.presetID = nil
        copy.presetUpdatedAt = nil
        copy.schemaVersion = BoardLayout.currentSchemaVersion
        for index in copy.features.indices { copy.features[index].id = nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(copy)
    }

    /// A file name like "Ridge Line.mechboard", safe for Files.
    public static func fileName(for board: BoardLayout) -> String {
        let raw = board.name.flatMap { $0.isEmpty ? nil : $0 } ?? "Board"
        let safe = raw.unicodeScalars.map { "/\\:*?\"<>|".unicodeScalars.contains($0) ? "-" : Character($0) }
        return String(safe) + "." + fileExtension
    }

    /// Reads a board from file data as a new board, never touching a saved one. `existingNames` are the names
    /// already in use.
    public static func importBoard(from data: Data, existingNames: [String], now: Date = Date()) throws -> Imported {
        guard data.count <= maxBytes else { throw ImportError.tooLarge }
        guard var board = try? JSONDecoder().decode(BoardLayout.self, from: data) else { throw ImportError.notABoard }
        if let version = board.schemaVersion, version > BoardLayout.currentSchemaVersion { throw ImportError.newerVersion }
        guard board.features.count + board.droppedPieceCount <= maxPieces else { throw ImportError.tooManyPieces }
        guard board.width.isFinite, board.depth.isFinite, board.width > 0, board.depth > 0 else { throw ImportError.notABoard }

        let dropped = board.droppedPieceCount
        board.sheets = Array(board.sheets.prefix(maxSheets))
        board.openTable = String(board.openTable.prefix(200))
        for index in board.features.indices {
            board.features[index].name = board.features[index].name.map { String($0.prefix(60)) }
        }
        let fitted = board.clampedToTable()
        let wasClamped = fitted != board

        var result = fitted
        let base = BoardPresets.cleanName(board.name ?? "")
        result.name = uniqueName(base.isEmpty ? "Imported board" : base, among: existingNames)
        result.id = UUID()
        result.createdAt = now
        result.updatedAt = now
        result.isStarter = nil
        result.presetID = nil
        result.presetUpdatedAt = nil
        result.schemaVersion = BoardLayout.currentSchemaVersion
        for index in result.features.indices { result.features[index].id = UUID() }
        result.droppedPieceCount = 0
        return Imported(board: result, droppedPieces: dropped, wasClamped: wasClamped)
    }

    /// "Name", then "Name 2", "Name 3" ... within the name limit.
    static func uniqueName(_ name: String, among names: [String]) -> String {
        let taken = Set(names.map { $0.lowercased() })
        var candidate = name
        var n = 2
        while taken.contains(candidate.lowercased()) {
            let suffix = " \(n)"
            candidate = String(name.prefix(BoardPresets.nameLimit - suffix.count)) + suffix
            n += 1
        }
        return candidate
    }
}
