import Testing
import MechBuddyDomain

@Suite("SATORResolver")
struct SATORResolverTests {
    @Test("Vector 1: skill4 ground TMM2 short → TN 6 odds 72")
    func vector1() throws {
        let tn = try SATORResolver.resolve(
            SATORInput(
                skill: 4,
                attackerMove: .ground,
                targetMove: .groundUsesTMM,
                targetTMM: 2,
                rangeBracket: .short
            )
        )
        #expect(tn.value == 6)
        #expect(tn.hitOddsPercent == 72)
        #expect(tn.reasons == [
            "Skill 4",
            "Shooter walked, +0",
            "Target walked, harder to hit by 2",
            "No woods, cover, or other penalty",
            "Short range, +0",
            "Need 6 or higher"
        ])
    }

    @Test("Vector 2: standstill vs standstill short → TN 3")
    func vector2() throws {
        let tn = try SATORResolver.resolve(
            SATORInput(
                skill: 4,
                attackerMove: .standstill,
                targetMove: .standstill,
                targetTMM: 2,
                rangeBracket: .short
            )
        )
        #expect(tn.value == 3)
        #expect(tn.hitOddsPercent == 97)
    }

    @Test("Vector 3: jump vs jump TMM2 medium → TN 11")
    func vector3() throws {
        let tn = try SATORResolver.resolve(
            SATORInput(
                skill: 4,
                attackerMove: .jump,
                targetMove: .jumpedUsesTMMPlus1,
                targetTMM: 2,
                rangeBracket: .medium
            )
        )
        #expect(tn.value == 11)
        #expect(tn.hitOddsPercent == 8)
    }

    @Test("Vector 4: woods + FC1 long → TN 13")
    func vector4() throws {
        let tn = try SATORResolver.resolve(
            SATORInput(
                skill: 4,
                attackerMove: .ground,
                targetMove: .groundUsesTMM,
                targetTMM: 2,
                other: OtherModifiers(woods: true, fireControlHits: 1),
                rangeBracket: .long
            )
        )
        // 4 + 0 + 2 + 1 + 2 + 4 = 13
        #expect(tn.value == 13)
        #expect(tn.autoMiss == true)
        #expect(tn.hitOddsPercent == 0)
        #expect(tn.reasons == [
            "Skill 4",
            "Shooter walked, +0",
            "Target walked, harder to hit by 2",
            "Trees in the way, +1",
            "Fire control hit, +2",
            "Long range, +4",
            "Need 13 or higher"
        ])
    }

    @Test("Vector 5: skill5 TMM3 heat2 short → TN 10")
    func vector5() throws {
        let tn = try SATORResolver.resolve(
            SATORInput(
                skill: 5,
                attackerMove: .ground,
                targetMove: .groundUsesTMM,
                targetTMM: 3,
                other: OtherModifiers(attackerHeat: 2),
                rangeBracket: .short
            )
        )
        #expect(tn.value == 10)
        #expect(tn.hitOddsPercent == 17)
    }

    @Test("Sprint cannot attack")
    func sprintBlocked() {
        #expect(throws: SATORError.self) {
            try SATORResolver.resolve(
                SATORInput(
                    skill: 4,
                    attackerMove: .sprint,
                    targetMove: .standstill,
                    targetTMM: 0,
                    rangeBracket: .short
                )
            )
        }
    }

    @Test("Unset attacker move defaults like ground")
    func unsetDefaultsGround() throws {
        let tn = try SATORResolver.resolve(
            SATORInput(
                skill: 4,
                attackerMove: .unset,
                targetMove: .groundUsesTMM,
                targetTMM: 2,
                rangeBracket: .short
            )
        )
        #expect(tn.value == 6)
    }
}
