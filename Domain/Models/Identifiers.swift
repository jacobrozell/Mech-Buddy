import Foundation

public struct GameModeId: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let alphaStrike = GameModeId(rawValue: "alpha-strike")
    public static let classicTW = GameModeId(rawValue: "classic-tw")
}

public struct ScenarioId: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let ridgeLine = ScenarioId(rawValue: "ridge-line")
    public static let brokenGround = ScenarioId(rawValue: "broken-ground")
    public static let runningHot = ScenarioId(rawValue: "running-hot")
    public static let closeQuarters = ScenarioId(rawValue: "close-quarters")
    public static let fullLances = ScenarioId(rawValue: "full-lances")
}

/// A side in a match. Raw values are saved in payloads and `SDMatchSession.activeSideRaw`, so A and B keep
/// their spelling. Missions use A and B; Play mode adds C and D (PlayModeSpec § 12).
/// There is no `other`: with more than two sides "the other side" has no meaning. Ask the session
/// (`MatchSession.opponents(of:)`, `otherSide(of:)`, `nextSide(after:)`).
public enum SideId: String, Codable, Sendable, CaseIterable, CodingKeyRepresentable {
    case lanceA
    case lanceB
    case lanceC
    case lanceD

    /// The letter shown on the side badge. It stays when a side is renamed.
    public var letter: String {
        switch self {
        case .lanceA: "A"
        case .lanceB: "B"
        case .lanceC: "C"
        case .lanceD: "D"
        }
    }

    /// Default name. A Play session may rename a side (`MatchSide.name`).
    public var displayName: String { "Side \(letter)" }

    /// The two sides every mission uses, in seat order.
    public static let missionPair: [SideId] = [.lanceA, .lanceB]
}

public enum PhaseId: String, Codable, Sendable, CaseIterable {
    case initiative
    case movement
    case combat
    case end

    public var displayName: String {
        switch self {
        case .initiative: "Roll dice"
        case .movement: "Move"
        case .combat: "Shoot"
        case .end: "Clean up"
        }
    }
}

public enum MatchStatus: String, Codable, Sendable {
    case active
    case completed
    case abandoned
}

public enum MovementMode: String, Codable, Sendable, CaseIterable {
    case unset
    case standstill
    case ground
    case sprint
    case jump

    public var displayName: String {
        switch self {
        case .unset: "Tap to record…"
        case .standstill: "Stood still"
        case .ground: "Walked"
        case .sprint: "Sprinted (can’t shoot)"
        case .jump: "Jumped"
        }
    }

    public var coachDetail: String {
        switch self {
        case .unset: "Record how this miniature moved on the table."
        case .standstill: "Moved less than 1 inch. Easier for it to shoot."
        case .ground: "Walked up to its Move inches on the card. Normal."
        case .sprint: "Ran extra far (about 1½× Move). It cannot shoot this turn."
        case .jump: "Jumped using the jump number on its card. Harder for it to shoot."
        }
    }

    /// How this unit’s recorded move counts when it is the shot’s target.
    public var asTargetMoveModifier: TargetMoveModifier {
        switch self {
        case .standstill: .standstill
        case .jump: .jumpedUsesTMMPlus1
        case .ground, .sprint, .unset: .groundUsesTMM
        }
    }
}

public enum UnitCombatStatus: String, Codable, Sendable {
    case active
    case destroyedPendingEnd
    case removed

    public var displayName: String {
        switch self {
        case .active: "In play"
        case .destroyedPendingEnd: "Wrecked — still shoots this turn"
        case .removed: "Off the table"
        }
    }
}

public enum PlayEngineId: String, Codable, Sendable {
    case alphaStrikePhased
    case classicTWPhased
}
