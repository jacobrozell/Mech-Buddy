import Foundation

/// The shot this ’Mech already took this turn. Cleared when the next turn starts.
public struct TurnShot: Codable, Sendable, Equatable {
    public var targetName: String
    public var hit: Bool
    public var total: Int
    public var targetNumber: Int
    public var damage: Int
    /// Weapon fire or a punch/kick. Saves from before physical attacks decode as `.weapon`.
    public var kind: AttackKind

    public init(
        targetName: String,
        hit: Bool,
        total: Int,
        targetNumber: Int,
        damage: Int,
        kind: AttackKind = .weapon
    ) {
        self.targetName = targetName
        self.hit = hit
        self.total = total
        self.targetNumber = targetNumber
        self.damage = damage
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case targetName, hit, total, targetNumber, damage, kind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        targetName = try c.decode(String.self, forKey: .targetName)
        hit = try c.decode(Bool.self, forKey: .hit)
        total = try c.decode(Int.self, forKey: .total)
        targetNumber = try c.decode(Int.self, forKey: .targetNumber)
        damage = try c.decode(Int.self, forKey: .damage)
        kind = try c.decodeIfPresent(AttackKind.self, forKey: .kind) ?? .weapon
    }

    public var isPhysical: Bool { kind == .physical }

    public var rowTitle: String {
        hit ? "Hit \(targetName) for \(damage)" : "Missed \(targetName)"
    }

    public var rowDetail: String {
        let how = isPhysical ? "Punch or kick. " : ""
        if hit {
            return "\(how)Rolled \(total), needed \(targetNumber)."
        }
        return "\(how)Rolled \(total), needed \(targetNumber). No damage."
    }
}

public struct CritFlags: Codable, Sendable, Equatable {
    public var fireControlHits: Int
    public var engineHits: Int
    public var weaponHits: Int
    /// Each MP hit halves Move and TMM again (at least −2″ and −1), down to 0 (rulebook p. 23).
    public var mpHits: Int
    public var ammoExploded: Bool
    public var destroyedByCrit: Bool

    public var mpHit: Bool {
        get { mpHits > 0 }
        set { mpHits = newValue ? max(mpHits, 1) : 0 }
    }

    public init(
        fireControlHits: Int = 0,
        engineHits: Int = 0,
        weaponHits: Int = 0,
        mpHit: Bool = false,
        mpHits: Int = 0,
        ammoExploded: Bool = false,
        destroyedByCrit: Bool = false
    ) {
        self.fireControlHits = fireControlHits
        self.engineHits = engineHits
        self.weaponHits = weaponHits
        self.mpHits = max(mpHits, mpHit ? 1 : 0)
        self.ammoExploded = ammoExploded
        self.destroyedByCrit = destroyedByCrit
    }

    private enum CodingKeys: String, CodingKey {
        case fireControlHits, engineHits, weaponHits, mpHit, mpHits, ammoExploded, destroyedByCrit
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fireControlHits = try c.decode(Int.self, forKey: .fireControlHits)
        engineHits = try c.decode(Int.self, forKey: .engineHits)
        weaponHits = try c.decode(Int.self, forKey: .weaponHits)
        let legacy = try c.decodeIfPresent(Bool.self, forKey: .mpHit) ?? false
        mpHits = try c.decodeIfPresent(Int.self, forKey: .mpHits) ?? (legacy ? 1 : 0)
        ammoExploded = try c.decode(Bool.self, forKey: .ammoExploded)
        destroyedByCrit = try c.decode(Bool.self, forKey: .destroyedByCrit)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fireControlHits, forKey: .fireControlHits)
        try c.encode(engineHits, forKey: .engineHits)
        try c.encode(weaponHits, forKey: .weaponHits)
        try c.encode(mpHit, forKey: .mpHit)
        try c.encode(mpHits, forKey: .mpHits)
        try c.encode(ammoExploded, forKey: .ammoExploded)
        try c.encode(destroyedByCrit, forKey: .destroyedByCrit)
    }
}

/// MP-hit maths: each hit halves (rounding down) but takes at least `minimumCut`, never below 0.
public enum MPHitMath {
    public static func reduce(_ value: Int, hits: Int, minimumCut: Int) -> Int {
        var v = value
        for _ in 0..<max(0, hits) {
            v = max(0, min(v / 2, v - minimumCut))
        }
        return v
    }
}

public struct MatchUnitState: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var libraryUnitId: UUID?
    public var name: String
    public var side: SideId
    public var skill: Int
    public var pv: Int
    public var sz: Int
    public var mv: String
    public var tmm: Int
    public var s: Int
    public var m: Int
    public var l: Int
    public var ov: Int
    public var armorCap: Int
    public var structureCap: Int
    public var armorDamage: Int
    public var structureDamage: Int
    public var heat: Int
    public var abilities: String
    public var crits: CritFlags
    /// Crits as they stood when this combat phase began. Alpha Strike resolves crit effects at the
    /// end of the phase, so shots this phase (including return fire) read this snapshot, not `crits`.
    public var combatPhaseCrits: CritFlags?
    public var movementMode: MovementMode
    public var hasMovedThisTurn: Bool
    public var hasAttackedThisTurn: Bool
    public var turnShot: TurnShot?
    public var combatStatus: UnitCombatStatus
    /// How many critical rolls this ’Mech still owes. One hit that marks structure or rolls a 12 adds one.
    public var criticalsOwed: Int
    /// Overheat points spent on this turn's shot. Becomes heat in the End Phase, then clears.
    public var overheatThisTurn: Int
    /// This turn's REAR attack, if any. Doesn't count as the turn's attack: the forward shot can follow.
    public var rearShot: TurnShot?
    /// Forward damage lost this turn to a REAR attack: its REAR value at the range used (p. 25).
    public var rearFireReduction: Int = 0
    /// Heat from enemy HT attacks that hit this turn, at most 2. Added last in the End Phase (rulebook p. 24–25).
    public var incomingHeatThisTurn: Int = 0
    /// Colour the players gave this miniature, if any.
    public var mini: MiniMarker?
    /// It left the play area. It counts as destroyed and can't come back (rulebook p. 12).
    /// Always paired with `combatStatus == .removed`.
    public var leftTable: Bool
    /// The End Phase has logged "… is crippled and must withdraw" for it (Forced Withdrawal).
    public var withdrawalAnnounced: Bool

    public var pendingCritical: Bool {
        get { criticalsOwed > 0 }
        set {
            if newValue {
                if criticalsOwed == 0 { criticalsOwed = 1 }
            } else {
                criticalsOwed = 0
            }
        }
    }

    public init(
        id: UUID = UUID(),
        libraryUnitId: UUID? = nil,
        name: String,
        side: SideId,
        skill: Int = 4,
        pv: Int,
        sz: Int,
        mv: String,
        tmm: Int,
        s: Int,
        m: Int,
        l: Int,
        ov: Int,
        armorCap: Int,
        structureCap: Int,
        armorDamage: Int = 0,
        structureDamage: Int = 0,
        heat: Int = 0,
        abilities: String = "",
        crits: CritFlags = CritFlags(),
        combatPhaseCrits: CritFlags? = nil,
        movementMode: MovementMode = .unset,
        hasMovedThisTurn: Bool = false,
        hasAttackedThisTurn: Bool = false,
        turnShot: TurnShot? = nil,
        combatStatus: UnitCombatStatus = .active,
        criticalsOwed: Int = 0,
        overheatThisTurn: Int = 0,
        mini: MiniMarker? = nil,
        leftTable: Bool = false,
        withdrawalAnnounced: Bool = false
    ) {
        self.id = id
        self.libraryUnitId = libraryUnitId
        self.name = name
        self.side = side
        self.skill = skill
        self.pv = pv
        self.sz = sz
        self.mv = mv
        self.tmm = tmm
        self.s = s
        self.m = m
        self.l = l
        self.ov = ov
        self.armorCap = armorCap
        self.structureCap = structureCap
        self.armorDamage = armorDamage
        self.structureDamage = structureDamage
        self.heat = heat
        self.abilities = abilities
        self.crits = crits
        self.combatPhaseCrits = combatPhaseCrits
        self.movementMode = movementMode
        self.hasMovedThisTurn = hasMovedThisTurn
        self.hasAttackedThisTurn = hasAttackedThisTurn
        self.turnShot = turnShot
        self.combatStatus = combatStatus
        self.criticalsOwed = criticalsOwed
        self.overheatThisTurn = overheatThisTurn
        self.mini = mini
        self.leftTable = leftTable
        self.withdrawalAnnounced = withdrawalAnnounced
    }

    public var remainingArmor: Int { max(0, armorCap - armorDamage) }
    public var remainingStructure: Int { max(0, structureCap - structureDamage) }
    public var isStructurallyDestroyed: Bool { structureCap > 0 && structureDamage >= structureCap }

    public var canFire: Bool {
        combatStatus == .active || combatStatus == .destroyedPendingEnd
    }

    /// Heat 4 is the S box: the ’Mech is shut down for the turn after it got there.
    public var isShutdown: Bool { heat >= AlphaStrikeHeat.shutdownLevel }

    /// Heat 2 or more costs 1 TMM, except when the ’Mech jumped.
    public var heatTMMPenalty: Int { heat >= 2 ? 1 : 0 }

    /// TMM for a ground move: motive hit halves it, heat 2+ takes 1 off.
    public var effectiveTMM: Int {
        let base = MPHitMath.reduce(tmm, hits: crits.mpHits, minimumCut: 1)
        return max(0, base - heatTMMPenalty)
    }

    /// Move on the card after a motive hit and heat.
    /// Heat takes 2″ per level off the ground move only. Jumping is unaffected, so `8"j` at heat 1 reads `6"/8"j`.
    public var effectiveMV: String {
        let base = motiveMV
        let penalty = 2 * min(heat, AlphaStrikeHeat.shutdownLevel)
        guard penalty > 0,
              let quote = base.firstIndex(of: "\""),
              let ground = Int(base[..<quote]) else { return base }
        let reduced = max(0, ground - penalty)
        let rest = base[quote...]
        if rest == "\"j" { return "\(reduced)\"/\(ground)\"j" }
        return "\(reduced)\(rest)"
    }

    /// Halves printed MV inches when `mpHit` is set (floor).
    /// Halves every printed inch value. `10"/6"j` becomes `5"/3"j`.
    public var motiveMV: String {
        guard crits.mpHits > 0 else { return mv }
        var result = ""
        var digits = ""
        func flushDigits() {
            guard !digits.isEmpty else { return }
            let value = Int(digits) ?? 0
            result.append(String(MPHitMath.reduce(value, hits: crits.mpHits, minimumCut: 2)))
            digits = ""
        }
        for character in mv {
            if character.isNumber {
                digits.append(character)
            } else {
                flushDigits()
                result.append(character)
            }
        }
        flushDigits()
        return result
    }

    public var effectiveDamage: (s: Int, m: Int, l: Int) {
        let w = crits.weaponHits
        return (max(0, s - w), max(0, m - w), max(0, l - w))
    }

    /// Crits that count for shots this combat phase (snapshot when one exists).
    public var firingCrits: CritFlags { combatPhaseCrits ?? crits }

    /// Damage this unit deals this phase: a weapon crit taken mid-phase waits for the end phase.
    public var firingDamage: (s: Int, m: Int, l: Int) {
        let w = firingCrits.weaponHits
        return (max(0, s - w), max(0, m - w), max(0, l - w))
    }

    /// TMM when targeted this phase: an MP crit taken mid-phase waits for the end phase.
    public var firingTMM: Int {
        MPHitMath.reduce(tmm, hits: firingCrits.mpHits, minimumCut: 1)
    }

    /// Ammo hit protection (rulebook p. 23): CASEII and ENE ignore it; CASE takes 1 extra damage instead.
    public enum AmmoProtection: Sendable { case none, caseOne, full }

    public var ammoProtection: AmmoProtection {
        let tags = abilityTags
        if tags.contains("ENE") || tags.contains("CASEII") { return .full }
        if tags.contains("CASE") { return .caseOne }
        return .none
    }

    public var hasAmmoImmunity: Bool { ammoProtection != .none }

    /// Ability codes on the card, upper-cased, without numbers after a slash ("SRM1/1" → "SRM1/1").
    public var abilityTags: [String] {
        abilities.uppercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Jump jets (rulebook p. 18, 20): JMPS# adds # to the jumping TMM, JMPW# takes # off.
    /// Each MP hit lowers JMPS by 1, to 0.
    public var jumpTMMAdjustment: Int {
        for tag in abilityTags {
            if tag.hasPrefix("JMPS"), let n = Int(tag.dropFirst(4)) { return max(0, n - firingCrits.mpHits) }
            if tag.hasPrefix("JMPW"), let n = Int(tag.dropFirst(4)) { return -n }
        }
        return 0
    }

    public var hasStealth: Bool {
        abilities.uppercased().contains("STL")
    }

    /// HT#/#/# (rulebook p. 25): heat a hit adds to the target at this range. 0 without HT, or "-" at that range.
    public func heatAbility(at bracket: RangeBracket) -> Int {
        guard let tag = abilityTags.first(where: { $0.hasPrefix("HT") }) else { return 0 }
        let values = tag.dropFirst(2).split(separator: "/", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        let index: Int
        switch bracket {
        case .short: index = 0
        case .medium: index = 1
        case .long: index = 2
        case .outOfRange: return 0
        }
        return index < values.count ? values[index] : 0
    }

    /// Most heat a ’Mech can take from HT attacks in one turn (rulebook p. 25).
    public static let maxIncomingHeatPerTurn = 2

    public var hasOVL: Bool {
        abilities.uppercased().contains("OVL")
    }

    /// MEL: physical attacks reach 2″ and deal Size + 1 (rulebook p. 22). No box card has it.
    public var hasMEL: Bool {
        abilityTags.contains("MEL")
    }

    /// Heat cools only on a turn without a weapon attack; a punch or kick doesn't count (p. 24).
    /// A REAR shot is a weapon attack.
    public var madeWeaponAttackThisTurn: Bool {
        (hasAttackedThisTurn && turnShot?.kind != .physical) || rearShot != nil
    }

    /// REAR#/#/# damage at this range (p. 25). 0 without REAR or "-" there.
    public func rearDamage(at bracket: RangeBracket) -> Int {
        guard let tag = abilityTags.first(where: { $0.hasPrefix("REAR") }) else { return 0 }
        let values = tag.dropFirst(4).split(separator: "/", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        let index: Int
        switch bracket {
        case .short: index = 0
        case .medium: index = 1
        case .long: index = 2
        case .outOfRange: return 0
        }
        return index < values.count ? values[index] : 0
    }

    public var hasRearFiring: Bool { abilityTags.contains { $0.hasPrefix("REAR") } }

    /// A REAR attack is allowed once a turn, before the forward shot or a punch (p. 25).
    public var canRearFireThisTurn: Bool {
        hasRearFiring && canAttackThisTurn && rearShot == nil
    }

    /// Eligible to open SATOR this combat impulse.
    public var canAttackThisTurn: Bool {
        canFire && !hasAttackedThisTurn && movementMode != .sprint && !isShutdown
    }

    /// Alpha Strike jump is printed on the card (`6"j` or `10"/6"j`).
    public var canJump: Bool {
        mv.range(of: "j", options: .caseInsensitive) != nil
    }

    /// Second MP critical sets move to 0, and a shut-down ’Mech can't move. Both are immobile targets.
    /// Heat alone never makes a ’Mech immobile: it can still jump.
    public var isImmobile: Bool {
        isShutdown || motiveMV.prefix(while: { $0.isNumber }) == "0"
    }

    /// Crippled (rulebook p. 12), any one of:
    /// - no armor left and structure at half its starting value (rounded up) or less;
    /// - Medium and Long damage both reduced to 0 by weapon hits;
    /// - immobilized by MP critical hits.
    /// Under Forced Withdrawal a crippled ’Mech must move toward its own edge (`MatchSession.mustWithdraw`).
    public var isCrippled: Bool {
        isArmorAndHalfStructureGone || areMediumAndLongGone || isImmobilizedByCrits
    }

    /// No armor left, and structure at or below half its starting value, rounded up (5 → 3, 7 → 4).
    public var isArmorAndHalfStructureGone: Bool {
        guard armorCap > 0 || structureCap > 0 else { return false }
        return remainingArmor == 0 && remainingStructure <= (structureCap + 1) / 2
    }

    /// Medium and Long both 0 after weapon hits. A card that prints 0 for both was never "reduced",
    /// so it needs a weapon hit before this counts.
    public var areMediumAndLongGone: Bool {
        let damage = effectiveDamage
        guard damage.m == 0, damage.l == 0 else { return false }
        return crits.weaponHits > 0 && (m > 0 || l > 0)
    }

    /// MP hits took its move to 0. Heat shutdown doesn't count: it restarts.
    public var isImmobilizedByCrits: Bool {
        crits.mpHits > 0 && motiveMV.prefix(while: { $0.isNumber }) == "0"
    }

    public var legalMovementModes: [MovementMode] {
        if isImmobile { return [.standstill] }
        var modes: [MovementMode] = [.standstill, .ground, .sprint]
        if canJump { modes.append(.jump) }
        return modes
    }
}

extension MatchUnitState {
    private enum CodingKeys: String, CodingKey {
        case id, libraryUnitId, name, side, skill, pv, sz, mv, tmm, s, m, l, ov
        case armorCap, structureCap, armorDamage, structureDamage, heat, abilities, crits, combatPhaseCrits
        case movementMode, hasMovedThisTurn, hasAttackedThisTurn, turnShot, combatStatus
        case pendingCritical, criticalsOwed, overheatThisTurn, mini, incomingHeatThisTurn
        case rearShot, rearFireReduction
        case leftTable, withdrawalAnnounced
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        libraryUnitId = try container.decodeIfPresent(UUID.self, forKey: .libraryUnitId)
        name = try container.decode(String.self, forKey: .name)
        side = try container.decode(SideId.self, forKey: .side)
        skill = try container.decode(Int.self, forKey: .skill)
        pv = try container.decode(Int.self, forKey: .pv)
        sz = try container.decode(Int.self, forKey: .sz)
        mv = try container.decode(String.self, forKey: .mv)
        tmm = try container.decode(Int.self, forKey: .tmm)
        s = try container.decode(Int.self, forKey: .s)
        m = try container.decode(Int.self, forKey: .m)
        l = try container.decode(Int.self, forKey: .l)
        ov = try container.decode(Int.self, forKey: .ov)
        armorCap = try container.decode(Int.self, forKey: .armorCap)
        structureCap = try container.decode(Int.self, forKey: .structureCap)
        armorDamage = try container.decode(Int.self, forKey: .armorDamage)
        structureDamage = try container.decode(Int.self, forKey: .structureDamage)
        heat = try container.decode(Int.self, forKey: .heat)
        abilities = try container.decode(String.self, forKey: .abilities)
        crits = try container.decode(CritFlags.self, forKey: .crits)
        combatPhaseCrits = try container.decodeIfPresent(CritFlags.self, forKey: .combatPhaseCrits)
        movementMode = try container.decode(MovementMode.self, forKey: .movementMode)
        hasMovedThisTurn = try container.decode(Bool.self, forKey: .hasMovedThisTurn)
        hasAttackedThisTurn = try container.decode(Bool.self, forKey: .hasAttackedThisTurn)
        turnShot = try container.decodeIfPresent(TurnShot.self, forKey: .turnShot)
        combatStatus = try container.decode(UnitCombatStatus.self, forKey: .combatStatus)
        if let owed = try container.decodeIfPresent(Int.self, forKey: .criticalsOwed) {
            criticalsOwed = owed
        } else {
            let flag = try container.decodeIfPresent(Bool.self, forKey: .pendingCritical) ?? false
            criticalsOwed = flag ? 1 : 0
        }
        overheatThisTurn = try container.decodeIfPresent(Int.self, forKey: .overheatThisTurn) ?? 0
        incomingHeatThisTurn = try container.decodeIfPresent(Int.self, forKey: .incomingHeatThisTurn) ?? 0
        rearShot = try container.decodeIfPresent(TurnShot.self, forKey: .rearShot)
        rearFireReduction = try container.decodeIfPresent(Int.self, forKey: .rearFireReduction) ?? 0
        mini = try container.decodeIfPresent(MiniMarker.self, forKey: .mini)
        leftTable = try container.decodeIfPresent(Bool.self, forKey: .leftTable) ?? false
        withdrawalAnnounced = try container.decodeIfPresent(Bool.self, forKey: .withdrawalAnnounced) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(libraryUnitId, forKey: .libraryUnitId)
        try container.encode(name, forKey: .name)
        try container.encode(side, forKey: .side)
        try container.encode(skill, forKey: .skill)
        try container.encode(pv, forKey: .pv)
        try container.encode(sz, forKey: .sz)
        try container.encode(mv, forKey: .mv)
        try container.encode(tmm, forKey: .tmm)
        try container.encode(s, forKey: .s)
        try container.encode(m, forKey: .m)
        try container.encode(l, forKey: .l)
        try container.encode(ov, forKey: .ov)
        try container.encode(armorCap, forKey: .armorCap)
        try container.encode(structureCap, forKey: .structureCap)
        try container.encode(armorDamage, forKey: .armorDamage)
        try container.encode(structureDamage, forKey: .structureDamage)
        try container.encode(heat, forKey: .heat)
        try container.encode(abilities, forKey: .abilities)
        try container.encode(crits, forKey: .crits)
        try container.encodeIfPresent(combatPhaseCrits, forKey: .combatPhaseCrits)
        try container.encode(movementMode, forKey: .movementMode)
        try container.encode(hasMovedThisTurn, forKey: .hasMovedThisTurn)
        try container.encode(hasAttackedThisTurn, forKey: .hasAttackedThisTurn)
        try container.encodeIfPresent(turnShot, forKey: .turnShot)
        try container.encode(combatStatus, forKey: .combatStatus)
        try container.encode(criticalsOwed, forKey: .criticalsOwed)
        try container.encode(pendingCritical, forKey: .pendingCritical)
        try container.encode(overheatThisTurn, forKey: .overheatThisTurn)
        if incomingHeatThisTurn > 0 { try container.encode(incomingHeatThisTurn, forKey: .incomingHeatThisTurn) }
        try container.encodeIfPresent(rearShot, forKey: .rearShot)
        if rearFireReduction > 0 { try container.encode(rearFireReduction, forKey: .rearFireReduction) }
        try container.encodeIfPresent(mini, forKey: .mini)
        try container.encode(leftTable, forKey: .leftTable)
        try container.encode(withdrawalAnnounced, forKey: .withdrawalAnnounced)
    }
}
