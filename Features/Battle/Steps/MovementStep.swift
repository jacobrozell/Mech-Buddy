import SwiftUI
import MechBuddyDomain

struct MovementStep: View {
    var session: MatchSession
    var coach: BattleCoach
    var showsUnits: Bool = true
    var onSetMove: (UUID, MovementMode) -> Void
    var onReviseMove: (UUID, MovementMode) -> Void
    var onOpenUnit: (MatchUnitState) -> Void

    @State private var showTable = false
    @State private var lastChoice: String?
    /// The active side picks which of its ’Mechs moves next (Alpha Strike lets players choose).
    @State private var chosenUnitId: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var candidates: [MatchUnitState] {
        AlphaStrikePhaseEngine.unitsNeedingMove(side: session.activeSide, units: session.units)
    }

    private var current: MatchUnitState? {
        candidates.first { $0.id == chosenUnitId } ?? candidates.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: verticalSizeClass == .compact ? TMSpace.md : TMSpace.lg) {
            CoachPrompt(
                title: coach.movementComplete
                    ? "Moves locked in"
                    : coach.otherMechStillToMove
                        ? "\(session.activeSide.displayName)’s other ’Mech"
                        : "\(session.activeSide.displayName) moves",
                // "Everyone has moved" read wrong when a ’Mech stood still.
                message: coach.movementComplete
                    ? "Every ’Mech’s move is set. Change any of them before you start shooting."
                    : candidates.count > 1
                        ? "Pick which ’Mech moves, measure on the table, then tap how it moved."
                        : "Measure on the table, then tap how it moved.",
                side: session.activeSide,
                accessibilityIdentifier: "as.battle.table"
            )
            wreckNotice
            if let current {
                moverCard(current)
                    .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
            orderSection
            if showsUnits {
                tableSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tmAnimation(TMMotion.state, value: current?.id)
        .tmHaptic(.dieFaceSelected, trigger: lastChoice, when: { $0 != nil })
        .onAppear {
            if sizeClass == .regular {
                showTable = true
            }
        }
    }

    @ViewBuilder
    private var wreckNotice: some View {
        let wrecks = session.units.filter { $0.combatStatus == .destroyedPendingEnd }
        if !wrecks.isEmpty {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                ForEach(wrecks) { unit in
                    HStack(spacing: TMSpace.sm) {
                        Text(unit.name)
                            .font(TMFont.cardTitle)
                        StatusChip(kind: .wrecked)
                    }
                }
            }
        }
    }

    private func moverCard(_ unit: MatchUnitState) -> some View {
        let move = PrintedMove(unit.effectiveMV)
        return TMCard(edgeColor: TMColor.side(unit.side), isRaised: true) {
            VStack(alignment: .leading, spacing: verticalSizeClass == .compact ? TMSpace.sm : TMSpace.md) {
                if verticalSizeClass != .compact {
                    Eyebrow("Now moving")
                }
                HStack(spacing: TMSpace.sm) {
                    SideBadge(side: unit.side)
                    Text(unit.name)
                        .font(TMFont.stepTitle)
                    // Landscape: move stats share the name row so the tiles stay above the fold.
                    if verticalSizeClass == .compact, !unit.isImmobile, let move {
                        Spacer(minLength: TMSpace.sm)
                        Text(move.summary)
                            .font(TMFont.cardTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(move.spokenSummary)
                    }
                }
                if verticalSizeClass == .compact, !unit.isImmobile {
                    EmptyView()
                } else if unit.isImmobile {
                    Text("Can’t move this turn")
                        .font(TMFont.body)
                    StatusChip(kind: .immobile)
                } else if let move {
                    Text(move.summary)
                        .font(TMFont.readoutM)
                        .accessibilityLabel(move.spokenSummary)
                }
                LazyVGrid(columns: columns, spacing: TMSpace.sm) {
                    ForEach(unit.legalMovementModes, id: \.self) { mode in
                        moveTile(mode: mode, unit: unit, move: unit.isImmobile ? nil : move)
                    }
                }
            }
        }
    }

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        // iPad and phone landscape: all four move tiles in one row, above the fold.
        if sizeClass == .regular || verticalSizeClass == .compact {
            return Array(repeating: GridItem(.flexible(), spacing: TMSpace.sm), count: 4)
        }
        return [GridItem(.flexible(), spacing: TMSpace.sm), GridItem(.flexible(), spacing: TMSpace.sm)]
    }

    private func moveTile(mode: MovementMode, unit: MatchUnitState, move: PrintedMove?) -> some View {
        let verb = unit.isImmobile && mode == .standstill ? "Stays put" : tileVerb(mode)
        return Button {
            lastChoice = "\(unit.id.uuidString)-\(mode.rawValue)"
            onSetMove(unit.id, mode)
        } label: {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Image(systemName: icon(mode))
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(verb)
                    .font(TMFont.cardTitle)
                if let detail = move?.detail(for: mode) {
                    Text(detail)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                if let note = consequence(mode), !unit.isImmobile {
                    Text(note)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(TMSpace.sm)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle)
        .tint(TMColor.side(unit.side))
        .accessibilityLabel(tileLabel(mode: mode, unit: unit, move: move))
        .accessibilityIdentifier("as.battle.move.\(mode.rawValue)")
    }

    private var orderSection: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow("Move order this turn")
            ForEach(moveOrder) { entry in
                orderRow(entry)
            }
        }
    }

    private func orderRow(_ entry: MoveOrderEntry) -> some View {
        HStack(spacing: TMSpace.sm) {
            SideBadge(side: entry.unit.side)
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(entry.unit.name)
                    .font(TMFont.cardTitle)
                Text(entry.marker.label(recordedMoveName(entry.unit.movementMode)))
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: TMSpace.sm)
            if entry.marker == .done {
                changeMenu(entry.unit)
            } else if entry.unit.side == session.activeSide, entry.unit.id != current?.id {
                Button("Move this one") {
                    chosenUnitId = entry.unit.id
                }
                .font(TMFont.detail.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityLabel("Move \(entry.unit.name) instead")
            }
        }
        .accessibilityElement(
            children: entry.marker == .done || (entry.unit.side == session.activeSide && entry.unit.id != current?.id)
                ? .contain : .combine
        )
    }

    private func changeMenu(_ unit: MatchUnitState) -> some View {
        Menu {
            ForEach(unit.legalMovementModes, id: \.self) { mode in
                Button(menuTitle(mode)) {
                    onReviseMove(unit.id, mode)
                }
            }
        } label: {
            Text("Change")
                .font(TMFont.detail.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityLabel("Change move for \(unit.name)")
    }

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Button {
                showTable.toggle()
            } label: {
                HStack {
                    Eyebrow("On the table")
                    Image(systemName: showTable ? "chevron.up" : "chevron.down")
                        .font(TMFont.detail.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("On the table")
            .accessibilityValue(showTable ? "Expanded" : "Collapsed")
            if showTable {
                ForEach(session.units.filter { $0.combatStatus != .removed }) { unit in
                    UnitCard(
                        unit: unit,
                        isActiveSide: unit.side == session.activeSide && unit.id == current?.id,
                        accessibilityIdentifier: "as.battle.unit.\(unit.id.uuidString)",
                        action: { onOpenUnit(unit) }
                    )
                }
            }
        }
    }

    private var moveOrder: [MoveOrderEntry] {
        let active = session.units.filter { $0.combatStatus == .active }
        var remaining: [SideId: [MatchUnitState]] = [
            .lanceA: active.filter { $0.side == .lanceA && !$0.hasMovedThisTurn },
            .lanceB: active.filter { $0.side == .lanceB && !$0.hasMovedThisTurn }
        ]
        // The chosen ’Mech is "Now"; the rest of its side follows.
        if let current, var queue = remaining[current.side],
           let index = queue.firstIndex(where: { $0.id == current.id }) {
            queue.insert(queue.remove(at: index), at: 0)
            remaining[current.side] = queue
        }
        var upcoming: [MatchUnitState] = []
        var side = session.activeSide
        while upcoming.count < active.count {
            let currentQueue = remaining[side] ?? []
            let other = side.other
            let otherQueue = remaining[other] ?? []
            if currentQueue.isEmpty && otherQueue.isEmpty { break }
            if !currentQueue.isEmpty {
                upcoming.append(currentQueue[0])
                remaining[side] = Array(currentQueue.dropFirst())
            }
            if !(remaining[other]?.isEmpty ?? true) {
                side = other
            }
        }
        var entries = upcoming.enumerated().map { index, unit in
            MoveOrderEntry(unit: unit, marker: index == 0 ? .now : index == 1 ? .next : .later)
        }
        let done = active.filter(\.hasMovedThisTurn)
        entries.append(contentsOf: done.map { MoveOrderEntry(unit: $0, marker: .done) })
        return entries
    }

    private func tileVerb(_ mode: MovementMode) -> String {
        switch mode {
        case .standstill: "Stood still"
        case .ground: "Walk"
        case .sprint: "Sprint"
        case .jump: "Jump"
        case .unset: "Move"
        }
    }

    private func menuTitle(_ mode: MovementMode) -> String {
        switch mode {
        case .standstill: "Stood still"
        case .ground: "Walk"
        case .sprint: "Sprint"
        case .jump: "Jump"
        case .unset: "Not recorded"
        }
    }

    private func icon(_ mode: MovementMode) -> String {
        switch mode {
        case .standstill: "figure.stand"
        case .ground, .unset: "figure.walk"
        case .sprint: "figure.run"
        case .jump: "arrow.up.forward"
        }
    }

    private func consequence(_ mode: MovementMode) -> String? {
        switch mode {
        case .sprint: "can’t shoot"
        case .jump: "harder shot"
        default: nil
        }
    }

    private func tileLabel(mode: MovementMode, unit: MatchUnitState, move: PrintedMove?) -> String {
        if unit.isImmobile { return "Stays put" }
        return move?.spokenChoice(mode) ?? tileVerb(mode)
    }
}

private struct MoveOrderEntry: Identifiable {
    var unit: MatchUnitState
    var marker: Marker

    var id: UUID { unit.id }

    enum Marker {
        case now
        case next
        case later
        case done

        func label(_ recorded: String) -> String {
            switch self {
            case .now: "Now"
            case .next: "Next"
            case .later: "Later"
            case .done: recorded
            }
        }
    }
}

#if DEBUG
#Preview("Movement") {
    ScrollView {
        MovementStep(
            session: PreviewFixtures.session(phase: .movement),
            coach: BattleCoach(session: PreviewFixtures.session(phase: .movement)),
            onSetMove: { _, _ in },
            onReviseMove: { _, _ in },
            onOpenUnit: { _ in }
        )
        .padding()
    }
}
#endif
