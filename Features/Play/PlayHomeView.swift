import SwiftUI
import MechBuddyData
import MechBuddyDomain

struct PlayHomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(PlayMatchCoordinator.self) private var matches
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openOnboarding) private var openOnboarding

    /// Every mission in the ladder, in order. Gated ones show as Coming soon.
    @State private var ladder: [ScenarioCatalogItemDTO] = []
    /// Loaded briefings for the playable missions, keyed by scenario id.
    @State private var missions: [String: GuidedScenarioDTO] = [:]
    @State private var loadError: String?
    @State private var showHowToPlay = false
    @State private var showClassic = false
    @State private var playAfterClassic = false
    @State private var selectedStop: MissionStop?

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
                if showsLadder {
                    if let resume = matches.resumeSession {
                        resumeStrip(resume)
                    }
                    if trackLayout.showsClassicSpotlight {
                        classicSpotlight
                    }
                    pathBlock
                } else {
                    if trackLayout.showsClassicSpotlight {
                        classicSpotlight
                    }
                    heroes
                }
                if trackLayout.showsClassicRow {
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
                matches.requestNew(.ridgeLine, using: dependencies, prefersZoom: false)
            })
        }
        .sheet(isPresented: $showClassic, onDismiss: followUpClassic) {
            ClassicComingSoonSheet {
                playAfterClassic = true
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedStop) { stop in
            MissionDetailSheet(
                stop: stop,
                mission: missions[stop.id],
                hasGameInProgress: matches.resumeSession != nil,
                onPlay: {
                    if let mission = missions[stop.id] {
                        startMission(mission, source: "mission", prefersZoom: false)
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { await loadContent() }
    }

    private var contentWidth: CGFloat {
        horizontalSizeClass == .regular ? 960 : 720
    }

    /// Classic picked in onboarding moves Classic from a small row to a card above the path.
    private var trackLayout: PlayTrackLayout {
        PlayTrackLayout.make(
            track: dependencies.preferences.learningTrack,
            classicEntryEnabled: dependencies.releaseSurface.isEnabled(.classicComingSoonEntry)
        )
    }

    private var showsLadder: Bool {
        dependencies.releaseSurface.isEnabled(.missionLadder) && ladder.count > 1
    }

    /// Missions the player can start now, in ladder order.
    private var playable: [GuidedScenarioDTO] {
        ladder.filter { !$0.gated }.compactMap { missions[$0.id] }
    }

    /// The next mission to play: the first one not finished yet, else the last one.
    private var featured: GuidedScenarioDTO? {
        guard dependencies.releaseSurface.isEnabled(.ridgeLineMission) else { return nil }
        let done = dependencies.preferences.completedMissions
        return playable.first { !done.contains($0.scenarioId) } ?? playable.last
    }

    @ViewBuilder
    private var heroes: some View {
        let resume = matches.resumeSession
        let mission = featured
        if horizontalSizeClass == .regular, resume != nil, mission != nil {
            HStack(alignment: .top, spacing: TMSpace.lg) {
                if let resume {
                    resumeCard(resume)
                }
                if let mission {
                    missionBlock(mission)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                if let resume {
                    resumeCard(resume)
                }
                if let mission {
                    missionBlock(mission)
                }
            }
        }
    }

    private func title(for id: ScenarioId?) -> String {
        let key = (id ?? .ridgeLine).rawValue
        return missions[key]?.title ?? ladder.first { $0.id == key }?.title ?? "Ridge Line"
    }

    private func startMission(_ mission: GuidedScenarioDTO, source: String, prefersZoom: Bool) {
        matches.requestNew(
            ScenarioId(rawValue: mission.scenarioId),
            title: mission.title,
            using: dependencies,
            source: source,
            prefersZoom: prefersZoom
        )
    }

    private func resumeCard(_ session: MatchSession) -> some View {
        let sideA = PlayForceMath.structure(of: .lanceA, in: session.units)
        let sideB = PlayForceMath.structure(of: .lanceB, in: session.units)
        return ResumeCard(
            title: title(for: session.scenarioId),
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

    /// Compact "In progress" row above the path, so the path stays on screen.
    /// Stacks (text, then a full-width Continue) at accessibility sizes.
    private func resumeStrip(_ session: MatchSession) -> some View {
        let turns = session.ruleset.maxTurns.map { "Turn \(session.turn) of \($0)" } ?? "Turn \(session.turn)"
        let copy = VStack(alignment: .leading, spacing: TMSpace.xxs) {
            Eyebrow("In progress")
            Text(title(for: session.scenarioId))
                .font(TMFont.cardTitle)
                .fixedSize(horizontal: false, vertical: true)
            // Non-breaking space before the dot: a wrap at large text never starts a line with "·".
            Text("\(turns)\u{00A0}· \(session.phase.displayName)")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        return TMCard {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    copy
                    resumeButton(session, turns: turns, fullWidth: true)
                }
            } else {
                HStack(spacing: TMSpace.md) {
                    copy
                    Spacer(minLength: TMSpace.sm)
                    resumeButton(session, turns: turns, fullWidth: false)
                }
            }
        }
        .playZoomSource("resume")
    }

    private func resumeButton(_ session: MatchSession, turns: String, fullWidth: Bool) -> some View {
        Button {
            matches.resume(using: dependencies)
        } label: {
            Text("Continue")
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(TMColor.signal)
        .controlSize(.large)
        .accessibilityIdentifier("as.modeHome.resume")
        .accessibilityLabel("Continue \(title(for: session.scenarioId)), \(turns)")
    }

    private func missionBlock(_ scenario: GuidedScenarioDTO) -> some View {
        let isRidgeLine = scenario.scenarioId == ScenarioId.ridgeLine.rawValue
        let minis = scenario.sides.lanceA.count + scenario.sides.lanceB.count
        return VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Alpha Strike")
            MissionCard(
                eyebrow: missionEyebrow(scenario),
                title: scenario.title,
                subtitle: missionSubtitle(scenario),
                facts: [
                    MissionFact(id: "players", systemImage: "person.2", text: "2 players"),
                    MissionFact(id: "dice", systemImage: "dice", text: "2 dice"),
                    MissionFact(id: "tape", systemImage: "ruler", text: "Tape measure"),
                    MissionFact(id: "minis", systemImage: "square.stack.3d.up", text: "\(minis) miniatures")
                ],
                sideANames: scenario.sides.lanceA.map { PlayForceMath.shortName($0.name) },
                sideBNames: scenario.sides.lanceB.map { PlayForceMath.shortName($0.name) },
                newRules: scenario.introduces ?? [],
                primaryTitle: matches.resumeSession == nil ? "Play \(scenario.title)" : "Start new \(scenario.title)",
                primaryIdentifier: isRidgeLine ? "as.modeHome.ridgeLine" : "as.modeHome.mission.\(scenario.scenarioId)",
                primaryProminent: matches.resumeSession == nil,
                primaryAction: {
                    startMission(scenario, source: "mission", prefersZoom: true)
                },
                secondaryLinks: [
                    (title: "How to play", identifier: "as.modeHome.howToPlay", action: { showHowToPlay = true })
                ]
            )
            .playZoomSource("mission")
        }
    }

    private func missionEyebrow(_ scenario: GuidedScenarioDTO) -> String {
        if let stage = ladder.first(where: { $0.id == scenario.scenarioId })?.stage {
            return stage
        }
        guard let number = scenario.missionNumber, number > 1 else { return "Beginner mission" }
        return "Mission \(number) of \(max(trainingLadder.count, number))"
    }

    private func missionSubtitle(_ scenario: GuidedScenarioDTO) -> String {
        let size = "\(scenario.sides.lanceA.count) vs \(scenario.sides.lanceB.count)"
        if let minutes = scenario.estimatedMinutes {
            return "\(size) · about \(minutes) minutes"
        }
        return scenario.subtitle ?? size
    }

    /// The training path: catalog missions without a stage.
    private var trainingLadder: [ScenarioCatalogItemDTO] { ladder.filter { $0.stage == nil } }

    /// Later sections (book scenarios), in catalog order of their first mission.
    private var stagedLadders: [(title: String, items: [ScenarioCatalogItemDTO])] {
        var order: [String] = []
        var items: [String: [ScenarioCatalogItemDTO]] = [:]
        for item in ladder {
            guard let stage = item.stage else { continue }
            if items[stage] == nil { order.append(stage) }
            items[stage, default: []].append(item)
        }
        return order.map { ($0, items[$0] ?? []) }
    }

    /// The training path's missions as stops.
    private var stops: [MissionStop] { pathStops(for: trainingLadder) }

    /// Missions as stops on a path, in ladder order.
    private func pathStops(for items: [ScenarioCatalogItemDTO]) -> [MissionStop] {
        let done = dependencies.preferences.completedMissions
        let next = featured?.scenarioId
        return items.enumerated().map { index, item in
            let state: MissionStop.State
            if item.gated || missions[item.id] == nil {
                state = .locked
            } else if done.contains(item.id) {
                state = .cleared
            } else {
                state = item.id == next ? .next : .open
            }
            return MissionStop(
                id: item.id,
                number: item.missionNumber ?? index + 1,
                title: item.title,
                icon: item.icon ?? "scope",
                unlocks: item.introduces ?? [],
                comingSoon: item.comingSoonSummary,
                state: state,
                stage: item.stage
            )
        }
    }

    private var pathBlock: some View {
        let stops = stops
        return VStack(alignment: .leading, spacing: TMSpace.xl) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                MissionPathHeader(cleared: stops.filter { $0.state == .cleared }.count, total: stops.count)
                if stops.contains(where: { $0.state == .open }) {
                    Label("Know the basics? Tap any mission to jump ahead.", systemImage: "forward.fill")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("as.modeHome.ladder.skipAheadHint")
                }
            }
            MissionPathView(
                stops: stops,
                onSelect: { selectedStop = $0 },
                upNext: upNextCard
            )
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            ForEach(stagedLadders, id: \.title) { stage in
                stageBlock(title: stage.title, stops: pathStops(for: stage.items))
            }
        }
    }

    /// A section after the training path, such as the box set's own scenarios. No trophy.
    private func stageBlock(title: String, stops: [MissionStop]) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.lg) {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Eyebrow(title)
                Text("The scenarios printed in the box’s rulebook, played with the app. Any time, in any order.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            MissionPathView(
                stops: stops,
                showsFinish: false,
                onSelect: { selectedStop = $0 },
                upNext: upNextCard
            )
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, TMSpace.xl)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("as.modeHome.stage.\(title)")
    }

    private func upNextCard(_ stop: MissionStop) -> some View {
        UpNextCard {
            MissionBrief(
                stop: stop,
                mission: missions[stop.id],
                hasGameInProgress: matches.resumeSession != nil,
                onPlay: missions[stop.id].map { mission in
                    { startMission(mission, source: "mission", prefersZoom: true) }
                },
                links: stop.number == 1 ? beginnerLinks : []
            )
        }
        .playZoomSource("mission")
    }

    private var beginnerLinks: [MissionBrief.Link] {
        [
            MissionBrief.Link(title: "How to play", identifier: "as.modeHome.howToPlay") { showHowToPlay = true }
        ]
    }

    /// The player chose Classic in onboarding. Says plainly it isn't playable yet and points at the path below.
    private var classicSpotlight: some View {
        TMCard(edgeColor: TMColor.signal, isRaised: true) {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                if dynamicTypeSize.isAccessibilitySize {
                    Eyebrow("Your game")
                    comingSoonBadge
                } else {
                    Eyebrow("Your game") {
                        comingSoonBadge
                    }
                }
                HStack(alignment: .top, spacing: TMSpace.md) {
                    Image(systemName: "hexagon")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(TMColor.signal)
                        .frame(width: 44, height: 44)
                        .background(TMColor.signal.opacity(0.14), in: RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: TMSpace.xs) {
                        Text("Classic BattleTech")
                            .font(TMFont.cardTitle)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Not playable in Mech Buddy yet. Start with the Alpha Strike missions below: same ’Mechs, and they teach the core of Classic.")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TMSpace.lg) { spotlightLinks }
                    VStack(alignment: .leading, spacing: 0) { spotlightLinks }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("play.classicSpotlight")
    }

    @ViewBuilder
    private var spotlightLinks: some View {
        Button {
            showClassic = true
        } label: {
            linkLabel("What’s coming")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("play.classicComingSoon")
        .accessibilityHint("Opens what’s coming later. Classic is not playable yet.")
        Button {
            openOnboarding(.changeTrack)
        } label: {
            linkLabel("Change game")
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("play.changeGame")
    }

    private func linkLabel(_ title: String) -> some View {
        HStack(spacing: TMSpace.xs) {
            Text(title)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
        }
        .font(TMFont.detail)
        .frame(minHeight: 44)
    }

    private var classicBlock: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("More modes")
            Button {
                showClassic = true
            } label: {
                TMCard {
                    ViewThatFits(in: .horizontal) {
                        classicRow(stacksBadge: false)
                        classicRow(stacksBadge: true)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("play.classicComingSoon")
            .accessibilityHint("Opens what’s coming later. Classic is not playable yet.")
        }
    }

    @ViewBuilder
    private func classicRow(stacksBadge: Bool) -> some View {
        if stacksBadge {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                classicCopy
                HStack(spacing: TMSpace.sm) {
                    comingSoonBadge
                    Spacer(minLength: 0)
                    classicChevron
                }
            }
        } else {
            HStack(spacing: TMSpace.md) {
                classicCopy
                Spacer(minLength: TMSpace.sm)
                comingSoonBadge
                classicChevron
            }
        }
    }

    private var classicCopy: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Text("Classic BattleTech")
                .font(TMFont.cardTitle)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Paper sheets, heat, and hit locations")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var comingSoonBadge: some View {
        Text("Coming soon")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, TMSpace.sm)
            .padding(.vertical, TMSpace.xs)
            .background(TMColor.readout, in: Capsule())
            .fixedSize()
    }

    private var classicChevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private func followUpClassic() {
        guard playAfterClassic else { return }
        playAfterClassic = false
        if let featured {
            startMission(featured, source: "mission", prefersZoom: false)
        } else {
            matches.requestNew(.ridgeLine, using: dependencies, source: "mission", prefersZoom: false)
        }
    }

    private func loadContent() async {
        do {
            let ladderEnabled = dependencies.releaseSurface.isEnabled(.missionLadder)
            let items = try dependencies.content.scenarios().scenarios
                .filter { ladderEnabled || $0.id == ScenarioId.ridgeLine.rawValue }
                .sorted { ($0.missionNumber ?? .max) < ($1.missionNumber ?? .max) }
            var loaded: [String: GuidedScenarioDTO] = [:]
            for item in items where !item.gated {
                do {
                    loaded[item.id] = try dependencies.content.scenario(id: ScenarioId(rawValue: item.id))
                } catch {
                    // One bad pack hides that mission only. Ridge Line failing still shows the banner.
                    dependencies.logger.error("\(item.id): \(error)", category: "content")
                    if item.id == ScenarioId.ridgeLine.rawValue { throw error }
                }
            }
            ladder = items
            missions = loaded
            loadError = nil
        } catch {
            loadError = "Could not load content: \(error.localizedDescription)"
            dependencies.logger.error("\(error)", category: "content")
        }
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
