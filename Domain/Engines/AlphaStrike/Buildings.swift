import Foundation

/// Building categories (Alpha Strike Quick-Start Rulebook p. 28, Alpha Strike Buildings Table).
/// The box's nine small buildings are Medium and its six large ones are Heavy (pp. 10, 28).
public enum BuildingType: String, Codable, Sendable, CaseIterable, Equatable {
    case light, medium, heavy, hardened

    public var displayName: String {
        switch self {
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        case .hardened: "Hardened"
        }
    }

    /// Extra inches of Move for each inch moved through the building (p. 28; p. 15 lists "+1–4″").
    public var moveCostPerInch: Int {
        switch self {
        case .light: 1
        case .medium: 2
        case .heavy: 3
        case .hardened: 4
        }
    }

    /// CF the players may choose from (p. 28).
    public var cfRange: ClosedRange<Int> {
        switch self {
        case .light: 1...5
        case .medium: 2...8
        case .heavy: 6...18
        case .hardened: 10...40
        }
    }

    /// Default CF (p. 28, in parentheses in the table).
    public var defaultCF: Int {
        switch self {
        case .light: 3
        case .medium: 4
        case .heavy: 12
        case .hardened: 20
        }
    }

    /// Most total Size of 'Mechs standing on it (p. 28 table). Owner call 2026-11-26: the table wins over the
    /// worked example's "Medium building—weight capacity 2".
    public var weightCapacity: Int {
        switch self {
        case .light: 2
        case .medium: 4
        case .heavy: 6
        case .hardened: 8
        }
    }

    /// Collapse damage value (p. 28 table). Light prints "0*": see `collapseIsMinimal`.
    public var collapseDamage: Int {
        switch self {
        case .light: 0
        case .medium: 1
        case .heavy: 2
        case .hardened: 4
        }
    }

    /// Light prints "0*", the book's mark for minimal damage (p. 21: 1D6, 4+ deals 1). Owner call 2026-11-26.
    public var collapseIsMinimal: Bool { self == .light }
}

/// One building on the table, with the CF it has left.
public struct BuildingState: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var type: BuildingType
    public var startingCF: Int
    public var cf: Int
    /// Height in whole inches. Only collapse damage uses it (p. 28).
    public var heightInches: Int
    public var collapsed: Bool

    public init(id: String, name: String, type: BuildingType, cf: Int? = nil, heightInches: Int = 2, collapsed: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        let start = cf.map { min(max($0, type.cfRange.lowerBound), type.cfRange.upperBound) } ?? type.defaultCF
        self.startingCF = start
        self.cf = start
        self.heightInches = max(1, heightInches)
        self.collapsed = collapsed
    }
}

/// Building rules from the Quick-Start Rulebook p. 28 (summary p. 10).
public enum BuildingRules {
    /// Extra Move to go `inches` through a building, on top of the normal 1″ per inch (p. 28).
    public static func extraMoveCost(_ type: BuildingType, inches: Int) -> Int {
        type.moveCostPerInch * max(0, inches)
    }

    /// A 'Mech moving through deals 1 point to the building's CF per inch inside it (p. 28).
    public static func moveThroughDamage(inches: Int) -> Int {
        max(0, inches)
    }

    /// The total Size standing on the building is more than it can hold, so it collapses (p. 28).
    public static func isOverCapacity(_ type: BuildingType, sizes: [Int]) -> Bool {
        sizes.reduce(0, +) > type.weightCapacity
    }

    /// The collapse damage value times every 4 full inches of height, round down, minimum 1 (p. 28).
    public static func collapseMultiplier(heightInches: Int) -> Int {
        max(1, heightInches / 4)
    }

    /// Damage to one 'Mech moving through or standing on the building when it collapses. +1 on the roof (p. 28).
    /// For a Light building ("0*") pass the minimal-damage die: 4+ deals 1 (owner call 2026-11-26).
    public static func collapseDamage(_ type: BuildingType, heightInches: Int, onRoof: Bool, minimalDie: Int? = nil) -> Int {
        let base: Int
        if type.collapseIsMinimal {
            base = minimalDie.map { MinimalDamage.damage(forDie: $0) } ?? 0
        } else {
            base = type.collapseDamage * collapseMultiplier(heightInches: heightInches)
        }
        return base + (onRoof ? 1 : 0)
    }

    /// A shot at a building: resolved as against an immobile target, −4 (pp. 18, 28). The building has no TMM.
    public static func attackTargetNumber(
        attacker: MatchUnitState,
        attackerMove: MovementMode,
        bracket: RangeBracket,
        woods: Bool = false,
        partialCover: Bool = false
    ) throws -> TargetNumber {
        try SATORResolver.resolve(
            SATORInput(
                skill: attacker.skill,
                attackerMove: attackerMove,
                targetMove: .immobile,
                targetTMM: 0,
                other: OtherModifiers(
                    woods: woods,
                    partialCover: partialCover,
                    fireControlHits: attacker.firingCrits.fireControlHits,
                    attackerHeat: attacker.heat
                ),
                rangeBracket: bracket
            )
        )
    }

    /// Weapon damage a hit does to the building's CF: the attacker's damage at that range (p. 28).
    /// No rear bonus (a building has no rear) and no overheat in this helper.
    public static func attackDamage(attacker: MatchUnitState, bracket: RangeBracket) -> Int {
        let d = attacker.firingDamage
        switch bracket {
        case .short: return d.s
        case .medium: return d.m
        case .long: return d.l
        case .outOfRange: return 0
        }
    }
}
