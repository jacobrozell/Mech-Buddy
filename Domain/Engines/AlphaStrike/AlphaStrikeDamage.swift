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
        // A unit this hit destroyed owes no critical: the roll could not change anything.
        let needsCritical = (structureMarked || naturalTwelveHit) && !updated.isStructurallyDestroyed
        var becameDestroyed = false
        if updated.isStructurallyDestroyed, updated.combatStatus == .active {
            updated.combatStatus = .destroyedPendingEnd
            becameDestroyed = true
        }
        if needsCritical {
            updated.criticalsOwed += 1
        }

        return ApplyDamageResult(
            unit: updated,
            needsCritical: needsCritical,
            becameStructurallyDestroyed: becameDestroyed
        )
    }
}
