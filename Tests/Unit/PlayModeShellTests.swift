// Learn | Play landing tab and the Play setup payload (PlayModeSpec § 3, § 12).
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

@Suite("Play mode shell")
struct PlayModeShellTests {
    @Test("Flag off always opens the Play tab")
    func flagOff() {
        #expect(RootTabRule.landing(playMode: false, onboardingDone: true, missionsCleared: 3, lastTab: "force") == "play")
        #expect(RootTabRule.landing(playMode: false, onboardingDone: true, missionsCleared: 0, lastTab: nil, openRules: true) == "rules")
    }

    @Test("New players land on Learn")
    func newPlayer() {
        #expect(RootTabRule.landing(playMode: true, onboardingDone: false, missionsCleared: 2, lastTab: "play") == "learn")
        #expect(RootTabRule.landing(playMode: true, onboardingDone: true, missionsCleared: 0, lastTab: "play") == "learn")
    }

    @Test("Others land on the last tab used")
    func lastTab() {
        #expect(RootTabRule.landing(playMode: true, onboardingDone: true, missionsCleared: 1, lastTab: "play") == "play")
        #expect(RootTabRule.landing(playMode: true, onboardingDone: true, missionsCleared: 1, lastTab: nil) == "learn")
        #expect(RootTabRule.landing(playMode: true, onboardingDone: true, missionsCleared: 1, lastTab: "bogus") == "learn")
    }

    @Test("A mission session decodes with no Play setup; a Play session round-trips")
    func sessionPlayField() throws {
        let mission = MatchSession(ruleset: .ridgeLine)
        let data = try JSONEncoder().encode(mission)
        #expect(try JSONDecoder().decode(MatchSession.self, from: data).play == nil)

        var setup = PlaySetup.pickup()
        setup.forces[.lanceA] = [ForcePick(cardId: "locust-lct-7v", name: "Locust LCT-7V", basePV: 25, size: 1, skill: 4, isClan: false)]
        let play = MatchSession(ruleset: setup.ruleset, sides: setup.sides, play: setup)
        let decoded = try JSONDecoder().decode(MatchSession.self, from: JSONEncoder().encode(play))
        #expect(decoded.play == setup)
        #expect(decoded.isPlayGame)
        #expect(decoded.play?.formatName == "1 v 1")
    }
}
