import Foundation
import MechBuddyDomain

/// Shots this turn, ordered by the combat event that recorded them.
/// Matches the full log sentence. A name-only prefix collides when one name starts another.
enum ShotFeed {
    struct Row: Identifiable, Equatable {
        var unitID: UUID
        var shooter: String
        var shot: TurnShot
        var order: Int

        var id: UUID { unitID }
    }

    static func rows(in session: MatchSession) -> [Row] {
        session.units.enumerated().compactMap { offset, unit in
            guard let shot = unit.turnShot else { return nil }
            let sentence = signature(shooter: unit.name, shot: shot)
            let order = session.eventLog.lastIndex {
                $0.turn == session.turn && $0.phase == .combat && $0.message.contains(sentence)
            } ?? (10_000 + offset)
            return Row(unitID: unit.id, shooter: unit.name, shot: shot, order: order)
        }
        .sorted { lhs, rhs in
            if lhs.order == rhs.order { return lhs.shooter < rhs.shooter }
            return lhs.order < rhs.order
        }
    }

    static func signature(shooter: String, shot: TurnShot) -> String {
        if shot.hit {
            return "\(shooter) hit \(shot.targetName) for \(shot.damage). Rolled \(shot.total), needed \(shot.targetNumber)."
        }
        return "\(shooter) missed \(shot.targetName). Rolled \(shot.total), needed \(shot.targetNumber)."
    }
}
