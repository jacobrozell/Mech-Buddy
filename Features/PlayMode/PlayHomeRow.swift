import SwiftUI

/// The title and detail lines every Play list row shares: Last setup, Saved forces, Boards, a saved force,
/// a board. `trailing` is an optional symbol (such as the load arrow shown when picking).
struct PlayRowLabel: View {
    var title: String
    var detail: String
    var extraDetail: String?
    var trailingSymbol: String?

    var body: some View {
        HStack(spacing: TMSpace.md) {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(title).font(TMFont.cardTitle)
                Text(detail)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if let extraDetail {
                    Text(extraDetail)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: TMSpace.sm)
            if let trailingSymbol {
                Image(systemName: trailingSymbol)
                    .foregroundStyle(TMColor.signal)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A row on Play home (and the Force tab) that opens something: icon, title, detail, chevron.
/// One home for Last setup, Saved forces and Boards so they look and read alike.
struct PlayHomeRow: View {
    var systemImage: String
    var title: String
    var detail: String
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TMSpace.md) {
                Image(systemName: systemImage)
                    .frame(width: 28)
                    .foregroundStyle(TMColor.signal)
                    .accessibilityHidden(true)
                PlayRowLabel(title: title, detail: detail)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
