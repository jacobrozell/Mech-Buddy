import SwiftUI
import TableMechData
import TableMechDomain

struct PlayHomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(PlayMatchCoordinator.self) private var matches
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var scenario: RidgeLineScenarioDTO?
    @State private var checklistIDs: [String] = []
    @State private var loadError: String?
    @State private var showGettingStarted = false
    @State private var showHowToPlay = false
    @State private var showClassic = false
    @State private var playAfterClassic = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                if dependencies.isUsingVolatileStore {
                    ErrorBanner(
                        message: "Games can't be saved on this device right now. Restart the app. If this keeps happening, contact support.",
                        linkTitle: "Contact support",
                        linkURL: AppLinks.support
                    )
                }
                if let notice = matches.unreadableNotice {
                    ErrorBanner(message: notice)
                }
                heroes
                if dependencies.releaseSurface.isEnabled(.classicComingSoonEntry) {
                    classicBlock
                }
                if let loadError {
                    ErrorBanner(message: loadError) {
                        Task { await loadContent() }
                    }
                }
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: contentWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Play")
        .accessibilityIdentifier("play.home")
        .navigationDestination(isPresented: $showHowToPlay) {
            HowToPlayRidgeLineView(onPlay: {
                matches.requestNew(using: dependencies, prefersZoom: false)
            })
        }
        .navigationDestination(isPresented: $showGettingStarted) {
            GettingStartedView(onPlay: {
                matches.requestNew(using: dependencies, prefersZoom: false)
            })
        }
        .sheet(isPresented: $showClassic, onDismiss: followUpClassic) {
            ClassicComingSoonSheet {
                playAfterClassic = true
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .task { await loadContent() }
    }

    private var contentWidth: CGFloat {
        horizontalSizeClass == .regular ? 960 : 720
    }

    private var showNewHereNudge: Bool {
        let required = Set(checklistIDs.filter { $0 != GettingStartedCatalog.playCueID })
        guard !required.isEmpty else { return false }
        return !dependencies.preferences.hasSeenIntro
            && !required.isSubset(of: dependencies.preferences.gettingStartedChecks)
    }

    @ViewBuilder
    private var heroes: some View {
        let resume = matches.resumeSession
        let showRidge = dependencies.releaseSurface.isEnabled(.ridgeLineMission) && scenario != nil
        if horizontalSizeClass == .regular, resume != nil, showRidge {
            HStack(alignment: .top, spacing: TMSpace.lg) {
                if let resume {
                    resumeCard(resume)
                }
                if let scenario {
                    missionBlock(scenario)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                if let resume {
                    resumeCard(resume)
                }
                if let scenario, dependencies.releaseSurface.isEnabled(.ridgeLineMission) {
                    missionBlock(scenario)
                }
            }
        }
    }

    private func resumeCard(_ session: MatchSession) -> some View {
        let sideA = PlayForceMath.structure(of: .lanceA, in: session.units)
        let sideB = PlayForceMath.structure(of: .lanceB, in: session.units)
        return ResumeCard(
            title: scenario?.title ?? "Ridge Line",
            turn: session.turn,
            maxTurns: session.ruleset.maxTurns,
            phase: session.phase,
            sideAStructureRemaining: sideA.remaining,
            sideAStructureCapacity: sideA.capacity,
            sideBStructureRemaining: sideB.remaining,
            sideBStructureCapacity: sideB.capacity,
            onContinue: { matches.resume(using: dependencies) }
        )
        .playZoomSource("resume")
    }

    private func missionBlock(_ scenario: RidgeLineScenarioDTO) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Alpha Strike")
            MissionCard(
                eyebrow: "Beginner mission",
                title: scenario.title,
                subtitle: missionSubtitle(scenario),
                facts: [
                    MissionFact(id: "players", systemImage: "person.2", text: "2 players"),
                    MissionFact(id: "dice", systemImage: "dice", text: "2 dice"),
                    MissionFact(id: "tape", systemImage: "ruler", text: "Tape measure"),
                    MissionFact(id: "minis", systemImage: "square.stack.3d.up", text: "4 miniatures")
                ],
                sideANames: scenario.sides.lanceA.map { PlayForceMath.shortName($0.name) },
                sideBNames: scenario.sides.lanceB.map { PlayForceMath.shortName($0.name) },
                primaryTitle: matches.resumeSession == nil ? "Play Ridge Line" : "Start new Ridge Line",
                primaryIdentifier: "as.modeHome.ridgeLine",
                primaryProminent: matches.resumeSession == nil,
                primaryAction: {
                    matches.requestNew(using: dependencies, source: "mission", prefersZoom: true)
                },
                secondaryLinks: [
                    (title: "How to play", identifier: "as.modeHome.howToPlay", action: { showHowToPlay = true }),
                    (title: "New here?", identifier: "as.modeHome.gettingStarted", action: { showGettingStarted = true })
                ]
            )
            .playZoomSource("mission")
        }
    }

    private func missionSubtitle(_ scenario: RidgeLineScenarioDTO) -> String {
        if showNewHereNudge {
            return "New here? Start with the 2-minute checklist"
        }
        if let minutes = scenario.estimatedMinutes {
            return "2 vs 2 · about \(minutes) minutes"
        }
        return scenario.subtitle ?? "2 vs 2 · about 40 minutes"
    }

    private var classicBlock: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("More modes")
            Button {
                showClassic = true
            } label: {
                TMCard {
                    HStack(spacing: TMSpace.md) {
                        VStack(alignment: .leading, spacing: TMSpace.xs) {
                            Text("Classic BattleTech")
                                .font(TMFont.cardTitle)
                                .foregroundStyle(.primary)
                            Text("Paper sheets, heat, and hit locations")
                                .font(TMFont.detail)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: TMSpace.sm)
                        Text("Coming soon")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, TMSpace.sm)
                            .padding(.vertical, TMSpace.xs)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("play.classicComingSoon")
            .accessibilityHint("Opens what’s coming later")
        }
    }

    private func followUpClassic() {
        guard playAfterClassic else { return }
        playAfterClassic = false
        matches.requestNew(using: dependencies, source: "mission", prefersZoom: false)
    }

    private func loadContent() async {
        do {
            scenario = try dependencies.content.ridgeLineScenario()
            loadError = nil
        } catch {
            loadError = "Could not load content: \(error.localizedDescription)"
            dependencies.logger.error("\(error)", category: "content")
        }
        checklistIDs = (try? dependencies.content.gettingStarted().items.map(\.id)) ?? []
    }
}

#if DEBUG
#Preview("Play") {
    PlayPreviewHost {
        NavigationStack {
            PlayHomeView()
        }
    }
}
#endif
