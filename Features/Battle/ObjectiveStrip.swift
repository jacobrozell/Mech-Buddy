import SwiftUI
import MechBuddyDomain

/// One thin row under the step strip while a Play objective is on: each side's victory points and what wins
/// (PlayModeSpec § 7.1). Sides with no 'Mechs left stay in the row, marked out; the numbers are text, never colour alone.
struct ObjectiveVPStrip: View {
    var session: MatchSession
    /// The one objective every side plays; nil when each side rolled its own (PM11).
    var objective: ObjectiveId?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // The battle screen's own identifier would replace this row's, so the spoken summary and `as.battle.vp` sit on
        // a hidden sibling inside a container, as the phase segments do (BattleStepStrip). The visible row is hidden
        // from VoiceOver so the summary isn't read twice.
        VStack(alignment: .leading, spacing: 0) {
            // One wrapping row: the title, each side's points, the win total. Wraps at large text.
            FlowLayout(spacing: TMSpace.md) {
                if let objective, session.sides.count <= 2 || dynamicTypeSize.isAccessibilitySize {
                    Text(objective.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                items
                if let objective {
                    Text("to \(ObjectiveRules.format(objective.baseThreshold))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .accessibilityHidden(true)
            .background {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(Self.spoken(session: session, objective: objective))
                    .accessibilityIdentifier("as.battle.vp")
            }
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, TMSpace.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var items: some View {
        ForEach(session.sides) { side in
            HStack(spacing: TMSpace.xs) {
                SideBadge(side: side.id)
                Text(ObjectiveRules.format(session.points(of: side.id)))
                    .font(TMFont.stat)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                // Own objectives: each side's name and target, since the row can't say it once.
                if objective == nil, let own = session.objective(for: side.id) {
                    Text("\(own.shortTitle) to \(ObjectiveRules.format(ObjectiveRules.threshold(for: side.id, objective: own, in: session)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if side.isOut {
                    Text("out").font(.caption).foregroundStyle(.secondary)
                }
            }
            .opacity(side.isOut ? 0.6 : 1)
        }
    }

    /// "Raid. Side A 6 points, Side B 4 points, 10 to win." A side with its own threshold says so.
    static func spoken(session: MatchSession, objective: ObjectiveId?) -> String {
        let sides = session.sides.map { side -> String in
            let points = session.points(of: side.id)
            let name = session.displayName(of: side.id)
            guard let sideObjective = objective ?? session.objective(for: side.id) else {
                return "\(name) \(ObjectiveRules.format(points)) \(points == 1 ? "point" : "points")\(side.isOut ? ", out" : "")"
            }
            let needs = ObjectiveRules.threshold(for: side.id, objective: sideObjective, in: session)
            // Shared objective: only a differing threshold is worth saying. Own objective: name it and its target.
            let own = objective == nil
                ? ", \(sideObjective.title), \(ObjectiveRules.format(needs)) to win"
                : (needs != sideObjective.baseThreshold ? ", needs \(ObjectiveRules.format(needs))" : "")
            return "\(name) \(ObjectiveRules.format(points)) \(points == 1 ? "point" : "points")\(own)\(side.isOut ? ", out" : "")"
        }
        guard let objective else { return "Objectives. " + sides.joined(separator: ", ") }
        return "\(objective.title). " + sides.joined(separator: ", ") + ", \(ObjectiveRules.format(objective.baseThreshold)) to win"
    }
}
