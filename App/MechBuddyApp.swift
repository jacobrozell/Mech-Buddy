import SwiftUI
import SwiftData

@main
struct MechBuddyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        let preferences = dependencies.preferences
        WindowGroup {
            RootTabView()
                .environment(dependencies)
                .environment(preferences)
                .environment(\.hapticsEnabled, preferences.hapticsEnabled)
                .tint(TMColor.signal)
                .preferredColorScheme(preferences.theme.colorScheme)
                .modelContainer(dependencies.modelContainer)
                .onAppear { preferences.applyKeepScreenAwake() }
                .onChange(of: preferences.keepScreenAwake) { _, _ in
                    preferences.applyKeepScreenAwake()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        preferences.applyKeepScreenAwake()
                    }
                }
        }
    }
}
