import SwiftUI

struct InfoLink: Identifiable, Sendable {
    var title: String
    var url: URL
    var id: String { title }
}

struct InfoContent: View {
    var title: String
    var message: String
    var links: [InfoLink] = []

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Text(title)
                .font(TMFont.cardTitle)
            Text(message)
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(links) { link in
                Link(link.title, destination: link.url)
                    .font(TMFont.detail)
                    .accessibilityHint("Opens in Safari")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Info content") {
    PreviewPair {
        InfoContent(
            title: "Move",
            message: "Inches this ’Mech can walk. Jump, when printed, is the number before the j.",
            links: [InfoLink(title: "Rules", url: URL(string: "https://jacobrozell.github.io/Mech-Buddy/support.html")!)]
        )
    }
}
#endif
