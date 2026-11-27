import Foundation

// Objectives and victory points in Play (PlayModeSpec § 7, PM8, PM11). Quick-Start p. 7 lists six objectives. Find the
// Target needs buildings (PM11). Anything the Quick-Start doesn't say is marked [HOUSE].

/// The six objectives, in book order (p. 7). Raw values are saved in `PlaySetup.objective`.
public enum ObjectiveId: String, Codable, Sendable, CaseIterable {
    case raid, controlTheField, destroyTheEnemy, holdTheFort, breakthrough, findTheTarget

    /// The five that need nothing on the table. Find the Target needs buildings (`minimumBuildings`).
    public static let built: [ObjectiveId] = [.raid, .controlTheField, .destroyTheEnemy, .holdTheFort, .breakthrough]

    /// The app scores all six since PM11. Find the Target is only offered when the setup has buildings.
    public var isBuilt: Bool { true }

    /// Find the Target hides `targetCount` targets among the buildings, so it needs at least that many **[HOUSE]**.
    public static let minimumBuildings = 3
    public static let targetCount = 3
    public static let pointsPerTarget = 5.0

    public var needsBuildings: Bool { self == .findTheTarget }

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

    /// A word or two for the VP strip when each side has its own objective.
    public var shortTitle: String {
        switch self {
        case .raid: "Raid"
        case .controlTheField: "Control"
        case .destroyTheEnemy: "Destroy"
        case .holdTheFort: "Hold"
        case .breakthrough: "Breakthrough"
        case .findTheTarget: "Find"
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
        case .findTheTarget: "Search buildings for hidden targets. 5 points each."
        }
    }

    /// What players place before Turn 1, or nil.
    public var setupStep: String? {
        switch self {
        case .raid:
            "Each side places 3 tokens at least 21″ from its own edge and 18″ apart."
        case .holdTheFort:
            "Each side places 2 tokens at least 12″ from its own edge and 18″ apart."
        case .findTheTarget:
            "[HOUSE] Place the buildings first. The app hides 3 targets among them; search a building by ending a ’Mech’s move beside it."
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
        case .findTheTarget: "[HOUSE] Which buildings did your ’Mechs search this turn? A building is searched by ending a move beside it."
        case .breakthrough: "Which ’Mechs touch an enemy home edge? They leave the game."
        case .destroyTheEnemy: nil
        }
    }

    /// Points needed to win (p. 7). Destroy the Enemy asks a Clan side for 12 (`ObjectiveRules.threshold`).
    public var baseThreshold: Double { 10 }

    /// Quick-Start page for the objective.
    public var page: String { "p. 7" }

    /// Raid and Hold the Fort tokens, and whether a Clan multiplier applies (§ 7.1).
    public var usesClanMultiplier: Bool { self == .destroyTheEnemy || self == .breakthrough }

    /// The 1D6 roll **[HOUSE mapping]**: the Quick-Start says "randomly determine" with no table (p. 7, D22). 1 Raid,
    /// 2 Control the Field, 3 Destroy the Enemy, 4 Hold the Fort, 5 Breakthrough. A 6 is Find the Target: it means
    /// roll again (nil) unless the table has enough buildings (`hasBuildings`).
    public static func fromRoll(_ die: Int) -> ObjectiveId? { fromRoll(die, hasBuildings: false) }

    public static func fromRoll(_ die: Int, hasBuildings: Bool) -> ObjectiveId? {
        switch die {
        case 1: .raid
        case 2: .controlTheField
        case 3: .destroyTheEnemy
        case 4: .holdTheFort
        case 5: .breakthrough
        case 6: hasBuildings ? .findTheTarget : nil
        default: nil
        }
    }

    /// Rolls until an objective comes up (a 6 rolls again without enough buildings).
    public static func roll<G: RandomNumberGenerator>(using generator: inout G, hasBuildings: Bool = false) -> ObjectiveId {
        while true {
            if let objective = fromRoll(Int.random(in: 1...6, using: &generator), hasBuildings: hasBuildings) { return objective }
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
        /// Find the Target: the side searched this building (`tokenId` holds the building id).
        case searched
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
    /// Which objective the token belongs to. Nil for a game saved before sides could roll their own (PM11): the
    /// game's one objective.
    public var objective: ObjectiveId?

    public init(id: String, owner: SideId, carrier: UUID? = nil, returned: Bool = false, objective: ObjectiveId? = nil) {
        self.id = id
        self.owner = owner
        self.carrier = carrier
        self.returned = returned
        self.objective = objective
    }

    private enum CodingKeys: String, CodingKey { case id, owner, carrier, returned, objective }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        owner = try c.decode(SideId.self, forKey: .owner)
        carrier = try c.decodeIfPresent(UUID.self, forKey: .carrier)
        returned = try c.decodeIfPresent(Bool.self, forKey: .returned) ?? false
        objective = try c.decodeIfPresent(ObjectiveId.self, forKey: .objective)
    }
}

/// Objective bookkeeping on a session (§ 12). Nil for a game without an objective.
public struct ObjectiveState: Codable, Sendable, Equatable {
    public var tokens: [ObjectiveToken]
    /// The turn `scoredSides` belongs to.
    public var scoredTurn: Int?
    /// Sides whose Score step is done this turn.
    public var scoredSides: [SideId]
    /// Find the Target: the buildings that hide a target (`ObjectiveRules.pickTargets`). The screens never show them.
    public var targetBuildingIds: [String]
    /// Find the Target: targets already found, building id to the side that found it. A building is found once.
    public var foundTargets: [String: SideId]

    public init(
        tokens: [ObjectiveToken] = [],
        scoredTurn: Int? = nil,
        scoredSides: [SideId] = [],
        targetBuildingIds: [String] = [],
        foundTargets: [String: SideId] = [:]
    ) {
        self.tokens = tokens
        self.scoredTurn = scoredTurn
        self.scoredSides = scoredSides
        self.targetBuildingIds = targetBuildingIds
        self.foundTargets = foundTargets
    }

    private enum CodingKeys: String, CodingKey { case tokens, scoredTurn, scoredSides, targetBuildingIds, foundTargets }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try c.decodeIfPresent([ObjectiveToken].self, forKey: .tokens) ?? []
        scoredTurn = try c.decodeIfPresent(Int.self, forKey: .scoredTurn)
        scoredSides = try c.decodeIfPresent([SideId].self, forKey: .scoredSides) ?? []
        targetBuildingIds = try c.decodeIfPresent([String].self, forKey: .targetBuildingIds) ?? []
        foundTargets = try c.decodeIfPresent([String: SideId].self, forKey: .foundTargets) ?? [:]
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

extension ObjectiveState {
    /// Bookkeeping for a new game where each side may have its own objective (§ 5.5, PM11). Raid tokens exist for every
    /// side as soon as any side plays Raid, so a Raid side has something to take **[HOUSE]**; Hold the Fort tokens only
    /// for the sides that play it. With one shared objective the ids stay "A1"; with mixed objectives Hold the Fort
    /// tokens are "AH1" so they never share an id with a Raid token. Find the Target hides its targets by a seed.
    public static func make(
        objectives: [SideId: ObjectiveId],
        sides: [SideId],
        buildings: [BuildingState],
        seed: UUID,
        mixed: Bool
    ) -> ObjectiveState {
        var tokens: [ObjectiveToken] = []
        if objectives.values.contains(.raid) {
            for side in sides {
                for n in 1...ObjectiveId.raid.tokensPerSide {
                    tokens.append(ObjectiveToken(id: "\(side.letter)\(n)", owner: side, objective: .raid))
                }
            }
        }
        for side in sides where objectives[side] == .holdTheFort {
            for n in 1...ObjectiveId.holdTheFort.tokensPerSide {
                tokens.append(ObjectiveToken(id: "\(side.letter)\(mixed ? "H" : "")\(n)", owner: side, objective: .holdTheFort))
            }
        }
        var state = ObjectiveState(tokens: tokens)
        if objectives.values.contains(.findTheTarget) {
            state.targetBuildingIds = ObjectiveRules.pickTargets(buildings: buildings, seed: seed)
        }
        return state
    }
}

/// Scoring rules the reducer, the evaluator and the screens share.
public enum ObjectiveRules {
    /// Which buildings hide a target **[HOUSE]**: `targetCount` of them, ordered by a hash of the game's id so the
    /// choice is the same every time the reducer runs. Empty when there are too few buildings.
    public static func pickTargets(buildings: [BuildingState], seed: UUID) -> [String] {
        guard buildings.count >= ObjectiveId.minimumBuildings else { return [] }
        func score(_ id: String) -> UInt64 {
            var hash: UInt64 = 14695981039346656037
            for byte in (seed.uuidString + id).utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
            return hash
        }
        return Array(buildings.map(\.id).sorted { score($0) < score($1) }.prefix(ObjectiveId.targetCount))
    }

    /// Buildings a side can still search: not already found.
    public static func searchableBuildings(in session: MatchSession) -> [BuildingState] {
        let found = Set((session.objectiveState?.foundTargets ?? [:]).keys)
        return (session.boxRules?.buildings ?? []).filter { !found.contains($0.id) }
    }

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
        case .destroyTheEnemy: false
        case .holdTheFort: turn >= 3
        default: true
        }
    }

    /// Sides the Score step waits for this turn: in the game with a ’Mech still on the table.
    public static func sidesToScore(in session: MatchSession) -> [SideId] {
        session.sidesInGame.filter { side in
            guard let objective = session.objective(for: side), asksQuestions(objective, turn: session.turn) else { return false }
            return session.units.contains { $0.side == side && $0.combatStatus == .active }
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

    /// Points the answers would add, for the Score step's preview. The reducer does the real scoring.
    public static func previewPoints(_ objective: ObjectiveId, side: SideId, entries: [ObjectiveScoreEntry], in session: MatchSession) -> Double {
        func size(_ id: UUID?) -> Double {
            Double(session.units.first { $0.id == id }?.sz ?? 0)
        }
        switch objective {
        case .raid:
            return 2 * Double(entries.filter { $0.kind == .returned }.count)
        case .controlTheField:
            return Set(entries.filter { $0.kind == .inPosition }.compactMap(\.unitId)).reduce(0) { $0 + size($1) }
        case .holdTheFort:
            return Double(min(Set(entries.filter { $0.kind == .guarded }.compactMap(\.tokenId)).count, 2))
        case .breakthrough:
            let sum = Set(entries.filter { $0.kind == .exited }.compactMap(\.unitId)).reduce(0) { $0 + size($1) }
            return sum * clanMultiplier(for: side, objective: .breakthrough, in: session)
        case .destroyTheEnemy, .findTheTarget:
            return 0
        }
    }

    /// "7.5", "10": half points are kept, whole points drop the ".0" (never rounded).
    public static func format(_ points: Double) -> String {
        points == points.rounded() ? String(Int(points)) : String(format: "%.1f", points)
    }

    /// Raid: enemy tokens a ’Mech of this side could pick up now.
    public static func availableTokens(for side: SideId, in session: MatchSession) -> [ObjectiveToken] {
        (session.objectiveState?.tokens ?? []).filter { isRaid($0, in: session) && $0.owner != side && $0.carrier == nil && !$0.returned }
    }

    /// Raid: the ’Mech carries a token.
    public static func carriedToken(by unitId: UUID, in session: MatchSession) -> ObjectiveToken? {
        session.objectiveState?.tokens.first { isRaid($0, in: session) && $0.carrier == unitId }
    }

    /// A token without its own objective (saved before PM11) belongs to the game's one objective.
    public static func isRaid(_ token: ObjectiveToken, in session: MatchSession) -> Bool {
        (token.objective ?? session.objective) == .raid
    }

    /// Hold the Fort tokens a side placed.
    public static func holdTokens(of side: SideId, in session: MatchSession) -> [ObjectiveToken] {
        (session.objectiveState?.tokens ?? []).filter { $0.owner == side && ($0.objective ?? session.objective) == .holdTheFort }
    }
}

extension PlaySetup {
    /// The objective, nil for last side standing. A saved name this build doesn't know reads as nil.
    public var objectiveId: ObjectiveId? {
        get { objective.flatMap(ObjectiveId.init(rawValue:)) }
        set { objective = newValue?.rawValue }
    }
}

extension PlaySetup {
    /// Each side rolls its own objective (§ 5.5, p. 7 optional rule). `sideObjectives` is empty when every side
    /// plays the one `objective`.
    public var perSideObjectives: Bool { !sideObjectives.isEmpty }

    /// The objective a side plays: its own when sides roll separately, else the shared one.
    public func objectiveId(for side: SideId) -> ObjectiveId? {
        if perSideObjectives { return sideObjectives[side.rawValue].flatMap(ObjectiveId.init(rawValue:)) }
        return objectiveId
    }

    public mutating func setObjective(_ objective: ObjectiveId?, for side: SideId) {
        sideObjectives[side.rawValue] = objective?.rawValue
    }

    /// Enough buildings for Find the Target (`ObjectiveId.minimumBuildings`).
    public var hasBuildingsForTargets: Bool { rules.buildings.count >= ObjectiveId.minimumBuildings }

    /// The setup with anything the game can't play taken out: Find the Target without enough buildings is dropped,
    /// and per-side objectives are cleared unless every side has one.
    public func sanitizedObjectives() -> PlaySetup {
        var copy = self
        if copy.objectiveId == .findTheTarget, !copy.hasBuildingsForTargets { copy.objectiveId = nil }
        if copy.perSideObjectives {
            if !copy.hasBuildingsForTargets {
                for (key, raw) in copy.sideObjectives where raw == ObjectiveId.findTheTarget.rawValue { copy.sideObjectives[key] = nil }
            }
            if copy.sides.contains(where: { copy.sideObjectives[$0.id.rawValue] == nil }) { copy.sideObjectives = [:] }
        }
        return copy
    }
}

extension MatchSession {
    /// Victory points for a side (§ 7.1). 0 before it scores.
    public func points(of side: SideId) -> Double { victoryPoints[side] ?? 0 }

    /// The one objective every side plays. Nil without an objective, and nil when each side has its own (PM11): use
    /// `objective(for:)` then.
    public var objective: ObjectiveId? {
        guard let play, !play.perSideObjectives, let objective = play.objectiveId, objective.isBuilt else { return nil }
        return objective
    }

    /// The objective this side plays (§ 5.5). Nil for last side standing.
    public func objective(for side: SideId) -> ObjectiveId? {
        play?.objectiveId(for: side)
    }

    /// Each side has its own objective.
    public var hasPerSideObjectives: Bool { play?.perSideObjectives == true && sideIds.contains { objective(for: $0) != nil } }

    /// The game has an objective of any kind, shared or per side.
    public var hasObjective: Bool { objective != nil || hasPerSideObjectives }
}
