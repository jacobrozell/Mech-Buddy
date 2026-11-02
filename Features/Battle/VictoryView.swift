import SwiftUI
import UIKit
import MechBuddyDomain

struct VictoryView: View {
    let session: MatchSession
    let onRematch: () -> Void
    let onDone: () -> Void
    let onBack: () -> Void

    @State private var confirmRematch = false
    @State private var didCelebrate = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 40
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: TMSpace.xl) {
                hero
                tally
                if shotStats.shots > 0 {
                    statsCard
                }
                actions
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityIdentifier("as.victory.screen")
                .accessibilityLabel("Victory")
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier("as.victory")
        .confirmationDialog("Start a new game?", isPresented: $confirmRematch, titleVisibility: .visible) {
            Button("Start over", role: .destructive, action: onRematch)
            Button("Stay here", role: .cancel) {}
        } message: {
            Text("This throws away the game you just finished.")
        }
        .onAppear { didCelebrate = true }
        .tmHaptic(.victory, trigger: didCelebrate, when: { $0 })
    }

    private var hero: some View {
        VStack(spacing: TMSpace.md) {
            Image(systemName: symbolName)
                .font(.system(size: 64))
                .foregroundStyle(symbolColor)
                .tmSymbolBounce(value: didCelebrate)
                .accessibilityHidden(true)
            if case .winner(let side) = session.outcome {
                SideBadge(side: side)
                Text("\(side.displayName) wins")
                    .font(TMFont.readoutL(size: titleSize))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            } else if session.outcome == .draw {
                Text("Draw")
                    .font(TMFont.readoutL(size: titleSize))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Text("Game over")
                    .font(TMFont.readoutL(size: titleSize))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(subtitle)
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var tally: some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.lg) {
                Eyebrow("Final tally")
                if usesPadColumns {
                    HStack(alignment: .top, spacing: TMSpace.lg) {
                        sideBlock(.lanceA)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        sideBlock(.lanceB)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(SideId.allCases, id: \.self) { side in
                        sideBlock(side)
                    }
                }
            }
        }
    }

    private var usesPadColumns: Bool {
        horizontalSizeClass == .regular
            && UIDevice.current.userInterfaceIdiom == .pad
            && !dynamicTypeSize.isAccessibilitySize
    }

    private func sideBlock(_ side: SideId) -> some View {
        let total = VictoryEvaluator.remainingStructure(side: side, in: session)
        let units = session.units.filter { $0.side == side }
        return VStack(alignment: .leading, spacing: TMSpace.sm) {
            HStack(spacing: TMSpace.sm) {
                SideBadge(side: side)
                Text(side.displayName)
                    .font(TMFont.cardTitle)
                Spacer(minLength: TMSpace.sm)
                Text("\(total) structure left")
                    .font(TMFont.stat)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(side.displayName), \(total) structure left")
            ForEach(units) { unit in
                unitRow(unit)
            }
        }
    }

    private func unitRow(_ unit: MatchUnitState) -> some View {
        HStack(alignment: .center, spacing: TMSpace.sm) {
            Text(unit.name)
                .font(TMFont.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            if unit.combatStatus == .active {
                PipTrack(
                    remaining: unit.remainingStructure,
                    capacity: unit.structureCap,
                    kind: .structure,
                    size: .compact,
                    accessibilityName: "\(unit.name) structure"
                )
            } else {
                HStack(spacing: TMSpace.xs) {
                    Image(systemName: "flame.fill")
                        .accessibilityHidden(true)
                    Text("Wrecked")
                        .font(TMFont.detail)
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(unit.name), wrecked")
            }
        }
    }

    private var statsCard: some View {
        let stats = shotStats
        let percent = Int((Double(stats.hits) / Double(stats.shots) * 100).rounded())
        return TMCard {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow("Match stats")
                Text("Shots \(stats.shots) · Hits \(stats.hits) (\(percent)%) · Crits \(stats.crits)")
                    .font(TMFont.body)
                    .monospacedDigit()
                if let attacker = stats.bestAttacker, let target = stats.bestTarget, stats.bestDamage > 0 {
                    Text("Best shot: \(attacker) → \(target), \(stats.bestDamage) damage")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: TMSpace.md) {
            PrimaryActionButton(
                title: "Play again",
                tint: playAgainTint,
                accessibilityIdentifier: "as.victory.rematch",
                action: { confirmRematch = true }
            )
            SecondaryActionButton(
                title: "Back to Play",
                accessibilityIdentifier: "as.victory.done",
                action: onDone
            )
            Button("Undo the last step", action: onBack)
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("as.victory.back")
        }
    }

    private var playAgainTint: Color {
        if case .winner(let side) = session.outcome {
            return TMColor.side(side)
        }
        return TMColor.signal
    }

    private var symbolName: String {
        switch session.outcome {
        case .winner: "trophy.fill"
        case .draw: "equal.circle"
        case nil: "flag.checkered"
        }
    }

    private var symbolColor: Color {
        switch session.outcome {
        case .winner(let side): TMColor.side(side)
        case .draw, nil: Color.secondary
        }
    }

    private var subtitle: String {
        switch session.outcome {
        case .draw:
            if VictoryEvaluator.livingSides(in: session).isEmpty {
                return "Both sides are wrecked · \(turnPhrase)"
            }
            return "Equal structure after turn \(session.turn)"
        case .winner(let side):
            let enemies = session.units.filter { $0.side != side }
            let allDown = !enemies.isEmpty && enemies.allSatisfy { $0.combatStatus != .active }
            if allDown {
                if enemies.count == 2 {
                    return "Both enemy ’Mechs destroyed · \(turnPhrase)"
                }
                if enemies.count == 1 {
                    return "Enemy ’Mech destroyed · \(turnPhrase)"
                }
                return "Enemy ’Mechs destroyed · \(turnPhrase)"
            }
            return "More structure left after turn \(session.turn)"
        case nil:
            return "The game is over"
        }
    }

    private var turnPhrase: String {
        if let max = session.ruleset.maxTurns {
            return "Turn \(session.turn) of \(max)"
        }
        return "Turn \(session.turn)"
    }

    /// Counts shots from the sentences MatchReducer already writes. No event-kind field.
    private var shotStats: ShotStats {
        var stats = ShotStats()
        for event in session.eventLog {
            if event.message.hasPrefix("Crit ") {
                stats.crits += 1
                continue
            }
            if event.message.contains(" missed "), event.message.contains(". Rolled ") {
                stats.shots += 1
                continue
            }
            guard event.message.contains(" hit "),
                  event.message.contains(". Rolled "),
                  let hit = event.message.range(of: " hit "),
                  let damageRange = event.message.range(of: " for ") else { continue }
            stats.shots += 1
            stats.hits += 1
            let attacker = String(event.message[..<hit.lowerBound])
            let afterHit = event.message[hit.upperBound...]
            let target = afterHit.split(separator: " for ", maxSplits: 1).first.map(String.init) ?? ""
            let digits = event.message[damageRange.upperBound...].prefix(while: \.isNumber)
            let damage = Int(digits) ?? 0
            if damage > stats.bestDamage {
                stats.bestDamage = damage
                stats.bestAttacker = attacker
                stats.bestTarget = target
            }
        }
        return stats
    }
}

private struct ShotStats {
    var shots = 0
    var hits = 0
    var crits = 0
    var bestAttacker: String?
    var bestTarget: String?
    var bestDamage = 0
}

#if DEBUG
#Preview("Victory") {
    VictoryView(
        session: {
            var session = PreviewFixtures.session(phase: .end, turn: 4)
            session.status = .completed
            session.outcome = .winner(.lanceA)
            session.units[1].combatStatus = .destroyedPendingEnd
            session.units[1].structureDamage = session.units[1].structureCap
            session.eventLog = [
                MatchEvent(
                    turn: 3,
                    phase: .combat,
                    message: "Shadow Hawk SHD-2H hit Locust LCT-1V for 2. Rolled 9, needed 6."
                ),
                MatchEvent(
                    turn: 4,
                    phase: .combat,
                    message: "Shadow Hawk SHD-2H missed Locust LCT-1V. Rolled 4, needed 8. No damage."
                ),
                MatchEvent(turn: 4, phase: .combat, message: "Crit MP hit on Locust LCT-1V")
            ]
            return session
        }(),
        onRematch: {},
        onDone: {},
        onBack: {}
    )
}
#endif
