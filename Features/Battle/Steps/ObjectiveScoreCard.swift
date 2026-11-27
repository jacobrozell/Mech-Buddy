import SwiftUI
import MechBuddyDomain

/// The End Phase Score step (PlayModeSpec § 7.1, § 8.5): each side answers one short question for the objective;
/// the dock then scores every side at once. Tapping nobody is a valid answer. Destroy the Enemy shows no questions:
/// the app works it out from who hit whom.
struct ObjectiveScoreCard: View {
    var session: MatchSession
    var objective: ObjectiveId
    @Binding var answers: [SideId: [ObjectiveScoreEntry]]

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow("Score: \(objective.title)") {
                Text(objective.page)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            TMCard(edgeColor: TMColor.signal) {
                VStack(alignment: .leading, spacing: TMSpace.lg) {
                    if objective == .holdTheFort, !ObjectiveRules.asksQuestions(objective, turn: session.turn) {
                        Text("Scoring starts on Turn 3. Until then, guard your tokens (p. 7).")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let question = objective.question {
                        Text(question)
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(ObjectiveRules.sidesStillToScore(in: session), id: \.self) { side in
                            sideSection(side)
                        }
                        if ObjectiveRules.sidesStillToScore(in: session).isEmpty {
                            Text("Nothing to score this turn.")
                                .font(TMFont.detail)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Nothing to enter. Points come from who hit what: a ’Mech scores for the side whose attack crippled or destroyed it.")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if session.sides.count > 2 {
                            Text("[HOUSE] With three or four sides the app credits the side that dealt the damage (Quick-Start p. 7 has two sides).")
                                .font(TMFont.detail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        // The battle screen's identifier would replace one set on the card, so the id sits on a hidden marker inside a
        // container, as the phase segments do (BattleStepStrip).
        .background {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement()
                .accessibilityLabel("Score the objective")
                .accessibilityIdentifier("as.battle.objective")
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Sections

    private func entries(_ side: SideId) -> [ObjectiveScoreEntry] { answers[side] ?? [] }

    private func isOn(_ side: SideId, _ entry: ObjectiveScoreEntry) -> Bool { entries(side).contains(entry) }

    private func toggle(_ side: SideId, _ entry: ObjectiveScoreEntry) {
        var list = entries(side)
        if let index = list.firstIndex(of: entry) { list.remove(at: index) } else { list.append(entry) }
        answers[side] = list
    }

    private func units(_ side: SideId) -> [MatchUnitState] {
        session.units.filter { $0.side == side }
    }

    private func sideSection(_ side: SideId) -> some View {
        let own = entries(side)
        let preview = ObjectiveRules.previewPoints(objective, side: side, entries: own, in: session)
        return VStack(alignment: .leading, spacing: TMSpace.sm) {
            HStack(spacing: TMSpace.sm) {
                SideBadge(side: side)
                Text(session.displayName(of: side))
                    .font(TMFont.cardTitle)
                Spacer(minLength: TMSpace.sm)
                Text(own.isEmpty ? "No one" : "+\(ObjectiveRules.format(preview))")
                    .font(TMFont.stat)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("as.battle.objective.\(side.rawValue).preview")
            }
            switch objective {
            case .raid:
                raidChips(side)
            case .controlTheField:
                unitChips(side, kind: .inPosition, units: units(side).filter { $0.combatStatus == .active }, caption: nil)
            case .breakthrough:
                unitChips(side, kind: .exited, units: units(side).filter { $0.combatStatus == .active }, caption: nil)
            case .holdTheFort:
                tokenChips(side)
            case .destroyTheEnemy, .findTheTarget:
                EmptyView()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("as.battle.objective.side.\(side.rawValue)")
    }

    @ViewBuilder
    private func raidChips(_ side: SideId) -> some View {
        let active = units(side).filter { $0.combatStatus == .active }
        let carriers = active.filter { ObjectiveRules.carriedToken(by: $0.id, in: session) != nil }
        let free = active.filter { ObjectiveRules.carriedToken(by: $0.id, in: session) == nil }
        let pickedNow = entries(side).filter { $0.kind == .pickedUp }.count
        let spare = ObjectiveRules.availableTokens(for: side, in: session).count - pickedNow
        if !carriers.isEmpty {
            unitChips(side, kind: .returned, units: carriers, caption: "Carried a token back to your edge (2 each)")
        }
        unitChips(
            side,
            kind: .pickedUp,
            units: free,
            caption: "Picked up an enemy token",
            canAdd: spare > 0
        )
    }

    private func unitChips(
        _ side: SideId,
        kind: ObjectiveScoreEntry.Kind,
        units list: [MatchUnitState],
        caption: String?,
        canAdd: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            if let caption {
                Text(caption).font(TMFont.detail).foregroundStyle(.secondary)
            }
            FlowLayout(spacing: TMSpace.sm) {
                ForEach(Array(list.enumerated()), id: \.element.id) { index, unit in
                    let entry = ObjectiveScoreEntry(kind: kind, unitId: unit.id)
                    let on = isOn(side, entry)
                    chip(
                        title: "\(unit.name) · Size \(unit.sz)",
                        isOn: on,
                        isEnabled: on || canAdd,
                        identifier: "as.battle.objective.\(side.rawValue).\(kind.rawValue).\(index)"
                    ) { toggle(side, entry) }
                }
            }
            if list.isEmpty {
                Text("No ’Mechs can answer.").font(TMFont.detail).foregroundStyle(.secondary)
            }
        }
    }

    private func tokenChips(_ side: SideId) -> some View {
        let tokens = (session.objectiveState?.tokens ?? []).filter { $0.owner == side }
        return FlowLayout(spacing: TMSpace.sm) {
            ForEach(tokens) { token in
                let entry = ObjectiveScoreEntry(kind: .guarded, tokenId: token.id)
                chip(
                    title: "Token \(token.id) guarded",
                    isOn: isOn(side, entry),
                    isEnabled: true,
                    identifier: "as.battle.objective.token.\(token.id)"
                ) { toggle(side, entry) }
            }
        }
    }

    private func chip(title: String, isOn: Bool, isEnabled: Bool, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: isOn ? "checkmark.circle.fill" : "circle")
                .font(TMFont.detail)
                .frame(minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? TMColor.signal : .secondary)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}
