import Foundation

/// Initiative dice typed in, or rolled, for three or four sides (PlayModeSpec § 6.1 **[HOUSE]**).
///
/// Round 0 holds every side still in the game. Sides that tie roll again in round 1, and only those sides;
/// a re-roll that ties again goes to round 2, and so on. The view asks `pending` which sides to show next and
/// `initiativeRolls` for the finished order. All of it is plain values, so it is unit-tested.
public struct InitiativeEntry: Sendable, Equatable {
    public struct Dice: Sendable, Equatable {
        public var die1: Int?
        public var die2: Int?

        public init(die1: Int? = nil, die2: Int? = nil) {
            self.die1 = die1
            self.die2 = die2
        }

        public var roll: DiceRoll2D6? {
            guard let die1, let die2 else { return nil }
            return DiceRoll2D6.validated(die1: die1, die2: die2)
        }

        public var total: Int? { roll?.total }
    }

    /// The sides still in the game, in seat order.
    public var sides: [SideId]
    /// `rounds[k][side]` is the dice that side rolled in round k.
    public var rounds: [[SideId: Dice]]

    public init(sides: [SideId], rounds: [[SideId: Dice]] = []) {
        self.sides = sides
        self.rounds = rounds
    }

    /// The sides that still need dice, and in which round. Nil when the order is settled.
    public struct Pending: Sendable, Equatable {
        public var round: Int
        public var sides: [SideId]
    }

    public func dice(round: Int, side: SideId) -> Dice {
        rounds.indices.contains(round) ? rounds[round][side] ?? Dice() : Dice()
    }

    public mutating func set(round: Int, side: SideId, die: Int, value: Int?) {
        while rounds.count <= round { rounds.append([:]) }
        var entry = rounds[round][side] ?? Dice()
        if die == 1 { entry.die1 = value } else { entry.die2 = value }
        rounds[round][side] = entry
    }

    private func completeRoll(round: Int, side: SideId) -> DiceRoll2D6? {
        rounds.indices.contains(round) ? rounds[round][side]?.roll : nil
    }

    /// Walks the rounds: the order if every round that is needed is complete, otherwise the next round to fill.
    public var progress: (order: [SideId]?, pending: Pending?) {
        guard sides.count >= 2 else { return (sides, nil) }
        var base: [SideId: DiceRoll2D6] = [:]
        for side in sides {
            guard let roll = completeRoll(round: 0, side: side) else {
                return (nil, Pending(round: 0, sides: sides))
            }
            base[side] = roll
        }
        var rerolls: [[SideId: DiceRoll2D6]] = []
        while true {
            let resolution = InitiativeOrder.resolve(rolls: base, rerolls: rerolls)
            if resolution.isResolved { return (resolution.order, nil) }
            let needed = SideId.allCases.filter { side in resolution.unresolvedTies.contains { $0.contains(side) } }
            let round = rerolls.count + 1
            var rolled: [SideId: DiceRoll2D6] = [:]
            for side in needed {
                guard let roll = completeRoll(round: round, side: side) else {
                    return (nil, Pending(round: round, sides: needed))
                }
                rolled[side] = roll
            }
            rerolls.append(rolled)
        }
    }

    /// Lowest first, winner last. Nil until every needed die is in.
    public var order: [SideId]? { progress.order }
    public var pending: Pending? { progress.pending }

    /// Rounds to show: every round that has been started or is pending, with the sides in each.
    public var visibleRounds: [Pending] {
        var result = [Pending(round: 0, sides: sides)]
        var round = 1
        while true {
            let state = trimmed(through: round - 1).progress
            guard let pending = state.pending, pending.round == round else { break }
            result.append(pending)
            round += 1
        }
        return result
    }

    private func trimmed(through round: Int) -> InitiativeEntry {
        InitiativeEntry(sides: sides, rounds: Array(rounds.prefix(round + 1)))
    }

    /// The finished rolls for `MatchCommand.setInitiative`. Nil until the order is settled.
    public var initiativeRolls: InitiativeRolls? {
        guard order != nil else { return nil }
        var base: [SideId: DiceRoll2D6] = [:]
        for side in sides { base[side] = completeRoll(round: 0, side: side) }
        var rerolls: [[SideId: DiceRoll2D6]] = []
        var round = 1
        while true {
            let resolution = InitiativeOrder.resolve(rolls: base, rerolls: rerolls)
            if resolution.isResolved { break }
            let needed = Set(resolution.unresolvedTies.flatMap { $0 })
            var rolled: [SideId: DiceRoll2D6] = [:]
            for side in needed { rolled[side] = completeRoll(round: round, side: side) }
            rerolls.append(rolled)
            round += 1
        }
        return InitiativeRolls(rolls: base, rerolls: rerolls)
    }

    /// Rolls for the app: every side, then only tied sides again, until the order is settled.
    public static func autoRolled<G: RandomNumberGenerator>(sides: [SideId], using generator: inout G) -> InitiativeEntry {
        var entry = InitiativeEntry(sides: sides)
        func fill(_ round: Int, _ needed: [SideId], _ generator: inout G) {
            for side in needed {
                entry.set(round: round, side: side, die: 1, value: Int.random(in: 1...6, using: &generator))
                entry.set(round: round, side: side, die: 2, value: Int.random(in: 1...6, using: &generator))
            }
        }
        fill(0, sides, &generator)
        // A tie among six totals out of eleven is common with four sides; a hundred rounds never run out.
        for _ in 0..<100 {
            guard let pending = entry.pending else { break }
            fill(pending.round, pending.sides, &generator)
        }
        return entry
    }

    public var isComplete: Bool { order != nil }
}

extension InitiativeRolls {
    /// "A 7, B 9, C 4" for the log and VoiceOver.
    public func summary(names: (SideId) -> String) -> String {
        rolls.keys.sorted { $0.rawValue < $1.rawValue }
            .compactMap { side in rolls[side].map { "\(names(side)) \($0.total)" } }
            .joined(separator: ", ")
    }
}
