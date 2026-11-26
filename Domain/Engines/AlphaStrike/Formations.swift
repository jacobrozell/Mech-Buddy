import Foundation

/// Formation types used by the box scenarios (Alpha Strike Quick-Start Rulebook pp. 32, 37–39).
public enum FormationKind: String, Codable, Sendable, CaseIterable, Equatable {
    /// Initiative reroll while the command 'Mech stands, and Combat Intuition on two 'Mechs (p. 32).
    case commandLance
    /// Maneuvering Ace for every member: woods cost 1″ less per inch (p. 32).
    case reconLance
    /// A shared pool of Lucky attack rerolls (p. 32: seven in Clash of Steel).
    case battleStar

    public var displayName: String {
        switch self {
        case .commandLance: "Command Lance"
        case .reconLance: "Recon Lance"
        case .battleStar: "Battle Star"
        }
    }
}

/// One Formation in play and what it has used.
public struct FormationState: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var kind: FormationKind
    public var name: String
    public var memberIds: [UUID]
    /// Command Lance: the 'Mech whose survival keeps the initiative reroll (Clash of Steel: the Atlas, p. 32).
    public var commandUnitId: UUID?
    /// Command Lance: how many 'Mechs get Combat Intuition (p. 32: two, not the Atlas).
    public var combatIntuitionCount: Int
    /// Chosen at the start of the scenario; fixed after that (pp. 32, 38).
    public var combatIntuitionIds: [UUID]
    /// Turn each Combat Intuition 'Mech last used it.
    public var combatIntuitionLastUsed: [UUID: Int]
    /// Battle Star: Lucky uses left (p. 32: seven).
    public var luckyUsesLeft: Int
    /// Command Lance: the turn the initiative reroll was last used.
    public var initiativeRerollTurn: Int?

    public init(
        id: String,
        kind: FormationKind,
        name: String? = nil,
        memberIds: [UUID],
        commandUnitId: UUID? = nil,
        combatIntuitionCount: Int = 0,
        combatIntuitionIds: [UUID] = [],
        combatIntuitionLastUsed: [UUID: Int] = [:],
        luckyUsesLeft: Int = 0,
        initiativeRerollTurn: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name ?? kind.displayName
        self.memberIds = memberIds
        self.commandUnitId = commandUnitId
        self.combatIntuitionCount = combatIntuitionCount
        self.combatIntuitionIds = combatIntuitionIds
        self.combatIntuitionLastUsed = combatIntuitionLastUsed
        self.luckyUsesLeft = luckyUsesLeft
        self.initiativeRerollTurn = initiativeRerollTurn
    }
}

public enum FormationRules {
    /// A Formation's bonus works while at least three of its 'Mechs are not destroyed (p. 37).
    public static let minimumSurvivors = 3

    /// Combat Intuition: once per 'Mech every 3 turns (p. 32). Used on turn 2, next on turn 5.
    public static let combatIntuitionCooldown = 3

    /// Not destroyed: still on the table, or crippled and withdrawing. A 'Mech that left the table counts as
    /// destroyed (p. 12).
    public static func isStanding(_ unit: MatchUnitState) -> Bool {
        unit.combatStatus == .active && !unit.isStructurallyDestroyed && !unit.crits.destroyedByCrit
    }

    public static func survivors(_ formation: FormationState, units: [MatchUnitState]) -> Int {
        formation.memberIds.filter { id in units.first { $0.id == id }.map(isStanding) ?? false }.count
    }

    public static func isActive(_ formation: FormationState, units: [MatchUnitState]) -> Bool {
        survivors(formation, units: units) >= minimumSurvivors
    }

    public static func side(of formation: FormationState, units: [MatchUnitState]) -> SideId? {
        formation.memberIds.lazy.compactMap { id in units.first { $0.id == id }?.side }.first
    }

    /// Command Lance reroll (p. 32): once per turn while the Atlas is not destroyed. The scenario text wins over
    /// the general "once every two turns" on p. 38 (owner call 2026-11-26).
    public static func canRerollInitiative(_ formation: FormationState, session: MatchSession) -> Bool {
        guard formation.kind == .commandLance, isActive(formation, units: session.units) else { return false }
        guard let commander = formation.commandUnitId,
              let unit = session.units.first(where: { $0.id == commander }), isStanding(unit) else { return false }
        return formation.initiativeRerollTurn != session.turn
    }

    /// Combat Intuition is off cooldown for this 'Mech on this turn. Using it again on the same turn (its other
    /// attacks) is part of the same use.
    public static func combatIntuitionReady(_ formation: FormationState, unitId: UUID, turn: Int) -> Bool {
        guard formation.combatIntuitionIds.contains(unitId) else { return false }
        guard let last = formation.combatIntuitionLastUsed[unitId] else { return true }
        return last == turn || turn - last >= combatIntuitionCooldown
    }

    /// Turn it can next be used, when it is cooling down.
    public static func combatIntuitionNextTurn(_ formation: FormationState, unitId: UUID) -> Int? {
        formation.combatIntuitionLastUsed[unitId].map { $0 + combatIntuitionCooldown }
    }

    /// Everything Combat Intuition needs right now (p. 32): the side won Initiative, it's the Movement Phase,
    /// the 'Mech has moved and can still attack, the Formation is active and the 'Mech is off cooldown.
    public static func combatIntuitionBlockReason(_ formation: FormationState, unit: MatchUnitState, session: MatchSession) -> String? {
        guard formation.combatIntuitionIds.contains(unit.id) else { return "\(unit.name) doesn’t have Combat Intuition." }
        guard session.phase == .movement else { return "Combat Intuition is used in the Movement Phase." }
        guard session.initiativeWinner == unit.side else { return "Only when its side won Initiative." }
        guard isActive(formation, units: session.units) else { return "The Command Lance has fewer than three ’Mechs left." }
        guard combatIntuitionReady(formation, unitId: unit.id, turn: session.turn) else {
            let next = combatIntuitionNextTurn(formation, unitId: unit.id) ?? session.turn
            return "Used recently. Ready again on turn \(next)."
        }
        guard unit.hasMovedThisTurn else { return "Record \(unit.name)’s move first, then attack." }
        guard unit.canAttackThisTurn else { return "\(unit.name) can’t attack this turn." }
        return nil
    }

    /// Lucky (p. 32): a 'Mech in the Battle Star rerolls one Attack Roll. Not crits, Initiative or other rolls.
    public static func canUseLucky(_ formation: FormationState, unitId: UUID, units: [MatchUnitState]) -> Bool {
        formation.kind == .battleStar && formation.luckyUsesLeft > 0
            && formation.memberIds.contains(unitId) && isActive(formation, units: units)
    }
}

/// Terrain for the movement-cost helper (Movement Cost Table p. 15, Buildings Table p. 28).
public enum MoveTerrain: Sendable, Equatable {
    case clear, roughOrRubble, woods, water
    case building(BuildingType)
}

public enum MovementCost {
    /// Level change, up or down, per inch: one extra inch per inch (p. 15 Level Change paragraph). The table on
    /// the same page prints "+2″"; owner call 2026-11-26 follows the paragraph.
    public static let levelChangePerInch = 1

    /// Extra inches per inch moved. Maneuvering Ace (Recon Lance, p. 32) takes 1″ off woods.
    public static func extraPerInch(_ terrain: MoveTerrain, maneuveringAce: Bool = false) -> Int {
        switch terrain {
        case .clear: 0
        case .roughOrRubble, .water: 1
        case .woods: maneuveringAce ? 0 : 1
        case .building(let type): type.moveCostPerInch
        }
    }

    /// Total Move used to go `inches` across terrain, plus any level change.
    public static func total(inches: Int, terrain: MoveTerrain, levelChange: Int = 0, maneuveringAce: Bool = false) -> Int {
        inches * (1 + extraPerInch(terrain, maneuveringAce: maneuveringAce)) + abs(levelChange) * levelChangePerInch
    }
}
