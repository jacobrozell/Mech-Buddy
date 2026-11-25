// Tests for Data/Collection/CollectionModel.swift and as-box-sets.json.
// Spec: specs/features/RosterSpec.md § Your collection, specs/ContentPackSpec.md § Box sets
import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

@Suite("Box sets content")
struct BoxSetsContentTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: CollectionBundleToken.self))
    }

    @Test("Stand-ins name real box chassis, never the 'Mech they stand in for")
    func standInsAreBoxChassis() throws {
        let file = try catalog.boxSets()
        let standIns = try #require(file.standIns)
        let boxChassis = Set(file.boxes.flatMap(\.units).map(UnitChassis.key))
        #expect(standIns.count == 8)
        for (unit, options) in standIns {
            #expect(boxChassis.contains(UnitChassis.key(unit)), "\(unit)")
            #expect(!options.isEmpty, "\(unit)")
            for option in options {
                #expect(boxChassis.contains(UnitChassis.key(option)), "\(unit) → \(option)")
                #expect(!UnitChassis.matches(option, unit), "\(unit)")
            }
        }
    }

    @Test("The Alpha Strike box alone covers every mission, with stand-ins")
    func alphaStrikeBoxCoversEveryMission() throws {
        let file = try catalog.boxSets()
        let owned = OwnedCollection(boxes: ["alpha-strike-box": 1])
        for item in try catalog.scenarios().scenarios where !item.gated {
            let dto = try catalog.scenario(id: ScenarioId(rawValue: item.id))
            let forces = (dto.sides.lanceA + dto.sides.lanceB).map(\.name)
            let check = CollectionMath.miniCheck(
                forces: forces, collection: owned, boxes: file.boxes, standIns: file.standIns ?? [:]
            )
            #expect(check.hasAll, "\(item.id): \(check.summary)")
        }
    }

    @Test("A Game of Armored Combat lists the four maps its scenarios use")
    func agoacMaps() throws {
        let agoac = try #require(try catalog.boxSets().boxes.first { $0.id == "agoac" })
        #expect(agoac.maps == ["Desert #2", "Grassland #2", "Grassland #3", "Desert #3"])
        #expect(agoac.mapSheets == 2)
    }

    @Test("Boxes with known maps: Starter, Core and Mercenaries")
    func otherBoxMaps() throws {
        let boxes = try catalog.boxSets().boxes
        let maps = Dictionary(uniqueKeysWithValues: boxes.map { ($0.id, $0.maps ?? []) })
        #expect(maps["starter-box"]?.count == 2)
        #expect(maps["core-box"]?.count == 4)
        #expect(maps["mercenaries-box"]?.count == 4)
        #expect(maps["alpha-strike-box"]?.isEmpty == true)
    }

    @Test("Five boxes with unique ids, in catalog order")
    func ids() throws {
        let boxes = try catalog.boxSets().boxes
        #expect(boxes.map(\.id) == ["agoac", "alpha-strike-box", "starter-box", "core-box", "mercenaries-box"])
        #expect(Set(boxes.map(\.id)).count == boxes.count)
    }

    @Test("Confirmed boxes list exactly as many units as minis")
    func countsMatch() throws {
        for box in try catalog.boxSets().boxes where box.contentsConfirmed {
            #expect(box.units.count == box.miniCount, "\(box.id)")
            // Mercenaries has two Galleons and two Maxims; every other box lists each mini once.
            if box.id != "mercenaries-box" {
                #expect(Set(box.units).count == box.units.count, "\(box.id) lists a unit twice")
            }
        }
    }

    @Test("Mercenaries lists its 8 BattleMechs and 4 vehicles, 12 minis, needs A Game of Armored Combat")
    func mercenaries() throws {
        let mercs = try #require(try catalog.boxSets().boxes.first { $0.id == "mercenaries-box" })
        #expect(mercs.contentsConfirmed)
        #expect(mercs.units.count == 12)
        #expect(mercs.miniCount == 12)
        #expect(mercs.units.filter { $0 == "Galleon Light Tank" }.count == 2)
        #expect(mercs.units.filter { $0 == "Maxim Hover Tank" }.count == 2)
        #expect(Set(mercs.units).isSuperset(of: ["Chameleon", "Starslayer", "Caesar", "Devastator", "Flea", "Firefly", "Quickdraw", "Ostsol"]))
        #expect(mercs.requires == ["agoac"])
    }

    @Test("A Game of Armored Combat matches the box roster cards")
    func agoacMatchesRoster() throws {
        let agoac = try #require(try catalog.boxSets().boxes.first { $0.id == "agoac" })
        let roster = try catalog.boxRoster().cards.map(\.name)
        #expect(Set(agoac.units) == Set(roster))
        #expect(agoac.game == .both)
    }

    @Test("Every box has copy, a badge, and an https source")
    func copyAndSources() throws {
        let boxes = try catalog.boxSets().boxes
        let ids = Set(boxes.map(\.id))
        for box in boxes {
            #expect(!box.title.isEmpty, "\(box.id)")
            #expect(!box.subtitle.isEmpty && box.subtitle.count <= 48, "\(box.id) subtitle")
            #expect(!box.game.badge.isEmpty)
            let url = try #require(URL(string: box.sourceURL), "\(box.id)")
            #expect(url.scheme == "https", "\(box.id)")
            for required in box.requires ?? [] {
                #expect(ids.contains(required), "\(box.id) requires unknown \(required)")
            }
        }
    }

    @Test("Box file carries names only, never card numbers")
    func namesOnly() throws {
        let url = try #require(Bundle(for: CollectionBundleToken.self).url(
            forResource: "as-box-sets", withExtension: "json", subdirectory: "Content/AlphaStrike"
        ) ?? Bundle(for: CollectionBundleToken.self).url(
            forResource: "as-box-sets", withExtension: "json", subdirectory: "AlphaStrike"
        ))
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let boxes = try #require(json["boxes"] as? [[String: Any]])
        let statKeys: Set<String> = ["pv", "mv", "tmm", "sz", "s", "m", "l", "ov", "armor", "structure", "skill"]
        for box in boxes {
            #expect(Set(box.keys).isDisjoint(with: statKeys))
            #expect(box["units"] is [String])
        }
    }
}

@Suite("Chassis matching")
struct ChassisTests {
    @Test("Drops the variant code", arguments: [
        ("Locust LCT-1V", "Locust"),
        ("Shadow Hawk SHD-2H", "Shadow Hawk"),
        ("BattleMaster BLR-1G", "BattleMaster"),
        ("Locust", "Locust"),
        ("Mad Cat Mk II", "Mad Cat Mk II"),
        ("  Timber   Wolf ", "Timber Wolf")
    ])
    func name(input: String, expected: String) {
        #expect(UnitChassis.name(input) == expected)
    }

    @Test("Matches across variants and case")
    func matches() {
        #expect(UnitChassis.matches("Locust LCT-1V", "Locust"))
        #expect(UnitChassis.matches("locust", "Locust LCT-1E"))
        #expect(!UnitChassis.matches("Locust", "Commando COM-2D"))
        #expect(!UnitChassis.matches("", ""))
    }
}

@Suite("Collection derivation")
struct CollectionDerivationTests {
    private let agoac = BoxSetDTO(
        id: "agoac", title: "A Game of Armored Combat", subtitle: "", game: .both, miniCount: 3,
        units: ["Locust LCT-1V", "Commando COM-2D", "Catapult CPLT-C1"],
        sourceURL: "https://example.com", contentsConfirmed: true
    )
    private let asBox = BoxSetDTO(
        id: "alpha-strike-box", title: "Alpha Strike Box Set", subtitle: "", game: .alphaStrike, miniCount: 2,
        units: ["Locust", "Atlas"], sourceURL: "https://example.com", contentsConfirmed: true
    )
    private let mercs = BoxSetDTO(
        id: "mercenaries-box", title: "Mercenaries Box Set", subtitle: "", game: .classic, miniCount: 12,
        units: [], requires: ["agoac"], sourceURL: "https://example.com", contentsConfirmed: false
    )
    private var boxes: [BoxSetDTO] { [agoac, asBox, mercs] }

    @Test("An owned box gives every unit it lists")
    func boxUnits() {
        let owned = OwnedCollection(boxes: ["agoac": 1])
        let units = CollectionMath.ownedUnits(owned, boxes: boxes)
        #expect(units.map(\.name) == ["Locust LCT-1V", "Commando COM-2D", "Catapult CPLT-C1"])
        #expect(units.allSatisfy { $0.have == 1 })
    }

    @Test("Two copies of a box double the counts")
    func copies() {
        var owned = OwnedCollection()
        owned.setCopies(2, ofBox: "agoac")
        #expect(owned.have("Locust LCT-1V", in: agoac) == 2)
        #expect(CollectionMath.chassisCounts(owned, boxes: boxes)["locust"] == 2)
    }

    @Test("Marking a box unit missing removes it; ticking it again restores it")
    func missing() {
        var owned = OwnedCollection(boxes: ["agoac": 2])
        owned.setUnit("Catapult CPLT-C1", in: agoac, owned: false)
        #expect(owned.have("Catapult CPLT-C1", in: agoac) == 0)
        #expect(!CollectionMath.ownedUnits(owned, boxes: boxes).contains { $0.name == "Catapult CPLT-C1" })
        let group = CollectionMath.groups(owned, boxes: boxes).first
        #expect(group?.units.first { $0.name == "Catapult CPLT-C1" }?.isMissing == true)
        owned.setUnit("Catapult CPLT-C1", in: agoac, owned: true)
        #expect(owned.have("Catapult CPLT-C1", in: agoac) == 2)
        #expect(owned.missing.isEmpty)
    }

    @Test("Removing a box drops its missing marks")
    func removeBox() {
        var owned = OwnedCollection(boxes: ["agoac": 1])
        owned.setUnit("Locust LCT-1V", in: agoac, owned: false)
        owned.toggleBox("agoac")
        #expect(owned.boxes.isEmpty)
        #expect(owned.missing.isEmpty)
        owned.toggleBox("agoac")
        #expect(owned.have("Locust LCT-1V", in: agoac) == 1)
    }

    @Test("Singles add up and merge by name, ignoring case and spaces")
    func singles() {
        var owned = OwnedCollection.empty
        #expect(owned.addSingle("  Atlas ") == "Atlas")
        #expect(owned.addSingle("atlas") == "Atlas")
        #expect(owned.addSingle("   ") == nil)
        #expect(owned.singles == ["Atlas": 2])
        owned.setSingle("Atlas", copies: 0)
        #expect(owned.singles.isEmpty)
    }

    @Test("Groups: owned boxes in catalog order, then Singles; unconfirmed boxes show with no units")
    func groups() {
        let owned = OwnedCollection(boxes: ["mercenaries-box": 1, "agoac": 1], singles: ["Wasp": 1])
        let groups = CollectionMath.groups(owned, boxes: boxes)
        #expect(groups.map(\.id) == ["box.agoac", "box.mercenaries-box", "singles"])
        #expect(groups[1].units.isEmpty)
        #expect(groups[2].title == "Singles")
        #expect(groups[2].units.map(\.name) == ["Wasp"])
    }

    @Test("Same unit from a box and as a single merges in the owned list")
    func merged() {
        let owned = OwnedCollection(boxes: ["alpha-strike-box": 1], singles: ["Locust": 1])
        let locust = CollectionMath.ownedUnits(owned, boxes: boxes).first { $0.name == "Locust" }
        #expect(locust?.have == 2)
    }

    @Test("Boxes the catalog no longer has are ignored")
    func unknownBox() {
        let owned = OwnedCollection(boxes: ["gone": 1])
        #expect(CollectionMath.groups(owned, boxes: boxes).isEmpty)
    }

    @Test("None yet is recorded but empty")
    func noneYet() {
        #expect(OwnedCollection.empty.isEmpty)
        #expect(!OwnedCollection(singles: ["Atlas": 1]).isEmpty)
    }
}

@Suite("Maps")
struct CollectionMapsTests {
    private let boxA = BoxSetDTO(
        id: "a", title: "Box A", subtitle: "", game: .both, miniCount: 0, units: [],
        sourceURL: "https://example.com", contentsConfirmed: true, maps: ["Grasslands", "Desert Hills"]
    )
    private let boxB = BoxSetDTO(
        id: "b", title: "Box B", subtitle: "", game: .classic, miniCount: 0, units: [],
        sourceURL: "https://example.com", contentsConfirmed: true, maps: ["grasslands", "City Ruins"]
    )

    @Test("Owned boxes' maps come first, then maps added by hand, without repeats")
    func ownedMaps() {
        var owned = OwnedCollection(boxes: ["a": 1, "b": 1])
        owned.addMap("  Lunar   Base ")
        owned.addMap("city ruins")
        let maps = CollectionMath.ownedMaps(owned, boxes: [boxA, boxB])
        #expect(maps.map(\.name) == ["Grasslands", "Desert Hills", "City Ruins", "Lunar Base"])
        #expect(maps.map(\.boxTitle) == ["Box A", "Box A", "Box B", nil])
    }

    @Test("Boxes not owned add no maps")
    func notOwned() {
        let maps = CollectionMath.ownedMaps(OwnedCollection(boxes: ["b": 1]), boxes: [boxA, boxB])
        #expect(maps.map(\.name) == ["grasslands", "City Ruins"])
    }

    @Test("Adding a map trims, skips blanks and repeats; removing drops it")
    func addRemove() {
        var owned = OwnedCollection()
        #expect(owned.addMap("   ") == nil)
        #expect(owned.addMap("Lunar Base") == "Lunar Base")
        #expect(owned.addMap("LUNAR BASE") == nil)
        owned.removeMap("Lunar Base")
        #expect(owned.maps.isEmpty)
        #expect(owned.isEmpty)
    }

    @Test("Collections saved before maps decode with no maps")
    func legacyDecode() throws {
        let json = #"{"boxes":{"agoac":1},"missing":{},"singles":{"Atlas":1}}"#
        let decoded = try JSONDecoder().decode(OwnedCollection.self, from: Data(json.utf8))
        #expect(decoded.maps.isEmpty)
        #expect(decoded.boxes == ["agoac": 1])
        var withMap = decoded
        withMap.addMap("Grasslands")
        let round = try JSONDecoder().decode(OwnedCollection.self, from: JSONEncoder().encode(withMap))
        #expect(round == withMap)
    }
}

@Suite("Map catalog")
struct MapCatalogTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: CollectionBundleToken.self))
    }

    @Test("Loads, and every box's maps are in it")
    func boxMapsInCatalog() throws {
        let maps = try catalog.mapCatalog()
        #expect(maps.products.count >= 50)
        let known = Set(maps.allMaps.map { $0.lowercased() })
        for box in try catalog.boxSets().boxes {
            for name in box.maps ?? [] {
                #expect(known.contains(name.lowercased()), "\(box.id): \(name)")
            }
        }
    }

    @Test("Suggestions: two letters minimum, prefix matches first, capped")
    func suggestions() throws {
        let maps = try catalog.mapCatalog()
        #expect(maps.suggestions(for: "d").isEmpty)
        let desert = maps.suggestions(for: "desert")
        #expect(desert.count == 5)
        #expect(desert.allSatisfy { $0.lowercased().hasPrefix("desert") })
        #expect(maps.suggestions(for: "lunar base").contains("Lunar Base Map"))
    }
}

@Suite("Your minis")
struct MiniCheckTests {
    private let agoac = BoxSetDTO(
        id: "agoac", title: "A Game of Armored Combat", subtitle: "", game: .both, miniCount: 8,
        units: [
            "Awesome AWS-8Q", "BattleMaster BLR-1G", "Catapult CPLT-C1", "Commando COM-2D",
            "Locust LCT-1V", "Shadow Hawk SHD-2H", "Thunderbolt TDR-5S", "Wolverine WVR-6M"
        ],
        sourceURL: "https://example.com", contentsConfirmed: true
    )
    private let runningHot = ["Catapult CPLT-C1", "Locust LCT-1V", "Thunderbolt TDR-5S", "Commando COM-2D"]

    @Test("All owned: You have all 4 ’Mechs")
    func allOwned() {
        let check = CollectionMath.miniCheck(
            forces: runningHot, collection: OwnedCollection(boxes: ["agoac": 1]), boxes: [agoac]
        )
        #expect(check.hasAll)
        #expect(check.summary == "You have all 4 ’Mechs")
    }

    @Test("One missing names it and offers a stand-in")
    func oneMissing() {
        var owned = OwnedCollection(boxes: ["agoac": 1])
        owned.setUnit("Catapult CPLT-C1", in: agoac, owned: false)
        let check = CollectionMath.miniCheck(forces: runningHot, collection: owned, boxes: [agoac])
        #expect(check.missing == ["Catapult"])
        #expect(check.summary == "Missing: Catapult. Use any mini or a coin as a stand-in.")
    }

    @Test("Singles match mission variants by chassis")
    func singlesMatch() {
        let owned = OwnedCollection(singles: ["locust": 1, "Commando": 1])
        let check = CollectionMath.miniCheck(forces: runningHot, collection: owned, boxes: [])
        #expect(check.missing == ["Catapult", "Thunderbolt"])
        #expect(check.summary == "Missing: Catapult and Thunderbolt. Use any mini or a coin as a stand-in.")
    }

    @Test("Two of the same chassis need two minis")
    func duplicates() {
        let owned = OwnedCollection(singles: ["Locust": 1])
        let check = CollectionMath.miniCheck(
            forces: ["Locust LCT-1V", "Locust LCT-1V", "Locust LCT-1E"], collection: owned, boxes: []
        )
        #expect(check.missing == ["Locust ×2"])
    }

    @Test("None yet: every ’Mech is missing")
    func noneYet() {
        let check = CollectionMath.miniCheck(forces: runningHot, collection: .empty, boxes: [agoac])
        #expect(check.missing == ["Catapult", "Locust", "Thunderbolt", "Commando"])
    }

    private let alphaStrikeBox = BoxSetDTO(
        id: "alpha-strike-box", title: "Alpha Strike Box Set", subtitle: "", game: .alphaStrike, miniCount: 4,
        units: ["Archer", "Atlas", "Locust", "Wasp"],
        sourceURL: "https://example.com", contentsConfirmed: true
    )
    private let standIns = [
        "Catapult": ["Archer", "Timber Wolf"],
        "Thunderbolt": ["Warhammer", "Timber Wolf"],
        "Commando": ["Wasp", "Fire Moth"],
        "Locust": ["Fire Moth", "Wasp"],
    ]

    @Test("Owned minis stand in for missing ’Mechs; exact matches come first")
    func standInsFromOtherBox() {
        let check = CollectionMath.miniCheck(
            forces: runningHot, collection: OwnedCollection(boxes: ["alpha-strike-box": 1]),
            boxes: [alphaStrikeBox], standIns: standIns
        )
        #expect(check.standIns == [
            .init(use: "Archer", asUnit: "Catapult"),
            .init(use: "Wasp", asUnit: "Commando"),
        ])
        #expect(check.missing == ["Thunderbolt"])
        #expect(!check.hasAll)
        #expect(check.summary
            == "Stand-ins: Archer as Catapult and Wasp as Commando. Missing: Thunderbolt. Use any mini or a coin as a stand-in.")
    }

    @Test("A stand-in mini is used once; the next option takes over")
    func standInUsedOnce() {
        let owned = OwnedCollection(singles: ["Wasp": 1, "Fire Moth": 1])
        let check = CollectionMath.miniCheck(
            forces: ["Commando COM-2D", "Commando COM-2D", "Commando COM-2D"],
            collection: owned, boxes: [], standIns: standIns
        )
        #expect(check.standIns == [
            .init(use: "Wasp", asUnit: "Commando"),
            .init(use: "Fire Moth", asUnit: "Commando"),
        ])
        #expect(check.missing == ["Commando"])
    }

    @Test("All covered by stand-ins reads as ready")
    func allCoveredByStandIns() {
        let owned = OwnedCollection(singles: ["Wasp": 2])
        let check = CollectionMath.miniCheck(
            forces: ["Commando COM-2D", "Commando COM-2D"], collection: owned, boxes: [], standIns: standIns
        )
        #expect(check.hasAll)
        #expect(check.summary == "Stand-ins: Wasp ×2 as Commando.")
    }

    @Test("Natural list joins")
    func naturalList() {
        #expect(CollectionMath.naturalList([]) == "")
        #expect(CollectionMath.naturalList(["A"]) == "A")
        #expect(CollectionMath.naturalList(["A", "B"]) == "A and B")
        #expect(CollectionMath.naturalList(["A", "B", "C"]) == "A, B, and C")
    }
}

@Suite("Collection persistence")
struct CollectionStoreTests {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "collection-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test("Fresh install: not recorded")
    func fresh() {
        withDefaults { defaults in
            #expect(CollectionStore.load(from: defaults) == nil)
        }
    }

    @Test("Round-trips boxes, missing marks, and singles")
    func roundTrip() {
        withDefaults { defaults in
            let owned = OwnedCollection(
                boxes: ["agoac": 2], missing: ["agoac": ["Catapult CPLT-C1": 1]], singles: ["Atlas": 1]
            )
            CollectionStore.save(owned, to: defaults)
            #expect(CollectionStore.load(from: defaults) == owned)
        }
    }

    @Test("None yet saves as recorded and empty")
    func noneYet() {
        withDefaults { defaults in
            CollectionStore.save(.empty, to: defaults)
            #expect(CollectionStore.load(from: defaults) == .empty)
        }
    }

    @Test("Saving nil clears it")
    func clear() {
        withDefaults { defaults in
            CollectionStore.save(OwnedCollection(boxes: ["agoac": 1]), to: defaults)
            CollectionStore.save(nil, to: defaults)
            #expect(CollectionStore.load(from: defaults) == nil)
        }
    }

    @Test("Removing the owned keys resets to not recorded (what AppPreferences.reset does)")
    func ownedKeysReset() {
        withDefaults { defaults in
            CollectionStore.save(OwnedCollection(boxes: ["agoac": 1]), to: defaults)
            for key in CollectionStore.ownedKeys {
                defaults.removeObject(forKey: key)
            }
            #expect(CollectionStore.load(from: defaults) == nil)
        }
    }

    @Test("Unreadable data reads as not recorded")
    func corrupt() {
        withDefaults { defaults in
            defaults.set(Data("nope".utf8), forKey: CollectionStore.collectionKey)
            #expect(CollectionStore.load(from: defaults) == nil)
        }
    }

    @Test("Owning anything ticks Miniatures on the kit screen")
    func kitTick() {
        #expect(OnboardingCollection.kitChecks(["dice"], after: OwnedCollection(boxes: ["agoac": 1])) == ["dice", "minis"])
        #expect(OnboardingCollection.kitChecks(["dice"], after: OwnedCollection(singles: ["Atlas": 1])) == ["dice", "minis"])
        #expect(OnboardingCollection.kitChecks(["dice"], after: .empty) == ["dice"])
    }
}

private final class CollectionBundleToken {}


@Suite("Map catalog content")
struct MapCatalogContentTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: CollectionBundleToken.self))
    }

    @Test("Every product has a name and non-empty map names, none blank")
    func wellFormed() throws {
        let file = try catalog.mapCatalog()
        #expect(file.products.count > 60)
        for product in file.products {
            #expect(!product.name.isEmpty)
            #expect(!product.maps.isEmpty, "\(product.name)")
            for map in product.maps {
                #expect(map == map.trimmingCharacters(in: .whitespaces) && !map.isEmpty, "\(product.name): '\(map)'")
            }
            #expect(Set(product.maps).count == product.maps.count, "\(product.name) repeats a map")
        }
    }

    @Test("Maps added after the first pass are suggested by name")
    func addedMapsSuggest() throws {
        let file = try catalog.mapCatalog()
        #expect(file.suggestions(for: "caldera").contains("Caldera Lake (Volcanic)"))
        #expect(file.suggestions(for: "thunder rift") == ["Thunder Rift Map"])
        #expect(file.allMaps.contains("Open Terrain 1"))
        #expect(file.allMaps.contains("WWE2020 Map #4"))
    }

    @Test("Every map a mission suggests is in the catalog or a box")
    func missionMapsAreKnown() throws {
        let known = Set(try catalog.mapCatalog().allMaps.map { $0.lowercased() })
            .union(try catalog.boxSets().boxes.flatMap { $0.maps ?? [] }.map { $0.lowercased() })
        for item in try catalog.scenarios().scenarios where !item.gated {
            let dto = try catalog.scenario(id: ScenarioId(rawValue: item.id))
            for name in dto.layout?.sheetNames ?? [] {
                #expect(known.contains(name.lowercased()), "\(item.id): \(name)")
            }
        }
    }
}

@Suite("Map swap")
struct MapSwapTests {
    private func layout(_ names: [String]) -> MissionLayoutDTO {
        let sheets = names.enumerated().map { index, name in
            MissionLayoutDTO.Sheet(name: name, area: .init(x: Double(index) * 18, y: 0, width: 18, depth: 22))
        }
        return MissionLayoutDTO(
            width: 36, depth: 22, sheets: sheets,
            zones: [.init(side: "A", area: .init(x: 0, y: 0, width: 6, depth: 22))],
            features: [.init(kind: .hill, area: .init(x: 15, y: 8, width: 6, depth: 6))],
            openTable: "Any table"
        )
    }

    @Test("No choice, or a choice that doesn't fit, keeps the suggested maps")
    func noChoice() {
        let base = layout(["Grassland #2", "Desert #2"])
        #expect(MapSwap.names(for: base, chosen: nil) == ["Grassland #2", "Desert #2"])
        #expect(MapSwap.names(for: base, chosen: ["Woodland"]) == ["Grassland #2", "Desert #2"])
    }

    @Test("Swapping relabels the sheets and keeps zones, terrain and areas")
    func relabel() throws {
        let base = layout(["Grassland #2", "Desert #2"])
        let chosen = try #require(MapSwap.setting(nil, index: 1, to: "Woodland", in: base))
        #expect(chosen == ["Grassland #2", "Woodland"])
        let shown = MapSwap.applying(chosen, to: base)
        #expect(shown.sheetNames == ["Grassland #2", "Woodland"])
        #expect(shown.zones == base.zones)
        #expect(shown.features == base.features)
        #expect(shown.sheets.map(\.area) == base.sheets.map(\.area))
    }

    @Test("Putting every suggested map back stores nothing")
    func backToSuggested() throws {
        let base = layout(["Grassland #2", "Desert #2"])
        let swapped = try #require(MapSwap.setting(nil, index: 0, to: "Mountain Lake", in: base))
        #expect(MapSwap.setting(swapped, index: 0, to: "grassland #2", in: base) == nil)
        #expect(MapSwap.setting(nil, index: 5, to: "X", in: base) == nil)
    }

    @Test("A blank name falls back to the suggestion")
    func blank() {
        let base = layout(["Grassland #2", "Desert #2"])
        #expect(MapSwap.setting(nil, index: 0, to: "   ", in: base) == nil)
    }

    @Test("Options list owned maps, the suggestion and the current pick once each")
    func options() {
        let list = MapSwap.options(owned: ["Woodland", "desert #2"], suggested: "Desert #2", current: "Woodland")
        #expect(list == ["Woodland", "desert #2"])
        #expect(MapSwap.options(owned: [], suggested: "A", current: "B") == ["A", "B"])
    }

    @Test("Swaps persist per mission and survive a reload")
    func persistence() throws {
        let suite = "MapSwapTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(MapSwap.load(from: defaults).isEmpty)
        MapSwap.save(["as-ridge-line": ["Grassland #2", "Woodland"], "as-broken-ground": ["Lake Area", "Desert #2"]], to: defaults)
        let loaded = MapSwap.load(from: defaults)
        #expect(loaded["as-ridge-line"] == ["Grassland #2", "Woodland"])
        #expect(loaded["as-broken-ground"] == ["Lake Area", "Desert #2"])
        MapSwap.save([:], to: defaults)
        #expect(MapSwap.load(from: defaults).isEmpty)
    }
}
