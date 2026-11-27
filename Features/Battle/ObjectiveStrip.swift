import SwiftUI
import MechBuddyDomain

/// One thin row under the step strip while a Play objective is on: each side's victory points and what wins
/// (PlayModeSpec § 7.1). Sides with no 'Mechs left stay in the row, marked out; the numbers are text, never colour alone.
struct ObjectiveVPStrip: View {
    var session: MatchSession
    var objective: ObjectiveId

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(showsTitle: true)
            row(showsTitle: false)
            // Narrow or large text: two lines rather than clipping.
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(objective.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                FlowLayout(spacing: TMSpace.md) { items }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, TMSpace.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(session: session, objective: objective))
        .accessibilityIdentifier("as.battle.vp")
    }

    private func row(showsTitle: Bool) -> some View {
        HStack(spacing: TMSpace.md) {
            if showsTitle {
                Text(objective.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            items
            Spacer(minLength: TMSpace.xs)
            Text("to \(ObjectiveRules.format(objective.baseThreshold))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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
                if side.isOut {
                    Text("out").font(.caption).foregroundStyle(.secondary)
                }
            }
            .opacity(side.isOut ? 0.6 : 1)
        }
    }

    /// "Raid. Side A 6 points, Side B 4 points, 10 to win." A side with its own threshold says so.
    static func spoken(session: MatchSession, objective: ObjectiveId) -> String {
        let sides = session.sides.map { side -> String in
            let points = session.points(of: side.id)
            let name = session.displayName(of: side.id)
            let needs = ObjectiveRules.threshold(for: side.id, objective: objective, in: session)
            let own = needs != objective.baseThreshold ? ", needs \(ObjectiveRules.format(needs))" : ""
            return "\(name) \(ObjectiveRules.format(points)) \(points == 1 ? "point" : "points")\(own)\(side.isOut ? ", out" : "")"
        }
        return "\(objective.title). " + sides.joined(separator: ", ") + ", \(ObjectiveRules.format(objective.baseThreshold)) to win"
    }
}
