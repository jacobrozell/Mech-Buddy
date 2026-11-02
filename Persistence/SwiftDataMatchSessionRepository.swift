import Foundation
import SwiftData
import MechBuddyDomain

public enum MatchPersistenceError: Error, Sendable, Equatable, LocalizedError {
    case unsupportedPayloadSchema(Int)
    case decodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPayloadSchema(let version):
            return "Unsupported saved match version (\(version))"
        case .decodeFailed(let message):
            return message
        }
    }
}

@MainActor
public final class SwiftDataMatchSessionRepository: MatchSessionRepository {
    private let container: ModelContainer
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    public private(set) var unreadableSessionIDs: [UUID] = []

    public init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
    }

    public func loadActive(mode: GameModeId) throws -> MatchSession? {
        let modeRaw = mode.rawValue
        let activeRaw = MatchStatus.active.rawValue
        let descriptor = FetchDescriptor<SDMatchSession>(
            predicate: #Predicate { row in
                row.modeId == modeRaw && row.statusRaw == activeRaw
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        for row in try context.fetch(descriptor) {
            do {
                return try decodeSession(from: row)
            } catch {
                row.statusRaw = "unreadable"
                try context.save()
                if !unreadableSessionIDs.contains(row.id) {
                    unreadableSessionIDs.append(row.id)
                }
            }
        }
        return nil
    }

    public func save(_ session: MatchSession) throws {
        let payload = try encoder.encode(session)
        let id = session.id
        let descriptor = FetchDescriptor<SDMatchSession>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.modeId = session.modeId.rawValue
            existing.scenarioId = session.scenarioId?.rawValue
            existing.statusRaw = session.status.rawValue
            existing.turn = session.turn
            existing.phaseRaw = session.phase.rawValue
            existing.activeSideRaw = session.activeSide.rawValue
            existing.payloadSchemaVersion = session.schemaVersion
            existing.payload = payload
            existing.updatedAt = session.updatedAt
        } else {
            context.insert(
                SDMatchSession(
                    id: session.id,
                    modeId: session.modeId.rawValue,
                    scenarioId: session.scenarioId?.rawValue,
                    statusRaw: session.status.rawValue,
                    turn: session.turn,
                    phaseRaw: session.phase.rawValue,
                    activeSideRaw: session.activeSide.rawValue,
                    payloadSchemaVersion: session.schemaVersion,
                    payload: payload,
                    updatedAt: session.updatedAt
                )
            )
        }
        try context.save()
    }

    public func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<SDMatchSession>(
            predicate: #Predicate { $0.id == id }
        )
        for row in try context.fetch(descriptor) {
            context.delete(row)
        }
        try context.save()
        unreadableSessionIDs.removeAll { $0 == id }
    }

    public func deleteAll() throws {
        let descriptor = FetchDescriptor<SDMatchSession>()
        for row in try context.fetch(descriptor) {
            context.delete(row)
        }
        try context.save()
        unreadableSessionIDs.removeAll()
    }

    private func decodeSession(from row: SDMatchSession) throws -> MatchSession {
        let session: MatchSession
        do {
            session = try decoder.decode(MatchSession.self, from: row.payload)
        } catch {
            throw MatchPersistenceError.decodeFailed(error.localizedDescription)
        }
        let version = max(session.schemaVersion, row.payloadSchemaVersion)
        guard version <= MatchSession.currentSchemaVersion else {
            throw MatchPersistenceError.unsupportedPayloadSchema(version)
        }
        return session
    }
}
