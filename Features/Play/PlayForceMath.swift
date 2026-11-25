import MechBuddyData
import MechBuddyDomain

enum PlayForceMath {
    static func structure(of side: SideId, in units: [MatchUnitState]) -> (remaining: Int, capacity: Int) {
        let rows = units.filter { $0.side == side }
        let remaining = rows.reduce(0) { $0 + $1.remainingStructure }
        let capacity = rows.reduce(0) { $0 + $1.structureCap }
        return (remaining, capacity)
    }

    static func pointValue(of side: SideId, in units: [MatchUnitState]) -> Int {
        units.filter { $0.side == side }.reduce(0) { $0 + $1.pv }
    }

    /// "Locust LCT-1V" → "Locust". Same rule the collection uses to match minis.
    static func shortName(_ name: String) -> String {
        UnitChassis.name(name)
    }
}
