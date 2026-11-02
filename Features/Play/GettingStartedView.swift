import SwiftUI
import MechBuddyData
import MechBuddyDomain

struct GettingStartedView: View {
    var onPlay: () -> Void

    @Environment(AppDependencies.self) private var dependencies
    @State private var items: [GettingStartedItemDTO] = []
    @State private var expanded: Set<String> = []
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                progressCapsule
                Text("You don’t need to know BattleTech yet. Gather a few things, then start Ridge Line. The app coaches every step.")
                    .font(TMFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let loadError {
                    ErrorBanner(message: loadError) {
                        Task { await load() }
                    }
                } else if checks.isEmpty {
                    ProgressView("Loading checklist")
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    checklist
                    cardLesson
                    playCue
                }
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Getting started")
        .navigationSubtitle(progressSubtitle)
        .accessibilityIdentifier("as.gettingStarted.screen")
        .task { await load() }
    }

    private var checks: [GettingStartedItemDTO] {
        items.filter { $0.id != GettingStartedCatalog.playCueID }
    }

    private var readyCount: Int {
        checks.filter { dependencies.preferences.gettingStartedChecks.contains($0.id) }.count
    }

    private var allReady: Bool {
        !checks.isEmpty && readyCount == checks.count
    }

    private var progressSubtitle: String {
        checks.isEmpty ? "Checklist" : "\(readyCount) of \(checks.count) ready"
    }

    private var progressCapsule: some View {
        Text(progressSubtitle)
            .font(TMFont.detail.weight(.semibold))
            .padding(.horizontal, TMSpace.md)
            .padding(.vertical, TMSpace.xs)
            .background(
                Capsule().fill(allReady ? TMColor.success.opacity(0.18) : Color.secondary.opacity(0.12))
            )
            .accessibilityLabel(progressSubtitle)
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Before you sit down")
            TMCard {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    ForEach(checks) { item in
                        VStack(alignment: .leading, spacing: TMSpace.xs) {
                            ChecklistRow(
                                title: item.title,
                                isChecked: dependencies.preferences.gettingStartedChecks.contains(item.id),
                                accessibilityIdentifier: "as.gettingStarted.check.\(item.id)",
                                detail: expandAction(for: item),
                                externalURL: item.linkURL.flatMap { URL(string: $0) },
                                onToggle: { dependencies.preferences.toggleGettingStarted(item.id) }
                            )
                            if expanded.contains(item.id), let detail = item.detail {
                                Text(detail)
                                    .font(TMFont.detail)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.leading, 36)
                            }
                        }
                    }
                }
            }
        }
        .tmAnimation(TMMotion.state, value: expanded)
        .tmAnimation(TMMotion.state, value: readyCount)
    }

    private var cardLesson: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Reading a unit card")
            TMCard(edgeColor: TMColor.sideA) {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    HStack(spacing: TMSpace.sm) {
                        SideBadge(side: .lanceA)
                        Text("Shadow Hawk SHD-2H")
                            .font(TMFont.cardTitle)
                    }
                    StatStrip(cells: sampleStats)
                    HealthReadout(
                        armorRemaining: 5,
                        armorCapacity: 5,
                        structureRemaining: 5,
                        structureCapacity: 5
                    )
                }
            }
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                legendRow("①", "MV — How many inches it can walk")
                legendRow("②", "TMM — Extra “harder to hit” when it moved")
                legendRow("③", "Armor — Outer hit points")
                legendRow("④", "Structure — Inner hit points. 0 means wrecked")
                legendRow("⑤", "Skill — Starting shot difficulty (4)")
                legendRow("⑥", "S / M / L — Damage at short, medium, and long range")
            }
        }
    }

    private var sampleStats: [StatCell] {
        [
            StatCell(id: "mv", label: "MV", value: "10″/6″j", helpTitle: "Move", helpBody: "How many inches it can walk."),
            StatCell(id: "tmm", label: "TMM", value: "2", helpTitle: "Harder to hit", helpBody: "Added when this ’Mech moved."),
            StatCell(id: "skl", label: "SKL", value: "4", helpTitle: "Skill", helpBody: "Starting shot difficulty."),
            StatCell(id: "dmg", label: "DMG", value: "2·2·1", helpTitle: "Damage", helpBody: "Short, medium, and long range damage.")
        ]
    }

    private var playCue: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            if allReady {
                Label("You’re ready", systemImage: "checkmark.circle.fill")
                    .font(TMFont.cardTitle)
                    .foregroundStyle(TMColor.success)
            }
            if let detail = items.first(where: { $0.id == GettingStartedCatalog.playCueID })?.detail {
                Text(detail)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryActionButton(
                title: "Play Ridge Line",
                systemImage: allReady ? "checkmark" : nil,
                tint: TMColor.signal,
                action: onPlay
            )
        }
    }

    private func legendRow(_ marker: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
            Text(marker)
                .font(TMFont.cardTitle)
                .frame(width: 28, alignment: .leading)
                .accessibilityHidden(true)
            Text(text)
                .font(TMFont.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func expandAction(for item: GettingStartedItemDTO) -> (() -> Void)? {
        guard item.detail != nil else { return nil }
        return { toggleExpanded(item.id) }
    }

    private func toggleExpanded(_ id: String) {
        if expanded.contains(id) {
            expanded.remove(id)
        } else {
            expanded.insert(id)
        }
    }

    private func load() async {
        do {
            items = try dependencies.content.gettingStarted().items
            loadError = nil
        } catch {
            loadError = "Could not load the checklist: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
#Preview("Getting started") {
    PlayPreviewHost {
        NavigationStack {
            GettingStartedView(onPlay: {})
        }
    }
}
#endif
