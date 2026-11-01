import Foundation

/// The shot this ’Mech already took this turn. Cleared when the next turn starts.
public struct TurnShot: Codable, Sendable, Equatable {
    public var targetName: String
    public var hit: Bool
    public var total: Int
    public var targetNumber: Int
    public var damage: Int

    public init(targetName: String, hit: Bool, total: Int, targetNumber: Int, damage: Int) {
        self.targetName = targetName
        self.hit = hit
        self.total = total
        self.targetNumber = targetNumber
        self.damage = damage
    }

    public var rowTitle: String {
        hit ? "Hit \(targetName) for \(damage)" : "Missed \(targetName)"
    }

    public var rowDetail: String {
        if hit {
            return "Rolled \(total), needed \(targetNumber)."
        }
        return "Rolled \(total), needed \(targetNumber). No damage."
    }
}

public struct CritFlags: Codable, Sendable, Equatable {
    public var fireControlHits: Int
    public var engineHits: Int
    public var weaponHits: Int
    public var mpHit: Bool
    public var ammoExploded: Bool
    public var destroyedByCrit: Bool

    public init(
        fireControlHits: Int = 0,
        engineHits: Int = 0,
        weaponHits: Int = 0,
        mpHit: Bool = false,
        ammoExploded: Bool = false,
        destroyedByCrit: Bool = false
    ) {
        self.fireControlHits = fireControlHits
        self.engineHits = engineHits
        self.weaponHits = weaponHits
        self.mpHit = mpHit
        self.ammoExploded = ammoExploded
        self.destroyedByCrit = destroyedByCrit
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
    public var movementMode: MovementMode
    public var hasMovedThisTurn: Bool
    public var hasAttackedThisTurn: Bool
    public var turnShot: TurnShot?
    public var combatStatus: UnitCombatStatus
    /// How many critical rolls this ’Mech still owes. One hit that marks structure or rolls a 12 adds one.
    public var criticalsOwed: Int

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
        movementMode: MovementMode = .unset,
        hasMovedThisTurn: Bool = false,
        hasAttackedThisTurn: Bool = false,
        turnShot: TurnShot? = nil,
        combatStatus: UnitCombatStatus = .active,
        criticalsOwed: Int = 0
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
        self.movementMode = movementMode
        self.hasMovedThisTurn = hasMovedThisTurn
        self.hasAttackedThisTurn = hasAttackedThisTurn
        self.turnShot = turnShot
        self.combatStatus = combatStatus
        self.criticalsOwed = criticalsOwed
    }

    public var remainingArmor: Int { max(0, armorCap - armorDamage) }
    public var remainingStructure: Int { max(0, structureCap - structureDamage) }
    public var isStructurallyDestroyed: Bool { structureCap > 0 && structureDamage >= structureCap }

    public var canFire: Bool {
        combatStatus == .active || combatStatus == .destroyedPendingEnd
    }

    public var effectiveTMM: Int {
        if crits.mpHit { return tmm / 2 }
        return tmm
    }

    /// Halves printed MV inches when `mpHit` is set (floor).
    /// Halves every printed inch value. `10"/6"j` becomes `5"/3"j`.
    public var effectiveMV: String {
        guard crits.mpHit else { return mv }
        var result = ""
        var digits = ""
        func flushDigits() {
            guard !digits.isEmpty else { return }
            let value = Int(digits) ?? 0
            result.append(String(value / 2))
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

    public var hasAmmoImmunity: Bool {
        let upper = abilities.uppercased()
        return upper.contains("ENE") || upper.contains("CASE")
    }

    public var hasStealth: Bool {
        abilities.uppercased().contains("STL")
    }

    public var hasOVL: Bool {
        abilities.uppercased().contains("OVL")
    }

    /// Eligible to open SATOR this combat impulse.
    public var canAttackThisTurn: Bool {
        canFire && !hasAttackedThisTurn && movementMode != .sprint
    }

    /// Alpha Strike jump is printed on the card (`6"j` or `10"/6"j`).
    public var canJump: Bool {
        mv.range(of: "j", options: .caseInsensitive) != nil
    }

    /// Second MP critical sets move to 0. Those targets are immobile.
    public var isImmobile: Bool {
        effectiveMV.prefix(while: { $0.isNumber }) == "0"
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
        case armorCap, structureCap, armorDamage, structureDamage, heat, abilities, crits
        case movementMode, hasMovedThisTurn, hasAttackedThisTurn, turnShot, combatStatus
        case pendingCritical, criticalsOwed
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
        try container.encode(movementMode, forKey: .movementMode)
        try container.encode(hasMovedThisTurn, forKey: .hasMovedThisTurn)
        try container.encode(hasAttackedThisTurn, forKey: .hasAttackedThisTurn)
        try container.encodeIfPresent(turnShot, forKey: .turnShot)
        try container.encode(combatStatus, forKey: .combatStatus)
        try container.encode(criticalsOwed, forKey: .criticalsOwed)
        try container.encode(pendingCritical, forKey: .pendingCritical)
    }
}
