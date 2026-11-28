import SwiftUI
import Testing
import UIKit
@testable import MechBuddy

@Suite("Landscape table layout (FUTURE-PLAN 1.7)")
struct BattleStageLayoutTests {
    @Test("Phone landscape (compact height) uses the table, portrait stays stacked")
    func phone() {
        #expect(BattleStageLayout.resolve(idiom: .phone, horizontal: .compact, vertical: .compact) == .table)
        #expect(BattleStageLayout.resolve(idiom: .phone, horizontal: .regular, vertical: .compact) == .table)
        #expect(BattleStageLayout.resolve(idiom: .phone, horizontal: .compact, vertical: .regular) == .stacked)
        #expect(BattleStageLayout.resolve(idiom: .phone, horizontal: nil, vertical: nil) == .stacked)
    }

    @Test("iPad uses the table at regular width only")
    func pad() {
        #expect(BattleStageLayout.resolve(idiom: .pad, horizontal: .regular, vertical: .regular) == .table)
        #expect(BattleStageLayout.resolve(idiom: .pad, horizontal: .compact, vertical: .regular) == .stacked)
    }

    @Test("Accessibility text sizes fall back to the single column")
    func accessibility() {
        #expect(BattleStageLayout.resolve(idiom: .phone, horizontal: .compact, vertical: .compact, isAccessibilitySize: true) == .stacked)
        #expect(BattleStageLayout.resolve(idiom: .pad, horizontal: .regular, vertical: .regular, isAccessibilitySize: true) == .stacked)
    }

    @Test("Set-up steps keep the full-width column; the rest use the table")
    func steps() {
        #expect(!BattleStageLayout.usesTable(.table, step: .tableSetup))
        #expect(!BattleStageLayout.usesTable(.table, step: .placeMiniatures))
        #expect(BattleStageLayout.usesTable(.table, step: .initiative))
        #expect(BattleStageLayout.usesTable(.table, step: .combat))
        #expect(BattleStageLayout.usesTable(.table, step: .end))
        #expect(!BattleStageLayout.usesTable(.stacked, step: .combat))
    }

    @Test("Side columns: two for 1v1, three when there is room, a 2x2 grid for four")
    func columns() {
        #expect(BattleStageLayout.columnCount(sideCount: 1, width: 800) == 1)
        #expect(BattleStageLayout.columnCount(sideCount: 2, width: 430) == 2)
        #expect(BattleStageLayout.columnCount(sideCount: 2, width: 150) == 1)
        #expect(BattleStageLayout.columnCount(sideCount: 3, width: 430) == 2)
        #expect(BattleStageLayout.columnCount(sideCount: 3, width: 700) == 3)
        #expect(BattleStageLayout.columnCount(sideCount: 4, width: 430) == 2)
        #expect(BattleStageLayout.columnCount(sideCount: 4, width: 1200) == 2)
    }

    @Test("Rows chunk the pinned-first groups, so the acting side leads the first row")
    func rows() {
        #expect(BattleStageLayout.rows(["A", "B"], columns: 2) == [["A", "B"]])
        #expect(BattleStageLayout.rows(["C", "A", "B"], columns: 2) == [["C", "A"], ["B"]])
        #expect(BattleStageLayout.rows(["A", "B", "C", "D"], columns: 2) == [["A", "B"], ["C", "D"]])
        #expect(BattleStageLayout.rows(["A", "B", "C"], columns: 3) == [["A", "B", "C"]])
        #expect(BattleStageLayout.rows([String](), columns: 2).isEmpty)
    }

    @Test("Tool column is wider on iPad")
    func toolWidth() {
        #expect(BattleStageLayout.toolColumnWidth(idiom: .pad) > BattleStageLayout.toolColumnWidth(idiom: .phone))
    }
}
