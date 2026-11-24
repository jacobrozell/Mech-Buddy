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

    public static func initiativeLoser(winner: SideId) -> SideId {
        winner.other
    }

    public static func resolveInitiative(rolls: InitiativeRolls) throws -> SideId {
        let a = rolls.lanceA.total
        let b = rolls.lanceB.total
        if a == b { throw MatchDomainError.initiativeTied }
        return a > b ? .lanceA : .lanceB
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

    /// Who moves after this move. Sides alternate, but before each pair of moves a side with at least
    /// twice as many 'Mechs left to move moves that multiple at once (rulebook p. 14).
    /// `firstToMove` is the initiative loser. Nil falls back to plain alternation.
    public static func nextMovementActiveSide(
        current: SideId,
        units: [MatchUnitState],
        firstToMove: SideId? = nil
    ) -> SideId {
        if let firstToMove {
            let sequence = movementSequence(firstToMove: firstToMove, units: units)
            let moved = movesRecorded(units: units)
            if moved < sequence.count { return sequence[moved] }
            return current
        }
        let other = current.other
        if !unitsNeedingMove(side: other, units: units).isEmpty {
            return other
        }
        return current
    }

    /// The whole turn's move order by side, from this turn's starting counts.
    public static func movementSequence(firstToMove: SideId, units: [MatchUnitState]) -> [SideId] {
        let active = units.filter(inMoveOrder)
        var first = active.filter { $0.side == firstToMove }.count
        var second = active.filter { $0.side != firstToMove }.count
        var sequence: [SideId] = []
        func batch(_ mine: Int, _ theirs: Int) -> Int {
            guard mine > 0 else { return 0 }
            guard theirs > 0 else { return mine }
            return mine >= 2 * theirs ? mine / theirs : 1
        }
        while first > 0 || second > 0 {
            let firstBatch = batch(first, second)
            let secondBatch = batch(second, first)
            sequence += Array(repeating: firstToMove, count: firstBatch)
            sequence += Array(repeating: firstToMove.other, count: secondBatch)
            first -= firstBatch
            second -= secondBatch
        }
        return sequence
    }

    public static func hasPendingCriticals(units: [MatchUnitState]) -> Bool {
        units.contains { $0.pendingCritical }
    }
}
