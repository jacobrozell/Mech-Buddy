import SwiftUI

struct ChecklistRow: View {
    var title: String
    var isChecked: Bool
    var accessibilityIdentifier: String?
    var detail: (() -> Void)?
    var externalURL: URL?
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: TMSpace.sm) {
            Button(action: onToggle) {
                HStack(spacing: TMSpace.sm) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isChecked ? TMColor.success : Color.secondary)
                        .imageScale(.large)
                    Text(title)
                        .font(TMFont.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .accessibilityID(accessibilityIdentifier)
            .accessibilityAddTraits(isChecked ? .isSelected : [])
            .accessibilityRemoveTraits(isChecked ? [] : .isSelected)
            if let detail {
                Button(action: detail) {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Details")
            }
            if let externalURL {
                Link(destination: externalURL) {
                    Image(systemName: "safari")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(title)
                .accessibilityHint("Opens in Safari")
            }
        }
    }
}

#if DEBUG
#Preview("Checklist") {
    PreviewPair {
        VStack {
            ChecklistRow(title: "Two dice", isChecked: true, accessibilityIdentifier: "preview.check", onToggle: {})
            ChecklistRow(
                title: "Quick-start rules",
                isChecked: false,
                externalURL: URL(string: "https://jacobrozell.github.io/Mech-Buddy/support.html"),
                onToggle: {}
            )
        }
    }
}
#endif
