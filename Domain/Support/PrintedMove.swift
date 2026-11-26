import Foundation

/// Card move such as `10"j`, `10"/6"j`, or `16"`, including a halved MP hit.
public struct PrintedMove: Equatable, Sendable {
    public var walk: Int
    public var jump: Int?

    public init?(_ mv: String) {
        let parts = mv.split(separator: "/")
        guard let first = parts.first else { return nil }
        let walkDigits = String(first.filter(\.isNumber))
        guard let walk = Int(walkDigits) else { return nil }
        self.walk = walk
        if parts.count >= 2 {
            let jumpDigits = String(parts[1].filter(\.isNumber))
            jump = Int(jumpDigits)
        } else if first.contains("j") {
            jump = walk
        } else {
            jump = nil
        }
    }

    public var sprint: Int { Int((Double(walk) * 1.5).rounded()) }

    public var summary: String {
        if let jump {
            if jump == walk { return "\(walk)″ walk or jump" }
            return "\(walk)″ walk · \(jump)″ jump"
        }
        return "\(walk)″ walk"
    }

    public var spokenSummary: String {
        if let jump {
            if jump == walk { return "\(walk) inches, walk or jump" }
            return "\(walk) inches walk, \(jump) inches jump"
        }
        return "\(walk) inches walk"
    }

    public func detail(for mode: MovementMode) -> String? {
        switch mode {
        case .standstill: "under 1″"
        case .ground: "\(walk)″"
        case .sprint: "about \(sprint)″"
        case .jump: jump.map { "\($0)″" }
        case .unset: nil
        }
    }

    public func spokenChoice(_ mode: MovementMode) -> String {
        switch mode {
        case .standstill: "Stood still, under 1 inch"
        case .ground: "Walk, \(walk) inches"
        case .sprint: "Sprint, about \(sprint) inches. Can’t shoot this turn."
        case .jump: jump.map { "Jump, \($0) inches" } ?? "Jump"
        case .unset: "Move"
        }
    }
}

public enum InitiativeDice {
    public static func winner(a1: Int?, a2: Int?, b1: Int?, b2: Int?) -> SideId? {
        guard let a1, let a2, let b1, let b2 else { return nil }
        let sideA = a1 + a2
        let sideB = b1 + b2
        if sideA > sideB { return .lanceA }
        if sideB > sideA { return .lanceB }
        return nil
    }

    /// Two sides: the side that moves first is the lower roll. Nil until all four dice are in, or on a tie.
    public static func firstToMove(a1: Int?, a2: Int?, b1: Int?, b2: Int?) -> SideId? {
        winner(a1: a1, a2: a2, b1: b1, b2: b2).map { $0 == .lanceA ? .lanceB : .lanceA }
    }

    public static func isTie(a1: Int?, a2: Int?, b1: Int?, b2: Int?) -> Bool {
        guard let a1, let a2, let b1, let b2 else { return false }
        return a1 + a2 == b1 + b2
    }
}

/// Past-tense label for a recorded move. The domain string for `.unset` stays "Tap to record…".
public func recordedMoveName(_ mode: MovementMode) -> String {
    mode == .unset ? "Not recorded" : mode.displayName
}
