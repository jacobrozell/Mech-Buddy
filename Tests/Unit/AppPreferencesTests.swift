// AppPreferences keeps every setting in UserDefaults. These tests use a throwaway suite so the
// player's real settings are never touched.
import Foundation
import SwiftUI
import Testing
import MechBuddyData
import MechBuddyDomain
@testable import MechBuddy

@MainActor
@Suite("App preferences")
struct AppPreferencesTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "prefs-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("A fresh install has the documented defaults")
    func defaults() {
        let prefs = AppPreferences(defaults: makeDefaults())
        #expect(prefs.hapticsEnabled && prefs.keepScreenAwake)
        #expect(prefs.theme == .system && prefs.coaching == .automatic && prefs.defaultDiceMode == .manual)
        #expect(prefs.learningTrack == nil && !prefs.hasCompletedOnboarding)
        #expect(prefs.completedMissions.isEmpty && prefs.gettingStartedChecks.isEmpty)
        #expect(prefs.collection == nil && prefs.mapSwaps.isEmpty && prefs.lastRootTab == nil)
        #expect(prefs.playDraft == nil && prefs.playLastSetup == nil && prefs.rulesGame == nil)
        #expect(prefs.rulesGameToShow == .alphaStrike)
    }

    @Test("Every setting survives being read back by a new instance")
    func roundTrip() {
        let defaults = makeDefaults()
        let prefs = AppPreferences(defaults: defaults)
        prefs.hapticsEnabled = false
        prefs.keepScreenAwake = false
        prefs.theme = .dark
        prefs.coaching = .brief
        prefs.defaultDiceMode = .auto
        prefs.gettingStartedChecks = ["dice", "minis"]
        prefs.completedMissions = ["ridge-line", "broken-ground"]
        prefs.rulesGame = .classic
        prefs.lastRootTab = AppTab.play.rawValue
        prefs.completeOnboarding(track: .classic)
        prefs.mapSwaps = ["ridge-line": ["Desert #1", "Desert #2"]]
        prefs.collection = OwnedCollection(boxes: ["alpha-strike-box": 1])
        var draft = PlaySetup.pickup()
        draft.turnLimit = 7
        prefs.playDraft = draft
        prefs.playLastSetup = PlaySetup.pickup(budgetPV: 300)

        let again = AppPreferences(defaults: defaults)
        #expect(!again.hapticsEnabled && !again.keepScreenAwake)
        #expect(again.theme == .dark && again.coaching == .brief && again.defaultDiceMode == .auto)
        #expect(again.gettingStartedChecks == ["dice", "minis"])
        #expect(again.completedMissions == ["ridge-line", "broken-ground"])
        #expect(again.rulesGame == .classic && again.lastRootTab == AppTab.play.rawValue)
        #expect(again.hasCompletedOnboarding && again.learningTrack == .classic)
        #expect(again.mapSwaps["ridge-line"] == ["Desert #1", "Desert #2"])
        #expect(again.collection?.boxes == ["alpha-strike-box": 1])
        #expect(again.playDraft?.turnLimit == 7)
        #expect(again.playLastSetup?.budget == .pointValue(300))
    }

    @Test("Clearing an optional setting removes it from storage")
    func clearing() {
        let defaults = makeDefaults()
        let prefs = AppPreferences(defaults: defaults)
        prefs.rulesGame = .classic
        prefs.lastRootTab = "play"
        prefs.playDraft = PlaySetup.pickup()
        prefs.rulesGame = nil
        prefs.lastRootTab = nil
        prefs.playDraft = nil
        let again = AppPreferences(defaults: defaults)
        #expect(again.rulesGame == nil && again.lastRootTab == nil && again.playDraft == nil)
    }

    @Test("Reset removes every owned key and puts the defaults back")
    func reset() {
        let defaults = makeDefaults()
        let prefs = AppPreferences(defaults: defaults)
        prefs.theme = .light
        prefs.completeOnboarding(track: .alphaStrike)
        prefs.markMissionCompleted(.ridgeLine)
        prefs.playLastSetup = PlaySetup.pickup()
        prefs.reset()
        #expect(prefs.theme == .system && !prefs.hasCompletedOnboarding && prefs.completedMissions.isEmpty)
        #expect(prefs.playLastSetup == nil)
        let again = AppPreferences(defaults: defaults)
        #expect(again.theme == .system && !again.hasCompletedOnboarding && again.learningTrack == nil)
    }

    @Test("Finishing onboarding keeps the earlier game when none is chosen")
    func completeOnboarding() {
        let prefs = AppPreferences(defaults: makeDefaults())
        prefs.completeOnboarding(track: .classic)
        prefs.completeOnboarding(track: nil)
        #expect(prefs.hasCompletedOnboarding && prefs.learningTrack == .classic)
    }

    @Test("The Rules tab follows the last game picked there, then the onboarding game")
    func rulesGameToShow() {
        let prefs = AppPreferences(defaults: makeDefaults())
        prefs.learningTrack = .classic
        #expect(prefs.rulesGameToShow == .classic)
        prefs.rulesGame = .alphaStrike
        #expect(prefs.rulesGameToShow == .alphaStrike)
    }

    @Test("Marking a mission done is idempotent; ticking a getting-started item toggles it")
    func missionsAndChecks() {
        let prefs = AppPreferences(defaults: makeDefaults())
        prefs.markMissionCompleted(.runningHot)
        prefs.markMissionCompleted(.runningHot)
        #expect(prefs.completedMissions == ["running-hot"])
        prefs.toggleGettingStarted("dice")
        #expect(prefs.gettingStartedChecks == ["dice"])
        prefs.toggleGettingStarted("dice")
        #expect(prefs.gettingStartedChecks.isEmpty)
    }

    @Test("Recording a collection ticks 'minis', and an empty one doesn't")
    func recordCollection() {
        let prefs = AppPreferences(defaults: makeDefaults())
        prefs.recordCollection(OwnedCollection())
        #expect(prefs.collection?.isEmpty == true && prefs.gettingStartedChecks.isEmpty)
        prefs.recordCollection(OwnedCollection(singles: ["Locust": 1]))
        #expect(prefs.gettingStartedChecks == ["minis"])
    }

    @Test("Map swaps are kept per mission and the suggested maps come back on request")
    func mapSwaps() throws {
        let defaults = makeDefaults()
        let prefs = AppPreferences(defaults: defaults)
        let layout = try #require(try BundleContentCatalogRepository(bundle: .main).scenario(id: .ridgeLine).layout)
        let first = try #require(layout.sheetNames.first)
        prefs.swapMap(mission: "ridge-line", index: 0, to: "My Own Map", layout: layout)
        let swapped = try #require(prefs.mapSwaps["ridge-line"])
        #expect(swapped.first == "My Own Map" && swapped.count == layout.sheets.count)
        #expect(swapped.first != first)
        #expect(AppPreferences(defaults: defaults).mapSwaps["ridge-line"] == swapped)
        prefs.useSuggestedMaps(mission: "ridge-line")
        #expect(prefs.mapSwaps["ridge-line"] == nil)
    }

    @Test("Theme and coaching copy")
    func enums() {
        #expect(AppColorSchemePreference.allCases.map(\.title) == ["System", "Light", "Dark"])
        #expect(AppColorSchemePreference.system.colorScheme == nil)
        #expect(AppColorSchemePreference.light.colorScheme == .light && AppColorSchemePreference.dark.colorScheme == .dark)
        #expect(CoachingLevel.allCases.map(\.title) == ["Automatic", "Full", "Brief", "Off"])
        #expect(CoachingLevel.automatic.resolved(for: nil) == .full)
        #expect(CoachingLevel.automatic.resolved(for: .ridgeLine) == .full)
        #expect(CoachingLevel.automatic.resolved(for: .runningHot) == .brief)
        for level in [CoachingLevel.full, .brief, .off] {
            #expect(level.resolved(for: .runningHot) == level)
        }
    }
}
