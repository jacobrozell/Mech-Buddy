// Pure logic that lives in the app target's Battle feature and design system.
import Foundation
import SwiftUI
import UIKit
import Testing
import MechBuddyData
import MechBuddyDomain
@testable import MechBuddy

private func appUnit(_ name: String, _ side: SideId, sz: Int = 2) -> MatchUnitState {
    MatchUnitState(name: name, side: side, skill: 4, pv: 20, sz: sz, mv: "8\"", tmm: 2,
                   s: 2, m: 2, l: 1, ov: 0, armorCap: 4, structureCap: 3)
}

private func appSession(phase: PhaseId = .initiative, turn: Int = 1, ready: Bool = true, placing: Bool = false) -> MatchSession {
    var session = MatchSession(ruleset: .ridgeLine, turn: turn, phase: phase,
                               units: [appUnit("Locust LCT-1V", .lanceA), appUnit("Wasp WSP-1A", .lanceB)],
                               status: .active, tableReady: ready, forcesLoaded: true)
    // Turn 1 Movement before the players confirm placement is its own step.
    session.deploymentAcknowledged = !placing
    return session
}

@MainActor
@Suite("Battle chrome")
struct BattleChromeTests {
    @Test("iPad with a regular width uses columns; everything else stacks")
    func layout() {
        #expect(BattleStageLayout.resolve(idiom: .pad, horizontal: .regular, vertical: .regular) == .padColumns)
        #expect(BattleStageLayout.resolve(idiom: .pad, horizontal: .compact, vertical: .regular) == .stacked)
        #expect(BattleStageLayout.resolve(idiom: .phone, horizontal: .regular, vertical: .compact) == .stacked)
        #expect(BattleStageLayout.resolve(idiom: .phone, horizontal: nil, vertical: nil) == .stacked)
        #expect(!BattleStageLayout.stacked.showsSideRoster && BattleStageLayout.padColumns.showsSideRoster)
        #expect(BattleStageLayout.phoneLandscape.showsSideRoster)
    }

    @Test("The header hides at table setup and the result; only Movement has one side up")
    func headerRules() {
        #expect(!BattleChrome.showsHeader(.tableSetup) && !BattleChrome.showsHeader(.victory))
        for step in [BattleCoach.Step.placeMiniatures, .initiative, .movement, .combat, .end] {
            #expect(BattleChrome.showsHeader(step))
        }
        #expect(BattleChrome.showsActiveSide(.movement))
        #expect(!BattleChrome.showsActiveSide(.combat) && !BattleChrome.showsActiveSide(.placeMiniatures))
    }

    @Test("Navigation title shows the turn out of the cap, or just the turn without one")
    func title() {
        var session = appSession(phase: .movement, turn: 3)
        let coach = BattleCoach(session: session)
        #expect(BattleChrome.navigationTitle(scenarioTitle: "Ridge Line", session: session, coach: coach)
                == "Ridge Line · Turn 3/\(session.ruleset.maxTurns ?? 0)")
        session.ruleset.maxTurns = nil
        #expect(BattleChrome.navigationTitle(scenarioTitle: "Ridge Line", session: session, coach: coach) == "Ridge Line · Turn 3")
        let setup = appSession(ready: false)
        #expect(BattleChrome.navigationTitle(scenarioTitle: "Ridge Line", session: setup, coach: BattleCoach(session: setup)) == "Ridge Line")
    }

    @Test("The coach key is per game and step, and a pending critical gets its own")
    func coachKey() {
        var session = appSession(phase: .movement)
        let movement = BattleChrome.coachKey(session: session, coach: BattleCoach(session: session))
        #expect(movement == "\(session.id.uuidString)|movement")
        session.units[0].criticalsOwed = 1
        #expect(BattleChrome.coachKey(session: session, coach: BattleCoach(session: session)) == "\(session.id.uuidString)|critical")
    }

    @Test("Brief coaching explains a step in full only on the turn it first appeared")
    func coachDisplay() {
        #expect(BattleChrome.coachDisplay(level: .full, scenario: .runningHot, firstSeenTurn: 1, turn: 4) == .full)
        #expect(BattleChrome.coachDisplay(level: .off, scenario: .ridgeLine, firstSeenTurn: nil, turn: 1) == .off)
        #expect(BattleChrome.coachDisplay(level: .brief, scenario: nil, firstSeenTurn: nil, turn: 2) == .full)
        #expect(BattleChrome.coachDisplay(level: .brief, scenario: nil, firstSeenTurn: 2, turn: 2) == .full)
        #expect(BattleChrome.coachDisplay(level: .brief, scenario: nil, firstSeenTurn: 1, turn: 2) == .brief)
        // Automatic: full on Ridge Line, brief afterwards.
        #expect(BattleChrome.coachDisplay(level: .automatic, scenario: .ridgeLine, firstSeenTurn: 1, turn: 5) == .full)
        #expect(BattleChrome.coachDisplay(level: .automatic, scenario: .runningHot, firstSeenTurn: 1, turn: 5) == .brief)
    }

    @Test("The dock tint warns for a critical, follows the mover in Movement, and is the signal colour otherwise")
    func dockTint() {
        var session = appSession(phase: .movement)
        session.activeSide = .lanceB
        #expect(BattleChrome.dockTint(session: session, coach: BattleCoach(session: session)) == TMColor.side(.lanceB))
        session.units[1].hasMovedThisTurn = true
        session.units[0].hasMovedThisTurn = true
        #expect(BattleChrome.dockTint(session: session, coach: BattleCoach(session: session)) == TMColor.signal)
        let combat = appSession(phase: .combat)
        #expect(BattleChrome.dockTint(session: combat, coach: BattleCoach(session: combat)) == TMColor.signal)
        var owed = combat
        owed.units[0].criticalsOwed = 1
        #expect(BattleChrome.dockTint(session: owed, coach: BattleCoach(session: owed)) == TMColor.warning)
    }

    @Test("VoiceOver announcements name the turn, phase and who moves")
    func announcements() {
        func say(_ s: MatchSession) -> String { BattleChrome.announcement(session: s, coach: BattleCoach(session: s)) }
        #expect(say(appSession(ready: false)) == "Set the table.")
        #expect(say(appSession(phase: .movement, placing: true)) == "Place the miniatures. Side B picks who places first.")
        let started = appSession(phase: .initiative)
        #expect(say(started) == "Turn 1, Roll.")
        var moving = appSession(phase: .movement, turn: 2)
        moving.activeSide = .lanceB
        #expect(say(moving) == "Turn 2, Move. Side B moves.")
        var shooting = moving
        shooting.phase = .combat
        #expect(say(shooting) == "Turn 2, Shoot. Both sides shoot, in any order.")
        shooting.phase = .end
        #expect(say(shooting) == "Turn 2, Clean up.")
        shooting.status = .completed
        #expect(say(shooting) == "Game over.")
        var owed = moving
        owed.units[0].criticalsOwed = 2
        #expect(say(owed) == "Critical hit. Locust LCT-1V took a serious hit.")
        owed.units[1].criticalsOwed = 1
        #expect(say(owed).hasSuffix("2 criticals are waiting."))
    }
}

@MainActor
@Suite("Objective strip speech")
struct ObjectiveStripSpeechTests {
    private func playSession(objective: ObjectiveId?) throws -> MatchSession {
        var setup = PlaySetup.pickup()
        setup.objectiveId = objective
        let units = [appUnit("A1", .lanceA), appUnit("B1", .lanceB)]
        return try MatchReducer.reduce(MatchSession(ruleset: setup.ruleset), .startPlay(setup: setup, units: units))
    }

    @Test("A shared objective is named once, with every side's points and the target")
    func shared() throws {
        var session = try playSession(objective: .raid)
        session.victoryPoints = [.lanceA: 6, .lanceB: 1]
        let text = ObjectiveVPStrip.spoken(session: session, objective: .raid)
        #expect(text.hasPrefix("Raid. Side A 6 points, Side B 1 point, "))
        #expect(text.hasSuffix("to win"))
    }

    @Test("With no objective the strip lists points only, and an eliminated side says so")
    func none() throws {
        var session = try playSession(objective: nil)
        session.sides[1].isOut = true
        let text = ObjectiveVPStrip.spoken(session: session, objective: nil)
        #expect(text == "Objectives. Side A 0 points, Side B 0 points, out")
    }

    @Test("Sides with their own objective each name it and its target")
    func perSide() throws {
        var setup = PlaySetup.pickup()
        setup.setObjective(.raid, for: .lanceA)
        setup.setObjective(.breakthrough, for: .lanceB)
        let units = [appUnit("A1", .lanceA), appUnit("B1", .lanceB)]
        let session = try MatchReducer.reduce(MatchSession(ruleset: setup.ruleset), .startPlay(setup: setup, units: units))
        let text = ObjectiveVPStrip.spoken(session: session, objective: nil)
        #expect(text.contains("Side A 0 points, Raid, ") && text.contains("Side B 0 points, Breakthrough, "))
    }
}

@MainActor
@Suite("Shot feed")
struct ShotFeedTests {
    private func shot(_ target: String, hit: Bool) -> TurnShot {
        TurnShot(targetName: target, hit: hit, total: hit ? 9 : 4, targetNumber: 7, damage: hit ? 2 : 0)
    }

    @Test("Signature matches the full log sentence for a hit and a miss")
    func signature() {
        #expect(ShotFeed.signature(shooter: "Locust", shot: shot("Wasp", hit: true)) == "Locust hit Wasp for 2. Rolled 9, needed 7.")
        #expect(ShotFeed.signature(shooter: "Locust", shot: shot("Wasp", hit: false)) == "Locust missed Wasp. Rolled 4, needed 7.")
    }

    @Test("Rows follow the order the shots were logged and skip removed 'Mechs")
    func rowOrder() {
        var session = appSession(phase: .combat)
        session.units[0].turnShot = shot("Wasp WSP-1A", hit: true)
        session.units[1].turnShot = shot("Locust LCT-1V", hit: false)
        // Wasp fired first.
        session.eventLog = [
            MatchEvent(turn: 1, phase: .combat, message: ShotFeed.signature(shooter: "Wasp WSP-1A", shot: session.units[1].turnShot!)),
            MatchEvent(turn: 1, phase: .combat, message: ShotFeed.signature(shooter: "Locust LCT-1V", shot: session.units[0].turnShot!))
        ]
        #expect(ShotFeed.rows(in: session).map(\.shooter) == ["Wasp WSP-1A", "Locust LCT-1V"])
        session.units[1].combatStatus = .removed
        #expect(ShotFeed.rows(in: session).map(\.shooter) == ["Locust LCT-1V"])
    }

    @Test("A shot with no log line sorts after logged ones, ties by name; other turns don't count")
    func unlogged() {
        var session = appSession(phase: .combat)
        session.units[0].turnShot = shot("Wasp WSP-1A", hit: true)
        session.units[1].turnShot = shot("Locust LCT-1V", hit: true)
        session.eventLog = [MatchEvent(turn: 0, phase: .combat, message: ShotFeed.signature(shooter: "Wasp WSP-1A", shot: session.units[1].turnShot!))]
        let rows = ShotFeed.rows(in: session)
        #expect(rows.map(\.shooter) == ["Locust LCT-1V", "Wasp WSP-1A"])
        #expect(rows.allSatisfy { $0.order >= 10_000 })
        #expect(rows[0].id == session.units[0].id)
    }

    @Test("Critical lines for this turn's combat phase come back without their prefix, oldest first")
    func crits() {
        var session = appSession(phase: .combat, turn: 2)
        session.eventLog = [
            MatchEvent(turn: 2, phase: .combat, message: "Crit Weapon hit on Locust"),
            MatchEvent(turn: 2, phase: .movement, message: "Crit Engine hit on Wasp"),
            MatchEvent(turn: 1, phase: .combat, message: "Crit Fire control on Wasp"),
            MatchEvent(turn: 2, phase: .combat, message: "Locust hit Wasp for 1."),
            MatchEvent(turn: 2, phase: .combat, message: "Crit MP hit on Wasp")
        ]
        #expect(ShotFeed.crits(in: session) == ["Weapon hit on Locust", "MP hit on Wasp"])
    }
}

@MainActor
@Suite("Names and small helpers")
struct BattleNameTests {
    @Test("Side names come from the session and fall back to the default")
    func sideNames() {
        var session = appSession()
        session.sides[0].name = "Wolves"
        let names = SideNames(session)
        #expect(names(.lanceA) == "Wolves" && names(.lanceB) == "Side B" && names(.lanceD) == "Side D")
        #expect(SideNames()(.lanceC) == "Side C")
        #expect(SideNames(session) == SideNames(session))
    }

    @Test("Force maths sums structure and PV for one side")
    func forceMath() {
        var units = [appUnit("A1", .lanceA), appUnit("A2", .lanceA), appUnit("B1", .lanceB)]
        units[0].structureDamage = 1
        let a = PlayForceMath.structure(of: .lanceA, in: units)
        #expect(a.remaining == 5 && a.capacity == 6)
        #expect(PlayForceMath.pointValue(of: .lanceA, in: units) == 40)
        #expect(PlayForceMath.structure(of: .lanceD, in: units) == (0, 0))
        #expect(PlayForceMath.shortName("Locust LCT-1V") == "Locust")
    }

    @Test("Initiative preview: higher total wins and the lower roll moves first; a tie has neither")
    func initiativePreview() {
        let a = InitiativeDicePreview(a1: 6, a2: 5, b1: 1, b2: 2)
        #expect(a.sideATotal == 11 && a.sideBTotal == 3 && a.winner == .lanceA && a.firstToMove == .lanceB)
        let b = InitiativeDicePreview(a1: 1, a2: 1, b1: 3, b2: 3)
        #expect(b.winner == .lanceB && b.firstToMove == .lanceA)
        let tie = InitiativeDicePreview(a1: 3, a2: 4, b1: 2, b2: 5)
        #expect(tie.winner == nil && tie.firstToMove == nil)
    }

    @Test("The fallback briefing is Ridge Line's three-step table")
    func fallbackBriefing() {
        #expect(ScenarioPresentation.fallback.title == "Ridge Line")
        #expect(ScenarioPresentation.fallback.tableSteps.count == 3)
        #expect(ScenarioPresentation.fallback.introduces.isEmpty && ScenarioPresentation.fallback.layout == nil)
    }
}

@MainActor
@Suite("Unit status and conditions")
struct UnitStatusTests {
    private func chip(_ unit: MatchUnitState, active: Bool = true, idle: Bool = true, over: Bool = false, withdrawal: Bool = false) -> StatusChip.Kind? {
        UnitStatus.chip(for: unit, isActiveSide: active, showsIdleStatus: idle, shootingOver: over, forcedWithdrawal: withdrawal)
    }

    @Test("A critical owed beats everything else")
    func critFirst() {
        var unit = appUnit("A", .lanceA)
        unit.criticalsOwed = 2
        unit.heat = 4
        #expect(chip(unit) == .critOwed(2))
    }

    @Test("A wreck still shoots until it has fired or shooting is over")
    func wrecked() {
        var unit = appUnit("A", .lanceA)
        unit.combatStatus = .destroyedPendingEnd
        #expect(chip(unit) == .wrecked)
        #expect(chip(unit, over: true) == .wreckedDone)
        unit.hasAttackedThisTurn = true
        #expect(chip(unit) == .wreckedDone)
        unit.combatStatus = .removed
        #expect(chip(unit) == nil)
    }

    @Test("Shutdown, immobile, withdrawing and sprinted come before shots and moves")
    func conditions() {
        var unit = appUnit("A", .lanceA)
        unit.heat = 4
        #expect(chip(unit) == .shutdown)
        unit = appUnit("A", .lanceA)
        unit.armorDamage = 4
        unit.structureDamage = 2
        #expect(chip(unit, withdrawal: true) == .withdrawing)
        #expect(chip(unit, withdrawal: false) != .withdrawing)
        unit = appUnit("A", .lanceA)
        unit.movementMode = .sprint
        unit.hasMovedThisTurn = true
        #expect(chip(unit) == .sprinted)
    }

    @Test("Shots show hit or miss, then moves, then ready or waiting")
    func flow() {
        var unit = appUnit("A", .lanceA)
        #expect(chip(unit) == .ready && chip(unit, idle: false) == nil)
        #expect(chip(unit, active: false) == .waiting && chip(unit, active: false, idle: false) == nil)
        unit.hasMovedThisTurn = true
        unit.movementMode = .jump
        #expect(chip(unit) == .moved(.jump))
        unit.turnShot = TurnShot(targetName: "Wasp", hit: true, total: 9, targetNumber: 7, damage: 2)
        #expect(chip(unit) == .hit(target: "Wasp", damage: 2))
        unit.turnShot = TurnShot(targetName: "Wasp", hit: false, total: 3, targetNumber: 7, damage: 0)
        #expect(chip(unit) == .missed(target: "Wasp"))
    }

    @Test("The condition line lists heat, shutdown, crits and water, and is nil when clean or removed")
    func conditionLine() {
        var unit = appUnit("A", .lanceA)
        #expect(UnitConditions.line(for: unit) == nil)
        unit.heat = 2
        unit.crits.weaponHits = 2
        unit.crits.fireControlHits = 1
        unit.crits.engineHits = 1
        unit.crits.mpHits = 1
        unit.inWater = true
        #expect(UnitConditions.line(for: unit) == "Heat 2 · Engine · Fire control ×1 · Weapon ×2 · MP hit · In water")
        unit.heat = 4
        #expect(UnitConditions.line(for: unit)?.hasPrefix("Shut down · ") == true)
        unit.combatStatus = .removed
        #expect(UnitConditions.line(for: unit) == nil)
    }

    @Test("Chip names drop a variant code")
    func shortNames() {
        #expect(StatusChip.Kind.short("Wolverine WVR-6M") == "Wolverine")
        #expect(StatusChip.Kind.short("Atlas") == "Atlas")
        #expect(StatusChip.Kind.short("Timber Wolf") == "Timber Wolf")
    }
}

@MainActor
@Suite("2D6 odds display")
struct TwoD6DisplayTests {
    @Test("Ways to roll each total form the 1-2-3-4-5-6-5-4-3-2-1 triangle; outside 2–12 is impossible")
    func ways() {
        #expect((2...12).map(TwoD6Display.ways) == [1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1])
        #expect(TwoD6Display.ways(for: 1) == 0 && TwoD6Display.ways(for: 13) == 0)
        #expect((2...12).map(TwoD6Display.ways).reduce(0, +) == 36)
    }

    @Test("Percent to hit counts that many ways or better out of 36, clamped at both ends")
    func percent() {
        #expect(TwoD6Display.percent(for: 2) == 100 && TwoD6Display.percent(for: -3) == 100)
        #expect(TwoD6Display.percent(for: 7) == 58)
        #expect(TwoD6Display.percent(for: 12) == 3)
        #expect(TwoD6Display.percent(for: 13) == 0 && TwoD6Display.percent(for: 20) == 0)
        let steps = (2...12).map(TwoD6Display.percent)
        #expect(steps == steps.sorted(by: >))
    }
}

@MainActor
@Suite("SATOR terms")
struct SATORTermTests {
    private func resolve(skill: Int = 4, move: MovementMode = .ground, target: TargetMoveModifier = .groundUsesTMM,
                         tmm: Int = 2, other: OtherModifiers = OtherModifiers(), bracket: RangeBracket = .short) throws -> TargetNumber {
        try SATORResolver.resolve(SATORInput(skill: skill, attackerMove: move, targetMove: target, targetTMM: tmm,
                                             other: other, rangeBracket: bracket))
    }

    @Test("A normal shot becomes five chips in S-A-T-O-R order that add up to the target number")
    func make() throws {
        let tn = try resolve(skill: 4, move: .ground, target: .groundUsesTMM, tmm: 2, other: OtherModifiers(woods: true), bracket: .medium)
        let terms = SATORTerms.make(from: tn)
        #expect(terms.map(\.letter) == ["S", "A", "T", "O", "R"])
        #expect(terms.map(\.label) == ["Skill", "Walked", "Target walked", "Other", "Medium"])
        #expect(terms.map(\.delta) == [4, 0, 2, 1, 2])
        #expect(terms.map(\.delta).reduce(0, +) == tn.value)
    }

    @Test("Standing still, jumping, immobile and long range read as plain words with signed deltas")
    func labels() throws {
        let still = SATORTerms.make(from: try resolve(move: .standstill, target: .standstill, bracket: .long))
        #expect(still.map(\.label) == ["Skill", "Stood still", "Stood still", "Other", "Long"])
        #expect(still.map(\.delta) == [4, -1, 0, 0, 4])
        let jumped = SATORTerms.make(from: try resolve(move: .jump, target: .jumpedUsesTMMPlus1, tmm: 2))
        #expect(jumped.map(\.label)[1...2] == ["Jumped", "Target jumped"])
        #expect(jumped.map(\.delta)[1...2] == [2, 3])
        let immobile = SATORTerms.make(from: try resolve(target: .immobile))
        #expect(immobile.map(\.label)[2] == "Can’t move" && immobile.map(\.delta)[2] == -4)
    }

    @Test("A sprinting attacker can't shoot at all, so there is no term to show")
    func sprint() {
        #expect(throws: SATORError.self) { try resolve(move: .sprint) }
    }

    @Test("Chip text keeps the skill bare and signs every other term")
    func chips() throws {
        let terms = SATORTerms.make(from: try resolve(move: .standstill, other: OtherModifiers(woods: true)))
        #expect(terms.map(SATORTerms.chipText) == ["S 4", "A -1", "T +2", "O +1", "R +0"])
    }

    @Test("The equation reads left to right with minus and plus signs and ends in the total")
    func equation() throws {
        let tn = try resolve(move: .standstill, other: OtherModifiers(woods: true))
        let terms = SATORTerms.make(from: tn)
        #expect(SATORTerms.equation(terms, total: tn.value) == "4 skill − 1 stood still + 2 target walked + 1 other + 0 short = 6")
        #expect(SATORTerms.equation([], total: 0) == " = 0")
    }

    @Test("Each chip carries the matching plain-language reason from the resolver")
    func explanations() throws {
        let tn = try resolve(bracket: .medium)
        let terms = SATORTerms.make(from: tn)
        #expect(terms.count == 5)
        #expect(terms[0].explanation == tn.reasons.first { $0.hasPrefix("Skill") })
        #expect(terms.allSatisfy { !$0.explanation.isEmpty })
    }
}

@MainActor
@Suite("Mission layout description")
struct MissionLayoutDescriptionTests {
    @Test("The spoken table names its size, maps, deployment edges and terrain")
    func spoken() throws {
        let layout = try #require(try BundleContentCatalogRepository(bundle: .main).scenario(id: .ridgeLine).layout)
        let text = MissionLayoutDescription.spoken(layout)
        #expect(text.hasPrefix("Table "))
        #expect(text.contains("inches."))
        #expect(text.contains("sets up within"))
        for name in layout.sheetNames { #expect(text.contains(name)) }
    }

    @Test("Terrain is counted in plain words; one reads as a singular")
    func terrain() {
        var board = BoardLayout(width: 48, depth: 36, zones: BoardZones.generate(width: 48, depth: 36, sideCount: 2))
        func add(_ kind: BoardLayout.FeatureKind) {
            board.features.append(.init(id: UUID(), kind: kind, area: .init(x: 10, y: 10, width: 4, depth: 4), shape: .rect))
        }
        add(.hill)
        add(.woods)
        add(.woods)
        add(.building)
        let text = MissionLayoutDescription.spoken(board)
        #expect(text.contains("Table 48 by 36 inches."))
        #expect(text.contains("a hill in the middle") && text.contains("2 patches of woods") && text.contains("a building"))
        #expect(text.contains("Side A sets up within 6 inches of the left edge."))
        #expect(text.contains("Side B sets up within 6 inches of the right edge."))
        #expect(!text.contains("Maps, left to right"))
    }
}
