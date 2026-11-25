import Foundation

/// Debug-only switches for UI tests. Spec: TestPlanSpec § Launch arguments.
enum LaunchArguments {
    static var all: [String] { ProcessInfo.processInfo.arguments }
    static var resetState: Bool { contains("-reset_state") }
    static var skipOnboarding: Bool { contains("-skip_onboarding") }
    static var inMemoryStore: Bool { contains("-ui_testing") }
    /// Opens on the Rules tab, for screenshots and UI tests of the game switch.
    static var openRules: Bool { contains("-open_rules") }

    private static func contains(_ flag: String) -> Bool {
        #if DEBUG
        return all.contains(flag)
        #else
        return false
        #endif
    }
}
