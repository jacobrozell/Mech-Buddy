import Foundation

/// A table edge, as seen from above with Side A's home edge to the south.
public enum TableEdge: String, Codable, Sendable, CaseIterable {
    case south
    case north
    case west
    case east
}

/// One side in a match (PlayModeSpec § 12). A team is one side (QSR p. 13).
/// Missions always have Side A and Side B with default names.
public struct MatchSide: Codable, Sendable, Equatable, Identifiable {
    public var id: SideId
    /// "Side A" or the players' choice.
    public var name: String
    /// Who plays this side. May be empty.
    public var players: [String]
    public var homeEdge: TableEdge?
    /// No ’Mechs left on the table, or conceded (§ 6.5). Its standing is kept for the result.
    public var isOut: Bool
    public var outOnTurn: Int?
    public var conceded: Bool

    public init(
        id: SideId,
        name: String? = nil,
        players: [String] = [],
        homeEdge: TableEdge? = nil,
        isOut: Bool = false,
        outOnTurn: Int? = nil,
        conceded: Bool = false
    ) {
        self.id = id
        self.name = name ?? id.displayName
        self.players = players
        self.homeEdge = homeEdge
        self.isOut = isOut
        self.outOnTurn = outOnTurn
        self.conceded = conceded
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, players, homeEdge, isOut, outOnTurn, conceded
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(SideId.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id.displayName
        players = try container.decodeIfPresent([String].self, forKey: .players) ?? []
        homeEdge = try container.decodeIfPresent(TableEdge.self, forKey: .homeEdge)
        isOut = try container.decodeIfPresent(Bool.self, forKey: .isOut) ?? false
        outOnTurn = try container.decodeIfPresent(Int.self, forKey: .outOnTurn)
        conceded = try container.decodeIfPresent(Bool.self, forKey: .conceded) ?? false
    }

    /// The name to show: what the players typed, or "Side A" when it is blank.
    public var label: String {
        name.trimmingCharacters(in: .whitespaces).isEmpty ? id.displayName : name
    }

    /// Side A and Side B with default names: every mission, and every save from before payload v2.
    public static var missionPair: [MatchSide] {
        SideId.missionPair.map { MatchSide(id: $0) }
    }
}

/// Initiative order from 2D6 rolls (QSR p. 13, PlayModeSpec § 6.1).
///
/// Lowest total acts first; highest acts last and is the initiative winner. Ties are broken by re-rolls
/// among the tied sides only **[HOUSE]**: a re-roll orders the tied sides among themselves and never
/// moves them past a side they didn't tie with. With two sides this is the QSR rule: roll, re-roll ties,
/// lower total moves first.
public enum InitiativeOrder {
    public struct Resolution: Sendable, Equatable {
        /// Lowest first. Complete only when `unresolvedTies` is empty.
        public var order: [SideId]
        /// Groups of sides still level after every re-roll so far; each group must roll again.
        public var unresolvedTies: [[SideId]]

        public var isResolved: Bool { unresolvedTies.isEmpty }
    }

    /// Orders `rolls`, using `rerolls[k]` for sides still tied after round k. A re-roll round may hold
    /// several tied groups at once (two pairs tied): each group is compared only within itself.
    /// Sides in a group that stays tied keep seat order in `order` until the tie is broken.
    public static func resolve(
        rolls: [SideId: DiceRoll2D6],
        rerolls: [[SideId: DiceRoll2D6]] = []
    ) -> Resolution {
        var ties: [[SideId]] = []
        let sides = SideId.allCases.filter { rolls[$0] != nil }
        let order = orderGroup(sides, totals: rolls.mapValues(\.total), rerolls: rerolls, round: 0, ties: &ties)
        return Resolution(order: order, unresolvedTies: ties)
    }

    private static func orderGroup(
        _ group: [SideId],
        totals: [SideId: Int],
        rerolls: [[SideId: DiceRoll2D6]],
        round: Int,
        ties: inout [[SideId]]
    ) -> [SideId] {
        guard group.count > 1 else { return group }
        // Bucket by total, lowest first; seat order inside a bucket.
        let buckets = Dictionary(grouping: group) { totals[$0] ?? 0 }
            .sorted { $0.key < $1.key }
            .map { bucket in SideId.allCases.filter { bucket.value.contains($0) } }
        var result: [SideId] = []
        for bucket in buckets {
            guard bucket.count > 1 else {
                result += bucket
                continue
            }
            // Tied: the next re-roll round orders only these sides.
            guard round < rerolls.count,
                  bucket.allSatisfy({ rerolls[round][$0] != nil }) else {
                ties.append(bucket)
                result += bucket
                continue
            }
            let rerollTotals = rerolls[round].filter { bucket.contains($0.key) }.mapValues(\.total)
            result += orderGroup(bucket, totals: rerollTotals, rerolls: rerolls, round: round + 1, ties: &ties)
        }
        return result
    }
}
