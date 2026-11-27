import SwiftUI
import UIKit
import MechBuddyDomain

struct VictoryView: View {
    /// Where this match sits on the mission path, for the "Mission cleared" card.
    struct MissionProgress: Equatable {
        var number: Int
        var total: Int
        var cleared: Int
        var nextTitle: String?
        var nextUnlocks: [String]
        var nextPlayable: Bool
    }

    let session: MatchSession
    var progress: MissionProgress? = nil
    let onRematch: () -> Void
    var onNextMission: (() -> Void)? = nil
    var onShowLog: (() -> Void)? = nil
    /// Play games: back to Review with this setup (PlayModeSpec § 7.4).
    var onEditAndPlayAgain: (() -> Void)? = nil
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
                if let progress {
                    clearedCard(progress)
                }
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
                Text("\(session.displayName(of: side)) wins")
                    .font(TMFont.readoutL(size: titleSize))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            } else if session.outcome == .draw {
                Text("Draw")
                    .font(TMFont.readoutL(size: titleSize))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
            } else if case .tied = session.outcome {
                Text("It’s a tie")
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
                Eyebrow(session.isPlayGame ? "Standings" : "Final tally")
                if session.isPlayGame {
                    ForEach(Array(VictoryEvaluator.standings(in: session).enumerated()), id: \.element) { index, side in
                        sideBlock(side, place: index + 1)
                    }
                } else if usesPadColumns {
                    HStack(alignment: .top, spacing: TMSpace.lg) {
                        sideBlock(.lanceA)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        sideBlock(.lanceB)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(session.sideIds, id: \.self) { side in
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

    private func sideBlock(_ side: SideId, place: Int? = nil) -> some View {
        let total = VictoryEvaluator.remainingStructure(side: side, in: session)
        let units = session.units.filter { $0.side == side }
        return VStack(alignment: .leading, spacing: TMSpace.sm) {
            // Accessibility sizes stack the count under the side: beside it, "structure" broke as "struc-ture".
            let headLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMSpace.xs))
                : AnyLayout(HStackLayout(spacing: TMSpace.sm))
            headLayout {
                HStack(spacing: TMSpace.sm) {
                    if let place {
                        Text("\(place)")
                            .font(TMFont.readoutM)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    SideBadge(side: side)
                    Text(session.displayName(of: side))
                        .font(TMFont.cardTitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: TMSpace.sm)
                }
                Text(tallyLine(side, structure: total))
                    .font(TMFont.stat)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(standingLabel(side, place: place, structure: total))
            .accessibilityIdentifier(place.map { "as.victory.standing.\($0)" } ?? "as.victory.side.\(side.rawValue)")
            ForEach(units) { unit in
                unitRow(unit)
            }
        }
    }

    /// Missions: Structure left. Play: PV left and ’Mechs left (§ 7.4).
    private func tallyLine(_ side: SideId, structure: Int) -> String {
        guard session.isPlayGame else { return "\(structure) structure left" }
        let pv = VictoryEvaluator.pvLeft(side: side, in: session)
        let mechs = VictoryEvaluator.unitsLeft(side: side, in: session)
        var line = "\(pv) PV · \(mechs) ’Mech\(mechs == 1 ? "" : "s") left"
        // An objective game ranks by victory points first (§ 7.4).
        if session.objective != nil {
            let points = session.points(of: side)
            line = "\(ObjectiveRules.format(points)) point\(points == 1 ? "" : "s") · " + line
        }
        // Three or four sides: say who went out and when (§ 6.5, § 14). Two sides already name the loser.
        if session.sides.count > 2, let out = session.side(side), out.isOut {
            let when = out.outOnTurn.map { " on turn \($0)" } ?? ""
            line = (out.conceded ? "Conceded" : "Out") + when + " · " + line
        }
        return line
    }

    private func standingLabel(_ side: SideId, place: Int?, structure: Int) -> String {
        let prefix = place.map { "Place \($0), " } ?? ""
        return "\(prefix)\(session.displayName(of: side)), \(tallyLine(side, structure: structure))"
    }

    private func unitRow(_ unit: MatchUnitState) -> some View {
        // Accessibility sizes put the pips under the name: beside them, "Commando" broke as "Comman-do".
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMSpace.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: TMSpace.sm))
        return layout {
            Text(unit.name)
                .font(TMFont.body)
                .fixedSize(horizontal: false, vertical: true)
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
                // Left the table counts as destroyed (Forced Withdrawal), but say what happened.
                HStack(spacing: TMSpace.xs) {
                    Image(systemName: unit.leftTable ? "figure.walk.departure" : "flame.fill")
                        .accessibilityHidden(true)
                    Text(unit.leftTable ? "Left the table" : "Wrecked")
                        .font(TMFont.detail)
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(unit.name), \(unit.leftTable ? "left the table" : "wrecked")")
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
                if !stats.killingBlows.isEmpty {
                    ForEach(Array(stats.killingBlows.enumerated()), id: \.offset) { _, blow in
                        Label(
                            "\(short(blow.attacker)) wrecked the \(short(blow.target)) · turn \(blow.turn)",
                            systemImage: "flame.fill"
                        )
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                } else if let attacker = stats.bestAttacker, let target = stats.bestTarget, stats.bestDamage > 0 {
                    Text("Best shot: \(attacker) → \(target), \(stats.bestDamage) damage")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let onShowLog {
                    Button(action: onShowLog) {
                        HStack(spacing: TMSpace.xs) {
                            Text("Full battle log")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                    }
                    .font(TMFont.detail.weight(.semibold))
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("as.victory.log")
                }
            }
        }
    }

    private func clearedCard(_ progress: MissionProgress) -> some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                HStack(spacing: TMSpace.sm) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(TMColor.signal)
                        .tmSymbolBounce(value: didCelebrate)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: TMSpace.xxs) {
                        Text("Mission \(progress.number) cleared")
                            .font(TMFont.cardTitle)
                        Text("\(progress.cleared) of \(progress.total) on the mission path")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: TMSpace.xs) {
                    ForEach(0..<max(progress.total, 1), id: \.self) { index in
                        Capsule()
                            .fill(index < progress.cleared ? TMColor.signal : TMColor.readout)
                            .frame(height: 8)
                    }
                }
                .accessibilityHidden(true)
                if let next = progress.nextTitle {
                    VStack(alignment: .leading, spacing: TMSpace.xs) {
                        Text(progress.nextPlayable ? "Up next: \(next)" : "Coming soon: \(next)")
                            .font(TMFont.detail.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        if !progress.nextUnlocks.isEmpty {
                            UnlockChips(rules: progress.nextUnlocks)
                                // At AX5 "Jumping for position" was wider than the card and clipped.
                                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        }
                    }
                } else {
                    Text("That was the last mission. You’re a trained pilot.")
                        .font(TMFont.detail.weight(.semibold))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("as.victory.missionCleared")
    }

    private var actions: some View {
        VStack(spacing: TMSpace.md) {
            if let onNextMission, let next = progress?.nextTitle, progress?.nextPlayable == true {
                PrimaryActionButton(
                    title: "Next: \(next)",
                    tint: TMColor.signal,
                    accessibilityIdentifier: "as.victory.nextMission",
                    action: onNextMission
                )
                SecondaryActionButton(
                    title: "Play again",
                    accessibilityIdentifier: "as.victory.rematch",
                    action: { confirmRematch = true }
                )
            } else {
                PrimaryActionButton(
                    title: "Play again",
                    tint: playAgainTint,
                    accessibilityIdentifier: "as.victory.rematch",
                    action: { confirmRematch = true }
                )
            }
            if let onEditAndPlayAgain {
                SecondaryActionButton(
                    title: "Edit and play again",
                    accessibilityIdentifier: "as.victory.editSetup",
                    action: onEditAndPlayAgain
                )
            }
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
        case .draw, .tied: "equal.circle"
        case nil: "flag.checkered"
        }
    }

    private var symbolColor: Color {
        switch session.outcome {
        case .winner(let side): TMColor.side(side)
        case .draw, .tied, nil: Color.secondary
        }
    }

    private var subtitle: String {
        switch session.outcome {
        case .tied(let sides):
            // Three or four sides level at the top share first place (§ 7.4).
            let names = sides.map { session.displayName(of: $0) }.joined(separator: " and ")
            return "\(names) are level at the top after turn \(session.turn)"
        case .draw:
            if VictoryEvaluator.livingSides(in: session).isEmpty {
                return "Both sides are wrecked · \(turnPhrase)"
            }
            return "Equal \(session.isPlayGame ? "PV" : "structure") after turn \(session.turn)"
        case .winner(let side):
            let enemies = session.units.filter { $0.side != side }
            let allDown = !enemies.isEmpty && enemies.allSatisfy { $0.combatStatus != .active }
            if allDown {
                if enemies.contains(where: \.leftTable) {
                    return "Every enemy ’Mech wrecked or withdrawn · \(turnPhrase)"
                }
                if enemies.count == 2 {
                    return "Both enemy ’Mechs destroyed · \(turnPhrase)"
                }
                if enemies.count == 1 {
                    return "Enemy ’Mech destroyed · \(turnPhrase)"
                }
                return "Enemy ’Mechs destroyed · \(turnPhrase)"
            }
            return "More \(session.isPlayGame ? "PV" : "structure") left after turn \(session.turn)"
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

    /// "Shadow Hawk SHD-2H" → "Shadow Hawk".
    private func short(_ name: String) -> String {
        PlayForceMath.shortName(name)
    }

    /// Counts shots from the sentences MatchReducer already writes. No event-kind field.
    private var shotStats: ShotStats {
        var stats = ShotStats()
        // Damage so far per target, to find the hit that wrecked each one.
        var taken: [String: Int] = [:]
        let toughness = Dictionary(
            session.units.map { ($0.name, $0.armorCap + $0.structureCap) },
            uniquingKeysWith: { first, _ in first }
        )
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
            let before = taken[target, default: 0]
            taken[target] = before + damage
            if let total = toughness[target], before < total, before + damage >= total {
                stats.killingBlows.append(KillingBlow(attacker: attacker, target: target, turn: event.turn))
            }
            if damage > stats.bestDamage {
                stats.bestDamage = damage
                stats.bestAttacker = attacker
                stats.bestTarget = target
            }
        }
        return stats
    }
}

private struct KillingBlow {
    var attacker: String
    var target: String
    var turn: Int
}

private struct ShotStats {
    var killingBlows: [KillingBlow] = []
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
