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
    /// Bases touching: no weapon attack, only physical (rulebook p. 20).
    public var basesTouching: Bool = false
    /// Weapon fire or a punch/kick. Physical attacks ignore range, overheat and bases touching.
    public var attackKind: AttackKind = .weapon

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
    public var attackKind: AttackKind = .weapon

    public var isPhysical: Bool { attackKind == .physical }

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
        physicalAttacksAllowed: Bool = false,
        roll: DiceRoll2D6? = nil
    ) -> CombatSolve {
        let move = insight.attackerMoveOverride
            ?? (attacker.movementMode == .unset ? .ground : attacker.movementMode)
        let physical = insight.attackKind == .physical
        // A punch or kick has no range band; .short keeps the range term at +0.
        let bracket = physical ? .short : insight.rangeBracket
        let verb = physical ? "attack" : "shoot"

        var cannot: String?
        if physical, !physicalAttacksAllowed {
            cannot = "Punches and kicks aren’t used in this mission."
        } else if !insight.canSeeTarget {
            cannot = physical ? "You can’t hit a ’Mech you can’t see." : "You can’t shoot a ’Mech you can’t see."
        } else if !insight.targetInFrontArc {
            cannot = physical
                ? "You can only punch or kick a ’Mech in front of you."
                : "You can only shoot a ’Mech in front of the shooter."
        } else if attacker.isShutdown {
            cannot = "\(attacker.name) is shut down from heat, so it can’t \(verb) this turn."
        } else if !attacker.canAttackThisTurn {
            cannot = attacker.movementMode == .sprint
                ? "\(attacker.name) sprinted, so it can’t \(verb) this turn."
                : "\(attacker.name) can’t \(verb) right now."
        } else if attacker.side == defender.side {
            cannot = "Pick an enemy, not a friendly 'Mech."
        } else if defender.combatStatus == .removed {
            cannot = "That 'Mech is already off the table."
        } else if !physical, insight.basesTouching {
            cannot = physicalAttacksAllowed
                ? "The bases are touching, so there’s no weapon shot. Punch or kick instead."
                : "The bases are touching, so there’s no weapon shot. Move apart first."
        } else if !physical, let reason = noDamageReason(attacker: attacker, bracket: bracket) {
            cannot = reason
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
                        rangeInches: physical ? nil : Double(insight.rangeInches),
                        bracket: bracket,
                        attackKind: insight.attackKind
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

        let delivered = physical
            ? AlphaStrikeDamage.physical(attacker: attacker, rearHit: insight.rearHit).delivered
            : AlphaStrikeDamage.delivered(
                damageInput(
                    attacker: attacker,
                    bracket: bracket,
                    rearHit: insight.rearHit,
                    overheatUsed: AlphaStrikeHeat.usableOverheat(
                        requested: insight.overheatUsed,
                        attacker: attacker,
                        bracket: bracket,
                        overheatAllowed: overheatAllowed
                    )
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
            isHit: isHit,
            attackKind: insight.attackKind
        )
    }

    /// A range where the card does no damage ("—" or 0) has no weapon attack (rulebook p. 20).
    /// "0*" minimal damage isn't stored on cards yet; every shipped 0 is treated as no damage.
    public static func noDamageReason(attacker: MatchUnitState, bracket: RangeBracket) -> String? {
        let damage = attacker.firingDamage
        let value: Int
        let name: String
        switch bracket {
        case .short: value = damage.s; name = "short"
        case .medium: value = damage.m; name = "medium"
        case .long: value = damage.l; name = "long"
        case .outOfRange: return nil
        }
        guard value == 0 else { return nil }
        return "\(attacker.name) does no damage at \(name) range, so it has no shot there."
    }

    static func satorInput(
        attacker: MatchUnitState,
        defender: MatchUnitState,
        attackerMove: MovementMode,
        targetMove: TargetMoveModifier,
        woods: Bool,
        partialCover: Bool,
        rangeInches: Double?,
        bracket: RangeBracket,
        attackKind: AttackKind = .weapon
    ) -> SATORInput {
        SATORInput(
            skill: attacker.skill,
            attackerMove: attackerMove,
            targetMove: targetMove,
            // Heat 2+ costs the target 1 TMM, except when it jumped.
            targetTMM: targetMove == .jumpedUsesTMMPlus1
                ? max(0, defender.firingTMM + defender.jumpTMMAdjustment)
                : max(0, defender.firingTMM - defender.heatTMMPenalty),
            other: OtherModifiers(
                woods: woods,
                partialCover: partialCover,
                targetHasSTL: defender.hasStealth,
                fireControlHits: attacker.firingCrits.fireControlHits,
                attackerHeat: attacker.heat
            ),
            rangeInches: rangeInches,
            rangeBracket: bracket,
            attackKind: attackKind
        )
    }

    static func damageInput(
        attacker: MatchUnitState,
        bracket: RangeBracket,
        rearHit: Bool,
        overheatUsed: Int
    ) -> DamageInput {
        let damage = attacker.firingDamage
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
