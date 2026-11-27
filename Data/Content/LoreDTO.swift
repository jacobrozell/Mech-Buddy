import Foundation

/// `Content/Lore/battletech-lore.json`: general BattleTech history, read-only (Lore section).
/// Only the parts the app shows are decoded; the rest of the file is ignored.
public struct LoreDocumentDTO: Decodable, Sendable {
    public var schemaVersion: String
    public var summary: LoreSummaryDTO
    public var data: LoreDataDTO

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case summary, data
    }

    /// Events oldest first. Events with no start year go last, in file order.
    public var timeline: [LoreEventDTO] {
        let dated = data.events.filter { $0.startYear != nil }.sorted { ($0.startYear ?? 0) < ($1.startYear ?? 0) }
        return dated + data.events.filter { $0.startYear == nil }
    }

    public var eras: [LoreEraDTO] { data.officialEras.eras }
}

public struct LoreSummaryDTO: Decodable, Sendable {
    public var onParagraph: String

    enum CodingKeys: String, CodingKey { case onParagraph = "one_paragraph" }
}

public struct LoreDataDTO: Decodable, Sendable {
    public var events: [LoreEventDTO]
    public var officialEras: LoreOfficialErasDTO

    enum CodingKeys: String, CodingKey {
        case events
        case officialEras = "official_eras"
    }
}

public struct LoreOfficialErasDTO: Decodable, Sendable {
    public var eras: [LoreEraDTO]
}

public struct LoreEraDTO: Decodable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var startYear: Int?
    public var endYear: Int?
    public var isOngoing: Bool
    public var subEras: [LoreSubEraDTO]

    enum CodingKeys: String, CodingKey {
        case id, name
        case startYear = "start_year"
        case endYear = "end_year"
        case isOngoing = "is_ongoing"
        case subEras = "sub_eras"
    }

    /// "2781 – 3049", "Before 2005" or "3151 – Present".
    public var yearLabel: String {
        switch (startYear, endYear) {
        case let (start?, end?): "\(start) – \(end)"
        case let (start?, nil): isOngoing ? "\(start) – Present" : "From \(start)"
        case let (nil, end?): "Up to \(end)"
        case (nil, nil): ""
        }
    }
}

public struct LoreSubEraDTO: Decodable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var yearLabel: String
    public var summary: String
    public var keyEvents: [String]
    public var keyFactions: [String]
    public var keyTechnologies: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, summary
        case yearLabel = "year_label"
        case keyEvents = "key_events"
        case keyFactions = "key_factions"
        case keyTechnologies = "key_technologies"
    }
}

public struct LoreEventDTO: Decodable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var startYear: Int?
    public var dateLabel: String?
    public var summary: String

    enum CodingKeys: String, CodingKey {
        case id, name, summary
        case startYear = "start_year"
        case dateLabel = "date_label"
    }
}
