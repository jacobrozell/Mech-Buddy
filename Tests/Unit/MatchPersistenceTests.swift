import Foundation
import Testing
import SwiftData
import MechBuddyData
import MechBuddyDomain

@Suite("SwiftData match persistence")
@MainActor
struct MatchPersistenceTests {
    @Test("Round-trip active session and resume fields")
    func roundTrip() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let repo = SwiftDataMatchSessionRepository(container: container)

        var session = MatchSession(
            modeId: .alphaStrike,
            scenarioId: .ridgeLine,
            ruleset: .ridgeLine,
            turn: 2,
            phase: .combat,
            activeSide: .lanceB,
            initiativeWinner: .lanceA,
            units: [
                MatchUnitState(
                    name: "Shadow Hawk SHD-2H",
                    side: .lanceA,
                    pv: 30,
                    sz: 2,
                    mv: "10\"",
                    tmm: 2,
                    s: 2,
                    m: 2,
                    l: 1,
                    ov: 0,
                    armorCap: 5,
                    structureCap: 5,
                    armorDamage: 2
                )
            ],
            status: .active,
            tableReady: true,
            forcesLoaded: true,
            diceMode: .auto
        )

        try repo.save(session)
        let loaded = try #require(try repo.loadActive(mode: .alphaStrike))
        #expect(loaded.id == session.id)
        #expect(loaded.turn == 2)
        #expect(loaded.phase == .combat)
        #expect(loaded.activeSide == .lanceB)
        #expect(loaded.initiativeWinner == .lanceA)
        #expect(loaded.units.first?.armorDamage == 2)
        #expect(loaded.tableReady == true)
        #expect(loaded.diceMode == .auto)
        #expect(loaded.schemaVersion == MatchSession.currentSchemaVersion)

        var prior = session
        prior.recoverySnapshots = []
        prior.turn = 1
        session.recoverySnapshots = [prior]
        try repo.save(session)
        let withUndo = try #require(try repo.loadActive(mode: .alphaStrike))
        #expect(withUndo.recoverySnapshots.count == 1)
        #expect(withUndo.recoverySnapshots.first?.turn == 1)

        session.status = .abandoned
        try repo.save(session)
        #expect(try repo.loadActive(mode: .alphaStrike) == nil)
    }

    @Test("A future payload schema is set aside so a new game can start")
    func futureSchemaIsSetAside() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let repo = SwiftDataMatchSessionRepository(container: container)
        let future = MatchSession(
            schemaVersion: MatchSession.currentSchemaVersion + 1,
            ruleset: .ridgeLine,
            status: .active,
            tableReady: true,
            forcesLoaded: true
        )
        try repo.save(future)
        #expect(try repo.loadActive(mode: .alphaStrike) == nil)
        #expect(repo.unreadableSessionIDs == [future.id])
        try expectRowStatus(id: future.id, status: "unreadable", in: container)

        let fresh = MatchSession(
            ruleset: .ridgeLine,
            status: .active,
            tableReady: true,
            forcesLoaded: true
        )
        try repo.save(fresh)
        let loaded = try #require(try repo.loadActive(mode: .alphaStrike))
        #expect(loaded.id == fresh.id)
    }

    @Test("A garbage payload is set aside so a new game can start")
    func garbagePayloadIsSetAside() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let id = UUID()
        let context = ModelContext(container)
        context.insert(
            SDMatchSession(
                id: id,
                modeId: GameModeId.alphaStrike.rawValue,
                scenarioId: nil,
                statusRaw: MatchStatus.active.rawValue,
                turn: 1,
                phaseRaw: PhaseId.initiative.rawValue,
                activeSideRaw: SideId.lanceA.rawValue,
                payload: Data("garbage".utf8),
                updatedAt: Date()
            )
        )
        try context.save()

        let repo = SwiftDataMatchSessionRepository(container: container)
        #expect(try repo.loadActive(mode: .alphaStrike) == nil)
        #expect(repo.unreadableSessionIDs == [id])
        try expectRowStatus(id: id, status: "unreadable", in: container)

        let fresh = MatchSession(
            ruleset: .ridgeLine,
            status: .active,
            tableReady: true,
            forcesLoaded: true
        )
        try repo.save(fresh)
        let loaded = try #require(try repo.loadActive(mode: .alphaStrike))
        #expect(loaded.id == fresh.id)
    }

    private func expectRowStatus(id: UUID, status: String, in container: ModelContainer) throws {
        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<SDMatchSession>())
        let row = try #require(rows.first { $0.id == id })
        #expect(row.statusRaw == status)
    }

    @Test("In-memory repository keeps newest active")
    func inMemory() throws {
        let repo = InMemoryMatchSessionRepository()
        let older = MatchSession(
            ruleset: .ridgeLine,
            turn: 1,
            phase: .initiative,
            status: .active,
            tableReady: true,
            forcesLoaded: true,
            updatedAt: Date().addingTimeInterval(-60)
        )
        let newer = MatchSession(
            ruleset: .ridgeLine,
            turn: 3,
            phase: .movement,
            status: .active,
            tableReady: true,
            forcesLoaded: true,
            updatedAt: Date()
        )
        try repo.save(older)
        try repo.save(newer)
        let loaded = try #require(try repo.loadActive(mode: .alphaStrike))
        #expect(loaded.turn == 3)
    }

    @Test("deleteAll removes the active session")
    func deleteAll() throws {
        let repo = InMemoryMatchSessionRepository()
        let session = MatchSession(
            ruleset: .ridgeLine,
            status: .active,
            tableReady: true,
            forcesLoaded: true
        )
        try repo.save(session)
        #expect(try repo.loadActive(mode: .alphaStrike) != nil)
        try repo.deleteAll()
        #expect(try repo.loadActive(mode: .alphaStrike) == nil)
    }

    @Test("Deleting a set-aside save forgets its id")
    func deleteForgetsUnreadableID() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let older = UUID()
        let newer = UUID()
        for (id, age) in [(older, -60.0), (newer, 0.0)] {
            context.insert(
                SDMatchSession(
                    id: id,
                    modeId: GameModeId.alphaStrike.rawValue,
                    scenarioId: nil,
                    statusRaw: MatchStatus.active.rawValue,
                    turn: 1,
                    phaseRaw: PhaseId.initiative.rawValue,
                    activeSideRaw: SideId.lanceA.rawValue,
                    payload: Data("garbage".utf8),
                    updatedAt: Date().addingTimeInterval(age)
                )
            )
        }
        try context.save()

        let repo = SwiftDataMatchSessionRepository(container: container)
        #expect(try repo.loadActive(mode: .alphaStrike) == nil)
        #expect(Set(repo.unreadableSessionIDs) == Set([older, newer]))

        try repo.delete(id: older)
        #expect(repo.unreadableSessionIDs == [newer])

        try repo.deleteAll()
        #expect(repo.unreadableSessionIDs.isEmpty)
    }
}
