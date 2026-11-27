import Foundation

/// A battle-roster section: one side and its units still on the table (PlayModeSpec § 8.6, PM5).
public struct SideGroup: Sendable, Equatable, Identifiable {
    public var side: SideId
    /// The session's name for the side ("Side A" or the players' choice).
    public var name: String
    public var units: [MatchUnitState]

    public var id: SideId { side }
}

public enum SideGrouping {
    /// Groups `session` units by side in seat order. Removed units and empty sides are dropped, so any
    /// number of sides (two today, up to four later) fits the same list. Unit order within a side is kept.
    public static func groups(in session: MatchSession) -> [SideGroup] {
        session.sideIds.compactMap { side in
            let units = session.units.filter { $0.side == side && $0.combatStatus != .removed }
            guard !units.isEmpty else { return nil }
            return SideGroup(side: side, name: session.displayName(of: side), units: units)
        }
    }
}
