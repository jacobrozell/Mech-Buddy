import Foundation
import SwiftData

public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [SDMatchSession.self]
    }
}

@Model
public final class SDMatchSession {
    @Attribute(.unique) public var id: UUID
    public var modeId: String
    public var scenarioId: String?
    public var statusRaw: String
    public var turn: Int
    public var phaseRaw: String
    public var activeSideRaw: String
    /// Mirrors `MatchSession.schemaVersion` for cheap rejection before full decode migration.
    public var payloadSchemaVersion: Int
    public var payload: Data
    public var updatedAt: Date

    public init(
        id: UUID,
        modeId: String,
        scenarioId: String?,
        statusRaw: String,
        turn: Int,
        phaseRaw: String,
        activeSideRaw: String,
        payloadSchemaVersion: Int = MatchSessionPayloadSchema.current,
        payload: Data,
        updatedAt: Date
    ) {
        self.id = id
        self.modeId = modeId
        self.scenarioId = scenarioId
        self.statusRaw = statusRaw
        self.turn = turn
        self.phaseRaw = phaseRaw
        self.activeSideRaw = activeSideRaw
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

/// Kept in Persistence so SchemaV1 does not import Domain at the model-type level for constants.
public enum MatchSessionPayloadSchema {
    public static let current = 1
}

public enum MechBuddyMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum PersistenceController {
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: MechBuddyMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
