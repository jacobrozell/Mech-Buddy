import SwiftUI
import UIKit
import MechBuddyData

struct RulesHomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var topics: [RulesTopicDTO] = []
    @State private var disclaimer: String?
    @State private var query = ""
    @State private var loadError: String?
    @State private var selection: String?

    private var usesSplit: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    var body: some View {
        if usesSplit {
            NavigationSplitView {
                splitList
            } detail: {
                if let topic = topics.first(where: { $0.id == selection }) {
                    RulesTopicDetailView(topic: topic)
                } else {
                    ContentUnavailableView(
                        "Choose a topic",
                        systemImage: "book.closed",
                        description: Text("Pick a topic from the list.")
                    )
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack {
                stackList
            }
        }
    }

    private var stackList: some View {
        List {
            topicSections(split: false)
        }
        .rulesListChrome(query: $query)
        .task { await load() }
    }

    private var splitList: some View {
        List(selection: $selection) {
            topicSections(split: true)
        }
        .rulesListChrome(query: $query)
        .task { await load() }
        .onChange(of: topics.map(\.id)) { _, ids in
            if selection == nil {
                selection = ids.first
            }
        }
    }

    @ViewBuilder
    private func topicSections(split: Bool) -> some View {
        if let loadError {
            EmptyState(
                systemImage: "book.closed",
                title: "Couldn’t load the rules",
                message: loadError,
                actionTitle: "Try again",
                action: { Task { await load() } }
            )
        }
        if grouped.isEmpty, !query.isEmpty {
            EmptyState(
                systemImage: "magnifyingglass",
                title: "No matching topics",
                message: "Try a different word from the title or the text."
            )
        }
        ForEach(grouped, id: \.group) { section in
            Section(section.group.title) {
                ForEach(section.topics) { topic in
                    if split {
                        topicRow(topic)
                            .tag(topic.id)
                            .accessibilityIdentifier("rules.as.\(topic.id)")
                            .accessibilityHint("Opens this topic")
                    } else {
                        NavigationLink {
                            RulesTopicDetailView(topic: topic)
                        } label: {
                            topicRow(topic)
                        }
                        .accessibilityIdentifier("rules.as.\(topic.id)")
                        .accessibilityHint("Opens this topic")
                    }
                }
            }
        }
        if let disclaimer, query.isEmpty {
            Section {
                Text(disclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var grouped: [(group: RulesGroup, topics: [RulesTopicDTO])] {
        RulesGroup.allCases.compactMap { group in
            let rows = topics.filter { matches($0) && RulesGroup.resolve($0) == group }
            return rows.isEmpty ? nil : (group, rows)
        }
    }

    private func matches(_ topic: RulesTopicDTO) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let parts = [topic.title, topic.summary ?? ""] + topic.sections.flatMap { [$0.heading, $0.body] }
        return parts.joined(separator: "\n").localizedStandardContains(needle)
    }

    private func topicRow(_ topic: RulesTopicDTO) -> some View {
        HStack(spacing: TMSpace.md) {
            Image(systemName: RulesGroup.symbol(for: topic.id))
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(topic.title)
                    .font(TMFont.body)
                Text(RulesGroup.summary(for: topic))
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func load() async {
        do {
            let packed = try dependencies.content.rulesTopics()
            topics = packed.topics
            disclaimer = packed.disclaimer
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            topics = []
        }
    }
}

enum RulesGroup: String, CaseIterable {
    case start
    case during
    case reference

    var title: String {
        switch self {
        case .start: "Start here"
        case .during: "During a game"
        case .reference: "Quick reference"
        }
    }

    static func resolve(_ topic: RulesTopicDTO) -> RulesGroup {
        if let group = topic.group, let parsed = RulesGroup(rawValue: group) {
            return parsed
        }
        switch topic.id {
        case "how-to-play", "turn":
            return .start
        case "movement", "combat", "sator", "damage":
            return .during
        default:
            return .reference
        }
    }

    static func symbol(for id: String) -> String {
        switch id {
        case "how-to-play": "questionmark.circle"
        case "turn": "arrow.triangle.2.circlepath"
        case "movement": "figure.walk"
        case "combat": "scope"
        case "sator": "target"
        case "damage": "shield.lefthalf.filled"
        case "tables": "tablecells"
        case "abbreviations": "textformat.abc"
        case "odds": "chart.bar"
        default: "book.closed"
        }
    }

    static func summary(for topic: RulesTopicDTO) -> String {
        if let summary = topic.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            return summary
        }
        guard let body = topic.sections.first?.body else { return "" }
        if let period = body.firstIndex(of: ".") {
            return String(body[...period])
        }
        return body
    }
}

private extension View {
    func rulesListChrome(query: Binding<String>) -> some View {
        self
            .navigationTitle("Rules")
            .accessibilityIdentifier("rules.home")
            .searchable(text: query, prompt: "Search titles and text")
    }
}

#if DEBUG
#Preview("Rules") {
    PlayPreviewHost {
        RulesHomeView()
    }
}
#endif
