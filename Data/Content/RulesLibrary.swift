import Foundation

// Rules tab content for both games. Lives in MechBuddyData so the unit tests can import it.
// Spec: specs/features/RulesReferenceSpec.md

/// The game a rules topic belongs to. `both` is for pages that compare the two games.
public enum RulesGameTag: String, Codable, CaseIterable, Sendable {
    case alphaStrike
    case classic
    case both

    /// Whether the topic shows on the Rules tab when `game` is picked.
    public func appears(in game: LearningTrack) -> Bool {
        switch self {
        case .both: true
        case .alphaStrike: game == .alphaStrike
        case .classic: game == .classic
        }
    }

    /// The middle part of `rules.{tag}.{topicId}` accessibility identifiers.
    public var identifierKey: String {
        switch self {
        case .alphaStrike: "as"
        case .classic: "classic"
        case .both: "both"
        }
    }

    /// Short badge text on a topic page.
    public var badge: String {
        switch self {
        case .alphaStrike: "Alpha Strike rules"
        case .classic: "Classic BattleTech rules"
        case .both: "Both games"
        }
    }
}

/// Which game the Rules tab opens on.
public enum RulesGameChoice {
    /// The last game picked on the Rules tab wins. Before that, the game picked in onboarding. Otherwise Alpha Strike.
    public static func initial(lastViewed: LearningTrack?, onboarding: LearningTrack?) -> LearningTrack {
        lastViewed ?? onboarding ?? .alphaStrike
    }

    /// Short segment label for the game switch.
    public static func shortTitle(_ game: LearningTrack) -> String {
        switch game {
        case .alphaStrike: "Alpha Strike"
        case .classic: "Classic"
        }
    }
}

/// Every rules pack, merged. Topics keep pack order: the game's own pack first, then the shared pages.
public struct RulesLibrary: Sendable {
    public var packs: [RulesTopicsDTO]

    public init(packs: [RulesTopicsDTO]) {
        self.packs = packs
    }

    public var allTopics: [RulesTopicDTO] {
        packs.flatMap(\.topics)
    }

    /// Topics for one game, including the pages tagged `both`. Untagged topics count as Alpha Strike (older packs).
    public func topics(for game: LearningTrack) -> [RulesTopicDTO] {
        allTopics.filter { ($0.game ?? .alphaStrike).appears(in: game) }
    }

    /// The disclaimer of the first pack whose topics are all for `game`.
    public func disclaimer(for game: LearningTrack) -> String? {
        packs.first { pack in
            !pack.topics.isEmpty && pack.topics.allSatisfy { ($0.game ?? .alphaStrike) == RulesGameTag(game) }
        }?.disclaimer
    }
}

public extension RulesGameTag {
    init(_ game: LearningTrack) {
        switch game {
        case .alphaStrike: self = .alphaStrike
        case .classic: self = .classic
        }
    }
}
