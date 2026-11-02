import SwiftUI
import MechBuddyData
import MechBuddyDomain

struct SettingsHomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(PlayMatchCoordinator.self) private var matches
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
                NavigationLink {
                    HowToPlayRidgeLineView(onPlay: {
                        matches.requestNew(using: dependencies, prefersZoom: false)
                    })
                } label: {
                    SettingsIconLabel(title: "How to play Ridge Line", systemName: "book", tint: Color.secondary)
                }
                NavigationLink {
                    GettingStartedView(onPlay: {
                        matches.requestNew(using: dependencies, prefersZoom: false)
                    })
                } label: {
                    SettingsIconLabel(title: "New here checklist", systemName: "checklist", tint: Color.secondary)
                }
                HStack(spacing: TMSpace.md) {
                    SettingsIconLabel(title: "Version", systemName: "info.circle", tint: Color.secondary)
                    Spacer(minLength: TMSpace.sm)
                    Text(versionText)
                        .foregroundStyle(.secondary)
                }
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
                .accessibilityHint("Deletes the saved game and your checklist")
            } header: {
                Text("Data")
            } footer: {
                Text("Removes the game in progress and your checklist.")
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
            Text("Removes the game in progress and your checklist.")
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
            dependencies.preferences.clearGettingStartedChecks()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

private struct SettingsIconLabel: View {
    var title: String
    var systemName: String
    var tint: Color

    var body: some View {
        HStack(spacing: TMSpace.md) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
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
