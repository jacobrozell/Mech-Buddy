import Foundation
import MechBuddyData
import MechBuddyDomain

/// The mission catalog as the Play and Learn screens read it: what is playable, which mission is next,
/// the path's stops and the briefing eyebrow and subtitle. Pure data in, copy out; `PlayHomeView` owns the state.
struct MissionLadder {
    /// Every mission in the ladder, in order. Gated ones show as Coming soon.
    var items: [ScenarioCatalogItemDTO]
    /// Loaded mission packs by id. A mission with no pack here can't be started.
    var missions: [String: GuidedScenarioDTO]
    /// Scenario ids of missions already played to the end.
    var completed: Set<String>
    /// False when the release surface hides the first mission (nothing is featured then).
    var ridgeLineEnabled = true

    /// Missions the player can start now, in ladder order.
    var playable: [GuidedScenarioDTO] {
        items.filter { !$0.gated }.compactMap { missions[$0.id] }
    }

    /// The next mission to play: the first one not finished yet, else the last one.
    var featured: GuidedScenarioDTO? {
        guard ridgeLineEnabled else { return nil }
        return playable.first { !completed.contains($0.scenarioId) } ?? playable.last
    }

    /// The training path: catalog missions without a stage.
    var training: [ScenarioCatalogItemDTO] { items.filter { $0.stage == nil } }

    /// Later sections (book scenarios), in catalog order of their first mission.
    var staged: [(title: String, items: [ScenarioCatalogItemDTO])] {
        var order: [String] = []
        var grouped: [String: [ScenarioCatalogItemDTO]] = [:]
        for item in items {
            guard let stage = item.stage else { continue }
            if grouped[stage] == nil { order.append(stage) }
            grouped[stage, default: []].append(item)
        }
        return order.map { ($0, grouped[$0] ?? []) }
    }

    /// The training path's missions as stops.
    var stops: [MissionStop] { stops(for: training) }

    /// Missions as stops on a path, in ladder order.
    func stops(for items: [ScenarioCatalogItemDTO]) -> [MissionStop] {
        let next = featured?.scenarioId
        return items.enumerated().map { index, item in
            let state: MissionStop.State
            if item.gated || missions[item.id] == nil {
                state = .locked
            } else if completed.contains(item.id) {
                state = .cleared
            } else {
                state = item.id == next ? .next : .open
            }
            return MissionStop(
                id: item.id,
                number: item.missionNumber ?? index + 1,
                title: item.title,
                icon: item.icon ?? "scope",
                unlocks: item.introduces ?? [],
                comingSoon: item.comingSoonSummary,
                state: state,
                stage: item.stage
            )
        }
    }

    func eyebrow(for scenario: GuidedScenarioDTO) -> String {
        if let stage = items.first(where: { $0.id == scenario.scenarioId })?.stage {
            return stage
        }
        guard let number = scenario.missionNumber, number > 1 else { return "Beginner mission" }
        return "Mission \(number) of \(max(training.count, number))"
    }

    static func subtitle(for scenario: GuidedScenarioDTO) -> String {
        let size = "\(scenario.sides.lanceA.count) vs \(scenario.sides.lanceB.count)"
        if let minutes = scenario.estimatedMinutes {
            return "\(size) · about \(minutes) minutes"
        }
        return scenario.subtitle ?? size
    }

    /// The name of a mission: its pack, else its catalog entry, else Ridge Line.
    func title(for id: ScenarioId?) -> String {
        let key = (id ?? .ridgeLine).rawValue
        return missions[key]?.title ?? items.first { $0.id == key }?.title ?? "Ridge Line"
    }
}
