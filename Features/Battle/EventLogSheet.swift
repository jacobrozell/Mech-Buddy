import SwiftUI
import MechBuddyDomain

struct EventLogSheet: View {
    @Bindable var store: MatchStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.session?.eventLog.isEmpty != false {
                    VStack(spacing: 0) {
                        undoBar
                        Spacer()
                        EmptyState(
                            systemImage: "list.bullet.rectangle",
                            title: "Nothing yet",
                            message: "The log fills in as you play."
                        )
                        Spacer()
                    }
                } else if let session = store.session {
                    VStack(spacing: 0) {
                        undoBar
                        List {
                            ForEach(groups(in: session)) { group in
                                Section {
                                    ForEach(group.phases) { phase in
                                        phaseBlock(phase)
                                    }
                                } header: {
                                    Text("Turn \(group.turn)")
                                }
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("as.battle.log")
            .navigationTitle("Match log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var undoBar: some View {
        if store.canUndo {
            Button(store.undoMenuTitle, systemImage: "arrow.uturn.backward") {
                store.undo()
            }
            .buttonStyle(.bordered)
            .padding(TMSpace.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func phaseBlock(_ phase: PhaseGroup) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            HStack(spacing: TMSpace.sm) {
                Image(systemName: phaseIcon(phase.phase))
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Eyebrow(phase.phase.displayName)
            }
            ForEach(phase.events) { event in
                eventRow(event)
            }
        }
        .padding(.vertical, TMSpace.xs)
    }

    private func eventRow(_ event: MatchEvent) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
                Image(systemName: phaseIcon(event.phase))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    .frame(width: 20)
                Text(event.message)
                    .font(TMFont.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(event.createdAt, style: .relative)
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func phaseIcon(_ phase: PhaseId) -> String {
        switch phase {
        case .initiative: "die.face.5.fill"
        case .movement: "figure.walk"
        case .combat: "scope"
        case .end: "checklist"
        }
    }

    private func groups(in session: MatchSession) -> [TurnGroup] {
        let turns = Array(Set(session.eventLog.map(\.turn))).sorted(by: >)
        return turns.map { turn in
            let events = session.eventLog.filter { $0.turn == turn }
            let phases = phaseOrder(in: events).map { phase in
                PhaseGroup(
                    phase: phase,
                    events: events.filter { $0.phase == phase }.reversed()
                )
            }
            return TurnGroup(turn: turn, phases: phases)
        }
    }

    private func phaseOrder(in events: [MatchEvent]) -> [PhaseId] {
        var seen: [PhaseId] = []
        for event in events where !seen.contains(event.phase) {
            seen.append(event.phase)
        }
        return seen.reversed()
    }
}

private struct TurnGroup: Identifiable {
    var turn: Int
    var phases: [PhaseGroup]
    var id: Int { turn }
}

private struct PhaseGroup: Identifiable {
    var phase: PhaseId
    var events: [MatchEvent]
    var id: PhaseId { phase }
}

#if DEBUG
#Preview("Match log") {
    EventLogSheet(store: BattlePreview.store(session: loggedSession()))
}

private func loggedSession() -> MatchSession {
    var session = PreviewFixtures.session(phase: .combat, turn: 3)
    session.eventLog = [
        MatchEvent(turn: 3, phase: .movement, message: "Side A movement"),
        MatchEvent(turn: 3, phase: .combat, message: "Shadow Hawk hit Locust for 2. Rolled 9, needed 6.")
    ]
    return session
}
#endif
