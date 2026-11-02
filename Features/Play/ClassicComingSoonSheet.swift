import SwiftUI

struct ClassicComingSoonSheet: View {
    var onPlay: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TMSpace.lg) {
                    hexCluster
                    Text("Coming later")
                        .font(TMFont.stepTitle)
                    Text("Classic uses paper record sheets, heat, and hit locations. Mech Buddy will guide those too.")
                        .font(TMFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("For a first night, play Ridge Line.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PrimaryActionButton(
                        title: "Play the beginner game",
                        tint: TMColor.signal,
                        accessibilityIdentifier: "classic.comingSoon.playAS",
                        action: {
                            onPlay()
                            dismiss()
                        }
                    )
                }
                .padding(TMSpace.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Classic BattleTech")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("classic.modeHome")
    }

    private var hexCluster: some View {
        VStack(spacing: TMSpace.xs) {
            HStack(spacing: TMSpace.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    Image(systemName: "hexagon")
                }
            }
            HStack(spacing: TMSpace.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "hexagon")
                }
            }
            .padding(.leading, 18)
        }
        .font(.title2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Classic soon") {
    ClassicComingSoonSheet(onPlay: {})
}
#endif
