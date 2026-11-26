import Foundation

/// Battlefield Support types (Alpha Strike Quick-Start Rulebook pp. 29–30, Alpha Strike Battlefield Support Table).
public enum BattlefieldSupportType: String, Codable, Sendable, CaseIterable, Equatable {
    case lightStrike, lightBombing, heavyStrike, heavyBombing, thumper, sniper

    public var displayName: String {
        switch self {
        case .lightStrike: "Light Strike"
        case .lightBombing: "Light Bombing"
        case .heavyStrike: "Heavy Strike"
        case .heavyBombing: "Heavy Bombing"
        case .thumper: "Thumper artillery"
        case .sniper: "Sniper artillery"
        }
    }

    public enum Category: String, Sendable { case aerospaceStrike, aerospaceBombing, artillery }

    public var category: Category {
        switch self {
        case .lightStrike, .heavyStrike: .aerospaceStrike
        case .lightBombing, .heavyBombing: .aerospaceBombing
        case .thumper, .sniper: .artillery
        }
    }

    /// 2D6 target number. No modifiers of any kind (pp. 29–30).
    public var targetNumber: Int {
        switch self {
        case .lightStrike: 5
        case .lightBombing: 5
        case .heavyStrike: 6
        case .heavyBombing: 7
        case .thumper: 7
        case .sniper: 8
        }
    }

    /// Damage to each 'Mech hit (p. 30 table; the Thumper and Sniper "12"/"22" are 1 and 2 with footnote 2).
    public var damage: Int {
        switch self {
        case .lightStrike, .lightBombing, .thumper: 1
        case .heavyStrike, .heavyBombing, .sniper: 2
        }
    }

    /// Battlefield Support Points (p. 30 table). The p. 29 example swaps the Thumper and Sniper costs;
    /// the table wins (owner call 2026-11-26).
    public var cost: Int {
        switch self {
        case .lightStrike: 2
        case .lightBombing: 3
        case .heavyStrike: 3
        case .heavyBombing: 4
        case .thumper: 2
        case .sniper: 3
        }
    }

    /// Bombing and artillery use the area-of-effect template: every 'Mech base it touches is hit (pp. 29–30).
    public var usesTemplate: Bool { category != .aerospaceStrike }

    /// A missed bombing or artillery attack scatters (p. 30 table footnote 1). A missed strike does nothing.
    public var scattersOnMiss: Bool { usesTemplate }

    /// Artillery targets a Point of Impact only; strikes target a 'Mech; bombing either (pp. 29–30).
    public var targetsMech: Bool { category != .artillery }
    public var targetsPointOfImpact: Bool { category != .aerospaceStrike }

    public var isArtillery: Bool { category == .artillery }
}

public enum BattlefieldSupportRules {
    /// Scenario budgets (p. 29): Extraction Raid 5, Objective Raid 12. Clash of Steel gives 5 each (p. 31).
    public static let extractionRaidBudget = 5
    public static let objectiveRaidBudget = 12

    /// When a scenario sets no budget, roll 1D6 (p. 12): 1–2 none, 3–4 Extraction Raid, 5–6 Objective Raid.
    public static func budget(forDie die: Int) -> Int {
        switch die {
        case ...2: 0
        case 3...4: extractionRaidBudget
        default: objectiveRaidBudget
        }
    }

    public static func cost(of picks: [BattlefieldSupportType]) -> Int {
        picks.reduce(0) { $0 + $1.cost }
    }

    public static func fitsBudget(_ picks: [BattlefieldSupportType], budget: Int) -> Bool {
        cost(of: picks) <= budget
    }

    /// Flat 2D6 against the table's number (p. 29).
    public static func isHit(_ type: BattlefieldSupportType, roll: DiceRoll2D6) -> Bool {
        roll.total >= type.targetNumber
    }

    /// A miss with the template: 1D6 picks one of six directions around the template, "1" toward the map's
    /// north; a second 1D6 × 2 is the distance in inches from the original target or point (p. 30).
    public struct Scatter: Codable, Sendable, Equatable {
        public var direction: Int
        public var inches: Int

        public init(direction: Int, inches: Int) {
            self.direction = direction
            self.inches = inches
        }
    }

    public static func scatter(directionDie: Int, distanceDie: Int) -> Scatter? {
        guard (1...6).contains(directionDie), (1...6).contains(distanceDie) else { return nil }
        return Scatter(direction: directionDie, inches: distanceDie * 2)
    }
}

/// One bought support, used once whether it hits or not (p. 29).
public struct SupportPick: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var type: BattlefieldSupportType
    /// Turn it was used. Nil while still available.
    public var usedOnTurn: Int?

    public init(id: UUID = UUID(), type: BattlefieldSupportType, usedOnTurn: Int? = nil) {
        self.id = id
        self.type = type
        self.usedOnTurn = usedOnTurn
    }

    public var isUsed: Bool { usedOnTurn != nil }
}

/// A side's secret Battlefield Support purchase.
public struct SupportInventory: Codable, Sendable, Equatable {
    public var budget: Int
    public var picks: [SupportPick]
    /// The picks are written down (p. 29: chosen before play begins). They can't change after.
    public var locked: Bool

    public init(budget: Int, picks: [SupportPick] = [], locked: Bool = false) {
        self.budget = budget
        self.picks = picks
        self.locked = locked
    }

    public var spent: Int { BattlefieldSupportRules.cost(of: picks.map(\.type)) }
    public var available: [SupportPick] { picks.filter { !$0.isUsed } }
}
