import Foundation

/// Debug-only switches for UI tests. Spec: TestPlanSpec § Launch arguments.
enum LaunchArguments {
    static var all: [String] { ProcessInfo.processInfo.arguments }
    static var resetState: Bool { contains("-reset_state") }
    static var skipOnboarding: Bool { contains("-skip_onboarding") }
    static var inMemoryStore: Bool { contains("-ui_testing") }
    /// Opens on the Rules tab, for screenshots and UI tests of the game switch.
    static var openRules: Bool { contains("-open_rules") }

    /// Starts a new mission with some ’Mechs already damaged (see `MatchStore.debugSeedDamage`).
    static var debugDamage: Bool { contains("-debug_damage") }
    /// `-open_mission full-lances` starts that mission on launch, for on-screen checks of later missions.
    static var openMission: String? {
        #if DEBUG
        guard let index = all.firstIndex(of: "-open_mission"), all.indices.contains(index + 1) else { return nil }
        return all[index + 1]
        #else
        return nil
        #endif
    }

    private static func contains(_ flag: String) -> Bool {
        #if DEBUG
        return all.contains(flag)
        #else
        return false
        #endif
    }
}
