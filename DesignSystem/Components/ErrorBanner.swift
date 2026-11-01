import SwiftUI

struct ErrorBanner: View {
    var message: String
    var retryTitle: String = "Try again"
    var accessibilityIdentifier: String?
    var linkTitle: String?
    var linkURL: URL?
    var onRetry: (() -> Void)?

    var body: some View {
        TMCard(edgeColor: TMColor.danger) {
            HStack(alignment: .top, spacing: TMSpace.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(TMColor.danger)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    Text(message)
                        .font(TMFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                    if let linkURL, let linkTitle {
                        Link(linkTitle, destination: linkURL)
                            .font(TMFont.detail)
                    }
                    if let onRetry {
                        Button(retryTitle, action: onRetry)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityID(accessibilityIdentifier)
    }
}

#if DEBUG
#Preview("Error") {
    PreviewPair {
        ErrorBanner(message: "The mission file didn’t load.", onRetry: {})
    }
}
#endif
