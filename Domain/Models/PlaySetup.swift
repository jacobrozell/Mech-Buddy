import Foundation

// A Play mode game's setup (PlayModeSpec § 5, § 12). Saved on the session, as the setup draft,
// and as the last setup. Every field decodes with a default so later milestones can add more.

/// How each side's force is limited (§ 5.2).
public enum ForceBudget: Codable, Sendable, Equatable {
    /// Point Value per side (p. 33). 50–500, step 5.
    case pointValue(Int)
    /// Number of 'Mechs per side, with an optional total Size cap (p. 33). PV is shown, not enforced.
    case count(units: Int, sizeCap: Int?)

    public static let pvRange = 50...500
    public static let pvStep = 5
    public static let pvPresets = [150, 200, 250, 300]

    /// Default budget by number of sides **[HOUSE]** (D5): 250 for two, 200 for three, 150 for four.
    public static func defaultPV(sides: Int) -> Int {
        switch sides {
        case ...2: 250
        case 3: 200
        default: 150
        }
    }

    private enum CodingKeys: String, CodingKey { case type, pv, units, sizeCap }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "count":
            self = .count(
                units: try c.decode(Int.self, forKey: .units),
                sizeCap: try c.decodeIfPresent(Int.self, forKey: .sizeCap)
            )
        default:
            self = .pointValue(try c.decodeIfPresent(Int.self, forKey: .pv) ?? 250)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pointValue(let pv):
            try c.encode("pointValue", forKey: .type)
            try c.encode(pv, forKey: .pv)
        case .count(let units, let sizeCap):
            try c.encode("count", forKey: .type)
            try c.encode(units, forKey: .units)
            try c.encodeIfPresent(sizeCap, forKey: .sizeCap)
        }
    }

    /// "250 PV" or "4 'Mechs, Size 11 or less".
    public var summary: String {
        switch self {
        case .pointValue(let pv):
            return "\(pv) PV"
        case .count(let units, let sizeCap):
            let mechs = units == 1 ? "1 ’Mech" : "\(units) ’Mechs"
            guard let sizeCap else { return mechs }
            return "\(mechs), Size \(sizeCap) or less"
        }
    }
}

/// Where the 'Mechs come from (§ 5.2).
public enum UnitPool: String, Codable, Sendable, CaseIterable {
    /// Minis the player owns (the collection), with any card face for each chassis.
    case owned
    /// Any card in the app.
    case anyCard
}

/// One 'Mech picked for a side (§ 5.3). Keeps a copy of the card's numbers it needs for the budget, so
/// a setup stays readable if the card library changes.
public struct ForcePick: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// Card library face id ("locust-lct-7v").
    public var cardId: String
    public var name: String
    /// Card PV at Skill 4.
    public var basePV: Int
    public var size: Int
    public var skill: Int
    public var isClan: Bool

    public init(
        id: UUID = UUID(),
        cardId: String,
        name: String,
        basePV: Int,
        size: Int,
        skill: Int,
        isClan: Bool
    ) {
        self.id = id
        self.cardId = cardId
        self.name = name
        self.basePV = basePV
        self.size = size
        self.skill = skill
        self.isClan = isClan
    }

    /// PV for this pilot (p. 35).
    public var adjustedPV: Int { AlphaStrikePointValue.adjusted(base: basePV, skill: skill) }

    /// The card's own skill: 4, or 3 for a Clan 'Mech (p. 35).
    public static func defaultSkill(isClan: Bool) -> Int { isClan ? 3 : 4 }
}

/// How the mapsheets are laid out (§ 5.4). A standard mapsheet is about 22″ × 17″.
public enum MapArrangement: String, Codable, Sendable, CaseIterable {
    case single
    /// Two sheets, long edges together.
    case pair
    case twoByTwo
    case threeByTwo

    public var sheetCount: Int {
        switch self {
        case .single: 1
        case .pair: 2
        case .twoByTwo: 4
        case .threeByTwo: 6
        }
    }

    /// Columns × rows of sheets, with the width running from Side A's home edge to Side B's.
    public var grid: (columns: Int, rows: Int) {
        switch self {
        case .single: (1, 1)
        case .pair: (1, 2)
        case .twoByTwo: (2, 2)
        case .threeByTwo: (3, 2)
        }
    }

    public var title: String {
        switch self {
        case .single: "1 sheet"
        case .pair: "2 sheets"
        case .twoByTwo: "2 × 2"
        case .threeByTwo: "3 × 2"
        }
    }

    public static let sheetWidth = 22.0
    public static let sheetDepth = 17.0
}

/// What the game is played on (§ 5.4). PM4: mapsheets or a mat; boards come in PM12–PM13.
public struct Battlefield: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case mat
        case mapsheets
    }

    public var kind: Kind
    /// Mat or table, inches. Width runs from Side A's home edge to Side B's.
    public var matWidth: Double
    public var matDepth: Double
    public var arrangement: MapArrangement
    /// One name per sheet, as printed ("Grassland #2").
    public var sheets: [String]

    public init(
        kind: Kind = .mat,
        matWidth: Double = 48,
        matDepth: Double = 36,
        arrangement: MapArrangement = .pair,
        sheets: [String] = []
    ) {
        self.kind = kind
        self.matWidth = matWidth
        self.matDepth = matDepth
        self.arrangement = arrangement
        self.sheets = sheets
    }

    /// Mat presets: 3′ × 4′, 4′ × 4′, 4′ × 6′ (width × depth in inches).
    public static let matPresets: [(title: String, width: Double, depth: Double)] = [
        ("3′ × 4′", 48, 36),
        ("4′ × 4′", 48, 48),
        ("4′ × 6′", 72, 48)
    ]

    /// Table width in inches, between the two home edges.
    public var width: Double {
        switch kind {
        case .mat: matWidth
        case .mapsheets: Double(arrangement.grid.columns) * MapArrangement.sheetWidth
        }
    }

    /// Table depth in inches.
    public var depth: Double {
        switch kind {
        case .mat: matDepth
        case .mapsheets: Double(arrangement.grid.rows) * MapArrangement.sheetDepth
        }
    }

    /// "Grassland #2 + Desert #2" or "Mat 48″ × 36″".
    public var summary: String {
        switch kind {
        case .mat:
            return "Mat \(Self.inches(matWidth)) × \(Self.inches(matDepth))"
        case .mapsheets:
            let names = sheets.prefix(arrangement.sheetCount)
            return names.isEmpty ? "\(arrangement.title) mapsheets" : names.joined(separator: " + ")
        }
    }

    static func inches(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))″" : String(format: "%.1f″", value)
    }

    /// Size advice for two sides (§ 5.4, p. 7). Nil when the table suits the force.
    public func advice(sides: Int, budgetPV: Int?) -> String? {
        if depth < 34 && width < 34 {
            return "Small table. Forces will meet on Turn 1."
        }
        if min(width, depth) < 34 {
            return "Small table. Forces will meet on Turn 1."
        }
        if sides <= 2, let budgetPV, budgetPV > 300, width * depth < 72 * 48 {
            return "Over about 300 PV a side, the book suggests 4′ × 6′."
        }
        if sides <= 2, width * depth < 48 * 36 {
            return "The book suggests 3′ × 4′ to 4′ × 4′."
        }
        return nil
    }
}

/// Optional rules for a Play game (§ 5.5). Defaults per D16 and D13.
public struct PlayRules: Codable, Sendable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case overheat, physicalAttacks, forcedWithdrawal, startOnTable, battlefieldSupport
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        overheat = try c.decodeIfPresent(Bool.self, forKey: .overheat) ?? true
        physicalAttacks = try c.decodeIfPresent(Bool.self, forKey: .physicalAttacks) ?? true
        forcedWithdrawal = try c.decodeIfPresent(Bool.self, forKey: .forcedWithdrawal) ?? true
        startOnTable = try c.decodeIfPresent(Bool.self, forKey: .startOnTable) ?? true
        battlefieldSupport = try c.decodeIfPresent(Int.self, forKey: .battlefieldSupport)
    }

    public var overheat: Bool
    public var physicalAttacks: Bool
    public var forcedWithdrawal: Bool
    /// On: 'Mechs start on the table. Off: they enter from their home edge on Turn 1 (p. 11 default).
    public var startOnTable: Bool
    /// Battlefield Support Points per side (pp. 12, 29-30). Nil = off. 0, 5 or 12.
    public var battlefieldSupport: Int?

    /// 1D6: 1-2 = 0, 3-4 = 5, 5-6 = 12 BSPs (p. 12).
    public static func supportPoints(forRoll roll: Int) -> Int { roll <= 2 ? 0 : (roll <= 4 ? 5 : 12) }

    public init(overheat: Bool = true, physicalAttacks: Bool = true, forcedWithdrawal: Bool = true, startOnTable: Bool = true,
                battlefieldSupport: Int? = nil) {
        self.battlefieldSupport = battlefieldSupport
        self.overheat = overheat
        self.physicalAttacks = physicalAttacks
        self.forcedWithdrawal = forcedWithdrawal
        self.startOnTable = startOnTable
    }
}

public struct PlaySetup: Codable, Sendable, Equatable {
    public var sides: [MatchSide]
    public var budget: ForceBudget
    public var allowImprovedSkills: Bool
    /// Best skill offered when improved skills are on (D7: 2 by default, 0–4 allowed).
    public var minimumSkill: Int
    public var pool: UnitPool
    public var battlefield: Battlefield
    /// Nil = last side standing (PM4). Objectives come in PM8.
    public var objective: String?
    /// Nil = no limit (PM4). Turn limits come in PM8.
    public var turnLimit: Int?
    public var rules: PlayRules
    public var diceMode: DiceMode
    public var forces: [SideId: [ForcePick]]

    public init(
        sides: [MatchSide] = MatchSide.missionPair,
        budget: ForceBudget = .pointValue(250),
        allowImprovedSkills: Bool = true,
        minimumSkill: Int = 2,
        pool: UnitPool = .owned,
        battlefield: Battlefield = Battlefield(),
        objective: String? = nil,
        turnLimit: Int? = nil,
        rules: PlayRules = PlayRules(),
        diceMode: DiceMode = .manual,
        forces: [SideId: [ForcePick]] = [:]
    ) {
        self.sides = sides
        self.budget = budget
        self.allowImprovedSkills = allowImprovedSkills
        self.minimumSkill = minimumSkill
        self.pool = pool
        self.battlefield = battlefield
        self.objective = objective
        self.turnLimit = turnLimit
        self.rules = rules
        self.diceMode = diceMode
        self.forces = forces
    }

    private enum CodingKeys: String, CodingKey {
        case sides, budget, allowImprovedSkills, minimumSkill, pool, battlefield
        case objective, turnLimit, rules, diceMode, forces
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sides = try c.decodeIfPresent([MatchSide].self, forKey: .sides) ?? MatchSide.missionPair
        budget = try c.decodeIfPresent(ForceBudget.self, forKey: .budget) ?? .pointValue(250)
        allowImprovedSkills = try c.decodeIfPresent(Bool.self, forKey: .allowImprovedSkills) ?? true
        minimumSkill = try c.decodeIfPresent(Int.self, forKey: .minimumSkill) ?? 2
        pool = try c.decodeIfPresent(UnitPool.self, forKey: .pool) ?? .owned
        battlefield = try c.decodeIfPresent(Battlefield.self, forKey: .battlefield) ?? Battlefield()
        objective = try c.decodeIfPresent(String.self, forKey: .objective)
        turnLimit = try c.decodeIfPresent(Int.self, forKey: .turnLimit)
        rules = try c.decodeIfPresent(PlayRules.self, forKey: .rules) ?? PlayRules()
        diceMode = try c.decodeIfPresent(DiceMode.self, forKey: .diceMode) ?? .manual
        forces = try c.decodeIfPresent([SideId: [ForcePick]].self, forKey: .forces) ?? [:]
    }

    /// "1 v 1": one entry per side, players per side (at least one).
    public var formatName: String {
        sides.map { String(max(1, $0.players.count)) }.joined(separator: " v ")
    }

    public func force(_ side: SideId) -> [ForcePick] { forces[side] ?? [] }

    /// Sum of adjusted PV (p. 35).
    public func totalPV(_ side: SideId) -> Int {
        force(side).reduce(0) { $0 + $1.adjustedPV }
    }

    public func totalSize(_ side: SideId) -> Int {
        force(side).reduce(0) { $0 + $1.size }
    }

    public var unitCount: Int { forces.values.reduce(0) { $0 + $1.count } }

    /// Under, exactly on, or over the side's budget (§ 5.3).
    public func budgetCheck(_ side: SideId) -> BudgetCheck {
        BudgetCheck.evaluate(budget, picks: force(side))
    }

    /// The ruleset the session plays by (§ 5.5). Last side standing; no turn cap.
    public var ruleset: ScenarioRuleset {
        ScenarioRuleset(
            overheatAllowed: rules.overheat,
            physicalAttacksAllowed: rules.physicalAttacks,
            forcedWithdrawal: rules.forcedWithdrawal,
            maxTurns: turnLimit,
            victory: .destroyAllEnemies
        )
    }

    /// Two sides, one player each, default names (PM4).
    public static func pickup(budgetPV: Int = 250, pool: UnitPool = .owned, diceMode: DiceMode = .manual) -> PlaySetup {
        PlaySetup(
            sides: [
                MatchSide(id: .lanceA, players: [""], homeEdge: .west),
                MatchSide(id: .lanceB, players: [""], homeEdge: .east)
            ],
            budget: .pointValue(budgetPV),
            pool: pool,
            diceMode: diceMode
        )
    }

    /// Per-side unit cap and per-game cap **[HOUSE app limit]** (D9).
    public static let maxUnitsPerSide = 10
    public static let maxUnitsPerGame = 24
}

/// A side's force against its budget (§ 5.3). Over budget is allowed; Review warns.
public struct BudgetCheck: Sendable, Equatable {
    public enum Status: Sendable, Equatable { case under, exact, over }

    public var status: Status
    /// PV or 'Mechs used and allowed.
    public var used: Int
    public var limit: Int
    /// Count budgets with a Size cap: total Size used and allowed.
    public var sizeUsed: Int?
    public var sizeCap: Int?

    public var isOver: Bool { status == .over }

    public static func evaluate(_ budget: ForceBudget, picks: [ForcePick]) -> BudgetCheck {
        switch budget {
        case .pointValue(let limit):
            let used = picks.reduce(0) { $0 + $1.adjustedPV }
            return BudgetCheck(status: status(used, limit), used: used, limit: limit)
        case .count(let units, let sizeCap):
            let size = picks.reduce(0) { $0 + $1.size }
            var result = BudgetCheck(status: status(picks.count, units), used: picks.count, limit: units, sizeUsed: size, sizeCap: sizeCap)
            if let sizeCap, size > sizeCap { result.status = .over }
            return result
        }
    }

    private static func status(_ used: Int, _ limit: Int) -> Status {
        used < limit ? .under : (used == limit ? .exact : .over)
    }

    /// "38 PV left", "12 PV over", "On budget". Count budgets: "1 ’Mech left", "Size 12 of 11".
    public var text: String {
        if let sizeUsed, let sizeCap, sizeUsed > sizeCap {
            return "Size \(sizeUsed) of \(sizeCap)"
        }
        let unit = sizeCap != nil || sizeUsed != nil ? "count" : "pv"
        switch status {
        case .exact:
            return "On budget"
        case .under:
            let left = limit - used
            return unit == "pv" ? "\(left) PV left" : (left == 1 ? "1 ’Mech left" : "\(left) ’Mechs left")
        case .over:
            let over = used - limit
            return unit == "pv" ? "\(over) PV over" : (over == 1 ? "1 ’Mech over" : "\(over) ’Mechs over")
        }
    }
}
