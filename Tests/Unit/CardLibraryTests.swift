import Foundation
import Testing
import MechBuddyData
import MechBuddyDomain

/// PlayModeSpec §10 and §20: the card library.
@Suite("Card library")
struct CardLibraryTests {
    private var catalog: BundleContentCatalogRepository {
        BundleContentCatalogRepository(bundle: Bundle(for: CardLibraryBundleToken.self))
    }

    private func library() throws -> CardLibrary { CardLibrary(try catalog.cardLibrary()) }

    @Test("Forty faces, 21 checked, 19 left for the owner")
    func counts() throws {
        let lib = try library()
        #expect(lib.faces.count == 40)
        #expect(lib.checkedFaces.count == 21)
        #expect(lib.faces(box: "alpha-strike-box").count == 26)
        #expect(lib.faces(box: "agoac").count == 14)
    }

    @Test("Ids are unique; every face has name, chassis and Size")
    func identity() throws {
        let faces = try library().faces
        #expect(Set(faces.map(\.id)).count == faces.count)
        for f in faces {
            #expect(!f.name.isEmpty && !f.chassis.isEmpty && (1...4).contains(f.sz), "\(f.id)")
        }
    }

    @Test("Checked faces have every stat; unchecked faces have none")
    func fields() throws {
        for f in try library().faces {
            if f.isChecked {
                #expect((f.pv ?? 0) > 0, "\(f.id) pv")
                #expect((f.armor ?? 0) > 0 && (f.structure ?? 0) > 0, "\(f.id) A/S")
                #expect(f.mv != nil && f.tmm != nil && f.ov != nil && f.abilities != nil, "\(f.id)")
                #expect(f.s != nil && f.m != nil && f.l != nil, "\(f.id) damage")
                #expect(f.scenarioUnit() != nil)
            } else {
                #expect(f.pv == nil && f.armor == nil && f.structure == nil && f.scenarioUnit() == nil, "\(f.id)")
            }
        }
    }

    @Test("Each printed card has one or two faces; Awesome and BattleMaster share one")
    func printedCards() throws {
        let lib = try library()
        for card in Set(lib.faces.map(\.printedCard)) {
            #expect((1...2).contains(lib.faces(printedCard: card).count), "\(card)")
        }
        let shared = lib.faces(printedCard: "agoac-awesome-battlemaster").map(\.chassis)
        #expect(Set(shared) == ["Awesome", "BattleMaster"])
    }

    @Test("Clan faces default to Skill 3, Inner Sphere to 4")
    func techBase() throws {
        let lib = try library()
        #expect(lib.face(id: "nova-t")?.defaultSkill == 3)
        #expect(lib.face(id: "locust-lct-7v")?.defaultSkill == 4)
        #expect(lib.faces(chassis: "Timber Wolf").allSatisfy { $0.techBase == .clan })
        #expect(lib.faces(chassis: "Wasp").allSatisfy { $0.techBase == .innerSphere })
    }

    @Test("Every owned Alpha Strike box unit has a face")
    func boxUnits() throws {
        let lib = try library()
        for box in try catalog.boxSets().boxes where box.game != .classic {
            guard box.id == "alpha-strike-box" || box.id == "agoac" else { continue }
            for unit in box.units {
                let hit = lib.face(named: unit) != nil || !lib.faces(chassis: unit).isEmpty
                #expect(hit, "\(box.id): \(unit)")
            }
        }
    }

    @Test("Box roster cards reference real faces of the same name")
    func rosterReferences() throws {
        let lib = try library()
        for card in try catalog.boxRoster().cards {
            let id = try #require(card.cardId, "\(card.name)")
            #expect(lib.face(id: id)?.name == card.name)
            if let back = card.back { #expect(lib.face(named: back) != nil, "\(back)") }
        }
    }

    @Test("Checked faces match the values in shipped missions (PV compared at Skill 4)")
    func missionsMatch() throws {
        let lib = try library()
        var seen = Set<String>()
        for item in try catalog.scenarios().scenarios where !item.gated && item.bundle != nil {
            let scenario = try catalog.scenario(id: ScenarioId(rawValue: item.id))
            for u in scenario.sides.lanceA + scenario.sides.lanceB {
                let face = try #require(lib.face(named: u.name), "\(item.id): \(u.name) not in library")
                #expect(face.isChecked, "\(u.name)")
                seen.insert(face.id)
                #expect(face.mv == u.mv && face.tmm == u.tmm && face.sz == u.sz, "\(u.name)")
                #expect(face.s == u.s && face.m == u.m && face.l == u.l, "\(u.name) damage")
                #expect(face.minimalDamage == u.minimalDamage, "\(u.name) 0*")
                #expect(face.ov == u.ov && face.armor == u.armor && face.structure == u.structure, "\(u.name)")
                #expect((face.abilities ?? "") == u.abilities, "\(u.name) abilities")
                if u.skill == 4 { #expect(face.pv == u.pv, "\(u.name) pv") }
                else { #expect((face.pv ?? 0) <= u.pv, "\(u.name) pv grows with skill") }
            }
        }
        #expect(seen.count >= 14)
    }

    @Test("0* damage decodes to 0 plus a minimal flag and round-trips")
    func minimalDamage() throws {
        let json = #"""
        {"id":"t","name":"T","chassis":"T","printedCard":"p","boxes":["b"],"techBase":"clan","sz":1,
         "pv":10,"mv":"8\"","tmm":1,"s":"0*","m":1,"l":0,"ov":0,"armor":1,"structure":1,"abilities":"",
         "checked":{"on":"2026-01-01","source":"test"}}
        """#
        let face = try JSONDecoder().decode(CardFaceDTO.self, from: Data(json.utf8))
        #expect(face.s == 0 && face.minimalDamage.short && !face.minimalDamage.medium)
        let again = try JSONDecoder().decode(CardFaceDTO.self, from: JSONEncoder().encode(face))
        #expect(again == face)
        #expect(face.scenarioUnit()?.minimalDamage.short == true)
    }
}

private final class CardLibraryBundleToken {}
