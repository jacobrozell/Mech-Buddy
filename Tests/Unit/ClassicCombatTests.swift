// Tests for Domain/Engines/ClassicTW/ClassicCombat.swift against the A Game of Armored Combat rulebook.
// Pages: docs/game-modes/classic/rules-check-2026-11-24.md (C3–C6).
import Testing
import MechBuddyDomain

@Suite("Classic to-hit")
struct ClassicToHitTests {
    private let mediumLaser = ClassicWeaponRange(minimum: 0, short: 3, medium: 6, long: 9)
    private let ppc = ClassicWeaponRange(minimum: 3, short: 6, medium: 12, long: 18)

    @Test("Target movement modifier bands, with +1 for jumping (AGOAC p. 16)")
    func targetMovement() {
        let bands: [(Int, Int)] = [(0, 0), (2, 0), (3, 1), (4, 1), (5, 2), (6, 2), (7, 3), (9, 3),
                                   (10, 4), (17, 4), (18, 5), (24, 5), (25, 6), (40, 6)]
        for (hexes, modifier) in bands {
            #expect(ClassicToHit.targetMovementModifier(hexesMoved: hexes, jumped: false) == modifier, "\(hexes)")
        }
        #expect(ClassicToHit.targetMovementModifier(hexesMoved: 5, jumped: true) == 3)
    }

    @Test("Range brackets and the minimum-range penalty (PPC +1 at 3 hexes, +3 at 1)")
    func ranges() {
        #expect(mediumLaser.bracket(at: 3) == .short)
        #expect(mediumLaser.bracket(at: 4) == .medium)
        #expect(mediumLaser.bracket(at: 9) == .long)
        #expect(mediumLaser.bracket(at: 10) == .outOfRange)
        #expect(ppc.minimumRangeModifier(at: 3) == 1)
        #expect(ppc.minimumRangeModifier(at: 2) == 2)
        #expect(ppc.minimumRangeModifier(at: 1) == 3)
        #expect(ppc.minimumRangeModifier(at: 4) == 0)
        #expect(mediumLaser.minimumRangeModifier(at: 1) == 0)
    }

    @Test("Gunnery 4, walked, target ran 5 hexes, medium range: 4 + 1 + 2 + 2 = 9")
    func fullSum() {
        let result = ClassicToHit.targetNumber(
            gunnery: 4, attacker: .walked, targetHexesMoved: 5, targetJumped: false, range: 5, weapon: mediumLaser
        )
        #expect(result.targetNumber == 9)
        #expect(result.bracket == .medium)
        #expect(result.terms.map(\.value) == [4, 1, 2, 2])
        #expect(!result.isImpossible)
    }

    @Test("Over 12 can't hit; out of range has no number; other modifiers are added and listed")
    func limits() {
        let far = ClassicToHit.targetNumber(
            gunnery: 4, attacker: .jumped, targetHexesMoved: 10, targetJumped: true, range: 8, weapon: mediumLaser,
            other: [ClassicToHit.Term("Woods", 1)]
        )
        #expect(far.targetNumber == 4 + 3 + 5 + 4 + 1)
        #expect(far.isImpossible)
        #expect(far.terms.last == ClassicToHit.Term("Woods", 1))
        let none = ClassicToHit.targetNumber(
            gunnery: 4, attacker: .stood, targetHexesMoved: 0, targetJumped: false, range: 12, weapon: mediumLaser
        )
        #expect(none.targetNumber == nil)
        #expect(none.bracket == .outOfRange)
    }

    @Test("Attacker modifier by mode: 0 / 1 / 2 / 3")
    func attacker() {
        #expect(ClassicMovementMode.allCases.map(\.attackerModifier) == [0, 1, 2, 3])
    }
}

@Suite("Classic hit locations")
struct ClassicHitLocationTests {
    @Test("Front column matches the table, 2 is a through-armor crit on the CT")
    func front() {
        let expected: [ClassicLocation] = [.centerTorso, .rightArm, .rightArm, .rightLeg, .rightTorso, .centerTorso,
                                           .leftTorso, .leftLeg, .leftArm, .leftArm, .head]
        for roll in 2...12 {
            #expect(ClassicHitLocation.weapon(roll: roll, from: .front).location == expected[roll - 2], "\(roll)")
        }
        #expect(ClassicHitLocation.weapon(roll: 2, from: .front).throughArmorCritical)
        #expect(!ClassicHitLocation.weapon(roll: 7, from: .front).throughArmorCritical)
    }

    @Test("Side columns: 7 hits that side's torso, 8 the CT, 12 the head")
    func sides() {
        #expect(ClassicHitLocation.weapon(roll: 7, from: .left).location == .leftTorso)
        #expect(ClassicHitLocation.weapon(roll: 8, from: .left).location == .centerTorso)
        #expect(ClassicHitLocation.weapon(roll: 7, from: .right).location == .rightTorso)
        #expect(ClassicHitLocation.weapon(roll: 3, from: .right).location == .rightLeg)
        #expect(ClassicHitLocation.weapon(roll: 12, from: .left).location == .head)
    }

    @Test("Rear shots land on rear torso armor only")
    func rear() {
        #expect(ClassicHitLocation.weapon(roll: 7, from: .rear) == ClassicHit(.centerTorso, rear: true))
        #expect(ClassicHitLocation.weapon(roll: 4, from: .rear) == ClassicHit(.rightArm, rear: false))
    }

    @Test("Punch and kick tables")
    func physical() {
        #expect((1...6).map { ClassicHitLocation.punch(roll: $0, from: .front).location }
            == [.leftArm, .leftTorso, .centerTorso, .rightTorso, .rightArm, .head])
        #expect(ClassicHitLocation.punch(roll: 4, from: .left).location == .leftArm)
        #expect(ClassicHitLocation.kick(roll: 2, from: .front).location == .rightLeg)
        #expect(ClassicHitLocation.kick(roll: 5, from: .front).location == .leftLeg)
        #expect(ClassicHitLocation.kick(roll: 1, from: .left).location == .leftLeg)
    }
}

@Suite("Classic damage")
struct ClassicDamageTests {
    /// Locust LCT-1V armor and structure from its record sheet.
    private var locust: ClassicDamageState {
        ClassicDamageState(
            armor: ["HD": 8, "CT": 10, "CTR": 2, "LT": 8, "LTR": 2, "RT": 8, "RTR": 2, "LA": 4, "RA": 4, "LL": 8, "RL": 8],
            structure: ["HD": 3, "CT": 6, "LT": 5, "RT": 5, "LA": 3, "RA": 3, "LL": 4, "RL": 4]
        )
    }

    @Test("Armor first, then structure, which calls for a crit check")
    func armorThenStructure() {
        var state = locust
        let events = ClassicDamage.apply(10, to: ClassicHit(.leftTorso), state: &state)
        #expect(events == [.armor(.leftTorso, rear: false, points: 8), .structure(.leftTorso, points: 2)])
        #expect(state.armor["LT"] == 0)
        #expect(state.armor["LTR"] == 2)
        #expect(state.structure["LT"] == 3)
    }

    @Test("A destroyed arm passes the rest to its torso")
    func armTransfers() {
        var state = locust
        let events = ClassicDamage.apply(10, to: ClassicHit(.rightArm), state: &state)
        #expect(events == [
            .armor(.rightArm, rear: false, points: 4),
            .destroyed(.rightArm),
            .transferred(from: .rightArm, to: .rightTorso, points: 3),
            .armor(.rightTorso, rear: false, points: 3),
        ])
        #expect(state.armor["RT"] == 5)
    }

    @Test("Losing a side torso blows off that arm; rear damage stays on rear armor")
    func sideTorso() {
        var state = locust
        let events = ClassicDamage.apply(9, to: ClassicHit(.leftTorso, rear: true), state: &state)
        #expect(events == [
            .armor(.leftTorso, rear: true, points: 2),
            .destroyed(.leftTorso),
            .armBlownOff(.leftArm),
            .transferred(from: .leftTorso, to: .centerTorso, points: 2),
            .armor(.centerTorso, rear: true, points: 2),
        ])
        #expect(state.isDestroyed(.leftArm))
        #expect(state.armor["CTR"] == 0)
        #expect(state.armor["CT"] == 10)
        #expect(!state.isMechDestroyed)
    }

    @Test("Head and centre torso don't transfer; losing either destroys the 'Mech")
    func destroyed() {
        var state = locust
        let events = ClassicDamage.apply(30, to: ClassicHit(.head), state: &state)
        #expect(events == [.armor(.head, rear: false, points: 8), .destroyed(.head)])
        #expect(state.isMechDestroyed)
    }
}
