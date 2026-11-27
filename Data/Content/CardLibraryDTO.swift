import Foundation
import MechBuddyDomain

/// `as-card-library.json`: every Alpha Strike card face from the boxes the owner has (PlayModeSpec §10).
public struct CardLibraryDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var sourceNote: String?
    public var cards: [CardFaceDTO]

    public init(schemaVersion: Int = 1, contentVersion: String, sourceNote: String? = nil, cards: [CardFaceDTO]) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.sourceNote = sourceNote
        self.cards = cards
    }
}

public enum CardTechBase: String, Codable, Sendable, Equatable {
    case innerSphere
    case clan
}

public struct CardCheck: Codable, Sendable, Equatable {
    public var on: String
    public var source: String
}

/// One face of a printed card. Stats are nil until the face is checked.
public struct CardFaceDTO: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var chassis: String
    /// Groups the faces of one physical card (the Awesome and BattleMaster share one).
    public var printedCard: String
    public var boxes: [String]
    public var techBase: CardTechBase
    public var role: String?
    public var mulId: Int?
    public var mulURL: String?
    public var sz: Int
    /// Printed at Skill 4.
    public var pv: Int?
    public var mv: String?
    public var tmm: Int?
    public var s: Int?
    public var m: Int?
    public var l: Int?
    /// Bands printed "0*" (the matching s/m/l decodes to 0). JSON writes them as the string "0*".
    public var minimalDamage: MinimalDamageBands = .none
    public var ov: Int?
    public var armor: Int?
    public var structure: Int?
    public var abilities: String?
    /// Nil until the numbers are read from an official source.
    public var checked: CardCheck?
    public var note: String?

    public var isChecked: Bool { checked != nil }
    /// Clan faces default to Skill 3 in Play (§ 5.3); Inner Sphere to 4.
    public var defaultSkill: Int { techBase == .clan ? 3 : 4 }

    private enum CodingKeys: String, CodingKey {
        case id, name, chassis, printedCard, boxes, techBase, role, mulId, mulURL, sz
        case pv, mv, tmm, s, m, l, ov, armor, structure, abilities, checked, note
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        chassis = try c.decode(String.self, forKey: .chassis)
        printedCard = try c.decode(String.self, forKey: .printedCard)
        boxes = try c.decode([String].self, forKey: .boxes)
        techBase = try c.decode(CardTechBase.self, forKey: .techBase)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        mulId = try c.decodeIfPresent(Int.self, forKey: .mulId)
        mulURL = try c.decodeIfPresent(String.self, forKey: .mulURL)
        sz = try c.decode(Int.self, forKey: .sz)
        pv = try c.decodeIfPresent(Int.self, forKey: .pv)
        mv = try c.decodeIfPresent(String.self, forKey: .mv)
        tmm = try c.decodeIfPresent(Int.self, forKey: .tmm)
        let ps = try c.contains(.s) && !c.decodeNil(forKey: .s) ? PrintedDamage.decode(c, .s) : nil
        let pm = try c.contains(.m) && !c.decodeNil(forKey: .m) ? PrintedDamage.decode(c, .m) : nil
        let pl = try c.contains(.l) && !c.decodeNil(forKey: .l) ? PrintedDamage.decode(c, .l) : nil
        s = ps?.value
        m = pm?.value
        l = pl?.value
        minimalDamage = MinimalDamageBands(short: ps?.minimal ?? false, medium: pm?.minimal ?? false, long: pl?.minimal ?? false)
        ov = try c.decodeIfPresent(Int.self, forKey: .ov)
        armor = try c.decodeIfPresent(Int.self, forKey: .armor)
        structure = try c.decodeIfPresent(Int.self, forKey: .structure)
        abilities = try c.decodeIfPresent(String.self, forKey: .abilities)
        checked = try c.decodeIfPresent(CardCheck.self, forKey: .checked)
        note = try c.decodeIfPresent(String.self, forKey: .note)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(chassis, forKey: .chassis)
        try c.encode(printedCard, forKey: .printedCard)
        try c.encode(boxes, forKey: .boxes)
        try c.encode(techBase, forKey: .techBase)
        try c.encodeIfPresent(role, forKey: .role)
        try c.encodeIfPresent(mulId, forKey: .mulId)
        try c.encodeIfPresent(mulURL, forKey: .mulURL)
        try c.encode(sz, forKey: .sz)
        try c.encodeIfPresent(pv, forKey: .pv)
        try c.encodeIfPresent(mv, forKey: .mv)
        try c.encodeIfPresent(tmm, forKey: .tmm)
        if let s { try PrintedDamage.encode(s, minimal: minimalDamage.short, &c, .s) }
        if let m { try PrintedDamage.encode(m, minimal: minimalDamage.medium, &c, .m) }
        if let l { try PrintedDamage.encode(l, minimal: minimalDamage.long, &c, .l) }
        try c.encodeIfPresent(ov, forKey: .ov)
        try c.encodeIfPresent(armor, forKey: .armor)
        try c.encodeIfPresent(structure, forKey: .structure)
        try c.encodeIfPresent(abilities, forKey: .abilities)
        try c.encodeIfPresent(checked, forKey: .checked)
        try c.encodeIfPresent(note, forKey: .note)
    }

    /// The face as a mission-style unit, or nil when it isn't checked. `pv` stays the printed Skill 4 value.
    public func scenarioUnit(skill: Int? = nil) -> ScenarioUnitDTO? {
        guard isChecked, let pv, let mv, let tmm, let s, let m, let l, let ov, let armor, let structure else { return nil }
        return ScenarioUnitDTO(
            name: name, pv: pv, mv: mv, tmm: tmm, sz: sz, s: s, m: m, l: l,
            ov: ov, armor: armor, structure: structure, skill: skill ?? defaultSkill,
            abilities: abilities ?? "", minimalDamage: minimalDamage
        )
    }
}

/// Lookups over the card library for the rest of the app.
public struct CardLibrary: Sendable {
    public let faces: [CardFaceDTO]
    private let byId: [String: CardFaceDTO]

    /// `userCards` are the player's hand-entered cards (PM9). They join `faces` and the lookups, but belong to no box.
    public init(_ dto: CardLibraryDTO, userCards: [CardFaceDTO] = []) {
        let all = dto.cards + userCards
        faces = all
        byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Hand-entered cards, in the order given.
    public var userFaces: [CardFaceDTO] { faces.filter(\.isUserCard) }

    public func face(id: String) -> CardFaceDTO? { byId[id] }

    /// Matches a unit's printed name ("Locust LCT-7V", "Nova T"), ignoring case.
    public func face(named name: String) -> CardFaceDTO? {
        faces.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    public func faces(chassis: String) -> [CardFaceDTO] {
        faces.filter { $0.chassis.caseInsensitiveCompare(chassis) == .orderedSame }
    }

    public func faces(box: String) -> [CardFaceDTO] {
        faces.filter { $0.boxes.contains(box) }
    }

    public func faces(printedCard: String) -> [CardFaceDTO] {
        faces.filter { $0.printedCard == printedCard }
    }

    /// Faces Play can use as-is (§ 10 checking rule).
    public var checkedFaces: [CardFaceDTO] { faces.filter(\.isChecked) }
}
