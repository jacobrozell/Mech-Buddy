import SwiftUI
import MechBuddyData
import MechBuddyDomain

struct SettingsHomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(PlayMatchCoordinator.self) private var matches
    @Environment(\.openOnboarding) private var openOnboarding
    @State private var confirmDelete = false
    @State private var deleteError: String?

    var body: some View {
        Form {
            Section {
                Picker(selection: Bindable(dependencies.preferences).defaultDiceMode) {
                    Text("Real dice").tag(DiceMode.manual)
                    Text("Let the app roll").tag(DiceMode.auto)
                } label: {
                    SettingsIconLabel(title: "Dice", systemName: "dice", tint: TMColor.signal)
                }
                .pickerStyle(.navigationLink)
                Toggle(isOn: Bindable(dependencies.preferences).hapticsEnabled) {
                    SettingsIconLabel(
                        title: "Haptics",
                        systemName: "iphone.radiowaves.left.and.right",
                        tint: TMColor.coolant
                    )
                }
                Toggle(isOn: Bindable(dependencies.preferences).keepScreenAwake) {
                    SettingsIconLabel(title: "Keep screen awake", systemName: "sun.max", tint: TMColor.info)
                }
            } header: {
                Text("Gameplay")
            } footer: {
                Text("Real dice is the default for a new game. Haptics buzz for dice and turn changes.")
            }

            Section {
                Picker(selection: Bindable(dependencies.preferences).theme) {
                    ForEach(AppColorSchemePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                } label: {
                    SettingsIconLabel(title: "Theme", systemName: "circle.lefthalf.filled", tint: Color.secondary)
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("Appearance")
            }

            Section {
                Button {
                    openOnboarding(.changeTrack)
                } label: {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: TMSpace.md) {
                            yourGameLabel
                            Spacer(minLength: TMSpace.sm)
                            Text(trackTitle)
                                .foregroundStyle(.secondary)
                            rowChevron
                        }
                        HStack(spacing: TMSpace.md) {
                            VStack(alignment: .leading, spacing: TMSpace.xs) {
                                yourGameLabel
                                Text(trackTitle)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            rowChevron
                        }
                    }
                }
                // Buttons in a List take the app tint; this row reads like its NavigationLink neighbours.
                .tint(.primary)
                .accessibilityLabel("Your game, \(trackTitle)")
                .accessibilityHint("Opens the intro to pick Alpha Strike or Classic")
                .accessibilityIdentifier("settings.onboarding")
                NavigationLink {
                    HowToPlayRidgeLineView(onPlay: {
                        matches.requestNew(using: dependencies, prefersZoom: false)
                    })
                } label: {
                    SettingsIconLabel(title: "How to play Ridge Line", systemName: "book", tint: Color.secondary)
                }
            } header: {
                Text("Learn")
            } footer: {
                Text("Your game reopens the intro, where you can switch between Alpha Strike and Classic.")
            }

            Section {
                // Side by side when it fits; stacked at large text, where "Version" broke as "Ver-sion".
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TMSpace.md) {
                        SettingsIconLabel(title: "Version", systemName: "info.circle", tint: Color.secondary)
                            .fixedSize()
                        Spacer(minLength: TMSpace.sm)
                        Text(versionText)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: TMSpace.xs) {
                        SettingsIconLabel(title: "Version", systemName: "info.circle", tint: Color.secondary)
                        Text(versionText)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            } header: {
                Text("About")
            }

            Section {
                safariLink("Support", systemName: "envelope", url: AppLinks.support)
                safariLink("Privacy Policy", systemName: "hand.raised", url: AppLinks.privacy)
                safariLink("Accessibility", systemName: "accessibility", url: AppLinks.accessibility)
            } header: {
                Text("Support & legal")
            } footer: {
                Text("Unofficial fan aid. BattleTech and Alpha Strike are trademarks of their respective owners.")
            }

            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    SettingsIconLabel(title: "Delete saved games", systemName: "trash", tint: TMColor.danger)
                }
                .accessibilityIdentifier("settings.deleteAll")
                .accessibilityHint("Deletes the game in progress")
            } header: {
                Text("Data")
            } footer: {
                Text("Removes the game in progress. Mission progress and your settings stay.")
            }
        }
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings.home")
        .confirmationDialog(
            "Delete saved games?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteSavedGames()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the game in progress. Mission progress and your settings stay.")
        }
        .alert(
            "Could not delete",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var yourGameLabel: some View {
        SettingsIconLabel(title: "Your game", systemName: "flag.2.crossed", tint: TMColor.signal)
            .foregroundStyle(.primary)
    }

    private var rowChevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private var trackTitle: String {
        (dependencies.preferences.learningTrack ?? .alphaStrike).title
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func safariLink(_ title: String, systemName: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: TMSpace.md) {
                SettingsIconLabel(title: title, systemName: systemName, tint: Color.secondary)
                Spacer(minLength: TMSpace.sm)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(title)
        .accessibilityHint("Opens in Safari")
    }

    private func deleteSavedGames() {
        do {
            try dependencies.matchSessions.deleteAll()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

private struct SettingsIconLabel: View {
    var title: String
    var systemName: String
    var tint: Color

    /// The tile grows a little with text size; the glyph stops at xxxLarge so it stays inside the tile.
    /// At accessibility sizes the glyph used to spill out of a fixed 28pt tile and over the title.
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 28

    var body: some View {
        HStack(spacing: TMSpace.md) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(tint)
                .frame(width: min(tile, 40), height: min(tile, 40))
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
        }
    }
}

#if DEBUG
#Preview("Settings") {
    PlayPreviewHost {
        NavigationStack {
            SettingsHomeView()
        }
    }
}
#endif
