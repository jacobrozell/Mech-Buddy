import Foundation

/// Briefing copy for the open mission. Cached on `MatchStore` so the battle screen does not decode JSON in `body`.
struct ScenarioPresentation: Equatable, Sendable {
    var title: String
    var subtitle: String?
    var tableSteps: [String]
    var winningSummary: String?
    /// What this mission adds over the one before. Empty for Ridge Line, which keeps its first-night briefing.
    var introduces: [String] = []
    /// Coach tips for the new rules. Shown with `introduces`.
    var coachNotes: [String] = []

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
