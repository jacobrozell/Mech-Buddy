import SwiftUI
import MechBuddyData

/// The row on the Rules tab that opens Lore. Styled exactly like a Rules topic row.
struct LoreEntryRow: View {
    var body: some View {
        NavigationLink {
            LoreOverviewView()
        } label: {
            LoreRow(symbol: "clock.arrow.circlepath", title: "BattleTech history", detail: "Eras from the Star League to today")
        }
        .accessibilityIdentifier("as.lore.entry")
        .accessibilityHint("Opens the history overview")
    }
}

/// Icon tile, title and detail line: the same layout as a Rules topic row.
private struct LoreRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: TMSpace.md) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(title)
                    .font(TMFont.body)
                Text(detail)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct LoreFootnote: View {
    var body: some View {
        Text("History condensed from Sarna BattleTechWiki (GFDL 1.2); eras per Catalyst Game Labs.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("as.lore.attribution")
    }
}

/// Loads the lore file once for a Lore screen.
private struct LoreLoader<Content: View>: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var lore: LoreDocumentDTO?
    @State private var loadError: String?
    @ViewBuilder var content: (LoreDocumentDTO) -> Content

    var body: some View {
        Group {
            if let lore {
                content(lore)
            } else if let loadError {
                EmptyState(
                    systemImage: "book.closed",
                    title: "Couldn’t load the history",
                    message: loadError,
                    actionTitle: "Try again",
                    action: { load() }
                )
            } else {
                ProgressView("Loading history")
            }
        }
        .task { load() }
    }

    private func load() {
        do {
            lore = try dependencies.content.lore()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct LoreOverviewView: View {
    var body: some View {
        LoreLoader { lore in
            List {
                Section {
                    Text(lore.summary.onParagraph)
                        .font(.body)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("as.lore.summary")
                }
                Section("Eras") {
                    ForEach(lore.eras) { era in
                        NavigationLink {
                            LoreEraDetailView(era: era)
                        } label: {
                            LoreRow(symbol: "calendar", title: era.name, detail: era.yearLabel)
                        }
                        .accessibilityIdentifier("as.lore.era.\(era.id)")
                        .accessibilityHint("Opens this era")
                    }
                }
                Section {
                    NavigationLink {
                        LoreTimelineView()
                    } label: {
                        LoreRow(symbol: "list.bullet", title: "Timeline", detail: "Key events in order")
                    }
                    .accessibilityIdentifier("as.lore.timeline.entry")
                }
                Section { LoreFootnote() }
            }
        }
        .navigationTitle("History")
        .accessibilityIdentifier("as.lore.overview")
    }
}

struct LoreEraDetailView: View {
    let era: LoreEraDTO

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                Text(era.yearLabel)
                    .font(TMFont.eyebrow)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, TMSpace.sm)
                    .padding(.vertical, TMSpace.xs)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                ForEach(era.subEras) { sub in
                    subEra(sub)
                }
                LoreFootnote()
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .navigationTitle(era.name)
        .accessibilityIdentifier("as.lore.era.detail.\(era.id)")
    }

    private func subEra(_ sub: LoreSubEraDTO) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            // An era with one sub-era of the same name would repeat the title and the year chip.
            if !(era.subEras.count == 1 && sub.name == era.name) {
                Text(sub.name)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(sub.yearLabel)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            Text(sub.summary)
                .font(.body)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            list("Key events", sub.keyEvents)
            list("Factions", sub.keyFactions)
            list("Technologies", sub.keyTechnologies)
        }
        .accessibilityIdentifier("as.lore.subera.\(sub.id)")
    }

    @ViewBuilder
    private func list(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Text(title)
                    .font(TMFont.cardTitle)
                    .padding(.top, TMSpace.xs)
                    .accessibilityAddTraits(.isHeader)
                ForEach(items, id: \.self) { item in
                    Label {
                        Text(item)
                            .font(TMFont.detail)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct LoreTimelineView: View {
    var body: some View {
        LoreLoader { lore in
            List {
                ForEach(lore.timeline) { event in
                    VStack(alignment: .leading, spacing: TMSpace.xxs) {
                        if let label = event.dateLabel ?? event.startYear.map(String.init) {
                            Text(label)
                                .font(TMFont.eyebrow)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.name)
                            .font(TMFont.body)
                        Text(event.summary)
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("as.lore.event.\(event.id)")
                }
                Section { LoreFootnote() }
            }
        }
        .navigationTitle("Timeline")
        .accessibilityIdentifier("as.lore.timeline")
    }
}

#if DEBUG
#Preview("Lore") {
    PlayPreviewHost {
        NavigationStack { LoreOverviewView() }
    }
}
#endif
