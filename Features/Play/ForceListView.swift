import SwiftUI
import MechBuddyData
import MechBuddyDomain

struct ForceListView: View {
    private var previewUnits: [MatchUnitState]?

    @Environment(AppDependencies.self) private var dependencies
    @State private var units: [MatchUnitState]
    @State private var loadedSession: MatchSession?
    @State private var loadError: String?
    @State private var didLoad: Bool
    @State private var selection: ForceSelection?

    init(previewUnits: [MatchUnitState]? = nil) {
        self.previewUnits = previewUnits
        _units = State(initialValue: previewUnits ?? [])
        _loadedSession = State(initialValue: nil)
        _loadError = State(initialValue: nil)
        _didLoad = State(initialValue: previewUnits != nil)
        _selection = State(initialValue: nil)
    }

    var body: some View {
        Group {
            if let loadError {
                EmptyState(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn’t load the roster",
                    message: loadError,
                    actionTitle: "Try again",
                    action: { Task { await loadForces() } }
                )
            } else if !didLoad {
                ProgressView("Loading roster")
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else if units.isEmpty {
                EmptyState(
                    systemImage: "person.3",
                    title: "Couldn’t load the roster",
                    message: "The mission file didn’t include any ’Mechs.",
                    actionTitle: "Try again",
                    action: { Task { await loadForces() } }
                )
            } else {
                roster
            }
        }
        .navigationTitle("Force")
        .accessibilityIdentifier("force.as.list")
        .task(id: dependencies.sessionRevision) {
            guard previewUnits == nil else { return }
            await loadForces()
        }
        .sheet(item: $selection) { selection in
            UnitFocusSheet(
                unit: selection.unit,
                session: selection.session,
                isReadOnly: true
            )
        }
    }

    private var roster: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                contextLabel
                ForEach(SideId.allCases, id: \.self) { side in
                    sideSection(side)
                }
                PVBalanceBar(
                    sideA: PlayForceMath.pointValue(of: .lanceA, in: units),
                    sideB: PlayForceMath.pointValue(of: .lanceB, in: units)
                )
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private var contextLabel: some View {
        Text(loadedSession == nil ? "Ridge Line roster" : "In this match")
            .font(TMFont.detail.weight(.semibold))
            .padding(.horizontal, TMSpace.md)
            .padding(.vertical, TMSpace.xs)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func sideSection(_ side: SideId) -> some View {
        let sideUnits = units.filter { $0.side == side }
        if !sideUnits.isEmpty {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow(side.displayName) {
                    HStack(spacing: TMSpace.sm) {
                        SideBadge(side: side)
                        Text("PV \(PlayForceMath.pointValue(of: side, in: units))")
                            .font(TMFont.stat)
                            .monospacedDigit()
                    }
                }
                ForEach(sideUnits) { unit in
                    ForceUnitCard(
                        unit: unit,
                        accessibilityIdentifier: "force.as.unit.\(unit.name)"
                    ) {
                        open(unit)
                    }
                    .background {
                        Color.clear
                            .frame(width: 1, height: 1)
                            .accessibilityElement()
                            .accessibilityIdentifier("force.as.unit.\(unit.id.uuidString)")
                            .accessibilityLabel(unit.name)
                    }
                }
            }
        }
    }

    private func open(_ unit: MatchUnitState) {
        let session = loadedSession ?? MatchSession(
            scenarioId: .ridgeLine,
            ruleset: .ridgeLine,
            units: units,
            forcesLoaded: true
        )
        selection = ForceSelection(unit: unit, session: session)
    }

    private func loadForces() async {
        do {
            if let session = try MatchStore.loadActive(from: dependencies.matchSessions) {
                loadedSession = session
                units = session.units
            } else {
                let scenario = try dependencies.content.ridgeLineScenario()
                loadedSession = nil
                units = RidgeLineFactory.makeUnits(from: scenario)
            }
            loadError = nil
            didLoad = true
        } catch {
            loadError = error.localizedDescription
            units = []
            loadedSession = nil
            didLoad = true
        }
    }
}

private struct ForceSelection: Identifiable {
    var unit: MatchUnitState
    var session: MatchSession
    var id: UUID { unit.id }
}

private struct PVBalanceBar: View {
    var sideA: Int
    var sideB: Int

    var body: some View {
        let total = max(sideA + sideB, 1)
        let gap = abs(sideA - sideB)
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("PV balance")
            HStack(spacing: TMSpace.sm) {
                SideBadge(side: .lanceA)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        Capsule()
                            .fill(TMColor.sideA)
                            .frame(width: geo.size.width * CGFloat(sideA) / CGFloat(total))
                        Capsule()
                            .fill(TMColor.sideB)
                            .frame(width: geo.size.width * CGFloat(sideB) / CGFloat(total))
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)
                SideBadge(side: .lanceB)
            }
            Text(caption(gap: gap))
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Point value balance. Side A \(sideA), Side B \(sideB). \(caption(gap: gap))")
    }

    private func caption(gap: Int) -> String {
        if gap == 0 { return "Even" }
        if gap <= 5 { return "Gap \(gap) — even" }
        let leader = sideA > sideB ? SideId.lanceA.displayName : SideId.lanceB.displayName
        return "Gap \(gap) — \(leader) ahead"
    }
}

#if DEBUG
#Preview("Force") {
    PlayPreviewHost {
        NavigationStack {
            ForceListView(previewUnits: [PreviewFixtures.shadowHawk, PreviewFixtures.locust])
        }
    }
}
#endif
