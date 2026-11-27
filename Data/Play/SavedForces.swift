import Foundation
import MechBuddyDomain

// Saving a Play side as a named force and loading it back (PlayModeSpec § 5.3, § 12).

public enum SavedForces {
    /// Copies the side's picks and any hand-entered cards they use.
    public static func make(name: String, setup: PlaySetup, side: SideId, library: CardLibrary, now: Date = Date()) -> SavedForce {
        let picks = setup.force(side)
        let cards = picks.compactMap { library.face(id: $0.cardId) }.filter(\.isUserCard)
        var seen = Set<String>()
        return SavedForce(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: now,
            picks: picks,
            cards: cards.filter { seen.insert($0.id).inserted }
        )
    }

    /// A pick's card is in the library (bundled and checked, or a user card).
    public static func isPlayable(_ pick: ForcePick, library: CardLibrary) -> Bool {
        library.face(id: pick.cardId)?.isChecked ?? false
    }

    public struct LoadResult: Equatable, Sendable {
        public var added: Int
        /// Picks left out: card no longer available, or no room (10 per side, 24 in the game).
        public var skipped: Int

        public init(added: Int, skipped: Int) {
            self.added = added
            self.skipped = skipped
        }
    }

    /// Replaces `side`'s force with the saved picks. New pick ids; skill clamped to what this setup offers;
    /// controller tags dropped when the side has fewer players. Call after restoring the force's own cards
    /// into the library.
    @discardableResult
    public static func load(_ force: SavedForce, into setup: inout PlaySetup, side: SideId, library: CardLibrary) -> LoadResult {
        setup.forces[side] = []
        let players = setup.sides.first { $0.id == side }?.players.count ?? 1
        var added = 0
        var skipped = 0
        for saved in force.picks {
            guard isPlayable(saved, library: library),
                  setup.force(side).count < PlaySetup.maxUnitsPerSide,
                  setup.unitCount < PlaySetup.maxUnitsPerGame else {
                skipped += 1
                continue
            }
            var pick = saved
            pick.id = UUID()
            // A MechWarrior card is [HOUSE] and one a side: it comes along only when this game uses cards.
            if !setup.rules.mechWarriorCards || setup.force(side).contains(where: { $0.pilotName != nil }) { pick.pilotName = nil }
            let range = PlayUnits.skillRange(for: pick, setup: setup)
            pick.skill = min(max(pick.skill, range.lowerBound), range.upperBound)
            if let tag = pick.controllerIndex, tag >= players || players == 1 { pick.controllerIndex = nil }
            setup.forces[side, default: []].append(pick)
            added += 1
        }
        return LoadResult(added: added, skipped: skipped)
    }
}
