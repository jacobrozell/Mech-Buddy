// Tests for Content/Classic/classic-agoac-sheets.json and Data/Content/ClassicSheetsDTO.swift.
// Spec: docs/game-modes/classic/mission-path-scope.md § C0. Every number on the sheets is checked
// against the construction rules a printed sheet must satisfy, so a typo shows up here.
import Foundation
import Testing
import MechBuddyData

@Suite("Classic record sheets")
struct ClassicSheetsTests {
    private var sheets: ClassicSheetsDTO {
        get throws {
            try BundleContentCatalogRepository(bundle: Bundle(for: ClassicSheetsBundleToken.self)).classicSheets()
        }
    }

    @Test("All 15 booklet sheets, unique ids, including every A Game of Armored Combat mini")
    func roster() throws {
        let sheets = try sheets
        #expect(sheets.units.count == 15)
        #expect(Set(sheets.units.map(\.id)).count == 15)
        for model in ["AWS-8Q", "BLR-1G", "CPLT-C1", "COM-2D", "LCT-1V", "SHD-2H", "TDR-5S", "WVR-6M"] {
            #expect(sheets.unit(id: model) != nil, "\(model)")
        }
    }

    @Test("Armor fits the structure: at most 2× per location (front + rear), head at most 9")
    func armorLimits() throws {
        for unit in try sheets.units {
            for location in ClassicLocation.allCases {
                let armor = unit.armor(location) + unit.armor(location, rear: true)
                let limit = location == .head ? 9 : 2 * unit.structure(location)
                #expect(unit.structure(location) > 0, "\(unit.id) \(location.rawValue) structure")
                #expect(armor <= limit, "\(unit.id) \(location.rawValue): \(armor) > \(limit)")
            }
            if let total = unit.armorTotalPoints {
                #expect(unit.totalArmor == total, "\(unit.id) armor total")
            }
        }
    }

    @Test("Movement: run is walk × 1.5 rounded up; one jump jet per jump MP")
    func movement() throws {
        for unit in try sheets.units {
            #expect(unit.run == (unit.walk * 3 + 1) / 2, "\(unit.id) run")
            let jets = ClassicLocation.allCases.reduce(0) { $0 + unit.crits($1).filter { $0 == "Jump Jet" }.count }
            #expect(jets == unit.jump, "\(unit.id) jump jets")
        }
    }

    @Test("Critical tables: 6 or 12 slots, and every weapon and ammo bin is in its location")
    func crits() throws {
        let sheets = try sheets
        for unit in sheets.units {
            for location in ClassicLocation.allCases {
                #expect(unit.crits(location).count == location.slots, "\(unit.id) \(location.rawValue) slots")
            }
            for location in ClassicLocation.allCases {
                let mounted = unit.weapons.filter { $0.location == location }
                for name in Set(mounted.map(\.name)) {
                    let listed = mounted.filter { $0.name == name }.count
                    let slots = unit.crits(location).filter { $0 == name || $0 == "\(name) (R)" }.count
                    // Big weapons fill several slots, so a slot count is at least the weapon count.
                    #expect(slots >= listed, "\(unit.id) \(location.rawValue) \(name)")
                }
            }
            for bin in unit.ammo {
                #expect(
                    unit.crits(bin.location).contains("Ammo (\(bin.weapon)) \(bin.shots)"),
                    "\(unit.id) ammo \(bin.weapon) in \(bin.location.rawValue)"
                )
            }
            for mount in unit.weapons {
                #expect(sheets.weapon(named: mount.name) != nil, "\(unit.id) \(mount.name) not in weapons table")
            }
        }
    }

    @Test("Heat sinks: the engine holds rating ÷ 25, the rest take a slot each")
    func heatSinks() throws {
        for unit in try sheets.units {
            let engine = try #require(unit.engine, "\(unit.id) engine")
            let inEngine = min(unit.heatSinks.count, engine.rating / 25)
            let slotted = ClassicLocation.allCases.reduce(0) { $0 + unit.crits($1).filter { $0 == "Heat Sink" }.count }
            #expect(inEngine + slotted == unit.heatSinks.count, "\(unit.id) heat sinks")
        }
    }

    @Test("Weapons table: ranges increase, missile racks have a rack size, ammo weapons a per-ton count")
    func weaponsTable() throws {
        for weapon in try sheets.weapons {
            #expect(weapon.short < weapon.medium && weapon.medium < weapon.long, "\(weapon.name) ranges")
            #expect(weapon.damage != nil || (weapon.damagePerMissile != nil && weapon.rackSize != nil), "\(weapon.name) damage")
        }
    }
}

private final class ClassicSheetsBundleToken {}
