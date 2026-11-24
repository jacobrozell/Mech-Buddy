import Foundation

public enum TargetMoveModifier: String, Sendable, Codable, Equatable {
    case immobile
    case standstill
    case groundUsesTMM
    case jumpedUsesTMMPlus1
}

/// A 'Mech makes one attack a turn: a weapon attack or a physical one, never both (rulebook pp. 18, 22).
public enum AttackKind: String, Sendable, Codable, Equatable, CaseIterable {
    case weapon
    /// Standard physical attack: a punch or kick within 1″ (2″ with MEL), target in the front arc.
    /// No range modifier; heat and fire-control hits don't apply (p. 20). Charge and Death From Above aren't modelled.
    case physical
}

public enum RangeBracket: String, Sendable, Codable, Equatable {
    case short
    case medium
    case long
    case outOfRange
}

public struct OtherModifiers: Sendable, Equatable {
    public var woods: Bool
    public var partialCover: Bool
    public var chargeOrDFA: Bool
    public var targetHasSTL: Bool
    public var fireControlHits: Int
    public var attackerHeat: Int

    public init(
        woods: Bool = false,
        partialCover: Bool = false,
        chargeOrDFA: Bool = false,
        targetHasSTL: Bool = false,
        fireControlHits: Int = 0,
        attackerHeat: Int = 0
    ) {
        self.woods = woods
        self.partialCover = partialCover
        self.chargeOrDFA = chargeOrDFA
        self.targetHasSTL = targetHasSTL
        self.fireControlHits = fireControlHits
        self.attackerHeat = attackerHeat
    }
}

public struct SATORInput: Sendable, Equatable {
    public var skill: Int
    public var attackerMove: MovementMode
    public var targetMove: TargetMoveModifier
    public var targetTMM: Int
    public var other: OtherModifiers
    public var rangeInches: Double?
    public var rangeBracket: RangeBracket?
    public var attackKind: AttackKind

    public init(
        skill: Int,
        attackerMove: MovementMode,
        targetMove: TargetMoveModifier,
        targetTMM: Int,
        other: OtherModifiers = OtherModifiers(),
        rangeInches: Double? = nil,
        rangeBracket: RangeBracket? = nil,
        attackKind: AttackKind = .weapon
    ) {
        self.skill = skill
        self.attackerMove = attackerMove
        self.targetMove = targetMove
        self.targetTMM = targetTMM
        self.other = other
        self.rangeInches = rangeInches
        self.rangeBracket = rangeBracket
        self.attackKind = attackKind
    }
}

public struct TargetNumber: Sendable, Equatable {
    public var value: Int
    public var autoMiss: Bool
    public var hitOddsPercent: Int
    public var breakdown: [String]
    /// Plain-language lines for the target number, in the order they add up.
    public var reasons: [String]
    public var rangeBracket: RangeBracket
}

public enum SATORError: Error, Sendable, Equatable, LocalizedError {
    case cannotAttack(reason: String)
    case outOfRange

    public var errorDescription: String? {
        switch self {
        case .cannotAttack(let reason):
            return reason
        case .outOfRange:
            return "Out of range"
        }
    }
}

public enum SATORResolver {
    /// Ways to roll this total or higher on 2D6.
    public static let waysAtLeast: [Int: Int] = [
        2: 36, 3: 35, 4: 33, 5: 30, 6: 26, 7: 21, 8: 15, 9: 10, 10: 6, 11: 3, 12: 1
    ]

    public static func bracket(forInches inches: Double) -> RangeBracket {
        if inches <= 6 { return .short }
        if inches <= 24 { return .medium }
        if inches <= 42 { return .long }
        return .outOfRange
    }

    public static func oddsPercent(forTN tn: Int) -> Int {
        if tn <= 2 { return 100 }
        if tn > 12 { return 0 }
        let ways = waysAtLeast[tn] ?? 0
        return Int((Double(ways) / 36.0 * 100.0).rounded())
    }

    public static func resolve(_ input: SATORInput) throws -> TargetNumber {
        var breakdown: [String] = []
        let move = input.attackerMove == .unset ? .ground : input.attackerMove
        let physical = input.attackKind == .physical
        if move == .sprint {
            throw SATORError.cannotAttack(reason: "Sprinted units cannot attack")
        }

        var tn = input.skill
        breakdown.append("S skill \(input.skill)")

        let aDelta: Int
        switch move {
        case .standstill: aDelta = -1
        case .ground, .unset: aDelta = 0
        case .jump: aDelta = 2
        case .sprint: aDelta = 0
        }
        tn += aDelta
        breakdown.append("A \(move.rawValue) \(signed(aDelta))")
        var reasons = attackerReasons(skill: input.skill, move: move, delta: aDelta, physical: physical)

        let tDelta: Int
        switch input.targetMove {
        case .immobile: tDelta = -4
        case .standstill: tDelta = 0
        case .groundUsesTMM: tDelta = input.targetTMM
        case .jumpedUsesTMMPlus1: tDelta = input.targetTMM + 1
        }
        tn += tDelta
        breakdown.append("T \(input.targetMove.rawValue) \(signed(tDelta))")
        reasons.append(targetReason(input.targetMove, tmm: input.targetTMM, delta: tDelta))

        // A punch or kick is always within reach, so it has no range band (p. 20).
        let bracket: RangeBracket
        if physical {
            bracket = .short
        } else {
            guard let measured = input.rangeBracket ?? input.rangeInches.map(bracket(forInches:)) else {
                throw SATORError.cannotAttack(reason: "Range required")
            }
            bracket = measured
        }
        if bracket == .outOfRange {
            throw SATORError.outOfRange
        }
        // Heat and fire-control hits only affect weapon attacks.
        var other = input.other
        if physical {
            other.fireControlHits = 0
            other.attackerHeat = 0
        }

        var oDelta = 0
        if other.woods { oDelta += 1 }
        if other.partialCover { oDelta += 1 }
        if other.chargeOrDFA { oDelta += 1 }
        if other.targetHasSTL {
            switch bracket {
            case .medium: oDelta += 1
            case .long: oDelta += 2
            default: break
            }
        }
        oDelta += other.fireControlHits * 2
        oDelta += min(4, max(0, other.attackerHeat))
        tn += oDelta
        breakdown.append("O \(signed(oDelta))")
        reasons.append(contentsOf: otherReasons(other, bracket: bracket))

        if physical {
            reasons.append("Punch or kick, no range modifier")
            reasons.append("Need \(tn) or higher")
            return TargetNumber(
                value: tn,
                autoMiss: tn > 12,
                hitOddsPercent: oddsPercent(forTN: tn),
                breakdown: breakdown,
                reasons: reasons,
                rangeBracket: bracket
            )
        }

        let rDelta: Int
        switch bracket {
        case .short: rDelta = 0
        case .medium: rDelta = 2
        case .long: rDelta = 4
        case .outOfRange: rDelta = 0
        }
        tn += rDelta
        breakdown.append("R \(bracket.rawValue) \(signed(rDelta))")
        reasons.append(rangeReason(bracket, inches: input.rangeInches, delta: rDelta))
        reasons.append("Need \(tn) or higher")

        let autoMiss = tn > 12
        return TargetNumber(
            value: tn,
            autoMiss: autoMiss,
            hitOddsPercent: oddsPercent(forTN: tn),
            breakdown: breakdown,
            reasons: reasons,
            rangeBracket: bracket
        )
    }

    private static func attackerReasons(skill: Int, move: MovementMode, delta: Int, physical: Bool) -> [String] {
        let who = physical ? "Attacker" : "Shooter"
        let moveLine: String
        switch move {
        case .standstill:
            moveLine = "\(who) stood still, \(signed(delta))"
        case .jump:
            moveLine = "\(who) jumped, \(signed(delta))"
        case .ground, .unset, .sprint:
            moveLine = "\(who) walked, \(signed(delta))"
        }
        return ["Skill \(skill)", moveLine]
    }

    private static func targetReason(_ move: TargetMoveModifier, tmm: Int, delta: Int) -> String {
        switch move {
        case .immobile:
            return "Target can’t move, \(signed(delta))"
        case .standstill:
            return "Target stood still, \(signed(delta))"
        case .groundUsesTMM:
            if tmm == 0 { return "Target walked, \(signed(delta))" }
            return "Target walked, harder to hit by \(tmm)"
        case .jumpedUsesTMMPlus1:
            return "Target jumped, harder to hit by \(tmm + 1)"
        }
    }

    private static func otherReasons(_ other: OtherModifiers, bracket: RangeBracket) -> [String] {
        var lines: [String] = []
        if other.woods { lines.append("Trees in the way, +1") }
        if other.partialCover { lines.append("Partial cover, +1") }
        if other.chargeOrDFA { lines.append("Charge or death from above, +1") }
        if other.targetHasSTL {
            switch bracket {
            case .medium: lines.append("Stealth, +1")
            case .long: lines.append("Stealth, +2")
            default: break
            }
        }
        if other.fireControlHits > 0 {
            let label = other.fireControlHits == 1 ? "Fire control hit" : "Fire control hits"
            lines.append("\(label), \(signed(other.fireControlHits * 2))")
        }
        let heat = min(4, max(0, other.attackerHeat))
        if heat > 0 { lines.append("Heat \(heat), \(signed(heat))") }
        if lines.isEmpty { lines.append("No woods, cover, or other penalty") }
        return lines
    }

    private static func rangeReason(_ bracket: RangeBracket, inches: Double?, delta: Int) -> String {
        let distance: String
        if let inches {
            let shown = Int(inches.rounded())
            distance = "\(shown) inch\(shown == 1 ? "" : "es"), "
        } else {
            distance = ""
        }
        switch bracket {
        case .short: return "\(distance)Short range, \(signed(delta))"
        case .medium: return "\(distance)Medium range, \(signed(delta))"
        case .long: return "\(distance)Long range, \(signed(delta))"
        case .outOfRange: return "\(distance)Too far to shoot"
        }
    }

    public static func isHit(tn: TargetNumber, roll: DiceRoll2D6) -> Bool {
        if tn.autoMiss { return false }
        return roll.total >= tn.value
    }

    private static func signed(_ n: Int) -> String {
        n >= 0 ? "+\(n)" : "\(n)"
    }
}
