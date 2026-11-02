import Foundation
import Testing
@testable import MechBuddyDomain

@Suite("Printed move")
struct PrintedMoveTests {
    @Test("Walk and jump card")
    func splitJump() throws {
        let move = try #require(PrintedMove("10\"/6\"j"))
        #expect(move.walk == 10)
        #expect(move.jump == 6)
        #expect(move.sprint == 15)
        #expect(move.summary == "10″ walk · 6″ jump")
        #expect(move.spokenSummary == "10 inches walk, 6 inches jump")
        #expect(move.detail(for: .ground) == "10″")
        #expect(move.detail(for: .jump) == "6″")
        #expect(move.detail(for: .sprint) == "about 15″")
        #expect(move.detail(for: .standstill) == "under 1″")
        #expect(move.spokenChoice(.standstill) == "Stood still, under 1 inch")
        #expect(move.spokenChoice(.sprint) == "Sprint, about 15 inches. Can’t shoot this turn.")
    }

    @Test("Jump-only card uses the same inches for walk and jump")
    func jumpOnly() throws {
        let move = try #require(PrintedMove("10\"j"))
        #expect(move.walk == 10)
        #expect(move.jump == 10)
        #expect(move.summary == "10″ walk or jump")
        #expect(move.detail(for: .jump) == "10″")
    }

    @Test("Ground card has no jump")
    func groundOnly() throws {
        let move = try #require(PrintedMove("16\""))
        #expect(move.walk == 16)
        #expect(move.jump == nil)
        #expect(move.sprint == 24)
        #expect(move.summary == "16″ walk")
        #expect(move.detail(for: .jump) == nil)
        #expect(move.spokenChoice(.ground) == "Walk, 16 inches")
    }

    @Test("Halved move still parses")
    func halved() throws {
        let move = try #require(PrintedMove("5\"/3\"j"))
        #expect(move.walk == 5)
        #expect(move.jump == 3)
        #expect(move.sprint == 8)
    }

    @Test("Blank and letter-only strings are not moves")
    func invalid() {
        #expect(PrintedMove("") == nil)
        #expect(PrintedMove("j") == nil)
        #expect(PrintedMove("walk") == nil)
    }

    @Test("Unset stays a view string")
    func unsetLabel() {
        #expect(recordedMoveName(.unset) == "Not recorded")
        #expect(recordedMoveName(.ground) == "Walked")
        #expect(MovementMode.unset.displayName == "Tap to record…")
    }
}
