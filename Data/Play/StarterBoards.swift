import Foundation
import MechBuddyDomain

/// Built-in boards (PlayModeSpec § 9.7): the missions' tables and two open tables. Read-only; Duplicate to change one.
/// Not stored: missions come from their JSON `layout`, the open tables from `as-starter-boards.json`.
public struct BoardListEntry: Identifiable, Equatable, Sendable {
    /// "starter.ridge-line" for a starter, the preset's UUID for yours.
    public var id: String
    public var board: BoardLayout
    public var isStarter: Bool
    public var name: String { board.name ?? "Board" }

    public init(id: String, board: BoardLayout, isStarter: Bool) {
        self.id = id
        self.board = board
        self.isStarter = isStarter
    }
}

public enum StarterBoards {
    /// Missions in the order the book teaches them, then Meet and Greet.
    public static let missionIDs: [ScenarioId] = [.ridgeLine, .brokenGround, .runningHot, .closeQuarters, .fullLances, ScenarioId(rawValue: "meet-and-greet")]

    public static func all(content: any ContentCatalogRepository, open: [BoardLayout]) -> [BoardListEntry] {
        var result: [BoardListEntry] = []
        let titles = Dictionary(
            uniqueKeysWithValues: ((try? content.scenarios().scenarios) ?? []).map { ($0.id, $0.title) }
        )
        for id in missionIDs {
            guard let dto = try? content.scenario(id: id).layout else { continue }
            var board = BoardLayout(dto)
            board.name = titles[id.rawValue] ?? id.rawValue
            board.isStarter = true
            result.append(BoardListEntry(id: "starter.\(id.rawValue)", board: board.clampedToTable().assigningIDs(), isStarter: true))
        }
        for var board in open {
            board.isStarter = true
            result.append(BoardListEntry(id: "starter.\(slug(board.name ?? "open"))", board: board.clampedToTable().assigningIDs(), isStarter: true))
        }
        return result
    }

    /// "Open 4′ × 4′ for four" → "open-4-4-for-four".
    static func slug(_ name: String) -> String {
        var out = ""
        for ch in name.lowercased() {
            if ch.isLetter && ch.isASCII || ch.isNumber { out.append(ch) } else if out.last != "-" { out.append("-") }
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
