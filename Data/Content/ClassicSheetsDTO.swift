import Foundation

// Classic BattleTech record sheets: `Content/Classic/classic-agoac-sheets.json`.
// Data only. Classic rules math belongs in Domain/Engines/ClassicTW (ClassicModeSpec).
// Spec: docs/game-modes/classic/mission-path-scope.md § C0

/// The eight hit locations on a 'Mech record sheet.
public enum ClassicLocation: String, Codable, CaseIterable, Sendable {
    case head = "HD"
    case centerTorso = "CT"
    case leftTorso = "LT"
    case rightTorso = "RT"
    case leftArm = "LA"
    case rightArm = "RA"
    case leftLeg = "LL"
    case rightLeg = "RL"

    /// Critical slots: 6 in the head and legs, 12 elsewhere.
    public var slots: Int {
        switch self {
        case .head, .leftLeg, .rightLeg: 6
        default: 12
        }
    }

    /// Armor key for the rear of a torso location ("CTR"); `nil` where there's no rear armor.
    public var rearKey: String? {
        switch self {
        case .centerTorso, .leftTorso, .rightTorso: rawValue + "R"
        default: nil
        }
    }
}

public struct ClassicSheetsDTO: Codable, Sendable, ContentSchemaVersioned {
    public var schemaVersion: Int
    public var contentVersion: String
    public var sourceNote: String?
    public var weapons: [ClassicWeaponDTO]
    public var units: [ClassicMechSheetDTO]

    public func weapon(named name: String) -> ClassicWeaponDTO? {
        weapons.first { $0.name == name }
    }

    public func unit(id: String) -> ClassicMechSheetDTO? {
        units.first { $0.id == id }
    }
}

/// One row of the Weapons and Equipment Table.
public struct ClassicWeaponDTO: Codable, Sendable, Equatable {
    public var name: String
    public var heat: Int
    /// Damage per hit; `nil` for missile racks, which use `damagePerMissile` × cluster hits.
    public var damage: Int?
    public var damagePerMissile: Int?
    public var rackSize: Int?
    /// Minimum range in hexes; 0 when none.
    public var minRange: Int
    public var short: Int
    public var medium: Int
    public var long: Int
    public var ammoPerTon: Int?
    public var source: String?
}

public struct ClassicMechSheetDTO: Codable, Sendable, Identifiable, Equatable {
    public struct HeatSinks: Codable, Sendable, Equatable {
        public var count: Int
        /// "single" or "double".
        public var type: String
    }

    public struct Engine: Codable, Sendable, Equatable {
        public var rating: Int
        public var type: String
    }

    public struct Mount: Codable, Sendable, Equatable {
        public var name: String
        public var location: ClassicLocation
        public var rear: Bool
    }

    public struct AmmoBin: Codable, Sendable, Equatable {
        public var weapon: String
        public var location: ClassicLocation
        public var shots: Int
    }

    public struct Equipment: Codable, Sendable, Equatable {
        public var name: String
        public var count: Int
        public var location: ClassicLocation
    }

    /// Model code, e.g. "LCT-1V".
    public var id: String
    public var chassis: String
    public var model: String
    public var tonnage: Int
    public var techBase: String
    public var bv: Int?
    public var walk: Int
    public var run: Int
    public var jump: Int
    public var heatSinks: HeatSinks
    public var engine: Engine?
    public var armorTotalPoints: Int?
    /// Location key ("HD", "CT", "CTR" for rear centre torso, …) → armor points.
    public var armor: [String: Int]
    /// Location key → internal structure points.
    public var structure: [String: Int]
    public var weapons: [Mount]
    public var ammo: [AmmoBin]
    public var equipment: [Equipment]
    /// Location key → critical slot contents, top to bottom.
    public var crits: [String: [String]]
    public var sources: [String]
    public var flags: [String]?

    /// "Locust LCT-1V".
    public var name: String { "\(chassis) \(model)" }

    public func armor(_ location: ClassicLocation, rear: Bool = false) -> Int {
        let key = rear ? (location.rearKey ?? "") : location.rawValue
        return armor[key] ?? 0
    }

    public func structure(_ location: ClassicLocation) -> Int {
        structure[location.rawValue] ?? 0
    }

    public func crits(_ location: ClassicLocation) -> [String] {
        crits[location.rawValue] ?? []
    }

    public var totalArmor: Int { armor.values.reduce(0, +) }
}
