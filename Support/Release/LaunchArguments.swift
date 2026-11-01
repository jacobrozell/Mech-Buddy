import Foundation

/// Debug-only switches for UI tests. Spec: TestPlanSpec § Launch arguments.
enum LaunchArguments {
    static var all: [String] { ProcessInfo.processInfo.arguments }
    static var resetState: Bool { contains("-reset_state") }
    static var skipOnboarding: Bool { contains("-skip_onboarding") }
    static var inMemoryStore: Bool { contains("-ui_testing") }

    private static func contains(_ flag: String) -> Bool {
        #if DEBUG
        return all.contains(flag)
        #else
        return false
        #endif
    }
}
