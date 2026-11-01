import Foundation

/// What the players observed on the table for this shot.
public struct CombatTableInsight: Sendable, Equatable {
    public var rangeInches: Int
    public var targetMove: TargetMoveModifier
    public var woods: Bool
    public var partialCover: Bool
    public var rearHit: Bool
    public var overheatUsed: Int
    public var canSeeTarget: Bool
    public var targetInFrontArc: Bool
    public var attackerMoveOverride: MovementMode?

    public init(
        rangeInches: Int = 6,
        targetMove: TargetMoveModifier = .groundUsesTMM,
        woods: Bool = false,
        partialCover: Bool = false,
        rearHit: Bool = false,
        overheatUsed: Int = 0,
        canSeeTarget: Bool = true,
        targetInFrontArc: Bool = true,
        attackerMoveOverride: MovementMode? = nil
    ) {
        self.rangeInches = rangeInches
        self.targetMove = targetMove
        self.woods = woods
        self.partialCover = partialCover
        self.rearHit = rearHit
        self.overheatUsed = overheatUsed
        self.canSeeTarget = canSeeTarget
        self.targetInFrontArc = targetInFrontArc
        self.attackerMoveOverride = attackerMoveOverride
    }

    public var rangeBracket: RangeBracket {
        SATORResolver.bracket(forInches: Double(rangeInches))
    }

    public var rangeLabel: String {
        switch rangeBracket {
        case .short: "Short range — easiest to hit"
        case .medium: "Medium range"
        case .long: "Long range — harder to hit"
        case .outOfRange: "Too far (over 42 inches) — no shot"
        }
    }
}

public struct CombatDamagePreview: Sendable, Equatable {
    public var delivered: Int
    public var armorBefore: Int
    public var armorAfter: Int
    public var structureBefore: Int
    public var structureAfter: Int
    public var needsCritical: Bool
    public var wrecksThisTurn: Bool

    public var chipsArmor: Int { armorBefore - armorAfter }
    public var chipsStructure: Int { structureBefore - structureAfter }
    public var zeroDamage: Bool { delivered == 0 }
}

public struct CombatSolve: Sendable, Equatable {
    public var attackerName: String
    public var defenderName: String
    public var attackerMove: MovementMode
    public var rangeBracket: RangeBracket
    public var targetNumber: TargetNumber?
    public var cannotShootReason: String?
    public var tableWarning: String?
    public var ifHit: CombatDamagePreview
    public var ifNaturalTwelve: CombatDamagePreview
    public var roll: DiceRoll2D6?
    public var isHit: Bool?

    public var canApply: Bool {
        cannotShootReason == nil && targetNumber != nil
    }

    public var rangeLabel: String {
        switch rangeBracket {
        case .short: "Short (easy)"
        case .medium: "Medium"
        case .long: "Long (hard)"
        case .outOfRange: "Too far to shoot"
        }
    }
}

public enum CombatSolver {
    public static func solve(
        attacker: MatchUnitState,
        defender: MatchUnitState,
        insight: CombatTableInsight,
        overheatAllowed: Bool,
        roll: DiceRoll2D6? = nil
    ) -> CombatSolve {
        let move = insight.attackerMoveOverride
            ?? (attacker.movementMode == .unset ? .ground : attacker.movementMode)
        let bracket = insight.rangeBracket

        var cannot: String?
        if !insight.canSeeTarget {
            cannot = "You can’t shoot a ’Mech you can’t see."
        } else if !insight.targetInFrontArc {
            cannot = "You can only shoot a ’Mech in front of the shooter."
        } else if !attacker.canAttackThisTurn {
            cannot = attacker.movementMode == .sprint
                ? "\(attacker.name) sprinted, so it can’t shoot this turn."
                : "\(attacker.name) can’t shoot right now."
        } else if attacker.side == defender.side {
            cannot = "Pick an enemy, not a friendly 'Mech."
        } else if defender.combatStatus == .removed {
            cannot = "That 'Mech is already off the table."
        }

        var tn: TargetNumber?
        if cannot == nil {
            do {
                tn = try SATORResolver.resolve(
                    satorInput(
                        attacker: attacker,
                        defender: defender,
                        attackerMove: move,
                        targetMove: insight.targetMove,
                        woods: insight.woods,
                        partialCover: insight.partialCover,
                        rangeInches: Double(insight.rangeInches),
                        bracket: bracket
                    )
                )
            } catch SATORError.cannotAttack(let reason) {
                cannot = reason
            } catch SATORError.outOfRange {
                cannot = "More than 42 inches — no shot."
            } catch {
                cannot = error.localizedDescription
            }
        }

        let delivered = AlphaStrikeDamage.delivered(
            damageInput(
                attacker: attacker,
                bracket: bracket,
                rearHit: insight.rearHit,
                overheatUsed: insight.overheatUsed
            ),
            overheatAllowed: overheatAllowed
        ).delivered

        let ifHit = preview(defender: defender, amount: delivered, naturalTwelve: false)
        let ifTwelve = preview(defender: defender, amount: delivered, naturalTwelve: true)

        var isHit: Bool?
        if let tn, let roll, cannot == nil {
            isHit = SATORResolver.isHit(tn: tn, roll: roll)
        }

        return CombatSolve(
            attackerName: attacker.name,
            defenderName: defender.name,
            attackerMove: move,
            rangeBracket: bracket,
            targetNumber: tn,
            cannotShootReason: cannot,
            tableWarning: nil,
            ifHit: ifHit,
            ifNaturalTwelve: ifTwelve,
            roll: roll,
            isHit: isHit
        )
    }

    static func satorInput(
        attacker: MatchUnitState,
        defender: MatchUnitState,
        attackerMove: MovementMode,
        targetMove: TargetMoveModifier,
        woods: Bool,
        partialCover: Bool,
        rangeInches: Double?,
        bracket: RangeBracket
    ) -> SATORInput {
        SATORInput(
            skill: attacker.skill,
            attackerMove: attackerMove,
            targetMove: targetMove,
            targetTMM: defender.effectiveTMM,
            other: OtherModifiers(
                woods: woods,
                partialCover: partialCover,
                targetHasSTL: defender.hasStealth,
                fireControlHits: attacker.crits.fireControlHits,
                attackerHeat: attacker.heat
            ),
            rangeInches: rangeInches,
            rangeBracket: bracket
        )
    }

    static func damageInput(
        attacker: MatchUnitState,
        bracket: RangeBracket,
        rearHit: Bool,
        overheatUsed: Int
    ) -> DamageInput {
        let damage = attacker.effectiveDamage
        return DamageInput(
            short: damage.s,
            medium: damage.m,
            long: damage.l,
            bracket: bracket,
            rearHit: rearHit,
            overheatUsed: overheatUsed,
            maxOverheat: attacker.ov,
            ovlAllowsLong: attacker.hasOVL
        )
    }

    private static func preview(
        defender: MatchUnitState,
        amount: Int,
        naturalTwelve: Bool
    ) -> CombatDamagePreview {
        let applied = AlphaStrikeDamage.apply(
            to: defender,
            amount: amount,
            naturalTwelveHit: naturalTwelve
        )
        return CombatDamagePreview(
            delivered: amount,
            armorBefore: defender.remainingArmor,
            armorAfter: applied.unit.remainingArmor,
            structureBefore: defender.remainingStructure,
            structureAfter: applied.unit.remainingStructure,
            needsCritical: applied.needsCritical,
            wrecksThisTurn: applied.becameStructurallyDestroyed
                || applied.unit.combatStatus == .destroyedPendingEnd
                    && defender.combatStatus != .destroyedPendingEnd
        )
    }
}
