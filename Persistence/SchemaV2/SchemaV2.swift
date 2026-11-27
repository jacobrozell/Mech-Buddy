import Foundation
import SwiftData

/// SchemaV2 (PM9): adds saved forces and hand-entered cards. `SDMatchSession` is unchanged, so
/// V1 → V2 is a lightweight stage (new tables only). PlayModeSpec § 12.
public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [SDMatchSession.self, SDSavedForce.self, SDUserCard.self]
    }
}

/// A named force saved from a Play side. `payload` is JSON (`SavedForcePayload`).
@Model
public final class SDSavedForce {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var updatedAt: Date
    public var payload: Data

    public init(id: UUID, name: String, updatedAt: Date, payload: Data) {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
        self.payload = payload
    }
}

/// A card typed in by hand. `payload` is the card face as JSON (`CardFaceDTO`).
@Model
public final class SDUserCard {
    @Attribute(.unique) public var id: String
    public var name: String
    public var updatedAt: Date
    public var payload: Data

    public init(id: String, name: String, updatedAt: Date, payload: Data) {
        self.id = id
        self.name = name
        self.updatedAt = updatedAt
        self.payload = payload
    }
}
