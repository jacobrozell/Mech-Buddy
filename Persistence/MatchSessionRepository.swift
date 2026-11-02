import Foundation
import MechBuddyDomain

@MainActor
public protocol MatchSessionRepository: AnyObject {
    var unreadableSessionIDs: [UUID] { get }
    func loadActive(mode: GameModeId) throws -> MatchSession?
    func save(_ session: MatchSession) throws
    func delete(id: UUID) throws
    func deleteAll() throws
}

@MainActor
public final class InMemoryMatchSessionRepository: MatchSessionRepository {
    private var sessions: [UUID: MatchSession] = [:]

    public init() {}

    public var unreadableSessionIDs: [UUID] { [] }

    public func loadActive(mode: GameModeId) throws -> MatchSession? {
        sessions.values
            .filter { $0.modeId == mode && $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    public func save(_ session: MatchSession) throws {
        sessions[session.id] = session
    }

    public func delete(id: UUID) throws {
        sessions[id] = nil
    }

    public func deleteAll() throws {
        sessions.removeAll()
    }
}
