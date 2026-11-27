import Foundation

/// Board presets (PlayModeSpec § 9.7): names, copies into a game, "Board changed since", list text.
public enum BoardPresets {
    /// Longest board name (§ 9.7).
    public static let nameLimit = 40

    /// Trimmed, whitespace collapsed to single spaces, cut to `nameLimit`.
    public static func cleanName(_ raw: String) -> String {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(nameLimit)).trimmingCharacters(in: .whitespaces)
    }

    /// "Name copy", "Name copy 2", ... the first not already used (ignoring case).
    public static func duplicateName(of name: String, among names: [String]) -> String {
        let taken = Set(names.map { $0.lowercased() })
        let suffix = " copy"
        let base = String(name.prefix(nameLimit - suffix.count - 3))
        var candidate = cleanName(base + suffix)
        var n = 2
        while taken.contains(candidate.lowercased()) {
            candidate = cleanName("\(base)\(suffix) \(n)")
            n += 1
        }
        return candidate
    }

    /// A copy of a preset under a new id (for Duplicate).
    public static func duplicate(_ board: BoardLayout, among names: [String], now: Date = Date()) -> BoardLayout {
        var copy = board
        copy.id = UUID()
        copy.name = duplicateName(of: board.name ?? "Board", among: names)
        copy.createdAt = now
        copy.updatedAt = now
        copy.isStarter = nil
        return copy
    }

    /// The board a game or setup holds: its own copy, with fresh piece ids. A saved preset is remembered by
    /// `presetID` and its `updatedAt`, so setup can say "Board changed since". Starters aren't remembered
    /// (they never change). Later edits to the preset never reach the copy (§ 9.7).
    public static func copyForSetup(_ board: BoardLayout, now: Date = Date()) -> BoardLayout {
        var copy = board
        let isSaved = board.isStarter != true && board.id != nil
        copy.presetID = isSaved ? board.id : nil
        copy.presetUpdatedAt = isSaved ? board.updatedAt : nil
        copy.id = UUID()
        copy.createdAt = now
        copy.updatedAt = now
        copy.isStarter = nil
        copy.schemaVersion = BoardLayout.currentSchemaVersion
        for index in copy.features.indices { copy.features[index].id = UUID() }
        return copy.clampedToTable()
    }

    /// The saved board this copy came from, when it has been saved again since the copy was made.
    public static func newerVersion(of board: BoardLayout, in presets: [BoardLayout]) -> BoardLayout? {
        guard let source = board.presetID,
              let preset = presets.first(where: { $0.id == source }),
              let updated = preset.updatedAt else { return nil }
        guard let copied = board.presetUpdatedAt else { return preset }
        return updated > copied ? preset : nil
    }

    /// "4′ × 4′" when both sides are whole feet, else both in inches ("36″ × 22″"): never mixed units.
    public static func tableText(_ board: BoardLayout) -> String {
        let width = Int(board.width.rounded())
        let depth = Int(board.depth.rounded())
        if width % 12 == 0 && depth % 12 == 0 {
            return "\(width / 12)′ × \(depth / 12)′"
        }
        return "\(width)″ × \(depth)″"
    }

    /// "4′ × 4′ · 2–4 sides · 12 pieces". Every board works for 2 to 4 sides: unset zone sets are generated.
    public static func summary(_ board: BoardLayout) -> String {
        let count = board.features.count
        return "\(tableText(board)) · 2–4 sides · \(count) \(count == 1 ? "piece" : "pieces")"
    }
}
