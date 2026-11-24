// Tests for Data/Onboarding/OnboardingModel.swift (MechBuddyData).
import Foundation
import Testing
import MechBuddyData

@Suite("Onboarding steps")
struct OnboardingStepTests {
    @Test("First run asks all four questions when Classic is visible")
    func firstRun() {
        #expect(OnboardingStep.steps(for: .firstRun, classicAvailable: true) == [.welcome, .track, .kit, .firstMission])
    }

    @Test("Changing game skips Welcome")
    func changeTrack() {
        #expect(OnboardingStep.steps(for: .changeTrack, classicAvailable: true) == [.track, .kit, .firstMission])
    }

    @Test("Without the Classic entry there is no track question", arguments: [OnboardingEntry.firstRun, .changeTrack])
    func noClassic(entry: OnboardingEntry) {
        #expect(OnboardingStep.steps(for: entry, classicAvailable: false) == [.welcome, .kit, .firstMission])
    }

    @Test("Progress runs 1 of n to n of n")
    func progress() {
        let steps = OnboardingStep.steps(for: .firstRun, classicAvailable: true)
        #expect(OnboardingStep.progress(of: .welcome, in: steps) == 0.25)
        #expect(OnboardingStep.progress(of: .kit, in: steps) == 0.75)
        #expect(OnboardingStep.progress(of: .firstMission, in: steps) == 1)
        #expect(OnboardingStep.progress(of: .track, in: [.welcome, .kit]) == 0)
    }
}

@Suite("Onboarding persistence")
struct OnboardingStoreTests {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "onboarding-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test("Fresh install: no track, not complete")
    func fresh() {
        withDefaults { defaults in
            #expect(OnboardingStore.load(from: defaults) == .fresh)
        }
    }

    @Test("Saved track and completion round-trip", arguments: LearningTrack.allCases)
    func roundTrip(track: LearningTrack) {
        withDefaults { defaults in
            let record = OnboardingRecord(track: track, isComplete: true)
            OnboardingStore.save(record, to: defaults)
            #expect(OnboardingStore.load(from: defaults) == record)
        }
    }

    @Test("Saving no track clears the stored one")
    func clearTrack() {
        withDefaults { defaults in
            OnboardingStore.save(OnboardingRecord(track: .classic, isComplete: true), to: defaults)
            OnboardingStore.save(OnboardingRecord(track: nil, isComplete: true), to: defaults)
            #expect(defaults.object(forKey: OnboardingStore.trackKey) == nil)
            #expect(OnboardingStore.load(from: defaults) == OnboardingRecord(track: nil, isComplete: true))
        }
    }

    @Test("Players from before onboarding count as done with Alpha Strike")
    func legacyIntro() {
        withDefaults { defaults in
            defaults.set(true, forKey: OnboardingStore.legacyIntroKey)
            #expect(OnboardingStore.load(from: defaults) == OnboardingRecord(track: .alphaStrike, isComplete: true))
        }
    }

    @Test("A saved record wins over the legacy flag")
    func savedBeatsLegacy() {
        withDefaults { defaults in
            defaults.set(true, forKey: OnboardingStore.legacyIntroKey)
            OnboardingStore.save(OnboardingRecord(track: .classic, isComplete: false), to: defaults)
            #expect(OnboardingStore.load(from: defaults) == OnboardingRecord(track: .classic, isComplete: false))
        }
    }

    @Test("Unknown stored track reads as no track")
    func unknownTrack() {
        withDefaults { defaults in
            defaults.set("freeBattle", forKey: OnboardingStore.trackKey)
            #expect(OnboardingStore.load(from: defaults).track == nil)
        }
    }

    @Test("Removing the owned keys resets to fresh (what AppPreferences.reset does)")
    func ownedKeysReset() {
        withDefaults { defaults in
            defaults.set(true, forKey: OnboardingStore.legacyIntroKey)
            OnboardingStore.save(OnboardingRecord(track: .classic, isComplete: true), to: defaults)
            for key in OnboardingStore.ownedKeys {
                defaults.removeObject(forKey: key)
            }
            #expect(OnboardingStore.load(from: defaults) == .fresh)
        }
    }
}

@Suite("Play layout by track")
struct PlayTrackLayoutTests {
    @Test("Classic pick: spotlight above the path, no bottom row")
    func classic() {
        let layout = PlayTrackLayout.make(track: .classic, classicEntryEnabled: true)
        #expect(layout == PlayTrackLayout(showsClassicSpotlight: true, showsClassicRow: false))
    }

    @Test("Alpha Strike or no pick: the usual small Classic row", arguments: [LearningTrack.alphaStrike, nil])
    func alphaStrike(track: LearningTrack?) {
        let layout = PlayTrackLayout.make(track: track, classicEntryEnabled: true)
        #expect(layout == PlayTrackLayout(showsClassicSpotlight: false, showsClassicRow: true))
    }

    @Test("Classic entry gated off: no Classic anywhere", arguments: [LearningTrack.alphaStrike, .classic, nil])
    func gated(track: LearningTrack?) {
        let layout = PlayTrackLayout.make(track: track, classicEntryEnabled: false)
        #expect(layout == PlayTrackLayout(showsClassicSpotlight: false, showsClassicRow: false))
    }

    @Test("Only Alpha Strike is playable in the app")
    func playable() {
        #expect(LearningTrack.alphaStrike.isPlayableInApp)
        #expect(!LearningTrack.classic.isPlayableInApp)
        for track in LearningTrack.allCases {
            #expect(track.commitments.map(\.id) == ["time", "rules", "gear"])
        }
    }
}

@Suite("Onboarding kit and next mission")
struct OnboardingKitTests {
    @Test("Still needed keeps screen order")
    func stillNeeded() {
        let ids = ["minis", "dice", "tape", "maps"]
        #expect(OnboardingKit.stillNeeded(kitIDs: ids, have: ["dice", "maps"]) == ["minis", "tape"])
        #expect(OnboardingKit.stillNeeded(kitIDs: ids, have: Set(ids)).isEmpty)
    }

    @Test("Known gear has its own symbol")
    func symbols() {
        let fallback = OnboardingKit.systemImage(for: "unknown")
        for id in ["minis", "dice", "tape", "maps"] {
            #expect(OnboardingKit.systemImage(for: id) != fallback, "\(id)")
        }
    }

    @Test("Next mission: first playable not cleared, else the last playable")
    func nextMission() {
        let ladder: [(id: String, playable: Bool)] = [
            ("ridge-line", true), ("broken-ground", true), ("close-quarters", false)
        ]
        #expect(OnboardingMissions.nextMissionID(ladder: ladder, completed: []) == "ridge-line")
        #expect(OnboardingMissions.nextMissionID(ladder: ladder, completed: ["ridge-line"]) == "broken-ground")
        #expect(OnboardingMissions.nextMissionID(ladder: ladder, completed: ["ridge-line", "broken-ground"]) == "broken-ground")
        #expect(OnboardingMissions.nextMissionID(ladder: [], completed: []) == nil)
    }
}
