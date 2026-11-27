import Foundation
import MechBuddyDomain

// Play mode setup helpers that need content (PlayModeSpec § 5.3, § 5.4, § 10).

/// Builds a Play game's ’Mechs from the setup and the card library.
public enum PlayUnits {
    /// One unit per pick, with the pick's skill. Faces without checked numbers are skipped:
    /// Play only uses checked faces (§ 10 checking rule).
    public static func make(setup: PlaySetup, library: CardLibrary) -> [MatchUnitState] {
        var units: [MatchUnitState] = []
        for side in setup.sides.map(\.id) {
            for pick in setup.force(side) {
                guard let face = library.face(id: pick.cardId), let dto = face.scenarioUnit(skill: pick.skill) else { continue }
                var unit = GuidedScenarioFactory.mapUnit(dto, side: side)
                unit.controller = setup.controllerName(of: pick, side: side)
                unit.isClan = pick.isClan
                units.append(unit)
            }
        }
        return units
    }

    /// A new pick for this face at its card skill (Clan 3, else 4). Nil for a face without checked numbers.
    public static func pick(_ face: CardFaceDTO) -> ForcePick? {
        guard face.isChecked, let pv = face.pv else { return nil }
        return ForcePick(
            cardId: face.id,
            name: face.name,
            basePV: pv,
            size: face.sz,
            skill: face.defaultSkill,
            isClan: face.techBase == .clan
        )
    }

    /// The same pick on another face of the card ("LCT-7V ⇄ LCT-3M"), keeping its id and skill.
    public static func switchFace(_ pick: ForcePick, to face: CardFaceDTO) -> ForcePick? {
        guard var next = Self.pick(face) else { return nil }
        next.id = pick.id
        next.skill = pick.skill
        next.controllerIndex = pick.controllerIndex
        return next
    }

    /// Skills offered for a pick (§ 5.2, D7): the card skill down to the setup's best skill when
    /// better skills are allowed. Worse than 4 is never offered.
    public static func skillRange(for pick: ForcePick, setup: PlaySetup) -> ClosedRange<Int> {
        let card = ForcePick.defaultSkill(isClan: pick.isClan)
        guard setup.allowImprovedSkills else { return card...card }
        return min(setup.minimumSkill, card)...4
    }

    /// Picks with skills reset to the card skill, for when better skills are turned off.
    public static func resetSkills(_ setup: inout PlaySetup) {
        for side in setup.forces.keys {
            setup.forces[side] = setup.forces[side]?.map { pick in
                var copy = pick
                let range = skillRange(for: pick, setup: setup)
                copy.skill = min(max(pick.skill, range.lowerBound), range.upperBound)
                return copy
            }
        }
    }

    /// A rough length, from the number of ’Mechs (§ 5.2). A guide, not a rule.
    public static func estimatedMinutes(units: Int) -> Int {
        let raw = 30 + 12 * max(units, 2)
        return Int((Double(raw) / 15).rounded()) * 15
    }
}

/// Chassis the player owns, with their card faces (unit picker "Your minis").
public struct OwnedChassis: Identifiable, Equatable, Sendable {
    public var chassis: String
    public var owned: Int
    public var faces: [CardFaceDTO]
    public var id: String { chassis.lowercased() }
}

public enum PlayPicker {
    /// Owned chassis in collection order, each with its library faces. Chassis without a face are left out.
    public static func ownedChassis(collection: OwnedCollection?, boxes: [BoxSetDTO], library: CardLibrary) -> [OwnedChassis] {
        guard let collection else { return [] }
        let counts = CollectionMath.chassisCounts(collection, boxes: boxes)
        var seen = Set<String>()
        var result: [OwnedChassis] = []
        for unit in CollectionMath.ownedUnits(collection, boxes: boxes) {
            let name = UnitChassis.name(unit.name)
            let key = name.lowercased()
            guard seen.insert(key).inserted else { continue }
            let faces = library.faces(chassis: name)
            guard !faces.isEmpty else { continue }
            result.append(OwnedChassis(chassis: faces[0].chassis, owned: counts[key] ?? unit.have, faces: faces))
        }
        return result
    }

    /// Minis of this chassis left after every side's picks. Negative means stand-ins are needed.
    public static func left(of chassis: String, owned: Int, setup: PlaySetup) -> Int {
        let used = setup.forces.values.joined().filter { UnitChassis.matches($0.name, chassis) }.count
        return owned - used
    }

    /// Every face, grouped by box in `boxes` order (§ 5.3 "All cards in the app").
    public static func allCards(boxes: [BoxSetDTO], library: CardLibrary) -> [(box: BoxSetDTO, faces: [CardFaceDTO])] {
        boxes.compactMap { box in
            let faces = library.faces(box: box.id)
            return faces.isEmpty ? nil : (box, faces)
        }
    }

    /// Search and filters (§ 5.3): name or chassis, Size, Clan / Inner Sphere.
    public static func matches(_ face: CardFaceDTO, query: String, size: Int?, techBase: CardTechBase?) -> Bool {
        if let size, face.sz != size { return false }
        if let techBase, face.techBase != techBase { return false }
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return true }
        return face.name.localizedCaseInsensitiveContains(text) || face.chassis.localizedCaseInsensitiveContains(text)
    }

    /// The mission sheet's minis line for every side (§ 5.6).
    public static func miniCheck(setup: PlaySetup, collection: OwnedCollection?, boxes: [BoxSetDTO], standIns: [String: [String]]) -> MiniCheck? {
        guard let collection else { return nil }
        let names = setup.sides.flatMap { setup.force($0.id).map(\.name) }
        return CollectionMath.miniCheck(forces: names, collection: collection, boxes: boxes, standIns: standIns)
    }
}

/// The table drawing for a Play game (§ 5.4): sheets or a mat, each side's home edge and zone.
public enum PlayLayout {
    /// Deployment depth from the home edge, inches (p. 11, "within 6 inches").
    public static let zoneDepth = BoardZones.zoneDepth

    /// Three or four sides use the middle 3/8 of their edge **[HOUSE]** (§ 6.4): 18″ on a 48″ edge.
    public static let houseZoneShare = BoardZones.houseZoneShare

    /// What the table looks like for this game: the built board with zones for the game's sides, or the
    /// generated mat / mapsheet layout without terrain (PM12, § 5.4).
    public static func board(for battlefield: Battlefield, sides: [MatchSide] = []) -> BoardLayout {
        guard var board = battlefield.board else {
            return BoardLayout(layout(for: battlefield, sides: sides))
        }
        let count = max(sides.count, 2)
        if let stored = board.zonesBySideCount?[count], !stored.isEmpty {
            board.zones = stored
        } else if count == 2, !board.zones.isEmpty, sides.allSatisfy({ $0.homeEdge == nil || [.west, .east].contains($0.homeEdge) }) {
            // The board's own two-side zones (a mission's, or ones the builder stored).
        } else {
            board.zones = zones(width: board.width, depth: board.depth, sides: sides).map { BoardLayout.Zone(side: $0.side, area: .init($0.area)) }
        }
        board.zonesBySideCount = nil
        return board
    }

    /// `sides` carries each side's home edge. Without it the layout is the two-side table (west, east).
    public static func layout(for battlefield: Battlefield, sides: [MatchSide] = []) -> MissionLayoutDTO {
        let width = battlefield.width
        let depth = battlefield.depth
        var sheets: [MissionLayoutDTO.Sheet] = []
        if battlefield.kind == .mapsheets {
            let grid = battlefield.arrangement.grid
            var index = 0
            for row in 0..<grid.rows {
                for column in 0..<grid.columns {
                    let name = battlefield.sheets.indices.contains(index) ? battlefield.sheets[index] : "Sheet \(index + 1)"
                    sheets.append(MissionLayoutDTO.Sheet(
                        name: name,
                        area: .init(
                            x: Double(column) * MapArrangement.sheetWidth,
                            y: Double(row) * MapArrangement.sheetDepth,
                            width: MapArrangement.sheetWidth,
                            depth: MapArrangement.sheetDepth
                        )
                    ))
                    index += 1
                }
            }
        }
        return MissionLayoutDTO(
            width: width,
            depth: depth,
            sheets: sheets,
            zones: zones(width: width, depth: depth, sides: sides),
            features: [],
            openTable: battlefield.summary
        )
    }

    /// One zone per side on its home edge, 6″ deep. Two sides take the full edge (p. 11); three or four take
    /// the middle 3/8 of it so neighbouring zones stay apart **[HOUSE]**.
    static func zones(width: Double, depth: Double, sides: [MatchSide]) -> [MissionLayoutDTO.Zone] {
        // Same rule as `BoardZones.generate`, with each side's own home edge.
        let seats = sides.isEmpty
            ? [(letter: "A", edge: TableEdge.west), (letter: "B", edge: .east)]
            : sides.enumerated().map { index, side in
                (letter: side.id.letter, edge: side.homeEdge ?? PlaySetup.defaultHomeEdges(sideCount: 4)[index])
            }
        let narrow = seats.count > 2
        return seats.map { seat in
            let vertical = seat.edge == .west || seat.edge == .east
            let edgeLength = vertical ? depth : width
            let band = narrow ? edgeLength * houseZoneShare : edgeLength
            let offset = (edgeLength - band) / 2
            let thick = min(zoneDepth, (vertical ? width : depth) / 3)
            let area: MissionLayoutDTO.Rect
            switch seat.edge {
            case .west: area = .init(x: 0, y: offset, width: thick, depth: band)
            case .east: area = .init(x: width - thick, y: offset, width: thick, depth: band)
            case .north: area = .init(x: offset, y: 0, width: band, depth: thick)
            case .south: area = .init(x: offset, y: depth - thick, width: band, depth: thick)
            }
            return .init(side: seat.letter, area: area)
        }
    }

    /// "How you win" on the briefing (§ 7.1). Last side standing without an objective.
    public static func winningSummary(for setup: PlaySetup) -> String {
        guard let objective = setup.objectiveId, objective.isBuilt else { return "Destroy every enemy ’Mech" }
        var line = "\(objective.title): \(objective.summary) First to \(ObjectiveRules.format(objective.baseThreshold)) points wins (\(objective.page))."
        if let limit = setup.turnLimit { line += " At turn \(limit), most points wins, then most PV [HOUSE]." }
        return line
    }

    /// Table setup checklist for a Play game (§ 8.1, p. 8, p. 11). Three or four sides use house rules (§ 5.4, D29).
    public static func tableSteps(for setup: PlaySetup) -> [String] {
        let house = setup.usesHouseRules
        var steps = [
            "Lay out the battlefield: \(setup.battlefield.summary)",
            "Each side rolls 2D6. The higher roll places terrain first"
        ]
        if house {
            steps.append("[HOUSE] Each side picks 6 pieces of terrain and places them in setup-roll order, one at a time. None inside a deployment zone, and none within 4″ of another unless they form one woods area")
            steps.append("[HOUSE] Home edges, highest setup roll first: one edge each, a zone in the middle 3/8 of the edge, 6″ deep")
        } else {
            steps.append("Each side picks 8 pieces of terrain and places them in turn: 4 toward the enemy, 2 toward its own edge, 2 near the centre line")
        }
        if let objective = setup.objectiveId, objective.isBuilt, let placing = objective.setupStep {
            steps.append("Objective (\(objective.page)): " + placing)
        }
        if setup.rules.startOnTable {
            steps.append(house
                ? "[HOUSE] The setup winner chooses to deploy first or last, then sides place one ’Mech at a time in setup-roll order within their zone"
                : "The setup winner chooses to deploy first or last, then sides place one ’Mech at a time within 6″ of their home edge")
        } else {
            steps.append("Leave the ’Mechs off the table. On Turn 1 they enter from their home edge")
        }
        return steps
    }
}
