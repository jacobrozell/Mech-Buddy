import SwiftUI
import MechBuddyDomain

/// The End Phase Score step (PlayModeSpec § 7.1, § 8.5): each side answers one short question for the objective;
/// the dock then scores every side at once. Tapping nobody is a valid answer. Destroy the Enemy shows no questions:
/// the app works it out from who hit whom.
struct ObjectiveScoreCard: View {
    var session: MatchSession
    /// The one objective every side plays; nil when each side rolled its own (PM11), then `session.objective(for:)`.
    var objective: ObjectiveId?
    @Binding var answers: [SideId: [ObjectiveScoreEntry]]

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow(objective.map { "Score: \($0.title)" } ?? "Score the objectives") {
                Text(objective?.page ?? "p. 7")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            TMCard(edgeColor: TMColor.signal) {
                VStack(alignment: .leading, spacing: TMSpace.lg) {
                    if let objective {
                        sharedBody(objective)
                    } else {
                        perSideBody
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

    /// Each side answers its own objective's question (PM11). Destroy the Enemy sides need no answer.
    @ViewBuilder
    private var perSideBody: some View {
        let waiting = ObjectiveRules.sidesStillToScore(in: session)
        Text("[HOUSE] Each side rolled its own objective. Answer for each side below.")
            .font(TMFont.detail)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        ForEach(waiting, id: \.self) { side in
            sideSection(side, objective: session.objective(for: side))
        }
        if waiting.isEmpty {
            Text("Nothing to score by hand this turn.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
        }
        if session.sideIds.contains(where: { session.objective(for: $0) == .destroyTheEnemy }) {
            Text("Destroy the Enemy sides score from who hit whom, so they have nothing to enter.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func sharedBody(_ objective: ObjectiveId) -> some View {
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
                            sideSection(side, objective: objective)
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

    private func sideSection(_ side: SideId, objective: ObjectiveId?) -> some View {
        let own = entries(side)
        let preview = objective.map { ObjectiveRules.previewPoints($0, side: side, entries: own, in: session) } ?? 0
        let previewText = objective == .findTheTarget
            ? (own.isEmpty ? "None" : "\(own.count) searched")
            : (own.isEmpty ? "No one" : "+\(ObjectiveRules.format(preview))")
        return VStack(alignment: .leading, spacing: TMSpace.sm) {
            HStack(spacing: TMSpace.sm) {
                SideBadge(side: side)
                Text(session.displayName(of: side))
                    .font(TMFont.cardTitle)
                Spacer(minLength: TMSpace.sm)
                Text(previewText)
                    .font(TMFont.stat)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("as.battle.objective.\(side.rawValue).preview")
            }
            // Sides with their own objective (PM11) say which one, then ask its question.
            if self.objective == nil, let objective {
                Text(objective.title).font(TMFont.detail.weight(.semibold))
                if let question = objective.question {
                    Text(question)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            switch objective {
            case nil:
                EmptyView()
            case .raid:
                raidChips(side)
            case .controlTheField:
                unitChips(side, kind: .inPosition, units: units(side).filter { $0.combatStatus == .active }, caption: nil)
            case .breakthrough:
                unitChips(side, kind: .exited, units: units(side).filter { $0.combatStatus == .active }, caption: nil)
            case .holdTheFort:
                tokenChips(side)
            case .findTheTarget:
                searchChips(side)
            case .destroyTheEnemy:
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
        let tokens = ObjectiveRules.holdTokens(of: side, in: session)
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

    /// Find the Target: the buildings not yet found, to tick off as searched. Targets stay hidden.
    private func searchChips(_ side: SideId) -> some View {
        let buildings = ObjectiveRules.searchableBuildings(in: session)
        return VStack(alignment: .leading, spacing: TMSpace.xs) {
            FlowLayout(spacing: TMSpace.sm) {
                ForEach(Array(buildings.enumerated()), id: \.element.id) { index, building in
                    let entry = ObjectiveScoreEntry(kind: .searched, tokenId: building.id)
                    chip(
                        title: "\(building.name) searched",
                        isOn: isOn(side, entry),
                        isEnabled: true,
                        identifier: "as.battle.objective.\(side.rawValue).searched.\(index)"
                    ) { toggle(side, entry) }
                }
            }
            if buildings.isEmpty {
                Text("Every target is found.").font(TMFont.detail).foregroundStyle(.secondary)
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
