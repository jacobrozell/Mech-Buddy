import SwiftUI
import MechBuddyData
import MechBuddyDomain

enum AppTab: Hashable {
    case play
    case force
    case rules
    case settings
}

struct RootTabView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: AppTab = LaunchArguments.openRules ? .rules : .play
    @State private var matches = PlayMatchCoordinator()
    @State private var replaceAfterConfirm = false
    /// The onboarding flow, when open. First launch opens it; Settings and Play can reopen it.
    @State private var onboarding: OnboardingEntry?
    @Namespace private var playZoom

    var body: some View {
        // Onboarding gets its own container: two fullScreenCovers on one view, and presenting
        // from onAppear before the first frame, both kept it from opening on first launch.
        ZStack {
            tabs
        }
        .task {
            await Task.yield()
            showOnboardingIfNeeded()
            if let mission = LaunchArguments.openMission {
                matches.requestNew(ScenarioId(rawValue: mission), title: mission, using: dependencies, prefersZoom: false)
            }
        }
        .fullScreenCover(item: $onboarding) { entry in
            OnboardingFlowView(entry: entry, onFinish: { tab = .play })
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Play", systemImage: "flag.checkered", value: AppTab.play) {
                NavigationStack {
                    PlayHomeView()
                }
            }
            Tab("Force", systemImage: "shield.lefthalf.filled", value: AppTab.force) {
                NavigationStack {
                    ForceListView()
                }
            }
            Tab("Rules", systemImage: "book", value: AppTab.rules) {
                RulesHomeView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsHomeView()
                }
            }
        }
        .environment(matches)
        .environment(\.playZoomNamespace, playZoom)
        .environment(\.openOnboarding, OpenOnboardingAction { entry in
            onboarding = entry
        })
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .task(id: dependencies.sessionRevision) {
            matches.refresh(using: dependencies)
        }
        .fullScreenCover(item: Bindable(matches).matchStore, onDismiss: {
            matches.refresh(using: dependencies)
            dependencies.preferences.applyKeepScreenAwake()
        }) { store in
            NavigationStack {
                BattleFlowView(store: store)
            }
            .modifier(CoverZoom(
                enabled: matches.prefersZoom && !reduceMotion,
                sourceID: matches.zoomSource,
                namespace: playZoom
            ))
        }
        .confirmationDialog(
            "Replace the game in progress?",
            isPresented: Bindable(matches).showReplaceConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard and start over", role: .destructive) {
                replaceAfterConfirm = true
            }
            Button("Keep current game", role: .cancel) {}
        } message: {
            Text("You already have a match saved. Starting \(matches.pendingTitle) will throw that progress away.")
        }
        .onChange(of: matches.showReplaceConfirm) { _, showing in
            guard !showing, replaceAfterConfirm else { return }
            replaceAfterConfirm = false
            matches.confirmReplace(using: dependencies)
        }
        .alert(
            matches.lastErrorTitle,
            isPresented: Binding(
                get: { matches.lastError != nil },
                set: { if !$0 { matches.lastError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { matches.lastError = nil }
        } message: {
            Text(matches.lastError ?? "")
        }
    }

    /// First launch: cover the tabs with onboarding straight away, without a slide-up.
    private func showOnboardingIfNeeded() {
        guard !dependencies.preferences.hasCompletedOnboarding, onboarding == nil else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            onboarding = .firstRun
        }
    }
}

private struct CoverZoom: ViewModifier {
    var enabled: Bool
    var sourceID: String
    var namespace: Namespace.ID

    func body(content: Content) -> some View {
        if enabled {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}
