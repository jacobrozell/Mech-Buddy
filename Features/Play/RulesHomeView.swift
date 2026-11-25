import SwiftUI
import UIKit
import MechBuddyData

struct RulesHomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var library: RulesLibrary?
    @State private var query = ""
    @State private var loadError: String?
    @State private var selection: String?

    /// The game whose rules are listed. Follows the onboarding game until the player picks one here.
    private var game: LearningTrack {
        dependencies.preferences.rulesGameToShow
    }

    private var gameBinding: Binding<LearningTrack> {
        Binding(
            get: { dependencies.preferences.rulesGameToShow },
            set: { dependencies.preferences.rulesGame = $0 }
        )
    }

    private var topics: [RulesTopicDTO] {
        library?.topics(for: game) ?? []
    }

    private var disclaimer: String? {
        library?.disclaimer(for: game)
    }

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
        .rulesListChrome(query: $query, game: game)
        .task { await load() }
    }

    private var splitList: some View {
        List(selection: $selection) {
            topicSections(split: true)
        }
        .rulesListChrome(query: $query, game: game)
        .task { await load() }
        .onChange(of: topics.map(\.id)) { _, ids in
            // A new game has different topics; keep the selection only if it is still listed.
            if selection.map({ !ids.contains($0) }) ?? true {
                selection = ids.first
            }
        }
    }

    @ViewBuilder
    private func topicSections(split: Bool) -> some View {
        Section {
            RulesGameSwitch(selection: gameBinding)
            if game == .classic {
                // Kept to one short line: at the largest text size the longer note filled the first screen.
                Label("Rules only. Classic isn’t playable yet.", systemImage: "info.circle")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("rules.classicNote")
            }
        }
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
                            .accessibilityIdentifier(RulesGroup.identifier(for: topic))
                            .accessibilityHint("Opens this topic")
                    } else {
                        NavigationLink {
                            RulesTopicDetailView(topic: topic)
                        } label: {
                            topicRow(topic)
                        }
                        .accessibilityIdentifier(RulesGroup.identifier(for: topic))
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
            library = try dependencies.content.rulesLibrary()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            library = nil
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

    /// `rules.as.{id}`, `rules.classic.{id}`, or `rules.both.{id}`.
    static func identifier(for topic: RulesTopicDTO) -> String {
        "rules.\((topic.game ?? .alphaStrike).identifierKey).\(topic.id)"
    }

    static func symbol(for id: String) -> String {
        let key = id.hasPrefix("classic-") ? String(id.dropFirst("classic-".count)) : id
        return switch key {
        case "how-to-play", "about": "questionmark.circle"
        case "differences": "arrow.left.arrow.right"
        case "turn": "arrow.triangle.2.circlepath"
        case "movement": "figure.walk"
        case "combat": "scope"
        case "sator", "to-hit": "target"
        case "damage": "shield.lefthalf.filled"
        case "heat": "thermometer.medium"
        case "physical": "hand.raised"
        case "withdrawal": "arrow.uturn.backward"
        case "points": "scalemass"
        case "piloting": "figure.fall"
        case "criticals": "exclamationmark.triangle"
        case "quickstart": "book"
        case "tables", "numbers": "tablecells"
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

/// "Alpha Strike | Classic" at the top of the Rules tab. Segments truncate at accessibility sizes,
/// so there the two games stack as full-width rows.
struct RulesGameSwitch: View {
    @Binding var selection: LearningTrack
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    Text("Rules for")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    ForEach(LearningTrack.allCases) { game in
                        stackedRow(game)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Rules for")
            } else {
                Picker("Rules for", selection: $selection) {
                    ForEach(LearningTrack.allCases) { game in
                        Text(RulesGameChoice.shortTitle(game))
                            .tag(game)
                            .accessibilityIdentifier("rules.game.\(game.rawValue)")
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityHint("Shows the rules for this game.")
            }
        }
        .accessibilityIdentifier("rules.gamePicker")
    }

    private func stackedRow(_ game: LearningTrack) -> some View {
        let isSelected = selection == game
        return Button {
            selection = game
        } label: {
            HStack(spacing: TMSpace.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
                Text(RulesGameChoice.shortTitle(game))
                    .font(TMFont.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(RulesGameChoice.shortTitle(game)) rules")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("rules.game.\(game.rawValue)")
    }
}

private extension View {
    func rulesListChrome(query: Binding<String>, game: LearningTrack) -> some View {
        self
            .navigationTitle("Rules")
            .accessibilityIdentifier("rules.home")
            .searchable(text: query, prompt: "Search \(RulesGameChoice.shortTitle(game)) rules")
    }
}

#if DEBUG
#Preview("Rules") {
    PlayPreviewHost {
        RulesHomeView()
    }
}
#endif
