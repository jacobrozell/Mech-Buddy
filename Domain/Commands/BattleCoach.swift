import Foundation

/// What the battle screen should offer for this session. Views render the step.
/// They do not re-decide placement, the primary action, or whether sides can swap.
public struct BattleCoach: Equatable, Sendable {
    public enum Step: Equatable, Sendable {
        case tableSetup
        case placeMiniatures
        case initiative
        case movement
        case combat
        case end
        case victory
    }

    public struct PendingCritical: Equatable, Sendable {
        public var unitId: UUID
        public var unitName: String
        public var count: Int
    }

    public enum Primary: Equatable, Sendable {
        case acknowledgeDeployment
        case useInitiativeRolls
        case rollInitiative
        case startShooting
        case solveShot
        case rollCritical(count: Int)
        case resolveEnd
    }

    public var step: Step
    public var pendingCritical: PendingCritical?
    public var canSwapSides: Bool
    public var primary: Primary?
    public var otherMechStillToMove: Bool
    public var movementComplete: Bool
    public var finishCombatNeedsConfirm: Bool
    /// Turn number has reached the ruleset cap. Ridge Line’s cap is 6.
    public var isLastTurn: Bool
    /// `VictoryEvaluator.evaluateAfterEnd` would complete the match from this board.
    /// A wipe counts on any turn. Ridge Line’s turn cap counts on the last turn even before End.
    public var endWouldFinishMatch: Bool

    public init(session: MatchSession) {
        let owed = session.units.filter(\.pendingCritical)
        if let first = owed.first {
            pendingCritical = PendingCritical(unitId: first.id, unitName: first.name, count: owed.count)
        } else {
            pendingCritical = nil
        }

        canSwapSides = session.canSwapSides
        movementComplete = AlphaStrikePhaseEngine.movementComplete(units: session.units)

        let movers = session.units.filter { $0.side == session.activeSide && $0.combatStatus == .active }
        otherMechStillToMove = movers.contains(where: \.hasMovedThisTurn) && movers.contains { !$0.hasMovedThisTurn }

        if session.status == .completed {
            step = .victory
        } else if !session.tableReady {
            step = .tableSetup
        } else if session.needsDeploymentAcknowledgement {
            step = .placeMiniatures
        } else {
            switch session.phase {
            case .initiative: step = .initiative
            case .movement: step = .movement
            case .combat: step = .combat
            case .end: step = .end
            }
        }

        finishCombatNeedsConfirm = step == .combat
            && pendingCritical == nil
            && session.units.contains(where: \.canAttackThisTurn)

        if let maxTurns = session.ruleset.maxTurns {
            isLastTurn = session.turn >= maxTurns
        } else {
            isLastTurn = false
        }
        endWouldFinishMatch = VictoryEvaluator.evaluateAfterEnd(session: session) != nil

        if let pendingCritical {
            primary = .rollCritical(count: pendingCritical.count)
            return
        }

        switch step {
        case .tableSetup, .victory:
            primary = nil
        case .placeMiniatures:
            primary = .acknowledgeDeployment
        case .initiative:
            primary = session.diceMode == .auto ? .rollInitiative : .useInitiativeRolls
        case .movement:
            primary = movementComplete ? .startShooting : nil
        case .combat:
            primary = .solveShot
        case .end:
            primary = .resolveEnd
        }
    }
}
