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

public struct InitiativeRolls: Codable, Sendable, Equatable {
    public var lanceA: DiceRoll2D6
    public var lanceB: DiceRoll2D6

    public init(lanceA: DiceRoll2D6, lanceB: DiceRoll2D6) {
        self.lanceA = lanceA
        self.lanceB = lanceB
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
    case draw

    private enum CodingKeys: String, CodingKey {
        case type, side
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
        }
    }

    public var displaySummary: String {
        switch self {
        case .draw:
            return "It’s a draw"
        case .winner(let side):
            return "\(side.displayName) wins"
        }
    }
}

public struct MatchSession: Identifiable, Codable, Sendable, Equatable {
    public static let currentSchemaVersion = 1

    public var id: UUID
    public var schemaVersion: Int
    public var modeId: GameModeId
    public var scenarioId: ScenarioId?
    public var ruleset: ScenarioRuleset
    public var turn: Int
    public var phase: PhaseId
    public var activeSide: SideId
    public var initiativeWinner: SideId?
    public var initiativeRolls: InitiativeRolls?
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
        initiativeWinner: SideId? = nil,
        initiativeRolls: InitiativeRolls? = nil,
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
        self.initiativeWinner = initiativeWinner
        self.initiativeRolls = initiativeRolls
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
        case id, schemaVersion, modeId, scenarioId, ruleset, turn, phase, activeSide
        case initiativeWinner, initiativeRolls, units, eventLog, status, outcome
        case tableReady, forcesLoaded, updatedAt, recoverySnapshots, diceMode, deploymentAcknowledged
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? MatchSession.currentSchemaVersion
        modeId = try container.decode(GameModeId.self, forKey: .modeId)
        scenarioId = try container.decodeIfPresent(ScenarioId.self, forKey: .scenarioId)
        ruleset = try container.decode(ScenarioRuleset.self, forKey: .ruleset)
        turn = try container.decode(Int.self, forKey: .turn)
        phase = try container.decode(PhaseId.self, forKey: .phase)
        activeSide = try container.decode(SideId.self, forKey: .activeSide)
        initiativeWinner = try container.decodeIfPresent(SideId.self, forKey: .initiativeWinner)
        initiativeRolls = try container.decodeIfPresent(InitiativeRolls.self, forKey: .initiativeRolls)
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
        try container.encodeIfPresent(initiativeWinner, forKey: .initiativeWinner)
        try container.encodeIfPresent(initiativeRolls, forKey: .initiativeRolls)
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
