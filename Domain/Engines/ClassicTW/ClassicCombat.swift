import Foundation

// Classic to-hit, hit locations and damage, from the A Game of Armored Combat rulebook (AGOAC).
// Rules and pages: docs/game-modes/classic/rules-check-2026-11-24.md (C3–C6).

// MARK: - Movement

/// How a 'Mech moved this turn. The attacker modifier depends on the mode, not the distance (AGOAC p. 16).
public enum ClassicMovementMode: String, Codable, CaseIterable, Sendable {
    case stood
    case walked
    case ran
    case jumped

    /// +0 stood, +1 walked, +2 ran, +3 jumped.
    public var attackerModifier: Int {
        switch self {
        case .stood: 0
        case .walked: 1
        case .ran: 2
        case .jumped: 3
        }
    }
}

// MARK: - To-hit

public enum ClassicRangeBracket: String, Codable, Sendable {
    case short
    case medium
    case long
    case outOfRange

    /// +0 short, +2 medium, +4 long (AGOAC p. 18).
    public var modifier: Int? {
        switch self {
        case .short: 0
        case .medium: 2
        case .long: 4
        case .outOfRange: nil
        }
    }
}

/// A weapon's range bands in hexes (Weapons and Equipment Table, AGOAC p. 55).
public struct ClassicWeaponRange: Equatable, Sendable {
    public var minimum: Int
    public var short: Int
    public var medium: Int
    public var long: Int

    public init(minimum: Int, short: Int, medium: Int, long: Int) {
        self.minimum = minimum
        self.short = short
        self.medium = medium
        self.long = long
    }

    public func bracket(at hexes: Int) -> ClassicRangeBracket {
        if hexes <= short { return .short }
        if hexes <= medium { return .medium }
        if hexes <= long { return .long }
        return .outOfRange
    }

    /// Inside minimum range: minimum − range + 1 (a PPC, minimum 3, gets +1 at 3 hexes, +3 at 1). Else 0.
    public func minimumRangeModifier(at hexes: Int) -> Int {
        guard minimum > 0, hexes <= minimum else { return 0 }
        return minimum - hexes + 1
    }
}

public enum ClassicToHit {
    /// Target movement modifier by hexes moved (not MP), +1 more if it jumped (AGOAC p. 16):
    /// 0–2 → 0, 3–4 → 1, 5–6 → 2, 7–9 → 3, 10–17 → 4, 18–24 → 5, 25+ → 6.
    public static func targetMovementModifier(hexesMoved: Int, jumped: Bool) -> Int {
        let base: Int
        switch max(0, hexesMoved) {
        case 0...2: base = 0
        case 3...4: base = 1
        case 5...6: base = 2
        case 7...9: base = 3
        case 10...17: base = 4
        case 18...24: base = 5
        default: base = 6
        }
        return base + (jumped ? 1 : 0)
    }

    /// One labelled line in the to-hit sum, for showing the player how the number was built.
    public struct Term: Equatable, Sendable {
        public var label: String
        public var value: Int

        public init(_ label: String, _ value: Int) {
            self.label = label
            self.value = value
        }
    }

    public struct Result: Equatable, Sendable {
        public var terms: [Term]
        /// `nil` when the target is out of range.
        public var targetNumber: Int?
        public var bracket: ClassicRangeBracket

        /// Over 12 can't hit (AGOAC p. 15).
        public var isImpossible: Bool { (targetNumber ?? 13) > 12 }
        /// 2 or less always hits.
        public var isAutomaticHit: Bool { (targetNumber ?? 13) <= 2 }
    }

    /// The modified target number for one weapon: gunnery + attacker movement + target movement + range
    /// (+ minimum range) + any other modifiers (terrain, heat, damage), each listed.
    public static func targetNumber(
        gunnery: Int,
        attacker: ClassicMovementMode,
        targetHexesMoved: Int,
        targetJumped: Bool,
        range hexes: Int,
        weapon: ClassicWeaponRange,
        other: [Term] = []
    ) -> Result {
        let bracket = weapon.bracket(at: hexes)
        guard let rangeModifier = bracket.modifier else {
            return Result(terms: [], targetNumber: nil, bracket: .outOfRange)
        }
        var terms = [
            Term("Gunnery", gunnery),
            Term("You \(attacker.rawValue)", attacker.attackerModifier),
            Term("Target moved \(targetHexesMoved) hex\(targetHexesMoved == 1 ? "" : "es")\(targetJumped ? ", jumped" : "")",
                 targetMovementModifier(hexesMoved: targetHexesMoved, jumped: targetJumped)),
            Term("\(bracket.rawValue.capitalized) range", rangeModifier),
        ]
        let minimum = weapon.minimumRangeModifier(at: hexes)
        if minimum > 0 { terms.append(Term("Minimum range", minimum)) }
        terms += other
        return Result(terms: terms, targetNumber: terms.reduce(0) { $0 + $1.value }, bracket: bracket)
    }
}

// MARK: - Hit location

/// Which side of the target the shot comes from (AGOAC p. 22).
public enum ClassicAttackDirection: String, Codable, CaseIterable, Sendable {
    case front
    case left
    case right
    case rear
}

public struct ClassicHit: Equatable, Sendable {
    public var location: ClassicLocation
    /// Applied to the rear torso armor (shots from the rear).
    public var rear: Bool
    /// A roll of 2: a crit check on that torso even if armor holds (through-armor critical, AGOAC p. 22).
    public var throughArmorCritical: Bool

    public init(_ location: ClassicLocation, rear: Bool = false, throughArmorCritical: Bool = false) {
        self.location = location
        self.rear = rear
        self.throughArmorCritical = throughArmorCritical
    }
}

public enum ClassicHitLocation {
    /// 2D6 Hit Location Table (AGOAC p. 23). Rear shots use the Front/Rear column on rear armor.
    public static func weapon(roll: Int, from direction: ClassicAttackDirection) -> ClassicHit {
        let roll = min(12, max(2, roll))
        let rear = direction == .rear
        let location: ClassicLocation
        switch direction {
        case .front, .rear:
            location = [.centerTorso, .rightArm, .rightArm, .rightLeg, .rightTorso, .centerTorso,
                        .leftTorso, .leftLeg, .leftArm, .leftArm, .head][roll - 2]
        case .left:
            location = [.leftTorso, .leftLeg, .leftArm, .leftArm, .leftLeg, .leftTorso,
                        .centerTorso, .rightTorso, .rightArm, .rightLeg, .head][roll - 2]
        case .right:
            location = [.rightTorso, .rightLeg, .rightArm, .rightArm, .rightLeg, .rightTorso,
                        .centerTorso, .leftTorso, .leftArm, .leftLeg, .head][roll - 2]
        }
        let torso = location.rearKey != nil
        return ClassicHit(location, rear: rear && torso, throughArmorCritical: roll == 2)
    }

    /// Punch Location Table, 1D6 (AGOAC p. 28).
    public static func punch(roll: Int, from direction: ClassicAttackDirection) -> ClassicHit {
        let index = min(6, max(1, roll)) - 1
        let location: ClassicLocation
        switch direction {
        case .front, .rear:
            location = [.leftArm, .leftTorso, .centerTorso, .rightTorso, .rightArm, .head][index]
        case .left:
            location = [.leftTorso, .leftTorso, .centerTorso, .leftArm, .leftArm, .head][index]
        case .right:
            location = [.rightTorso, .rightTorso, .centerTorso, .rightArm, .rightArm, .head][index]
        }
        return ClassicHit(location, rear: direction == .rear && location.rearKey != nil)
    }

    /// Kick Location Table, 1D6 (AGOAC p. 28): front/rear 1–3 right leg, 4–6 left leg; a side kick hits that side's leg.
    public static func kick(roll: Int, from direction: ClassicAttackDirection) -> ClassicHit {
        switch direction {
        case .left: ClassicHit(.leftLeg)
        case .right: ClassicHit(.rightLeg)
        case .front, .rear: ClassicHit(roll <= 3 ? .rightLeg : .leftLeg)
        }
    }
}

// MARK: - Damage

/// Armor and structure left on one 'Mech. Keys follow the record sheet ("CT", "CTR" for rear CT armor).
public struct ClassicDamageState: Codable, Equatable, Sendable {
    public var armor: [String: Int]
    public var structure: [String: Int]

    public init(armor: [String: Int], structure: [String: Int]) {
        self.armor = armor
        self.structure = structure
    }

    public func isDestroyed(_ location: ClassicLocation) -> Bool {
        (structure[location.rawValue] ?? 0) <= 0
    }

    /// The 'Mech is destroyed when its head or centre torso is (AGOAC p. 32). Engine hits and pilot
    /// wounds also destroy it, but those come from criticals, which aren't tracked here yet.
    public var isMechDestroyed: Bool { isDestroyed(.head) || isDestroyed(.centerTorso) }
}

public enum ClassicDamage {
    /// What one hit did, step by step, for the log and the crit prompts.
    public enum Event: Equatable, Sendable {
        case armor(ClassicLocation, rear: Bool, points: Int)
        /// Structure damaged but the location survives: roll for a critical (AGOAC p. 30).
        case structure(ClassicLocation, points: Int)
        case destroyed(ClassicLocation)
        /// Destroying a side torso takes that side's arm with it (AGOAC p. 34).
        case armBlownOff(ClassicLocation)
        case transferred(from: ClassicLocation, to: ClassicLocation, points: Int)
    }

    /// Where damage goes once a location is destroyed: arm or leg → same-side torso → centre torso.
    /// Head and centre torso never transfer.
    public static func transfer(from location: ClassicLocation) -> ClassicLocation? {
        switch location {
        case .leftArm, .leftLeg: .leftTorso
        case .rightArm, .rightLeg: .rightTorso
        case .leftTorso, .rightTorso: .centerTorso
        case .head, .centerTorso: nil
        }
    }

    /// Applies one hit: armor (front or rear) first, then structure, then the rest moves inward
    /// (AGOAC pp. 30, 34–35). Transferred rear damage stays on rear armor of the next torso.
    @discardableResult
    public static func apply(_ points: Int, to hit: ClassicHit, state: inout ClassicDamageState) -> [Event] {
        var events: [Event] = []
        var remaining = max(0, points)
        var location = hit.location
        var rear = hit.rear
        while remaining > 0 {
            if state.isDestroyed(location) {
                guard let next = transfer(from: location) else { break }
                events.append(.transferred(from: location, to: next, points: remaining))
                location = next
                rear = rear && next.rearKey != nil
                continue
            }
            let armorKey = rear ? (location.rearKey ?? location.rawValue) : location.rawValue
            let armor = state.armor[armorKey] ?? 0
            if armor > 0 {
                let taken = min(armor, remaining)
                state.armor[armorKey] = armor - taken
                remaining -= taken
                events.append(.armor(location, rear: rear, points: taken))
                continue
            }
            let structure = state.structure[location.rawValue] ?? 0
            let taken = min(structure, remaining)
            state.structure[location.rawValue] = structure - taken
            remaining -= taken
            if structure - taken > 0 {
                events.append(.structure(location, points: taken))
            } else {
                events.append(.destroyed(location))
                for key in [location.rawValue, location.rearKey].compactMap({ $0 }) { state.armor[key] = 0 }
                if let arm = armOnSide(of: location), !state.isDestroyed(arm) {
                    state.structure[arm.rawValue] = 0
                    state.armor[arm.rawValue] = 0
                    events.append(.armBlownOff(arm))
                }
            }
        }
        return events
    }

    private static func armOnSide(of location: ClassicLocation) -> ClassicLocation? {
        switch location {
        case .leftTorso: .leftArm
        case .rightTorso: .rightArm
        default: nil
        }
    }
}
