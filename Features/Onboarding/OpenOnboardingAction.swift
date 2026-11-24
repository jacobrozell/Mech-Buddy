import SwiftUI
import MechBuddyData

/// Reopens the onboarding flow from anywhere under `RootTabView` (Settings, the Classic card on Play).
struct OpenOnboardingAction: Sendable {
    private let handler: @MainActor @Sendable (OnboardingEntry) -> Void

    init(_ handler: @escaping @MainActor @Sendable (OnboardingEntry) -> Void) {
        self.handler = handler
    }

    @MainActor
    func callAsFunction(_ entry: OnboardingEntry = .changeTrack) {
        handler(entry)
    }
}

extension EnvironmentValues {
    @Entry var openOnboarding = OpenOnboardingAction { _ in }
}
