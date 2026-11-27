import Foundation
import MechBuddyDomain

// Hand-entered cards (PlayModeSpec § 5.3 "Card entry", § 10 "User cards").

extension CardFaceDTO {
    /// A face built in code (user cards). Stats are all set.
    public init(
        id: String, name: String, chassis: String, printedCard: String, boxes: [String],
        techBase: CardTechBase, sz: Int, pv: Int, mv: String, tmm: Int,
        s: Int, m: Int, l: Int, minimalDamage: MinimalDamageBands = .none,
        ov: Int, armor: Int, structure: Int, abilities: String, checked: CardCheck?
    ) {
        self.id = id
        self.name = name
        self.chassis = chassis
        self.printedCard = printedCard
        self.boxes = boxes
        self.techBase = techBase
        self.role = nil
        self.mulId = nil
        self.mulURL = nil
        self.sz = sz
        self.pv = pv
        self.mv = mv
        self.tmm = tmm
        self.s = s
        self.m = m
        self.l = l
        self.minimalDamage = minimalDamage
        self.ov = ov
        self.armor = armor
        self.structure = structure
        self.abilities = abilities
        self.checked = checked
        self.note = nil
    }

    public static let userCardPrefix = "user-"
    public static let userSource = "user"

    /// A card the player typed in. Shown as "Your numbers" everywhere.
    public var isUserCard: Bool { checked?.source == Self.userSource }
}

/// The card-entry fields, as typed. Text in, checked numbers out.
public struct UserCardDraft: Equatable, Sendable {
    public enum Field: String, Sendable, CaseIterable {
        case name, pv, size, move, tmm, short, medium, long, overheat, armor, structure, specials
    }

    public struct Issue: Equatable, Sendable, Identifiable {
        public var field: Field
        public var message: String
        public var id: String { field.rawValue }
    }

    public var name = ""
    public var pv = ""
    public var size = 1
    public var move = ""
    public var tmm = ""
    public var short = ""
    public var medium = ""
    public var long = ""
    public var overheat = "0"
    public var armor = ""
    public var structure = ""
    public var specials = ""
    public var isClan = false

    public init() {}

    /// Prefilled from a card face (editing, or "Enter numbers from your card").
    public init(face: CardFaceDTO) {
        name = face.name
        size = face.sz
        isClan = face.techBase == .clan
        if let pv = face.pv { self.pv = String(pv) }
        move = face.mv ?? ""
        if let tmm = face.tmm { self.tmm = String(tmm) }
        short = Self.damageText(face.s, face.minimalDamage.short)
        medium = Self.damageText(face.m, face.minimalDamage.medium)
        long = Self.damageText(face.l, face.minimalDamage.long)
        overheat = String(face.ov ?? 0)
        if let armor = face.armor { self.armor = String(armor) }
        if let structure = face.structure { self.structure = String(structure) }
        specials = face.abilities ?? ""
    }

    private static func damageText(_ value: Int?, _ minimal: Bool) -> String {
        guard let value else { return "" }
        return minimal ? "0*" : String(value)
    }

    // Limits are generous: they catch typos, not unusual units.
    public static let maxName = 60
    public static let pvRange = 1...999
    public static let tmmRange = 0...8
    public static let damageRange = 0...30
    public static let overheatRange = 0...4
    public static let armorRange = 0...99
    public static let structureRange = 1...99
    public static let maxSpecials = 300

    /// Everything wrong with the draft, in field order. Empty means it can be saved.
    public func issues() -> [Issue] {
        var found: [Issue] = []
        func add(_ field: Field, _ message: String) { found.append(Issue(field: field, message: message)) }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { add(.name, "Enter the ’Mech’s name.") }
        else if trimmed.count > Self.maxName { add(.name, "Keep the name under \(Self.maxName) characters.") }

        if Self.integer(pv, in: Self.pvRange) == nil { add(.pv, "PV is a whole number from 1 to 999.") }
        if !(1...4).contains(size) { add(.size, "Size is 1 to 4.") }
        if Self.normalizedMove(move) == nil { add(.move, "Move looks like 10\", 10\"j or 10\"/6\"j.") }
        if Self.integer(tmm, in: Self.tmmRange) == nil { add(.tmm, "TMM is a whole number from 0 to 8.") }
        for (field, text, label) in [(Field.short, short, "Short"), (.medium, medium, "Medium"), (.long, long, "Long")]
        where Self.damage(text) == nil {
            add(field, "\(label) damage is 0 to 30, or 0* for minimal damage.")
        }
        if Self.integer(overheat, in: Self.overheatRange) == nil { add(.overheat, "Overheat is 0 to 4.") }
        if Self.integer(armor, in: Self.armorRange) == nil { add(.armor, "Armor is a whole number from 0 to 99.") }
        if Self.integer(structure, in: Self.structureRange) == nil { add(.structure, "Structure is a whole number from 1 to 99.") }
        if specials.count > Self.maxSpecials { add(.specials, "Keep specials under \(Self.maxSpecials) characters.") }
        return found
    }

    public func issue(for field: Field) -> Issue? { issues().first { $0.field == field } }

    /// The checked face for this draft, or nil while `issues()` is not empty. `id` is kept when editing.
    public func makeFace(id: String? = nil, on date: Date = Date()) -> CardFaceDTO? {
        guard issues().isEmpty,
              let pv = Self.integer(pv, in: Self.pvRange),
              let mv = Self.normalizedMove(move),
              let tmm = Self.integer(tmm, in: Self.tmmRange),
              let s = Self.damage(short), let m = Self.damage(medium), let l = Self.damage(long),
              let ov = Self.integer(overheat, in: Self.overheatRange),
              let armor = Self.integer(armor, in: Self.armorRange),
              let structure = Self.integer(structure, in: Self.structureRange)
        else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let faceId = id ?? CardFaceDTO.userCardPrefix + UUID().uuidString.lowercased()
        let stamp = ISO8601DateFormatter().string(from: date)
        return CardFaceDTO(
            id: faceId, name: trimmed, chassis: UnitChassis.name(trimmed), printedCard: faceId,
            boxes: ["user"], techBase: isClan ? .clan : .innerSphere,
            sz: size, pv: pv, mv: mv, tmm: tmm,
            s: s.value, m: m.value, l: l.value,
            minimalDamage: MinimalDamageBands(short: s.minimal, medium: m.minimal, long: l.minimal),
            ov: ov, armor: armor, structure: structure,
            abilities: specials.trimmingCharacters(in: .whitespacesAndNewlines),
            checked: CardCheck(on: stamp, source: CardFaceDTO.userSource)
        )
    }

    // MARK: Parsing

    static func integer(_ text: String, in range: ClosedRange<Int>) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isASCII), trimmed.allSatisfy(\.isNumber),
              let value = Int(trimmed), range.contains(value) else { return nil }
        return value
    }

    /// "0*" is minimal damage (p. 41): value 0, flagged.
    static func damage(_ text: String) -> (value: Int, minimal: Bool)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed == "0*" { return (0, true) }
        return integer(trimmed, in: damageRange).map { ($0, false) }
    }

    /// `10`, `10"`, `10"j`, `10"/6"j` → the card's own form (`10"`, `10"j`, `10"/6"j`). Nil when it isn't a move.
    public static func normalizedMove(_ text: String) -> String? {
        let cleaned = text.lowercased().filter { !" \"″”“'".contains($0) }
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= 2 else { return nil }
        func parse(_ part: String) -> (Int, Bool)? {
            let jump = part.hasSuffix("j")
            let digits = jump ? String(part.dropLast()) : part
            guard let value = integer(digits, in: 0...60) else { return nil }
            return (value, jump)
        }
        guard let first = parse(parts[0]) else { return nil }
        if parts.count == 1 { return first.1 ? "\(first.0)\"j" : "\(first.0)\"" }
        guard let second = parse(parts[1]) else { return nil }
        return "\(first.0)\"/\(second.0)\"j"
    }
}
