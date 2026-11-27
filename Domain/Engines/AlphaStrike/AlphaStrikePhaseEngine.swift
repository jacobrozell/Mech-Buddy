import Foundation

public enum MatchDomainError: Error, Sendable, Equatable {
    case initiativeTied
    case illegalPhaseTransition(String)
    case unitNotFound
    case cannotAttack(String)
    case noActiveSession
    case setupIncomplete
    case unsupportedPayloadSchema(Int)
}

extension MatchDomainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .initiativeTied:
            return "Initiative tied — both sides re-roll."
        case .illegalPhaseTransition(let message):
            return message
        case .unitNotFound:
            return "Unit not found"
        case .cannotAttack(let message):
            return message
        case .noActiveSession:
            return "No active match"
        case .setupIncomplete:
            return "Setup incomplete"
        case .unsupportedPayloadSchema(let version):
            return "Unsupported saved match version (\(version))"
        }
    }
}

public enum AlphaStrikePhaseEngine {
    public static let phaseOrder: [PhaseId] = [.initiative, .movement, .combat, .end]

    /// The winner: highest roll, acts last (p. 13). Throws while any tie is unbroken.
    public static func resolveInitiative(rolls: InitiativeRolls) throws -> SideId {
        let order = try initiativeOrder(rolls: rolls)
        return order[order.count - 1]
    }

    /// Lowest first, winner last (§ 6.1). Throws `initiativeTied` while tied sides still need a re-roll.
    /// Two sides: the lower total moves first; equal totals re-roll (p. 13).
    public static func initiativeOrder(rolls: InitiativeRolls) throws -> [SideId] {
        let resolution = rolls.resolution
        guard resolution.isResolved, resolution.order.count >= 2 else {
            throw MatchDomainError.initiativeTied
        }
        return resolution.order
    }

    public static func resetTurnFlags(_ units: inout [MatchUnitState]) {
        for i in units.indices {
            // Removed wrecks keep no per-turn state; a stale turnShot leaks into later shot feeds.
            units[i].turnShot = nil
            // A ’Mech that left the table counted in last turn's move order only.
            if units[i].leftTable {
                units[i].hasMovedThisTurn = false
            }
            guard units[i].combatStatus == .active || units[i].combatStatus == .destroyedPendingEnd else {
                continue
            }
            units[i].hasMovedThisTurn = false
            units[i].hasAttackedThisTurn = false
            units[i].rearShot = nil
            units[i].rearFireReduction = 0
            units[i].inWater = false
            units[i].turnShot = nil
            units[i].movementMode = .unset
        }
    }

    public static func removeDestroyedAtEnd(_ units: inout [MatchUnitState]) {
        for i in units.indices {
            if units[i].combatStatus == .destroyedPendingEnd
                || units[i].crits.destroyedByCrit
                || units[i].isStructurallyDestroyed {
                units[i].combatStatus = .removed
            }
        }
    }

    /// In this turn's move order: still on the table, or left it on this turn's move.
    /// Keeps the alternation right when a ’Mech drives off mid-phase.
    public static func inMoveOrder(_ unit: MatchUnitState) -> Bool {
        unit.combatStatus == .active || (unit.leftTable && unit.hasMovedThisTurn)
    }

    /// Moves recorded this turn, counting a ’Mech that left the table on its move.
    public static func movesRecorded(units: [MatchUnitState]) -> Int {
        units.filter { inMoveOrder($0) && $0.hasMovedThisTurn }.count
    }

    /// Marks sides with no ’Mech left on the table as out (§ 6.5). Returns the sides that went out now.
    /// Only the End Phase and conceding call this, so a side is never out mid-phase.
    @discardableResult
    public static func markSidesOut(_ session: inout MatchSession) -> [SideId] {
        var wentOut: [SideId] = []
        for index in session.sides.indices where !session.sides[index].isOut {
            let id = session.sides[index].id
            let onTable = session.units.contains { $0.side == id && $0.combatStatus == .active }
            if !onTable {
                session.sides[index].isOut = true
                session.sides[index].outOnTurn = session.turn
                wentOut.append(id)
            }
        }
        return wentOut
    }

    /// Raid: a token whose carrier is destroyed, off the table or gone drops where it stood (§ 7.1). It can be
    /// picked up again.
    public static func dropOrphanedTokens(_ session: inout MatchSession) {
        guard var state = session.objectiveState else { return }
        let active = Set(session.units.filter { $0.combatStatus == .active }.map(\.id))
        var dropped = false
        for index in state.tokens.indices {
            if let carrier = state.tokens[index].carrier, !active.contains(carrier) {
                state.tokens[index].carrier = nil
                dropped = true
            }
        }
        if dropped { session.objectiveState = state }
    }

    public static func movementComplete(units: [MatchUnitState]) -> Bool {
        units
            .filter { $0.combatStatus == .active }
            .allSatisfy(\.hasMovedThisTurn)
    }

    public static func unitsNeedingMove(side: SideId, units: [MatchUnitState]) -> [MatchUnitState] {
        units.filter {
            $0.side == side && $0.combatStatus == .active && !$0.hasMovedThisTurn
        }
    }

    /// Who moves after this move, reading `movementSequence(order:units:)` at the number of moves made.
    /// `order` is this turn's initiative order, lowest first. Empty falls back to plain rotation by seat.
    public static func nextMovementActiveSide(
        current: SideId,
        units: [MatchUnitState],
        order: [SideId]
    ) -> SideId {
        if !order.isEmpty {
            let sequence = movementSequence(order: order, units: units)
            let moved = movesRecorded(units: units)
            if moved < sequence.count { return sequence[moved] }
            return current
        }
        let seats = SideId.allCases
        let start = seats.firstIndex(of: current) ?? 0
        for step in 1..<seats.count {
            let side = seats[(start + step) % seats.count]
            if !unitsNeedingMove(side: side, units: units).isEmpty { return side }
        }
        return current
    }

    /// The whole turn's move order by side, from this turn's starting counts (PlayModeSpec § 6.2).
    ///
    /// Round by round: let *r* be each side's ’Mechs left to move and *m* the smallest non-zero *r*.
    /// Each side with ’Mechs left moves floor(*r* / *m*) of them (at least 1), in initiative order, lowest
    /// first. When only one side has ’Mechs left it moves them all.
    ///
    /// With two sides this is the QSR's unequal-numbers rule (p. 14): a side with at least twice as many
    /// ’Mechs left moves that multiple at once (8 vs 5 → 1-1, 1-1, 1-2, 1-2, 1-2). With three or four sides
    /// it is a house rule **[HOUSE]**.
    public static func movementSequence(order: [SideId], units: [MatchUnitState]) -> [SideId] {
        let active = units.filter(inMoveOrder)
        var remaining = order.map { side in active.filter { $0.side == side }.count }
        var sequence: [SideId] = []
        while remaining.contains(where: { $0 > 0 }) {
            let live = remaining.filter { $0 > 0 }
            if live.count == 1, let index = remaining.firstIndex(where: { $0 > 0 }) {
                sequence += Array(repeating: order[index], count: remaining[index])
                break
            }
            let smallest = live.min() ?? 1
            for index in order.indices where remaining[index] > 0 {
                let batch = max(1, remaining[index] / smallest)
                sequence += Array(repeating: order[index], count: batch)
                remaining[index] -= batch
            }
        }
        return sequence
    }

    /// Two sides: `firstToMove` (the initiative loser), then every other side that has units, in seat order.
    public static func movementSequence(firstToMove: SideId, units: [MatchUnitState]) -> [SideId] {
        let present = Set(units.map(\.side))
        let rest = SideId.allCases.filter { $0 != firstToMove && present.contains($0) }
        return movementSequence(order: [firstToMove] + rest, units: units)
    }

    public static func hasPendingCriticals(units: [MatchUnitState]) -> Bool {
        units.contains { $0.pendingCritical }
    }
}
