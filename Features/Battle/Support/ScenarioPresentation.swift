import Foundation
import MechBuddyData
import MechBuddyDomain

/// Briefing copy for the open mission. Cached on `MatchStore` so the battle screen does not decode JSON in `body`.
struct ScenarioPresentation: Equatable, Sendable {
    /// Scenario id, for per-mission choices such as swapped maps. Empty for the fallback.
    var id: String = ""
    var title: String
    var subtitle: String?
    var tableSteps: [String]
    var winningSummary: String?
    /// What this mission adds over the one before. Empty for Ridge Line, which keeps its first-night briefing.
    var introduces: [String] = []
    /// Coach tips for the new rules. Shown with `introduces`.
    var coachNotes: [String] = []
    /// Maps needed and the table diagram, when the pack has one.
    var layout: MissionLayoutDTO? = nil
    /// A terrain board built in Play (PM12): shown at table setup and from Board in battle.
    var board: BoardLayout? = nil

    static let fallback = ScenarioPresentation(
        title: "Ridge Line",
        subtitle: nil,
        tableSteps: [
            "Clear a table about 3 feet across",
            "Set out the four ’Mechs and their cards",
            "Have two six-sided dice and a tape measure ready"
        ],
        winningSummary: nil
    )
}
