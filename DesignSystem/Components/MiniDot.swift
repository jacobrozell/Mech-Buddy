import SwiftUI
import MechBuddyDomain

extension TMColor {
    /// Paint colours for miniature tags. Literal hues on purpose: they name the paint on the table.
    static func mini(_ marker: MiniMarker) -> Color {
        switch marker {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        case .white: .white
        case .grey: .gray
        case .black: .black
        }
    }
}

/// Small paint dot for a tagged miniature. Outlined so white and black read on either theme.
struct MiniDot: View {
    var marker: MiniMarker
    var size: CGFloat = 14

    var body: some View {
        Circle()
            .fill(TMColor.mini(marker))
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.35), lineWidth: 1))
            .frame(width: size, height: size)
            .accessibilityLabel("\(marker.displayName) mini")
    }
}

/// Menu that tags a unit's miniature with a colour.
struct MiniMarkerMenu: View {
    var unitName: String
    var marker: MiniMarker?
    var onPick: (MiniMarker?) -> Void

    var body: some View {
        Menu {
            Picker("Mini colour", selection: Binding(get: { marker }, set: onPick)) {
                Text("No colour").tag(MiniMarker?.none)
                ForEach(MiniMarker.allCases) { option in
                    Text(option.displayName).tag(MiniMarker?.some(option))
                }
            }
        } label: {
            HStack(spacing: TMSpace.xs) {
                if let marker {
                    MiniDot(marker: marker)
                    Text("\(marker.displayName) mini")
                } else {
                    Image(systemName: "paintpalette")
                    Text("Mark mini")
                }
            }
            .font(TMFont.detail)
            .frame(minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel(marker.map { "\(unitName) mini, \($0.displayName)" } ?? "Mark \(unitName) mini colour")
        .accessibilityHint("Pick the colour of this ’Mech’s miniature so you can match it to its card")
    }
}
