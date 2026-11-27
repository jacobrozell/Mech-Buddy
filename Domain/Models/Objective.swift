import Foundation

// Objectives and victory points in Play (PlayModeSpec § 7, PM8). Quick-Start p. 7 lists six objectives; the app builds
// five. Find the Target needs buildings and waits for PM11. Anything the Quick-Start doesn't say is marked [HOUSE].

/// The six objectives, in book order (p. 7). Raw values are saved in `PlaySetup.objective`.
public enum ObjectiveId: String, Codable, Sendable, CaseIterable {
    case raid, controlTheField, destroyTheEnemy, holdTheFort, breakthrough, findTheTarget

    /// The five the app scores. Find the Target needs buildings (PM11).
    public static let built: [ObjectiveId] = [.raid, .controlTheField, .destroyTheEnemy, .holdTheFort, .breakthrough]

    public var isBuilt: Bool { self != .findTheTarget }

    public var title: String {
        switch self {
        case .raid: "Raid"
        case .controlTheField: "Control the Field"
        case .destroyTheEnemy: "Destroy the Enemy"
        case .holdTheFort: "Hold the Fort"
        case .breakthrough: "Breakthrough"
        case .findTheTarget: "Find the Target"
        }
    }

    /// One line for the picker (p. 7).
    public var summary: String {
        switch self {
        case .raid: "Carry enemy tokens back to your edge. 2 points each."
        case .controlTheField: "End a turn near an enemy edge. Each ’Mech scores its Size."
        case .destroyTheEnemy: "Destroy or cripple enemy ’Mechs. Each scores its Size."
        case .holdTheFort: "Guard your two tokens from Turn 3. 1 point each, per turn."
        case .breakthrough: "Run ’Mechs off an enemy edge. Each scores its Size."
        case .findTheTarget: "Needs buildings: coming later."
        }
    }

    /// What players place before Turn 1, or nil.
    public var setupStep: String? {
        switch self {
        case .raid:
            "Each side places 3 tokens at least 21″ from its own edge and 18″ apart."
        case .holdTheFort:
            "Each side places 2 tokens at least 12″ from its own edge and 18″ apart."
        default:
            nil
        }
    }

    /// Tokens each side places (§ 7.1).
    public var tokensPerSide: Int {
        switch self {
        case .raid: 3
        case .holdTheFort: 2
        default: 0
        }
    }

    /// The question the Score step asks of each side in the End Phase. Nil when the app works it out (Destroy the Enemy).
    public var question: String? {
        switch self {
        case .raid: "Which ’Mechs picked up a token, and which carried one back to your edge?"
        case .controlTheField: "Which ’Mechs are within 12″ of an enemy home edge, and 12″ from each other?"
        case .holdTheFort: "Which tokens have your ’Mech within 6″ and no enemy within 12″?"
        case .breakthrough: "Which ’Mechs touch an enemy home edge? They leave the game."
        case .destroyTheEnemy, .findTheTarget: nil
        }
    }

    /// Points needed to win (p. 7). Destroy the Enemy asks a Clan side for 12 (`ObjectiveRules.threshold`).
    public var baseThreshold: Double { 10 }

    /// Quick-Start page for the objective.
    public var page: String { "p. 7" }

    /// Raid and Hold the Fort tokens, and whether a Clan multiplier applies (§ 7.1).
    public var usesClanMultiplier: Bool { self == .destroyTheEnemy || self == .breakthrough }

    /// The 1D6 roll **[HOUSE mapping]**: the Quick-Start says "randomly determine" with no table (p. 7, D22). 1 Raid,
    /// 2 Control the Field, 3 Destroy the Enemy, 4 Hold the Fort, 5 Breakthrough. A 6 is Find the Target, which is
    /// not built yet, so it means roll again (nil).
    public static func fromRoll(_ die: Int) -> ObjectiveId? {
        switch die {
        case 1: .raid
        case 2: .controlTheField
        case 3: .destroyTheEnemy
        case 4: .holdTheFort
        case 5: .breakthrough
        default: nil
        }
    }

    /// Rolls until a built objective comes up (a 6 rolls again).
    public static func roll<G: RandomNumberGenerator>(using generator: inout G) -> ObjectiveId {
        while true {
            if let objective = fromRoll(Int.random(in: 1...6, using: &generator)) { return objective }
        }
    }
}

/// One answer in the Score step (§ 7.1).
public struct ObjectiveScoreEntry: Codable, Sendable, Equatable, Hashable {
    public enum Kind: String, Codable, Sendable {
        /// Raid: this ’Mech picked up an enemy token.
        case pickedUp
        /// Raid: this ’Mech carried a token back to its own edge.
        case returned
        /// Control the Field: this ’Mech is in position.
        case inPosition
        /// Hold the Fort: this token is guarded.
        case guarded
        /// Breakthrough: this ’Mech touched an enemy home edge and left the game.
        case exited
    }

    public var kind: Kind
    public var unitId: UUID?
    public var tokenId: String?

    public init(kind: Kind, unitId: UUID? = nil, tokenId: String? = nil) {
        self.kind = kind
        self.unitId = unitId
        self.tokenId = tokenId
    }
}

/// A Raid or Hold the Fort token (§ 7.1, § 9.5 marker kind `objectiveToken`). It has no effect on the board.
public struct ObjectiveToken: Codable, Sendable, Equatable, Identifiable {
    /// "A1", "B2": the owner's letter and a number.
    public var id: String
    public var owner: SideId
    /// Raid: the ’Mech carrying it. A carrier that is destroyed or leaves drops it.
    public var carrier: UUID?
    /// Raid: carried back to the taker's edge and out of play.
    public var returned: Bool

    public init(id: String, owner: SideId, carrier: UUID? = nil, returned: Bool = false) {
        self.id = id
        self.owner = owner
        self.carrier = carrier
        self.returned = returned
    }

    private enum CodingKeys: String, CodingKey { case id, owner, carrier, returned }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        owner = try c.decode(SideId.self, forKey: .owner)
        carrier = try c.decodeIfPresent(UUID.self, forKey: .carrier)
        returned = try c.decodeIfPresent(Bool.self, forKey: .returned) ?? false
    }
}

/// Objective bookkeeping on a session (§ 12). Nil for a game without an objective.
public struct ObjectiveState: Codable, Sendable, Equatable {
    public var tokens: [ObjectiveToken]
    /// The turn `scoredSides` belongs to.
    public var scoredTurn: Int?
    /// Sides whose Score step is done this turn.
    public var scoredSides: [SideId]

    public init(tokens: [ObjectiveToken] = [], scoredTurn: Int? = nil, scoredSides: [SideId] = []) {
        self.tokens = tokens
        self.scoredTurn = scoredTurn
        self.scoredSides = scoredSides
    }

    private enum CodingKeys: String, CodingKey { case tokens, scoredTurn, scoredSides }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try c.decodeIfPresent([ObjectiveToken].self, forKey: .tokens) ?? []
        scoredTurn = try c.decodeIfPresent(Int.self, forKey: .scoredTurn)
        scoredSides = try c.decodeIfPresent([SideId].self, forKey: .scoredSides) ?? []
    }

    /// Tokens for a new game: `perSide` for every side, "A1", "A2"…
    public static func make(objective: ObjectiveId, sides: [SideId]) -> ObjectiveState {
        guard objective.tokensPerSide > 0 else { return ObjectiveState() }
        let tokens = sides.flatMap { side in
            (1...objective.tokensPerSide).map { ObjectiveToken(id: "\(side.letter)\($0)", owner: side) }
        }
        return ObjectiveState(tokens: tokens)
    }
}

/// Scoring rules the reducer, the evaluator and the screens share.
public enum ObjectiveRules {
    /// A Clan side playing only Inner Sphere sides scores 1.5 × Size in Destroy the Enemy and Breakthrough, and needs
    /// 12 in Destroy the Enemy (p. 7). Mixed forces use no multiplier **[HOUSE]** (D12). With three or four sides the
    /// Clan side must face only Inner Sphere sides **[HOUSE]**.
    public static func clanMultiplier(for side: SideId, objective: ObjectiveId, in session: MatchSession) -> Double {
        guard objective.usesClanMultiplier else { return 1 }
        return isClanVersusInnerSphere(side, in: session) ? 1.5 : 1
    }

    static func isClanVersusInnerSphere(_ side: SideId, in session: MatchSession) -> Bool {
        let mine = session.units.filter { $0.side == side }
        let others = session.units.filter { $0.side != side }
        guard !mine.isEmpty, !others.isEmpty else { return false }
        return mine.allSatisfy(\.isClan) && others.allSatisfy { !$0.isClan }
    }

    /// Points a side needs to win now (p. 7).
    public static func threshold(for side: SideId, objective: ObjectiveId, in session: MatchSession) -> Double {
        if objective == .destroyTheEnemy, isClanVersusInnerSphere(side, in: session) { return 12 }
        return objective.baseThreshold
    }

    /// Whether the End Phase asks for answers: every built objective but Destroy the Enemy, and Hold the Fort
    /// only from Turn 3 (p. 7).
    public static func asksQuestions(_ objective: ObjectiveId, turn: Int) -> Bool {
        switch objective {
        case .destroyTheEnemy, .findTheTarget: false
        case .holdTheFort: turn >= 3
        default: true
        }
    }

    /// Sides the Score step waits for this turn: in the game with a ’Mech still on the table.
    public static func sidesToScore(in session: MatchSession) -> [SideId] {
        guard let objective = session.play?.objectiveId, asksQuestions(objective, turn: session.turn) else { return [] }
        return session.sidesInGame.filter { side in
            session.units.contains { $0.side == side && $0.combatStatus == .active }
        }
    }

    /// Sides still to answer this turn.
    public static func sidesStillToScore(in session: MatchSession) -> [SideId] {
        let done = session.objectiveState?.scoredTurn == session.turn ? Set(session.objectiveState?.scoredSides ?? []) : []
        return sidesToScore(in: session).filter { !done.contains($0) }
    }

    public static func hasScored(_ side: SideId, in session: MatchSession) -> Bool {
        session.objectiveState?.scoredTurn == session.turn && session.objectiveState?.scoredSides.contains(side) == true
    }

    /// "7.5", "10": half points are kept, whole points drop the ".0" (never rounded).
    public static func format(_ points: Double) -> String {
        points == points.rounded() ? String(Int(points)) : String(format: "%.1f", points)
    }

    /// Raid: enemy tokens a ’Mech of this side could pick up now.
    public static func availableTokens(for side: SideId, in session: MatchSession) -> [ObjectiveToken] {
        (session.objectiveState?.tokens ?? []).filter { $0.owner != side && $0.carrier == nil && !$0.returned }
    }

    /// Raid: the ’Mech carries a token.
    public static func carriedToken(by unitId: UUID, in session: MatchSession) -> ObjectiveToken? {
        session.objectiveState?.tokens.first { $0.carrier == unitId }
    }
}

extension PlaySetup {
    /// The objective, nil for last side standing. A saved name this build doesn't know reads as nil.
    public var objectiveId: ObjectiveId? {
        get { objective.flatMap(ObjectiveId.init(rawValue:)) }
        set { objective = newValue?.rawValue }
    }
}

extension MatchSession {
    /// Victory points for a side (§ 7.1). 0 before it scores.
    public func points(of side: SideId) -> Double { victoryPoints[side] ?? 0 }

    /// The objective this game plays, when it has one and the app scores it.
    public var objective: ObjectiveId? {
        guard let objective = play?.objectiveId, objective.isBuilt else { return nil }
        return objective
    }
}
