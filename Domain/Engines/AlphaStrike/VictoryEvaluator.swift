import Foundation

public enum VictoryEvaluator {
    /// Living = still on table for victory (active only; pending-end count as destroyed for victory).
    /// Under Forced Withdrawal a crippled ’Mech is out too: those scenarios are won by crippling or destroying
    /// every enemy (pp. 26, 31), and a withdrawing ’Mech that never reaches its edge must not stall the game.
    public static func livingSides(in session: MatchSession) -> Set<SideId> {
        var sides = Set<SideId>()
        for unit in session.units where countsAsLiving(unit, in: session) {
            sides.insert(unit.side)
        }
        return sides
    }

    static func countsAsLiving(_ unit: MatchUnitState, in session: MatchSession) -> Bool {
        guard unit.combatStatus == .active else { return false }
        return !(session.ruleset.forcedWithdrawal && unit.isCrippled)
    }

    public static func remainingStructure(side: SideId, in session: MatchSession) -> Int {
        session.units
            .filter { $0.side == side && $0.combatStatus == .active }
            .reduce(0) { $0 + $1.remainingStructure }
    }

    public static func evaluate(session: MatchSession) -> MatchOutcome? {
        if let wipe = wipeOutcome(in: session) {
            return wipe
        }

        switch session.ruleset.victory {
        case .destroyAllEnemies:
            return nil
        case .destroyAllEnemiesOrStructureAfterTurn(let maxTurn):
            guard session.turn >= maxTurn, session.phase == .end || session.phase == .initiative else {
                return nil
            }
            return structureCapOutcome(session: session)
        }
    }

    /// Call after End phase work when checking turn-cap victory.
    public static func evaluateAfterEnd(session: MatchSession) -> MatchOutcome? {
        if let wipe = wipeOutcome(in: session) {
            return wipe
        }

        if case .destroyAllEnemiesOrStructureAfterTurn(let maxTurn) = session.ruleset.victory,
           session.turn >= maxTurn {
            return structureCapOutcome(session: session)
        }
        return nil
    }

    private static func wipeOutcome(in session: MatchSession) -> MatchOutcome? {
        let living = livingSides(in: session)
        if living.count == 1, let winner = living.first {
            return .winner(winner)
        }
        if living.isEmpty {
            return .draw
        }
        return nil
    }

    private static func structureCapOutcome(session: MatchSession) -> MatchOutcome {
        let a = remainingStructure(side: .lanceA, in: session)
        let b = remainingStructure(side: .lanceB, in: session)
        if a > b { return .winner(.lanceA) }
        if b > a { return .winner(.lanceB) }
        return .draw
    }
}
