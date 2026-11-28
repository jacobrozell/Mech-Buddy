import Foundation
import MechBuddyDomain

/// The rules behind the setup flow's footer and navigation: which steps can move on, why Start is blocked,
/// which side is over budget, and how the setup is tidied before the game starts. `PlaySetupFlowView` owns the state.
enum PlaySetupRules {
    /// Continue is disabled until Players and sides is valid, and until every side has a ’Mech.
    static func isContinueDisabled(step: PlaySetupStep, setup: PlaySetup) -> Bool {
        (step == .sides && !setup.teamIssues.isEmpty)
            || (step == .forces && setup.sides.contains { setup.force($0.id).isEmpty })
    }

    /// Why Start game is disabled on Review, or nil when the game can start.
    static func startBlockedReason(for setup: PlaySetup) -> String? {
        if let issue = setup.teamIssues.first { return PlaySidesStep.text(for: issue) }
        if let empty = setup.sides.first(where: { setup.force($0.id).isEmpty }) {
            return "\(empty.name) needs at least one ’Mech."
        }
        if setup.unitCount > PlaySetup.maxUnitsPerGame {
            return "Up to \(PlaySetup.maxUnitsPerGame) ’Mechs in one game."
        }
        return nil
    }

    /// Leaving Forces: the first side over its budget, which the player must confirm before moving on.
    static func overBudgetSide(in setup: PlaySetup) -> SideId? {
        setup.sides.first { setup.budgetCheck($0.id).isOver }?.id
    }

    /// "Side A is 12 PV over. Play anyway?"
    static func overBudgetTitle(side: SideId?, in setup: PlaySetup) -> String {
        guard let side else { return "" }
        let check = setup.budgetCheck(side)
        let name = setup.sides.first { $0.id == side }?.name ?? side.displayName
        return "\(name) is \(check.text). Play anyway?"
    }

    static func next(after step: PlaySetupStep) -> PlaySetupStep? { PlaySetupStep(rawValue: step.rawValue + 1) }

    static func previous(before step: PlaySetupStep) -> PlaySetupStep? { PlaySetupStep(rawValue: step.rawValue - 1) }

    /// The setup as the game starts it: side names trimmed, and an empty name falls back to "Side A".
    static func readyToStart(_ setup: PlaySetup) -> PlaySetup {
        var ready = setup
        for index in ready.sides.indices {
            let trimmed = ready.sides[index].name.trimmingCharacters(in: .whitespaces)
            ready.sides[index].name = trimmed.isEmpty ? ready.sides[index].id.displayName : trimmed
        }
        return ready
    }
}
