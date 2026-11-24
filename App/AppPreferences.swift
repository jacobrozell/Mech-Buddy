import Foundation
import MechBuddyData
import Observation
import SwiftUI
import MechBuddyDomain
import UIKit

enum AppColorSchemePreference: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Observable
@MainActor
final class AppPreferences {
    static let hapticsKey = "settings.hapticsEnabled"
    static let themeKey = "settings.theme"
    static let keepScreenAwakeKey = "settings.keepScreenAwake"
    static let defaultDiceModeKey = "settings.defaultDiceMode"
    /// Ids from `as-getting-started.json` the player ticked on the onboarding "What do you have?" screen.
    static let gettingStartedChecksKey = "settings.gettingStartedChecks"
    static let completedMissionsKey = "missions.completed"

    private let defaults: UserDefaults

    private var isReloading = false

    private static let ownedKeys = [
        hapticsKey, themeKey, keepScreenAwakeKey, defaultDiceModeKey, gettingStartedChecksKey,
        completedMissionsKey
    ] + OnboardingStore.ownedKeys

    var hapticsEnabled: Bool {
        didSet { persist(hapticsEnabled, forKey: Self.hapticsKey) }
    }

    var theme: AppColorSchemePreference {
        didSet { persist(theme.rawValue, forKey: Self.themeKey) }
    }

    var keepScreenAwake: Bool {
        didSet { persist(keepScreenAwake, forKey: Self.keepScreenAwakeKey) }
    }

    var defaultDiceMode: DiceMode {
        didSet { persist(defaultDiceMode.rawValue, forKey: Self.defaultDiceModeKey) }
    }

    var gettingStartedChecks: Set<String> {
        didSet { persist(Array(gettingStartedChecks).sorted(), forKey: Self.gettingStartedChecksKey) }
    }

    /// The game picked in onboarding. `nil` until chosen; Play treats that as Alpha Strike.
    var learningTrack: LearningTrack? {
        didSet { persistOnboarding() }
    }

    /// True once the first-run flow was finished or skipped. Until then RootTabView shows it.
    var hasCompletedOnboarding: Bool {
        didSet { persistOnboarding() }
    }

    /// Scenario ids of missions played to the end (win, loss, or draw). Drives the "next mission" on Play.
    var completedMissions: Set<String> {
        didSet { persist(Array(completedMissions).sorted(), forKey: Self.completedMissionsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isReloading = true
        hapticsEnabled = true
        theme = .system
        keepScreenAwake = true
        defaultDiceMode = .manual
        gettingStartedChecks = []
        learningTrack = nil
        hasCompletedOnboarding = false
        completedMissions = []
        isReloading = false
        reload()
    }

    /// Removes every key this type owns, then reloads the built-in defaults.
    func reset() {
        for key in Self.ownedKeys {
            defaults.removeObject(forKey: key)
        }
        reload()
    }

    private func persist(_ value: Any, forKey key: String) {
        guard !isReloading else { return }
        defaults.set(value, forKey: key)
    }

    private func reload() {
        isReloading = true
        defer { isReloading = false }
        if defaults.object(forKey: Self.hapticsKey) == nil {
            hapticsEnabled = true
        } else {
            hapticsEnabled = defaults.bool(forKey: Self.hapticsKey)
        }
        theme = AppColorSchemePreference(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .system
        if defaults.object(forKey: Self.keepScreenAwakeKey) == nil {
            keepScreenAwake = true
        } else {
            keepScreenAwake = defaults.bool(forKey: Self.keepScreenAwakeKey)
        }
        defaultDiceMode = DiceMode(rawValue: defaults.string(forKey: Self.defaultDiceModeKey) ?? "") ?? .manual
        gettingStartedChecks = Set(defaults.stringArray(forKey: Self.gettingStartedChecksKey) ?? [])
        let onboarding = OnboardingStore.load(from: defaults)
        learningTrack = onboarding.track
        hasCompletedOnboarding = onboarding.isComplete
        completedMissions = Set(defaults.stringArray(forKey: Self.completedMissionsKey) ?? [])
    }

    private func persistOnboarding() {
        guard !isReloading else { return }
        OnboardingStore.save(
            OnboardingRecord(track: learningTrack, isComplete: hasCompletedOnboarding),
            to: defaults
        )
    }

    /// Finish (or skip) the flow. A `nil` track keeps whatever was chosen before.
    func completeOnboarding(track: LearningTrack?) {
        if let track {
            learningTrack = track
        }
        hasCompletedOnboarding = true
    }

    func markMissionCompleted(_ id: ScenarioId) {
        guard !completedMissions.contains(id.rawValue) else { return }
        completedMissions.insert(id.rawValue)
    }

    func toggleGettingStarted(_ id: String) {
        var next = gettingStartedChecks
        if next.contains(id) {
            next.remove(id)
        } else {
            next.insert(id)
        }
        gettingStartedChecks = next
    }

    func applyKeepScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
    }
}
