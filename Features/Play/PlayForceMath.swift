import MechBuddyDomain

enum GettingStartedCatalog {
    static let playCueID = "roster"
}

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

    static func shortName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        guard parts.count > 1, let last = parts.last, last.contains(where: \.isNumber) else {
            return name
        }
        return parts.dropLast().joined(separator: " ")
    }
}
