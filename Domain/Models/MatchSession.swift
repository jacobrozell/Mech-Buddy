import Foundation

public struct DiceRoll2D6: Codable, Sendable, Equatable {
    public var die1: Int
    public var die2: Int

    public init(die1: Int, die2: Int) {
        precondition((1...6).contains(die1) && (1...6).contains(die2), "Dice must be 1–6")
        self.die1 = die1
        self.die2 = die2
    }

    public var total: Int { die1 + die2 }
    public var isNaturalTwelve: Bool { die1 == 6 && die2 == 6 }

    public static func validated(die1: Int, die2: Int) -> DiceRoll2D6? {
        guard (1...6).contains(die1), (1...6).contains(die2) else { return nil }
        return DiceRoll2D6(die1: die1, die2: die2)
    }
}

/// How this match produces 2D6 results. Chosen once (table setup or “we don’t have dice”) and reused for every roll.
public enum DiceMode: String, Codable, Sendable, Equatable {
    /// Players roll on the table and tap the faces. The app says hit or miss.
    case manual
    /// The app rolls. The app says hit or miss.
    case auto
}

/// Initiative dice for one turn (PlayModeSpec § 12). `order` is lowest first; its last side is the winner.
/// Payload v1 saved `{ "lanceA": …, "lanceB": … }`; that shape still decodes.
public struct InitiativeRolls: Codable, Sendable, Equatable {
    public var rolls: [SideId: DiceRoll2D6]
    /// Tie-break rounds (§ 6.1). Round k holds only the sides still tied after round k − 1.
    public var rerolls: [[SideId: DiceRoll2D6]]
    /// Lowest first. Empty while a tie is unresolved.
    public var order: [SideId]

    public init(rolls: [SideId: DiceRoll2D6], rerolls: [[SideId: DiceRoll2D6]] = []) {
        self.rolls = rolls
        self.rerolls = rerolls
        let resolution = InitiativeOrder.resolve(rolls: rolls, rerolls: rerolls)
        self.order = resolution.isResolved ? resolution.order : []
    }

    /// Two sides, one roll each (missions).
    public init(lanceA: DiceRoll2D6, lanceB: DiceRoll2D6) {
        self.init(rolls: [.lanceA: lanceA, .lanceB: lanceB])
    }

    public var lanceA: DiceRoll2D6? { rolls[.lanceA] }
    public var lanceB: DiceRoll2D6? { rolls[.lanceB] }

    /// Highest roll, acts last. Nil while tied.
    public var winner: SideId? { order.last }

    public var resolution: InitiativeOrder.Resolution {
        InitiativeOrder.resolve(rolls: rolls, rerolls: rerolls)
    }

    private enum CodingKeys: String, CodingKey {
        case rolls, rerolls, order
        case lanceA, lanceB
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.rolls) {
            let rolls = try container.decode([SideId: DiceRoll2D6].self, forKey: .rolls)
            let rerolls = try container.decodeIfPresent([[SideId: DiceRoll2D6]].self, forKey: .rerolls) ?? []
            self.init(rolls: rolls, rerolls: rerolls)
            if let saved = try container.decodeIfPresent([SideId].self, forKey: .order), !saved.isEmpty {
                order = saved
            }
        } else {
            // Payload v1.
            self.init(
                lanceA: try container.decode(DiceRoll2D6.self, forKey: .lanceA),
                lanceB: try container.decode(DiceRoll2D6.self, forKey: .lanceB)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rolls, forKey: .rolls)
        if !rerolls.isEmpty {
            try container.encode(rerolls, forKey: .rerolls)
        }
        try container.encode(order, forKey: .order)
    }

    /// The same rolls with sides renamed (Swap sides).
    func mapSides(_ transform: (SideId) -> SideId) -> InitiativeRolls {
        var copy = self
        copy.rolls = Dictionary(uniqueKeysWithValues: rolls.map { (transform($0.key), $0.value) })
        copy.rerolls = rerolls.map { round in
            Dictionary(uniqueKeysWithValues: round.map { (transform($0.key), $0.value) })
        }
        copy.order = order.map(transform)
        return copy
    }
}

public struct MatchEvent: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var turn: Int
    public var phase: PhaseId
    public var message: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        turn: Int,
        phase: PhaseId,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.turn = turn
        self.phase = phase
        self.message = message
        self.createdAt = createdAt
    }
}

public enum MatchOutcome: Codable, Sendable, Equatable {
    case winner(SideId)
    /// Every side level (two sides), or a mutual wipe. Missions only ever end this way or with a winner.
    case draw
    /// Some sides finished level and share the result (3–4 sides, PlayModeSpec § 7.4).
    case tied([SideId])

    private enum CodingKeys: String, CodingKey {
        case type, side, sides
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "draw":
            self = .draw
        case "winner":
            let side = try container.decode(SideId.self, forKey: .side)
            self = .winner(side)
        case "tied":
            self = .tied(try container.decode([SideId].self, forKey: .sides))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown outcome \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .draw:
            try container.encode("draw", forKey: .type)
        case .winner(let side):
            try container.encode("winner", forKey: .type)
            try container.encode(side, forKey: .side)
        case .tied(let sides):
            try container.encode("tied", forKey: .type)
            try container.encode(sides, forKey: .sides)
        }
    }

    public var displaySummary: String {
        switch self {
        case .draw:
            return "It’s a draw"
        case .winner(let side):
            return "\(side.displayName) wins"
        case .tied(let sides):
            return "Tie: " + sides.map(\.displayName).joined(separator: ", ")
        }
    }

    /// The sides that share first place.
    public var winningSides: [SideId] {
        switch self {
        case .winner(let side): [side]
        case .tied(let sides): sides
        case .draw: []
        }
    }
}

public struct MatchSession: Identifiable, Codable, Sendable, Equatable {
    /// Payload version. 2 added sides (C, D, `sides`), initiative order and `.tied` (PlayModeSpec § 12).
    /// v1 payloads decode with Side A and Side B.
    public static let currentSchemaVersion = 2

    public var id: UUID
    public var schemaVersion: Int
    public var modeId: GameModeId
    public var scenarioId: ScenarioId?
    public var ruleset: ScenarioRuleset
    public var turn: Int
    public var phase: PhaseId
    public var activeSide: SideId
    /// The sides in this match, in seat order. Missions: Side A, Side B.
    public var sides: [MatchSide]
    public var initiativeWinner: SideId?
    public var initiativeRolls: InitiativeRolls?
    /// This turn's initiative order, lowest first: first to move, winner last. Empty before initiative.
    public var initiativeOrder: [SideId]
    public var units: [MatchUnitState]
    public var eventLog: [MatchEvent]
    public var status: MatchStatus
    public var outcome: MatchOutcome?
    public var tableReady: Bool
    public var forcesLoaded: Bool
    public var diceMode: DiceMode
    /// Turn 1 placement has been confirmed. Old saves decode as false.
    public var deploymentAcknowledged: Bool
    public var updatedAt: Date
    /// Prior sessions for Undo and Back. Empty on snapshots so saves stay flat.
    public var recoverySnapshots: [MatchSession]

    public init(
        id: UUID = UUID(),
        schemaVersion: Int = MatchSession.currentSchemaVersion,
        modeId: GameModeId = .alphaStrike,
        scenarioId: ScenarioId? = nil,
        ruleset: ScenarioRuleset,
        turn: Int = 1,
        phase: PhaseId = .initiative,
        activeSide: SideId = .lanceA,
        sides: [MatchSide] = MatchSide.missionPair,
        initiativeWinner: SideId? = nil,
        initiativeRolls: InitiativeRolls? = nil,
        initiativeOrder: [SideId]? = nil,
        units: [MatchUnitState] = [],
        eventLog: [MatchEvent] = [],
        status: MatchStatus = .active,
        outcome: MatchOutcome? = nil,
        tableReady: Bool = false,
        forcesLoaded: Bool = false,
        diceMode: DiceMode = .manual,
        deploymentAcknowledged: Bool = false,
        updatedAt: Date = Date(),
        recoverySnapshots: [MatchSession] = []
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.modeId = modeId
        self.scenarioId = scenarioId
        self.ruleset = ruleset
        self.turn = turn
        self.phase = phase
        self.activeSide = activeSide
        self.sides = sides
        self.initiativeWinner = initiativeWinner
        self.initiativeRolls = initiativeRolls
        self.initiativeOrder = initiativeOrder
            ?? Self.legacyOrder(winner: initiativeWinner, rolls: initiativeRolls, sides: sides)
        self.units = units
        self.eventLog = eventLog
        self.status = status
        self.outcome = outcome
        self.tableReady = tableReady
        self.forcesLoaded = forcesLoaded
        self.diceMode = diceMode
        self.deploymentAcknowledged = deploymentAcknowledged
        self.updatedAt = updatedAt
        self.recoverySnapshots = recoverySnapshots
    }

    private enum CodingKeys: String, CodingKey {
        case id, schemaVersion, modeId, scenarioId, ruleset, turn, phase, activeSide, sides
        case initiativeWinner, initiativeRolls, initiativeOrder, units, eventLog, status, outcome
        case tableReady, forcesLoaded, updatedAt, recoverySnapshots, diceMode, deploymentAcknowledged
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        // An older payload is upgraded in memory and saved as the current version. A newer one keeps its
        // number so the repository can set it aside (MatchSessionSpec).
        let savedVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? MatchSession.currentSchemaVersion
        schemaVersion = max(savedVersion, MatchSession.currentSchemaVersion)
        modeId = try container.decode(GameModeId.self, forKey: .modeId)
        scenarioId = try container.decodeIfPresent(ScenarioId.self, forKey: .scenarioId)
        ruleset = try container.decode(ScenarioRuleset.self, forKey: .ruleset)
        turn = try container.decode(Int.self, forKey: .turn)
        phase = try container.decode(PhaseId.self, forKey: .phase)
        activeSide = try container.decode(SideId.self, forKey: .activeSide)
        sides = try container.decodeIfPresent([MatchSide].self, forKey: .sides) ?? MatchSide.missionPair
        initiativeWinner = try container.decodeIfPresent(SideId.self, forKey: .initiativeWinner)
        initiativeRolls = try container.decodeIfPresent(InitiativeRolls.self, forKey: .initiativeRolls)
        initiativeOrder = try container.decodeIfPresent([SideId].self, forKey: .initiativeOrder)
            ?? Self.legacyOrder(winner: initiativeWinner, rolls: initiativeRolls, sides: sides)
        units = try container.decode([MatchUnitState].self, forKey: .units)
        eventLog = try container.decode([MatchEvent].self, forKey: .eventLog)
        status = try container.decode(MatchStatus.self, forKey: .status)
        outcome = try container.decodeIfPresent(MatchOutcome.self, forKey: .outcome)
        tableReady = try container.decode(Bool.self, forKey: .tableReady)
        forcesLoaded = try container.decode(Bool.self, forKey: .forcesLoaded)
        diceMode = try container.decodeIfPresent(DiceMode.self, forKey: .diceMode) ?? .manual
        deploymentAcknowledged = try container.decodeIfPresent(Bool.self, forKey: .deploymentAcknowledged) ?? false
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        recoverySnapshots = try container.decodeIfPresent([MatchSession].self, forKey: .recoverySnapshots) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(modeId, forKey: .modeId)
        try container.encodeIfPresent(scenarioId, forKey: .scenarioId)
        try container.encode(ruleset, forKey: .ruleset)
        try container.encode(turn, forKey: .turn)
        try container.encode(phase, forKey: .phase)
        try container.encode(activeSide, forKey: .activeSide)
        try container.encode(sides, forKey: .sides)
        try container.encodeIfPresent(initiativeWinner, forKey: .initiativeWinner)
        try container.encodeIfPresent(initiativeRolls, forKey: .initiativeRolls)
        try container.encode(initiativeOrder, forKey: .initiativeOrder)
        try container.encode(units, forKey: .units)
        try container.encode(eventLog, forKey: .eventLog)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(outcome, forKey: .outcome)
        try container.encode(tableReady, forKey: .tableReady)
        try container.encode(forcesLoaded, forKey: .forcesLoaded)
        try container.encode(diceMode, forKey: .diceMode)
        try container.encode(deploymentAcknowledged, forKey: .deploymentAcknowledged)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(recoverySnapshots, forKey: .recoverySnapshots)
    }
}

extension MatchSession {
    /// A v1 save has a winner and maybe rolls but no order. Two sides: loser first, winner last.
    static func legacyOrder(winner: SideId?, rolls: InitiativeRolls?, sides: [MatchSide]) -> [SideId] {
        if let rolls, !rolls.order.isEmpty { return rolls.order }
        guard let winner else { return [] }
        return sides.map(\.id).filter { $0 != winner } + [winner]
    }
}

// MARK: - Sides

extension MatchSession {
    /// Every side in seat order, including sides that are out.
    public var sideIds: [SideId] { sides.map(\.id) }

    /// Sides still in the game, in seat order.
    public var sidesInGame: [SideId] { sides.filter { !$0.isOut }.map(\.id) }

    public func side(_ id: SideId) -> MatchSide? {
        sides.first { $0.id == id }
    }

    /// The name players see for this side: the session's name, or "Side A" for a side it doesn't hold.
    public func displayName(of id: SideId) -> String {
        side(id)?.name ?? id.displayName
    }

    /// The other sides still in the game, in seat order. Any of their ’Mechs is a legal target (§ 6.3).
    public func opponents(of id: SideId) -> [SideId] {
        sidesInGame.filter { $0 != id }
    }

    /// The next side after this one in seat order, wrapping round. Sides that are out are skipped
    /// unless every other side is out.
    public func nextSide(after id: SideId) -> SideId {
        let ids = sideIds
        guard let index = ids.firstIndex(of: id), ids.count > 1 else { return id }
        let rotated = Array(ids[(index + 1)...] + ids[..<index])
        let inGame = Set(sidesInGame)
        return rotated.first { inGame.contains($0) } ?? rotated[0]
    }

    /// The opposing side in a two-side game (every mission). Keeps mission code short.
    /// With more sides there is no single "other side": use `opponents(of:)`.
    public func otherSide(of id: SideId) -> SideId {
        assert(sides.count == 2, "otherSide(of:) is for two-side games; use opponents(of:)")
        let ids = sideIds
        return ids.first { $0 != id } ?? id
    }

    /// The side that moves first this turn: lowest initiative. Nil before initiative.
    public var firstToMove: SideId? { initiativeOrder.first }
}

extension MatchSession {
    /// Sides can be traded until a move, a shot, or damage is recorded.
    public var canSwapSides: Bool {
        guard phase == .initiative || phase == .movement else { return false }
        return !units.contains {
            $0.hasMovedThisTurn || $0.hasAttackedThisTurn || $0.armorDamage > 0 || $0.structureDamage > 0
        }
    }

    /// Forced Withdrawal is on and this ’Mech is crippled and still on the table:
    /// it must move toward its own edge, and it can still attack (rulebook p. 12).
    public func mustWithdraw(_ unit: MatchUnitState) -> Bool {
        ruleset.forcedWithdrawal && unit.combatStatus == .active && unit.isCrippled
    }

    /// Crippled this turn and not yet announced. The End Phase logs them, then they drop off this list.
    public var newlyCrippled: [MatchUnitState] {
        units.filter { mustWithdraw($0) && !$0.withdrawalAnnounced }
    }

    /// Why this ’Mech can't be recorded as leaving the table right now, or nil when it can.
    /// During Movement it leaves on its own move, so the move order stays right.
    public func leaveTableBlockReason(_ unit: MatchUnitState) -> String? {
        guard status == .active else { return "The game is over." }
        guard unit.combatStatus == .active else {
            return unit.combatStatus == .removed ? "It’s already off the table." : "It’s wrecked."
        }
        if units.contains(where: \.pendingCritical) {
            return "Roll the critical first."
        }
        if phase == .movement, !unit.hasMovedThisTurn, unit.side != activeSide {
            return "Record this on its move."
        }
        return nil
    }

    /// First movement of turn 1, before anyone has moved and before the players confirm placement.
    public var needsDeploymentAcknowledgement: Bool {
        phase == .movement
            && turn == 1
            && tableReady
            && !deploymentAcknowledged
            && !units.contains(where: \.hasMovedThisTurn)
    }
}
