import Foundation

/// The Alpha Strike box's extra rules for one match: Battlefield Support, Formations and buildings
/// (Quick-Start Rulebook pp. 28–32). Nil for missions that don't use them.
public struct BoxRulesState: Codable, Sendable, Equatable {
    /// Each side's secret purchase (p. 29). Missing side: no support.
    public var support: [SideId: SupportInventory]
    public var formations: [FormationState]
    public var buildings: [BuildingState]
    /// Targets of a Combat Intuition attack, with the turn. Their damage effects apply at once (p. 32).
    public var combatIntuitionTargets: [UUID: Int]

    public init(
        support: [SideId: SupportInventory] = [:],
        formations: [FormationState] = [],
        buildings: [BuildingState] = [],
        combatIntuitionTargets: [UUID: Int] = [:]
    ) {
        self.support = support
        self.formations = formations
        self.buildings = buildings
        self.combatIntuitionTargets = combatIntuitionTargets
    }

    public func formation(_ id: String) -> FormationState? {
        formations.first { $0.id == id }
    }

    /// The Formation a 'Mech belongs to, of that kind.
    public func formation(of unitId: UUID, kind: FormationKind) -> FormationState? {
        formations.first { $0.kind == kind && $0.memberIds.contains(unitId) }
    }

    public func building(_ id: String) -> BuildingState? {
        buildings.first { $0.id == id }
    }

    /// The same state with sides renamed (Swap sides). Formations follow their 'Mechs, so only support moves.
    public func mapSides(_ transform: (SideId) -> SideId) -> BoxRulesState {
        var copy = self
        copy.support = Dictionary(uniqueKeysWithValues: support.map { (transform($0.key), $0.value) })
        return copy
    }
}
