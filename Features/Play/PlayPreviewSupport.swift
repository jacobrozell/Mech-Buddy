import SwiftUI
import MechBuddyData

#if DEBUG
struct PlayPreviewHost<Content: View>: View {
    @State private var dependencies = AppDependencies(matchSessions: InMemoryMatchSessionRepository())
    @State private var matches = PlayMatchCoordinator()
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .environment(dependencies)
            .environment(dependencies.preferences)
            .environment(matches)
            .environment(\.hapticsEnabled, dependencies.preferences.hapticsEnabled)
    }
}
#endif
