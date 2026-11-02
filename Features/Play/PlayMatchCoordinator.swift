import SwiftUI
import TableMechData
import TableMechDomain

extension EnvironmentValues {
    @Entry var playZoomNamespace: Namespace.ID?
}

@Observable
@MainActor
final class PlayMatchCoordinator {
    var matchStore: MatchStore?
    var showReplaceConfirm = false
    var lastErrorTitle = "Couldn’t open the game"
    var lastError: String?
    var unreadableNotice: String?
    var resumeSession: MatchSession?
    var zoomSource = "mission"
    var prefersZoom = true

    func refresh(using dependencies: AppDependencies) {
        do {
            resumeSession = try MatchStore.loadActive(from: dependencies.matchSessions)
        } catch {
            resumeSession = nil
            dependencies.logger.error("\(error)", category: "persistence")
        }
        let unreadable = dependencies.matchSessions.unreadableSessionIDs
        if unreadable.isEmpty {
            unreadableNotice = nil
        } else if unreadableNotice == nil {
            unreadableNotice = "A saved game couldn't be opened, so it was set aside. You can start a new game."
            for id in unreadable {
                dependencies.logger.error("unreadable saved game \(id.uuidString)", category: "persistence")
            }
        }
    }

    func requestNew(
        using dependencies: AppDependencies,
        source: String = "mission",
        prefersZoom: Bool = true
    ) {
        zoomSource = source
        self.prefersZoom = prefersZoom
        refresh(using: dependencies)
        if resumeSession != nil {
            showReplaceConfirm = true
        } else {
            startNew(using: dependencies, replaceActive: false)
        }
    }

    func confirmReplace(using dependencies: AppDependencies) {
        startNew(using: dependencies, replaceActive: true)
    }

    func resume(using dependencies: AppDependencies) {
        zoomSource = "resume"
        prefersZoom = true
        let store = MatchStore(repository: dependencies.matchSessions)
        do {
            guard try store.resumeActive() else {
                resumeSession = nil
                return
            }
            dependencies.preferences.hasSeenIntro = true
            lastError = nil
            matchStore = store
        } catch {
            lastErrorTitle = "Couldn’t open the game"
            lastError = "Could not resume: \(error.localizedDescription)"
        }
    }

    private func startNew(using dependencies: AppDependencies, replaceActive: Bool) {
        let store = MatchStore(repository: dependencies.matchSessions)
        store.startRidgeLine(from: dependencies.content, replaceActive: replaceActive)
        guard store.session != nil else {
            lastErrorTitle = store.lastErrorTitle
            lastError = store.lastError ?? "Could not start Ridge Line"
            return
        }
        if dependencies.preferences.defaultDiceMode != .manual {
            store.setDiceMode(dependencies.preferences.defaultDiceMode)
        }
        dependencies.preferences.hasSeenIntro = true
        lastError = nil
        matchStore = store
    }
}

extension View {
    func playZoomSource(_ id: String) -> some View {
        modifier(PlayZoomSource(id: id))
    }
}

private struct PlayZoomSource: ViewModifier {
    var id: String
    @Environment(\.playZoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}
