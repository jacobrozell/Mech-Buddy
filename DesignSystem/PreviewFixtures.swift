import Foundation
import MechBuddyDomain

#if DEBUG
enum PreviewFixtures {
    static let shadowHawk = MatchUnitState(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        name: "Shadow Hawk SHD-2H",
        side: .lanceA,
        pv: 28,
        sz: 2,
        mv: "10\"/6\"j",
        tmm: 2,
        s: 2,
        m: 2,
        l: 1,
        ov: 0,
        armorCap: 5,
        structureCap: 3,
        armorDamage: 2,
        abilities: "ENE"
    )

    static let locust = MatchUnitState(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
        name: "Locust LCT-1V",
        side: .lanceB,
        pv: 18,
        sz: 1,
        mv: "16\"",
        tmm: 3,
        s: 1,
        m: 1,
        l: 0,
        ov: 0,
        armorCap: 2,
        structureCap: 2,
        armorDamage: 1
    )

    static func session(phase: PhaseId = .combat, turn: Int = 3) -> MatchSession {
        MatchSession(
            scenarioId: .ridgeLine,
            ruleset: .ridgeLine,
            turn: turn,
            phase: phase,
            activeSide: .lanceA,
            units: [shadowHawk, locust],
            tableReady: true,
            forcesLoaded: true,
            deploymentAcknowledged: true
        )
    }
}
#endif
