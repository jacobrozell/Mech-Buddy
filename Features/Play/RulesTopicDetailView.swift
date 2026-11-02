import SwiftUI
import MechBuddyData

struct RulesTopicDetailView: View {
    let topic: RulesTopicDTO

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                if topic.id == "odds" {
                    oddsPicture
                }
                if topic.id == "sator" {
                    satorLegend
                }
                ForEach(topic.sections, id: \.heading) { section in
                    VStack(alignment: .leading, spacing: TMSpace.sm) {
                        heading(section.heading)
                        Text(section.body)
                            .font(.body)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .navigationTitle(topic.title)
        .accessibilityIdentifier("rules.as.detail.\(topic.id)")
    }

    private var oddsPicture: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Text("A 7 or higher is the common case")
                .font(.title3.weight(.semibold))
            TNGauge(
                targetNumber: 7,
                previewIdentifier: "rules.as.odds.sample",
                gaugeIdentifier: nil
            )
        }
    }

    private var satorLegend: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Text("Five pieces")
                .font(.title3.weight(.semibold))
            ForEach(Self.satorRows, id: \.letter) { row in
                HStack(alignment: .firstTextBaseline, spacing: TMSpace.md) {
                    Text(row.letter)
                        .font(TMFont.cardTitle)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: TMSpace.xxs) {
                        Text(row.name)
                            .font(TMFont.cardTitle)
                        Text(row.detail)
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func heading(_ text: String) -> some View {
        if let numbered = numberedHeading(text) {
            HStack(alignment: .firstTextBaseline, spacing: TMSpace.sm) {
                Text(numbered.number)
                    .font(.caption.weight(.bold))
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.15), in: Circle())
                    .accessibilityHidden(true)
                Text(numbered.title)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(numbered.number). \(numbered.title)")
            .accessibilityAddTraits(.isHeader)
        } else {
            Text(text)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func numberedHeading(_ text: String) -> (number: String, title: String)? {
        guard let dot = text.firstIndex(of: ".") else { return nil }
        let number = text[..<dot]
        guard !number.isEmpty, number.count <= 2, number.allSatisfy(\.isNumber) else { return nil }
        let title = text[text.index(after: dot)...].trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }
        return (String(number), title)
    }

    private static let satorRows: [(letter: String, name: String, detail: String)] = [
        ("S", "Skill", "Starting number on the card, usually 4"),
        ("A", "Attacker", "How you moved"),
        ("T", "Target", "How they moved"),
        ("O", "Other", "Woods, cover, and criticals"),
        ("R", "Range", "Short, medium, or long")
    ]
}

#if DEBUG
#Preview("Rules topic") {
    PlayPreviewHost {
        RulesTopicPreview()
    }
}

private struct RulesTopicPreview: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var topic: RulesTopicDTO?

    var body: some View {
        NavigationStack {
            if let topic {
                RulesTopicDetailView(topic: topic)
            } else {
                ProgressView("Loading topic")
            }
        }
        .task {
            topic = try? dependencies.content.rulesTopics().topics.first { $0.id == "turn" }
        }
    }
}
#endif
