import Foundation

public enum CritResultId: String, Sendable, Equatable {
    case ammo
    case engine
    case fireControl
    case none
    case weapon
    case mp
    case destroyed
}

public struct CritApplyResult: Sendable, Equatable {
    public var unit: MatchUnitState
    public var resultId: CritResultId
    public var title: String
}

public enum AlphaStrikeCriticals {
    public static func resultId(forTotal total: Int) -> CritResultId {
        switch total {
        case 2: return .ammo
        case 3, 11: return .engine
        case 4, 10: return .fireControl
        case 5, 9: return .none
        case 6, 8: return .weapon
        case 7: return .mp
        case 12: return .destroyed
        default: return .none
        }
    }

    public static func title(for id: CritResultId) -> String {
        switch id {
        case .ammo: "Ammo hit"
        case .engine: "Engine hit"
        case .fireControl: "Fire control"
        case .none: "No critical"
        case .weapon: "Weapon hit"
        case .mp: "MP hit"
        case .destroyed: "Destroyed"
        }
    }

    public static func apply(to unit: MatchUnitState, roll: DiceRoll2D6) -> CritApplyResult {
        var updated = unit
        if updated.criticalsOwed > 0 {
            updated.criticalsOwed -= 1
        }
        let id = resultId(forTotal: roll.total)

        switch id {
        case .ammo:
            switch updated.ammoProtection {
            case .full:
                break // CASEII / ENE: no effect.
            case .caseOne:
                // CASE: 1 extra damage; if it reaches structure, roll again (rulebook p. 23).
                updated = AlphaStrikeDamage.apply(to: updated, amount: 1, naturalTwelveHit: false).unit
            case .none:
                updated.crits.ammoExploded = true
                updated.crits.destroyedByCrit = true
                if updated.combatStatus == .active {
                    updated.combatStatus = .destroyedPendingEnd
                }
            }
        case .engine:
            updated.crits.engineHits += 1
            if updated.crits.engineHits >= 2 {
                updated.crits.destroyedByCrit = true
                if updated.combatStatus == .active {
                    updated.combatStatus = .destroyedPendingEnd
                }
            }
        case .fireControl:
            updated.crits.fireControlHits += 1
        case .none:
            break
        case .weapon:
            let damage = updated.effectiveDamage
            if damage.s == 0 && damage.m == 0 && damage.l == 0 {
                updated = extraDamage(updated)
            } else {
                updated.crits.weaponHits += 1
            }
        case .mp:
            if updated.motiveMV.prefix(while: { $0.isNumber }) == "0" {
                updated = extraDamage(updated)
            } else {
                // Each MP hit halves move and TMM again (MPHitMath); 0″ makes it immobile.
                updated.crits.mpHits += 1
            }
        case .destroyed:
            updated.crits.destroyedByCrit = true
            if updated.combatStatus == .active {
                updated.combatStatus = .destroyedPendingEnd
            }
        }

        return CritApplyResult(unit: updated, resultId: id, title: title(for: id))
    }

    /// A crit whose effect can't apply deals 1 damage instead, with no further crit roll (p. 23).
    private static func extraDamage(_ unit: MatchUnitState) -> MatchUnitState {
        let owedBefore = unit.criticalsOwed
        var hit = AlphaStrikeDamage.apply(to: unit, amount: 1, naturalTwelveHit: false).unit
        hit.criticalsOwed = owedBefore
        return hit
    }
}
