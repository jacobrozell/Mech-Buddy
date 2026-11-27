// Tests for the Rules tab content (Resources/Content/**/rules) and Data/Content/RulesLibrary.swift.
// Spec: specs/features/RulesReferenceSpec.md
import Foundation
import Testing
import MechBuddyData

@Suite("Rules content")
struct RulesContentTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: RulesBundleToken.self))
    }

    @Test("Every topic has a game tag")
    func everyTopicTagged() throws {
        let library = try catalog.rulesLibrary()
        #expect(!library.allTopics.isEmpty)
        for topic in library.allTopics {
            #expect(topic.game != nil, "\(topic.id) has no game")
        }
    }

    @Test("Each pack holds one game's topics")
    func packsMatchTheirGame() throws {
        #expect(try catalog.rulesTopics().topics.allSatisfy { $0.game == .alphaStrike })
        #expect(try catalog.classicRulesTopics().topics.allSatisfy { $0.game == .classic })
        #expect(try catalog.sharedRulesTopics().topics.allSatisfy { $0.game == .both })
    }

    @Test("Topic ids are unique across both games")
    func uniqueIds() throws {
        let ids = try catalog.rulesLibrary().allTopics.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Both games have their own topics", arguments: LearningTrack.allCases)
    func bothGamesHaveTopics(game: LearningTrack) throws {
        let topics = try catalog.rulesLibrary().topics(for: game)
        #expect(topics.filter { $0.game == RulesGameTag(game) }.count >= 8)
    }

    @Test("How the two games differ shows for both games", arguments: LearningTrack.allCases)
    func differencesReachable(game: LearningTrack) throws {
        let topics = try catalog.rulesLibrary().topics(for: game)
        #expect(topics.contains { $0.id == "differences" })
    }

    @Test("No topic from the other game leaks in")
    func noCrossover() throws {
        let library = try catalog.rulesLibrary()
        #expect(!library.topics(for: .alphaStrike).contains { $0.game == .classic })
        #expect(!library.topics(for: .classic).contains { $0.game == .alphaStrike })
    }

    @Test("Classic topics cover the requested rules")
    func classicCoverage() throws {
        let ids = Set(try catalog.classicRulesTopics().topics.map(\.id))
        for id in ["classic-turn", "classic-movement", "classic-to-hit", "classic-damage", "classic-heat",
                   "classic-piloting", "classic-criticals", "classic-physical", "classic-quickstart"] {
            #expect(ids.contains(id), "missing \(id)")
        }
    }

    @Test("Classic says it isn’t playable yet and cites printed pages")
    func classicNotPlayableAndCited() throws {
        let pack = try catalog.classicRulesTopics()
        let text = pack.topics.flatMap { $0.sections.map(\.body) }.joined(separator: "\n")
        #expect(text.contains("isn’t playable in Mech Buddy yet"))
        #expect(pack.disclaimer?.contains("isn’t playable") == true)
        for topic in pack.topics where topic.id != "classic-about" {
            let body = topic.sections.map(\.body).joined()
            #expect(body.contains("p. ") || body.contains("pp. "), "\(topic.id) cites no page")
        }
    }

    @Test("Alpha Strike topics cover the rules the app now plays")
    func alphaStrikeCoverage() throws {
        let text = try catalog.rulesTopics().topics
            .flatMap { [$0.title] + $0.sections.flatMap { [$0.heading, $0.body] } }
            .joined(separator: "\n")
        for phrase in ["JMPW", "JMPS", "MP hit", "natural 12", "CASE", "Bases touching", "0 damage",
                       "Done shooting", "Size", "Forced Withdrawal", "HT", "shut down", "p. 35"] {
            #expect(text.contains(phrase), "missing \(phrase)")
        }
    }

    @Test("Copy uses curly apostrophes")
    func curlyApostrophes() throws {
        for topic in try catalog.rulesLibrary().allTopics {
            let parts = [topic.title, topic.summary ?? ""] + topic.sections.flatMap { [$0.heading, $0.body] }
            for part in parts {
                #expect(!part.contains("'"), "\(topic.id): straight apostrophe in \(part.prefix(40))")
                #expect(!part.contains("'Mech"), "\(topic.id): 'Mech")
            }
        }
    }

    @Test("Disclaimers follow the game")
    func disclaimers() throws {
        let library = try catalog.rulesLibrary()
        #expect(library.disclaimer(for: .alphaStrike)?.contains("Alpha Strike") == true)
        #expect(library.disclaimer(for: .classic)?.contains("A Game of Armored Combat") == true)
    }
}

@Suite("Rules game choice")
struct RulesGameChoiceTests {
    @Test("Nothing chosen opens on Alpha Strike")
    func defaultsToAlphaStrike() {
        #expect(RulesGameChoice.initial(lastViewed: nil, onboarding: nil) == .alphaStrike)
    }

    @Test("Follows the game picked in onboarding", arguments: LearningTrack.allCases)
    func followsOnboarding(game: LearningTrack) {
        #expect(RulesGameChoice.initial(lastViewed: nil, onboarding: game) == game)
    }

    @Test("The last game picked on the Rules tab wins over onboarding")
    func lastViewedWins() {
        #expect(RulesGameChoice.initial(lastViewed: .alphaStrike, onboarding: .classic) == .alphaStrike)
        #expect(RulesGameChoice.initial(lastViewed: .classic, onboarding: .alphaStrike) == .classic)
        #expect(RulesGameChoice.initial(lastViewed: .classic, onboarding: nil) == .classic)
    }

    @Test("Tags show in the right games")
    func tagFiltering() {
        #expect(RulesGameTag.both.appears(in: .alphaStrike))
        #expect(RulesGameTag.both.appears(in: .classic))
        #expect(RulesGameTag.alphaStrike.appears(in: .alphaStrike))
        #expect(!RulesGameTag.alphaStrike.appears(in: .classic))
        #expect(RulesGameTag.classic.appears(in: .classic))
        #expect(!RulesGameTag.classic.appears(in: .alphaStrike))
    }

    @Test("Untagged topics from older packs count as Alpha Strike")
    func untaggedIsAlphaStrike() {
        let old = RulesTopicDTO(id: "old", title: "Old", sections: [])
        let library = RulesLibrary(packs: [
            RulesTopicsDTO(schemaVersion: 1, contentVersion: "0", disclaimer: nil, topics: [old])
        ])
        #expect(library.topics(for: .alphaStrike).map(\.id) == ["old"])
        #expect(library.topics(for: .classic).isEmpty)
    }

    @Test("Short titles for the switch")
    func shortTitles() {
        #expect(RulesGameChoice.shortTitle(.alphaStrike) == "Alpha Strike")
        #expect(RulesGameChoice.shortTitle(.classic) == "Classic")
    }
}

private final class RulesBundleToken {}

@Suite("Lore content")
struct LoreContentTests {
    @Test("The bundled lore file decodes and has eras with sub-eras")
    func decodes() throws {
        let lore = try BundleContentCatalogRepository(bundle: Bundle(for: RulesBundleToken.self)).lore()
        #expect(!lore.summary.onParagraph.isEmpty)
        #expect(lore.eras.count >= 7)
        #expect(lore.eras.allSatisfy { !$0.subEras.isEmpty && !$0.yearLabel.isEmpty })
        #expect(Set(lore.eras.map(\.id)).count == lore.eras.count)
    }

    @Test("Timeline is sorted by start year, undated events last")
    func timelineOrder() throws {
        let lore = try BundleContentCatalogRepository(bundle: Bundle(for: RulesBundleToken.self)).lore()
        let years = lore.timeline.compactMap(\.startYear)
        #expect(years == years.sorted())
        #expect(lore.timeline.count == lore.data.events.count)
    }
}
