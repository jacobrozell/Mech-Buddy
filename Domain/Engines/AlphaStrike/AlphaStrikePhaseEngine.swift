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

    /// v1 hotseat: after a move, flip to the other side when it still has units to move.
    public static func nextMovementActiveSide(current: SideId, units: [MatchUnitState]) -> SideId {
        let other = current.other
        if !unitsNeedingMove(side: other, units: units).isEmpty {
            return other
        }
        if !unitsNeedingMove(side: current, units: units).isEmpty {
            return current
        }
        return current
    }

    public static func hasPendingCriticals(units: [MatchUnitState]) -> Bool {
        units.contains { $0.pendingCritical }
    }
}
