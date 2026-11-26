import Foundation

/// Which range bands of a card print "0*" instead of a plain 0 (Quick-Start Rulebook, 3rd printing,
/// p. 4 and p. 21). The damage Ints on a card stay 0 at those bands; this only says the shot is allowed.
public struct MinimalDamageBands: Codable, Sendable, Equatable {
    public var short: Bool
    public var medium: Bool
    public var long: Bool

    public static let none = MinimalDamageBands()

    public init(short: Bool = false, medium: Bool = false, long: Bool = false) {
        self.short = short
        self.medium = medium
        self.long = long
    }

    public var isEmpty: Bool { !short && !medium && !long }

    public func contains(_ bracket: RangeBracket) -> Bool {
        switch bracket {
        case .short: short
        case .medium: medium
        case .long: long
        case .outOfRange: false
        }
    }
}

/// "0*" minimal damage (Quick-Start Rulebook 3rd printing, p. 21): a successful attack at a 0* band rolls 1D6.
/// On 4 or higher it delivers a single point of standard damage. Otherwise it still hits but delivers no damage,
/// and a minimal attack that delivers no damage may not resolve any Critical Hit checks.
public enum MinimalDamage {
    public static let threshold = 4
    public static let damageOnSuccess = 1

    /// Reads a printed card value: "0*" is minimal damage, anything else is a plain number.
    /// Returns nil for text that is neither (a dash maps to a plain 0).
    public static func parse(_ text: String) -> (value: Int, minimal: Bool)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "0*" { return (0, true) }
        if trimmed == "-" || trimmed == "—" || trimmed == "–" { return (0, false) }
        guard let value = Int(trimmed), value >= 0 else { return nil }
        return (value, false)
    }

    public static func isValid(die: Int) -> Bool { (1...6).contains(die) }

    /// The 1D6 result: 1 point of damage on 4+, else 0.
    public static func damage(forDie die: Int) -> Int {
        die >= threshold ? damageOnSuccess : 0
    }
}
