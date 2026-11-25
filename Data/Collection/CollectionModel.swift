import Foundation

// Non-view collection logic: which boxes and minis the player owns. Lives in MechBuddyData so the
// unit tests can import it. Box contents come from `as-box-sets.json` (`BoxSetDTO`).
// Spec: specs/features/RosterSpec.md § Your collection

// MARK: - Chassis matching

/// Mission forces name a variant ("Locust LCT-1V"); boxes and singles often don't ("Locust").
/// Minis match by chassis: the name without its variant code.
public enum UnitChassis {
    /// "Locust LCT-1V" → "Locust", "Nova T" → "Nova", "Timber Wolf Prime" → "Timber Wolf".
    /// Drops the last word when it has a digit, or is an OmniMech configuration (one capital letter or "Prime").
    /// "Mad Cat Mk II" stays whole.
    public static func name(_ unit: String) -> String {
        let parts = unit.split(whereSeparator: \.isWhitespace)
        guard parts.count > 1, let last = parts.last else { return parts.joined(separator: " ") }
        let isVariant = last.contains(where: \.isNumber)
            || last == "Prime"
            || (last.count == 1 && last.first?.isUppercase == true)
        return isVariant ? parts.dropLast().joined(separator: " ") : parts.joined(separator: " ")
    }

    /// Case- and spacing-insensitive chassis, for comparing.
    public static func key(_ unit: String) -> String {
        name(unit).lowercased()
    }

    public static func matches(_ lhs: String, _ rhs: String) -> Bool {
        let left = key(lhs)
        return !left.isEmpty && left == key(rhs)
    }
}

// MARK: - Stored record

/// What the player said they own. `nil` in `AppPreferences` means they haven't said yet.
public struct OwnedCollection: Codable, Equatable, Sendable {
    /// Box id → copies owned (1 or more).
    public var boxes: [String: Int]
    /// Box id → unit name (as listed in the box) → copies missing, across all copies of that box.
    public var missing: [String: [String: Int]]
    /// Minis owned outside a box: name as typed → copies.
    public var singles: [String: Int]
    /// Maps owned outside a box, as typed, in the order added. Box maps are assumed owned with the box.
    public var maps: [String]

    public init(
        boxes: [String: Int] = [:],
        missing: [String: [String: Int]] = [:],
        singles: [String: Int] = [:],
        maps: [String] = []
    ) {
        self.boxes = boxes
        self.missing = missing
        self.singles = singles
        self.maps = maps
    }

    private enum CodingKeys: String, CodingKey { case boxes, missing, singles, maps }

    /// Collections saved before maps existed decode with no extra maps.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        boxes = try c.decodeIfPresent([String: Int].self, forKey: .boxes) ?? [:]
        missing = try c.decodeIfPresent([String: [String: Int]].self, forKey: .missing) ?? [:]
        singles = try c.decodeIfPresent([String: Int].self, forKey: .singles) ?? [:]
        maps = try c.decodeIfPresent([String].self, forKey: .maps) ?? []
    }

    /// "None yet": recorded, but nothing owned.
    public static let empty = OwnedCollection()

    /// No boxes or minis. Maps added by hand don't count.
    public var isEmpty: Bool { boxes.isEmpty && singles.isEmpty }

    public func copies(ofBox id: String) -> Int { boxes[id] ?? 0 }

    public func owns(box id: String) -> Bool { copies(ofBox: id) > 0 }

    /// Sets how many of a box the player owns. 0 removes it and its missing marks.
    /// Missing marks stay when the count changes; `have(_:in:)` never goes below 0.
    public mutating func setCopies(_ copies: Int, ofBox id: String) {
        if copies > 0 {
            boxes[id] = copies
        } else {
            boxes[id] = nil
            missing[id] = nil
        }
    }

    /// Owned ↔ not owned (1 copy).
    public mutating func toggleBox(_ id: String) {
        setCopies(owns(box: id) ? 0 : 1, ofBox: id)
    }

    /// Copies of `unit` the player has from `box`: listed copies × boxes owned, minus missing.
    public func have(_ unit: String, in box: BoxSetDTO) -> Int {
        let listed = box.units.filter { $0 == unit }.count * copies(ofBox: box.id)
        return max(0, listed - (missing[box.id]?[unit] ?? 0))
    }

    /// Ticks or unticks every copy of a box unit. Unticking marks them all missing.
    public mutating func setUnit(_ unit: String, in box: BoxSetDTO, owned: Bool) {
        var marks = missing[box.id] ?? [:]
        if owned {
            marks[unit] = nil
        } else {
            let listed = box.units.filter { $0 == unit }.count * copies(ofBox: box.id)
            marks[unit] = listed > 0 ? listed : nil
        }
        missing[box.id] = marks.isEmpty ? nil : marks
    }

    /// Adds one single. Trims spaces; an empty name does nothing. Matches an existing single by chassis,
    /// so "locust" adds to "Locust". Returns the stored name, or `nil` when nothing was added.
    @discardableResult
    public mutating func addSingle(_ typed: String) -> String? {
        let name = typed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty else { return nil }
        let existing = singles.keys.first { $0.lowercased() == name.lowercased() }
        let key = existing ?? name
        singles[key, default: 0] += 1
        return key
    }

    /// Sets the copies of a single. 0 removes it.
    public mutating func setSingle(_ name: String, copies: Int) {
        singles[name] = copies > 0 ? copies : nil
    }

    /// Adds a map by name. Trims spaces; empty or already listed (any case) does nothing.
    /// Returns the stored name, or `nil` when nothing was added.
    @discardableResult
    public mutating func addMap(_ typed: String) -> String? {
        let name = typed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty, !maps.contains(where: { $0.lowercased() == name.lowercased() }) else { return nil }
        maps.append(name)
        return name
    }

    public mutating func removeMap(_ name: String) {
        maps.removeAll { $0 == name }
    }
}

// MARK: - Derived views

/// One unit in a collection group: how many the player has out of how many the source lists.
public struct CollectionUnit: Identifiable, Equatable, Sendable {
    public var name: String
    public var have: Int
    /// Copies listed by the box (× boxes owned). For singles, equal to `have`.
    public var listed: Int

    public var id: String { name }
    public var isMissing: Bool { have == 0 }

    public init(name: String, have: Int, listed: Int) {
        self.name = name
        self.have = have
        self.listed = listed
    }
}

/// The Force tab groups owned minis by box, then "Singles".
public struct CollectionGroup: Identifiable, Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case box(BoxSetDTO)
        case singles
    }

    public var source: Source
    public var units: [CollectionUnit]

    public var id: String {
        switch source {
        case .box(let box): "box.\(box.id)"
        case .singles: "singles"
        }
    }

    public var title: String {
        switch source {
        case .box(let box): box.title
        case .singles: "Singles"
        }
    }

    public init(source: Source, units: [CollectionUnit]) {
        self.source = source
        self.units = units
    }
}

/// A map the player has, from a box or added by hand.
public struct OwnedMap: Identifiable, Equatable, Sendable {
    public var name: String
    /// The box it came with; `nil` when added by hand.
    public var boxTitle: String?

    public var id: String { name.lowercased() }

    public init(name: String, boxTitle: String?) {
        self.name = name
        self.boxTitle = boxTitle
    }
}

/// A mission's forces checked against the collection.
public struct MiniCheck: Equatable, Sendable {
    /// A mini the player owns, suggested for a mission 'Mech they don't have.
    public struct StandIn: Equatable, Sendable {
        /// Chassis of the owned mini, e.g. "Atlas".
        public var use: String
        /// Chassis it plays, e.g. "Awesome".
        public var asUnit: String
        public var count: Int

        public init(use: String, asUnit: String, count: Int = 1) {
            self.use = use
            self.asUnit = asUnit
            self.count = count
        }

        /// "Atlas as Awesome", "Wasp ×2 as Commando".
        public var text: String {
            count > 1 ? "\(use) ×\(count) as \(asUnit)" : "\(use) as \(asUnit)"
        }
    }

    /// Minis the mission puts on the table.
    public var needed: Int
    /// Chassis names short, in mission order. A chassis short twice reads "Locust ×2".
    public var missing: [String]
    /// Owned minis suggested for 'Mechs the player doesn't have, in mission order.
    public var standIns: [StandIn]

    public init(needed: Int, missing: [String], standIns: [StandIn] = []) {
        self.needed = needed
        self.missing = missing
        self.standIns = standIns
    }

    /// Every 'Mech has a mini: the exact one or a suggested stand-in.
    public var hasAll: Bool { missing.isEmpty }

    /// "You have all 4 ’Mechs", "Stand-ins: Atlas as Awesome.", or
    /// "Missing: Catapult. Use any mini or a coin as a stand-in."
    public var summary: String {
        if hasAll && standIns.isEmpty {
            return needed == 1 ? "You have the ’Mech" : "You have all \(needed) ’Mechs"
        }
        var parts: [String] = []
        if !standIns.isEmpty {
            parts.append("Stand-ins: \(CollectionMath.naturalList(standIns.map(\.text))).")
        }
        if !missing.isEmpty {
            parts.append("Missing: \(CollectionMath.naturalList(missing)). Use any mini or a coin as a stand-in.")
        }
        return parts.joined(separator: " ")
    }
}

public enum CollectionMath {
    /// Owned boxes (catalog order) then Singles. Boxes the catalog no longer lists are left out.
    public static func groups(_ collection: OwnedCollection, boxes: [BoxSetDTO]) -> [CollectionGroup] {
        var groups: [CollectionGroup] = boxes.filter { collection.owns(box: $0.id) }.map { box in
            var seen = Set<String>()
            let units = box.units.filter { seen.insert($0).inserted }.map { unit in
                CollectionUnit(
                    name: unit,
                    have: collection.have(unit, in: box),
                    listed: box.units.filter { $0 == unit }.count * collection.copies(ofBox: box.id)
                )
            }
            return CollectionGroup(source: .box(box), units: units)
        }
        let singles = collection.singles
            .filter { $0.value > 0 }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { CollectionUnit(name: $0.key, have: $0.value, listed: $0.value) }
        if !singles.isEmpty {
            groups.append(CollectionGroup(source: .singles, units: singles))
        }
        return groups
    }

    /// Every unit the player has, merged by exact name with counts, in group order.
    public static func ownedUnits(_ collection: OwnedCollection, boxes: [BoxSetDTO]) -> [CollectionUnit] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for group in groups(collection, boxes: boxes) {
            for unit in group.units where unit.have > 0 {
                if counts[unit.name] == nil { order.append(unit.name) }
                counts[unit.name, default: 0] += unit.have
            }
        }
        return order.map { CollectionUnit(name: $0, have: counts[$0] ?? 0, listed: counts[$0] ?? 0) }
    }

    /// Chassis key → minis owned.
    public static func chassisCounts(_ collection: OwnedCollection, boxes: [BoxSetDTO]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for unit in ownedUnits(collection, boxes: boxes) {
            counts[UnitChassis.key(unit.name), default: 0] += unit.have
        }
        return counts
    }

    /// Which of `forces` (unit names, both sides) the player has a mini for, matched by chassis.
    /// Exact minis are matched first. Then each 'Mech still short takes the first owned, unused
    /// mini from `standIns` (mission chassis → closest minis, best first).
    public static func miniCheck(
        forces: [String],
        collection: OwnedCollection,
        boxes: [BoxSetDTO],
        standIns: [String: [String]] = [:]
    ) -> MiniCheck {
        var available = chassisCounts(collection, boxes: boxes)
        var shortUnits: [String] = []
        for unit in forces {
            let key = UnitChassis.key(unit)
            if let count = available[key], count > 0 {
                available[key] = count - 1
            } else {
                shortUnits.append(UnitChassis.name(unit))
            }
        }

        let options: [String: [String]] = Dictionary(
            standIns.map { (UnitChassis.key($0.key), $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        var pairOrder: [String] = []
        var pairs: [String: MiniCheck.StandIn] = [:]
        var shortOrder: [String] = []
        var short: [String: Int] = [:]
        for name in shortUnits {
            let candidate = options[name.lowercased()]?.first { (available[UnitChassis.key($0)] ?? 0) > 0 }
            if let candidate {
                available[UnitChassis.key(candidate)]? -= 1
                let id = "\(candidate)|\(name)"
                if pairs[id] == nil {
                    pairOrder.append(id)
                    pairs[id] = MiniCheck.StandIn(use: candidate, asUnit: name, count: 0)
                }
                pairs[id]?.count += 1
            } else {
                if short[name] == nil { shortOrder.append(name) }
                short[name, default: 0] += 1
            }
        }
        let missing = shortOrder.map { name in
            let count = short[name] ?? 1
            return count > 1 ? "\(name) ×\(count)" : name
        }
        return MiniCheck(
            needed: forces.count,
            missing: missing,
            standIns: pairOrder.compactMap { pairs[$0] }
        )
    }

    /// Maps the player has: each owned box's maps (catalog order), then maps added by hand.
    /// A name already listed by an earlier box is skipped.
    public static func ownedMaps(_ collection: OwnedCollection, boxes: [BoxSetDTO]) -> [OwnedMap] {
        var seen = Set<String>()
        var result: [OwnedMap] = []
        for box in boxes where collection.owns(box: box.id) {
            for name in box.maps ?? [] where seen.insert(name.lowercased()).inserted {
                result.append(OwnedMap(name: name, boxTitle: box.title))
            }
        }
        for name in collection.maps where seen.insert(name.lowercased()).inserted {
            result.append(OwnedMap(name: name, boxTitle: nil))
        }
        return result
    }

    /// "A", "A and B", "A, B, and C".
    public static func naturalList(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + ", and " + (items.last ?? "")
        }
    }
}

public extension BoxSetDTO.Game {
    /// Tile badge.
    var badge: String {
        switch self {
        case .alphaStrike: "Alpha Strike"
        case .classic: "Classic"
        case .both: "Classic + Alpha Strike"
        }
    }
}

// MARK: - Persistence

/// Saves the collection in `UserDefaults` through `AppPreferences`. Absent key = not recorded yet.
public enum CollectionStore {
    public static let collectionKey = "collection.owned"

    /// Every key this store writes. `AppPreferences.reset()` removes them all.
    public static let ownedKeys = [collectionKey]

    public static func load(from defaults: UserDefaults) -> OwnedCollection? {
        guard let data = defaults.data(forKey: collectionKey) else { return nil }
        return try? JSONDecoder().decode(OwnedCollection.self, from: data)
    }

    public static func save(_ collection: OwnedCollection?, to defaults: UserDefaults) {
        guard let collection else {
            defaults.removeObject(forKey: collectionKey)
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        if let data = try? encoder.encode(collection) {
            defaults.set(data, forKey: collectionKey)
        }
    }
}

// MARK: - Onboarding hand-off

public enum OnboardingCollection {
    /// Kit ids after the box questions: owning any mini ticks "minis" on the "What do you have?" screen.
    public static func kitChecks(_ checks: Set<String>, after collection: OwnedCollection) -> Set<String> {
        guard !collection.isEmpty else { return checks }
        return checks.union(["minis"])
    }
}
