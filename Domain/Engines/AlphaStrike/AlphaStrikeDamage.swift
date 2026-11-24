import Foundation

public struct DamageInput: Sendable, Equatable {
    public var short: Int
    public var medium: Int
    public var long: Int
    public var bracket: RangeBracket
    public var rearHit: Bool
    public var overheatUsed: Int
    public var maxOverheat: Int
    public var ovlAllowsLong: Bool

    public init(
        short: Int,
        medium: Int,
        long: Int,
        bracket: RangeBracket,
        rearHit: Bool = false,
        overheatUsed: Int = 0,
        maxOverheat: Int = .max,
        ovlAllowsLong: Bool = false
    ) {
        self.short = short
        self.medium = medium
        self.long = long
        self.bracket = bracket
        self.rearHit = rearHit
        self.overheatUsed = overheatUsed
        self.maxOverheat = maxOverheat
        self.ovlAllowsLong = ovlAllowsLong
    }
}

public struct DamageResult: Sendable, Equatable {
    public var delivered: Int
}

public struct ApplyDamageResult: Sendable, Equatable {
    public var unit: MatchUnitState
    public var needsCritical: Bool
    public var becameStructurallyDestroyed: Bool
}

public enum AlphaStrikeDamage {
    public static func delivered(_ input: DamageInput, overheatAllowed: Bool) -> DamageResult {
        let base: Int
        switch input.bracket {
        case .short: base = input.short
        case .medium: base = input.medium
        case .long: base = input.long
        case .outOfRange: base = 0
        }

        var ov = 0
        let overheat = max(0, min(input.overheatUsed, input.maxOverheat))
        if overheatAllowed, overheat > 0 {
            switch input.bracket {
            case .short, .medium:
                ov = overheat
            case .long where input.ovlAllowsLong:
                ov = overheat
            default:
                ov = 0
            }
        }

        let rear = input.rearHit ? 1 : 0
        return DamageResult(delivered: max(0, base + rear + ov))
    }

    /// Standard physical attack (punch or kick): damage equals the attacker's Size, Size + 1 with MEL.
    /// Weapon-hit crits don't lower it and overheat can't add to it (rulebook pp. 22–24).
    /// A rear hit adds 1, as for any successful attack (owner call on rulebook question P5).
    public static func physical(attacker: MatchUnitState, rearHit: Bool) -> DamageResult {
        let base = max(0, attacker.sz) + (attacker.hasMEL ? 1 : 0)
        return DamageResult(delivered: base + (rearHit ? 1 : 0))
    }

    public static func apply(
        to unit: MatchUnitState,
        amount: Int,
        naturalTwelveHit: Bool
    ) -> ApplyDamageResult {
        var updated = unit
        var remaining = amount
        let beforeStructure = updated.structureDamage

        let armorLeft = updated.remainingArmor
        let toArmor = min(armorLeft, remaining)
        updated.armorDamage += toArmor
        remaining -= toArmor

        if remaining > 0 {
            updated.structureDamage = min(
                updated.structureCap,
                updated.structureDamage + remaining
            )
        }

        let structureMarked = updated.structureDamage > beforeStructure
        // Q1: a natural 12 rolls once. Q6: damage that reached structure rolls once more.
        // A unit this hit destroyed owes nothing: the roll could not change anything.
        let owed = updated.isStructurallyDestroyed ? 0 : (naturalTwelveHit ? 1 : 0) + (structureMarked ? 1 : 0)
        let needsCritical = owed > 0
        var becameDestroyed = false
        if updated.isStructurallyDestroyed, updated.combatStatus == .active {
            updated.combatStatus = .destroyedPendingEnd
            becameDestroyed = true
        }
        updated.criticalsOwed += owed

        return ApplyDamageResult(
            unit: updated,
            needsCritical: needsCritical,
            becameStructurallyDestroyed: becameDestroyed
        )
    }
}
