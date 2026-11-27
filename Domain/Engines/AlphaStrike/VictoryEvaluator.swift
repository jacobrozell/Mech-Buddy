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
        // § 7.2 order: sides out (done by the caller), objective, last side standing, turn limit.
        if let reached = objectiveOutcome(in: session) {
            return reached
        }
        if let wipe = wipeOutcome(in: session) {
            return wipe
        }

        if case .destroyAllEnemiesOrStructureAfterTurn(let maxTurn) = session.ruleset.victory,
           session.turn >= maxTurn {
            return structureCapOutcome(session: session)
        }
        // Play: at the turn limit the objective's points decide, then PV still on the table; level sides tie (§ 7.3).
        if let limit = session.play?.turnLimit, session.turn >= limit {
            return session.hasObjective ? pointsLimitOutcome(session: session) : pvLimitOutcome(session: session)
        }
        return nil
    }

    /// Adjusted PV (p. 35) of this side's ’Mechs still in the fight: not destroyed, not withdrawn,
    /// and under Forced Withdrawal not crippled (§ 7.3).
    public static func pvLeft(side: SideId, in session: MatchSession) -> Int {
        session.units
            .filter { $0.side == side && countsAsLiving($0, in: session) }
            .reduce(0) { $0 + AlphaStrikePointValue.adjusted(base: $1.pv, skill: $1.skill) }
    }

    /// ’Mechs of this side still in the fight.
    public static func unitsLeft(side: SideId, in session: MatchSession) -> Int {
        session.units.filter { $0.side == side && countsAsLiving($0, in: session) }.count
    }

    /// Objective: any side at or over its threshold wins; the higher score if several reach it together; equal
    /// scores tie **[HOUSE]** (§ 7.2). Nil when nobody has reached it.
    static func objectiveOutcome(in session: MatchSession) -> MatchOutcome? {
        guard session.hasObjective else { return nil }
        let reached = session.sideIds.filter { side in
            guard let objective = session.objective(for: side) else { return false }
            return session.points(of: side) >= ObjectiveRules.threshold(for: side, objective: objective, in: session)
        }
        guard !reached.isEmpty else { return nil }
        return leaders(among: reached, in: session, tieBreakPV: false)
    }

    /// Turn limit with an objective (§ 7.3): most victory points, then most PV still on the table, then a tie.
    private static func pointsLimitOutcome(session: MatchSession) -> MatchOutcome {
        let contenders = session.sidesInGame.isEmpty ? session.sideIds : session.sidesInGame
        return leaders(among: contenders, in: session, tieBreakPV: true)
    }

    /// The side with the most points among `sides`; level sides tie. `tieBreakPV` then asks for most PV left first.
    private static func leaders(among sides: [SideId], in session: MatchSession, tieBreakPV: Bool) -> MatchOutcome {
        let best = sides.map { session.points(of: $0) }.max() ?? 0
        var top = sides.filter { session.points(of: $0) == best }
        if top.count > 1, tieBreakPV {
            let bestPV = top.map { pvLeft(side: $0, in: session) }.max() ?? 0
            top = top.filter { pvLeft(side: $0, in: session) == bestPV }
        }
        if top.count == 1 { return .winner(top[0]) }
        return session.sides.count <= 2 ? .draw : .tied(top)
    }

    private static func pvLimitOutcome(session: MatchSession) -> MatchOutcome {
        let contenders = session.sidesInGame.isEmpty ? session.sideIds : session.sidesInGame
        let scores = contenders.map { (side: $0, pv: pvLeft(side: $0, in: session)) }
        guard let best = scores.map(\.pv).max() else { return .draw }
        let leaders = scores.filter { $0.pv == best }.map(\.side)
        if leaders.count == 1 { return .winner(leaders[0]) }
        return session.sides.count <= 2 ? .draw : .tied(leaders)
    }

    /// Play result order (§ 7.4): winners first, then by PV left, then sides that went out,
    /// latest out first.
    public static func standings(in session: MatchSession) -> [SideId] {
        let winners = session.outcome?.winningSides ?? []
        return session.sideIds.sorted { lhs, rhs in
            let lw = winners.contains(lhs), rw = winners.contains(rhs)
            if lw != rw { return lw }
            let lOut = session.side(lhs)?.isOut ?? false, rOut = session.side(rhs)?.isOut ?? false
            if lOut != rOut { return !lOut }
            if lOut && rOut {
                let lt = session.side(lhs)?.outOnTurn ?? 0, rt = session.side(rhs)?.outOnTurn ?? 0
                if lt != rt { return lt > rt }
            }
            if session.hasObjective {
                let lv = session.points(of: lhs), rv = session.points(of: rhs)
                if lv != rv { return lv > rv }
            }
            let lp = pvLeft(side: lhs, in: session), rp = pvLeft(side: rhs, in: session)
            if lp != rp { return lp > rp }
            return (session.sideIds.firstIndex(of: lhs) ?? 0) < (session.sideIds.firstIndex(of: rhs) ?? 0)
        }
    }

    /// Last side standing only, for checks outside the End Phase (conceding).
    public static func lastSideStanding(in session: MatchSession) -> MatchOutcome? {
        wipeOutcome(in: session)
    }

    /// Last side standing (§ 7.2): one side with living ’Mechs wins; none left (mutual wipe) is a draw.
    /// Two sides: when all of one side's ’Mechs are gone the other wins (p. 13).
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

    /// Turn cap (missions): most Structure left wins. Two sides level is a draw, as before.
    /// With 3–4 sides only sides still in the game compete, and sides level at the top tie **[HOUSE]** (§ 7.3).
    private static func structureCapOutcome(session: MatchSession) -> MatchOutcome {
        let contenders = session.sides.count <= 2 ? session.sideIds : session.sidesInGame
        let scores = contenders.map { (side: $0, structure: remainingStructure(side: $0, in: session)) }
        guard let best = scores.map(\.structure).max() else { return .draw }
        let leaders = scores.filter { $0.structure == best }.map(\.side)
        if leaders.count == 1 { return .winner(leaders[0]) }
        if session.sides.count <= 2 { return .draw }
        return .tied(leaders)
    }
}
