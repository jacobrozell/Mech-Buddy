import Foundation
import Observation
import SwiftUI
import TableMechDomain
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
    static let gettingStartedChecksKey = "settings.gettingStartedChecks"
    static let hasSeenIntroKey = "settings.hasSeenIntro"

    private let defaults: UserDefaults

    private var isReloading = false

    private static let ownedKeys = [
        hapticsKey, themeKey, keepScreenAwakeKey, defaultDiceModeKey, gettingStartedChecksKey, hasSeenIntroKey
    ]

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

    var hasSeenIntro: Bool {
        didSet { persist(hasSeenIntro, forKey: Self.hasSeenIntroKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isReloading = true
        hapticsEnabled = true
        theme = .system
        keepScreenAwake = true
        defaultDiceMode = .manual
        gettingStartedChecks = []
        hasSeenIntro = false
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
        hasSeenIntro = defaults.bool(forKey: Self.hasSeenIntroKey)
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

    func clearGettingStartedChecks() {
        gettingStartedChecks = []
    }

    func applyKeepScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
    }
}
