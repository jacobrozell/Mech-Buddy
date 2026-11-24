import Foundation

/// Heat, cooling, and shutdown (Alpha Strike quick-start rules, Heat and Overheating).
///
/// Heat only changes in the End Phase, so its effects land on the next turn:
/// + heat to the ’Mech's own weapon attacks, −2″ ground move per level, −1 TMM at heat 2+ (not when jumping).
/// Heat 4 is the S box: shut down for the next turn (no move, no attack, immobile target).
public enum AlphaStrikeHeat {
    public static let shutdownLevel = 4

    /// Overheat points a shot may legally use. Zero when the mission keeps overheat off, at long range
    /// without OVL, or out of range. Never more than the card's OV.
    public static func usableOverheat(
        requested: Int,
        attacker: MatchUnitState,
        bracket: RangeBracket,
        overheatAllowed: Bool
    ) -> Int {
        guard overheatAllowed, attacker.ov > 0 else { return 0 }
        switch bracket {
        case .short, .medium: break
        case .long where attacker.hasOVL: break
        default: return 0
        }
        return max(0, min(requested, attacker.ov))
    }

    /// What happened to one ’Mech's heat this End Phase.
    public enum Change: Equatable, Sendable {
        case rose(to: Int)
        case shutDown
        case cooled
        case restarted
    }

    /// End Phase heat for one ’Mech, in rulebook order:
    /// 1. add overheat used this turn (and 1 per engine hit if it fired);
    /// 2. (standing in water −1: not tracked by the app);
    /// 3. clear all heat if it made no weapon attack this turn;
    /// 4. clear all heat and restart if it began this End Phase shut down.
    public static func endPhase(_ unit: inout MatchUnitState) -> Change? {
        let before = unit.heat
        let beganShutdown = unit.isShutdown
        let fired = unit.hasAttackedThisTurn
        var heat = before
        if fired {
            heat += unit.overheatThisTurn
            heat += min(1, unit.crits.engineHits)
        }
        if !fired { heat = 0 }
        if beganShutdown { heat = 0 }
        heat = min(shutdownLevel, max(0, heat))
        unit.heat = heat
        unit.overheatThisTurn = 0

        if beganShutdown { return .restarted }
        if heat == before { return nil }
        if heat >= shutdownLevel { return .shutDown }
        if heat > before { return .rose(to: heat) }
        return .cooled
    }

    /// Applies End Phase heat to every ’Mech still on the table. Returns log lines.
    public static func applyEndPhase(_ units: inout [MatchUnitState]) -> [String] {
        var lines: [String] = []
        for i in units.indices where units[i].combatStatus != .removed {
            guard let change = endPhase(&units[i]) else { continue }
            let name = units[i].name
            switch change {
            case .rose(let level):
                lines.append("\(name) heat \(level)")
            case .shutDown:
                lines.append("\(name) shuts down from heat")
            case .cooled:
                lines.append("\(name) cools to heat 0")
            case .restarted:
                lines.append("\(name) restarts, heat 0")
            }
        }
        return lines
    }
}
