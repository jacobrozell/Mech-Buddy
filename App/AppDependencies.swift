import Foundation
import Observation
import SwiftData
import TableMechData
import TableMechDomain

@Observable
@MainActor
public final class AppDependencies {
    public let content: any ContentCatalogRepository
    public let matchSessions: any MatchSessionRepository
    public let releaseSurface: any ReleaseSurfaceProviding
    public let logger: any AppLogging
    public let modelContainer: ModelContainer
    /// True when SwiftData failed and matches exist only in memory. Hidden for `-ui_testing`.
    private(set) var isUsingVolatileStore = false
    let preferences: AppPreferences
    /// Bumps when a match is saved or deleted. Play and Force reload from this.
    var sessionRevision = 0

    public init(
        content: any ContentCatalogRepository = BundleContentCatalogRepository(),
        matchSessions: (any MatchSessionRepository)? = nil,
        releaseSurface: any ReleaseSurfaceProviding = ReleaseSurface(),
        logger: any AppLogging = ConsoleAppLogger(),
        modelContainer: ModelContainer? = nil
    ) {
        let container: ModelContainer
        let volatileStore: Bool
        if let modelContainer {
            container = modelContainer
            volatileStore = false
        } else if LaunchArguments.inMemoryStore {
            do {
                container = try PersistenceController.makeContainer(inMemory: true)
            } catch {
                preconditionFailure("SwiftData unavailable even in-memory: \(error)")
            }
            volatileStore = false
        } else {
            do {
                container = try PersistenceController.makeContainer()
                volatileStore = false
            } catch {
                logger.error("SwiftData store failed; using in-memory. \(error)", category: "persistence")
                do {
                    container = try PersistenceController.makeContainer(inMemory: true)
                } catch {
                    preconditionFailure("SwiftData unavailable even in-memory: \(error)")
                }
                volatileStore = true
            }
        }
        let stored = matchSessions ?? SwiftDataMatchSessionRepository(container: container)
        let revising = SessionRevisionRepository(base: stored)
        let preferences = AppPreferences()
        if LaunchArguments.resetState {
            try? stored.deleteAll()
            preferences.reset()
        }
        if LaunchArguments.skipOnboarding {
            preferences.hasSeenIntro = true
        }
        self.modelContainer = container
        self.content = content
        self.matchSessions = revising
        self.releaseSurface = releaseSurface
        self.logger = logger
        self.isUsingVolatileStore = volatileStore
        self.preferences = preferences
        revising.onMutation = { [weak self] in
            guard let self else { return }
            self.sessionRevision += 1
        }
    }
}

/// Forwards match saves and deletes, then bumps `AppDependencies.sessionRevision`.
@MainActor
private final class SessionRevisionRepository: MatchSessionRepository {
    private let base: any MatchSessionRepository
    var onMutation: (@MainActor () -> Void)?

    init(base: any MatchSessionRepository) {
        self.base = base
    }

    var unreadableSessionIDs: [UUID] { base.unreadableSessionIDs }

    func loadActive(mode: GameModeId) throws -> MatchSession? {
        try base.loadActive(mode: mode)
    }

    func save(_ session: MatchSession) throws {
        try base.save(session)
        onMutation?()
    }

    func delete(id: UUID) throws {
        try base.delete(id: id)
        onMutation?()
    }

    func deleteAll() throws {
        try base.deleteAll()
        onMutation?()
    }
}
