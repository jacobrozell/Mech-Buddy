import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

@Suite("Content catalog")
struct ContentCatalogTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: BundleToken.self))
    }

    @Test("Loads ridge line and builds units")
    func ridgeLine() throws {
        let scenario = try catalog.ridgeLineScenario()
        #expect(scenario.scenarioId == "ridge-line")
        let units = RidgeLineFactory.makeUnits(from: scenario)
        #expect(units.count == 4)
        #expect(units.filter { $0.side == .lanceA }.count == 2)
        let hawk = try #require(units.first { $0.name.contains("Shadow Hawk") })
        #expect(hawk.armorCap == 5)
        #expect(hawk.structureCap == 5)
        #expect(hawk.skill == 4)
    }

    @Test("Manifest includes alpha-strike")
    func manifest() throws {
        let manifest = try catalog.gameModesManifest()
        #expect(manifest.modes.contains { $0.id == "alpha-strike" })
    }

    @Test("Crit table has 11 entries")
    func crits() throws {
        let table = try catalog.critTable()
        #expect(table.entries.count == 11)
    }

    @Test("Crit table JSON matches AlphaStrikeCriticals map")
    func critTableParity() throws {
        let table = try catalog.critTable()
        for entry in table.entries {
            let id = AlphaStrikeCriticals.resultId(forTotal: entry.roll)
            #expect(id.rawValue == entry.id, "roll \(entry.roll)")
            #expect(AlphaStrikeCriticals.title(for: id) == entry.title, "roll \(entry.roll)")
        }
    }

    @Test("Rules topics non-empty")
    func rules() throws {
        let topics = try catalog.rulesTopics()
        #expect(topics.topics.count >= 8)
    }
}

private final class BundleToken {}
