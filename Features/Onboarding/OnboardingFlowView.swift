import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// First-run flow: one question per screen, a progress bar, one Continue button, skippable.
/// Presented full screen by `RootTabView`. Spec: specs/features/OnboardingSpec.md
struct OnboardingFlowView: View {
    var entry: OnboardingEntry
    /// Called after the flow saves and closes, so the root can land on Play.
    var onFinish: () -> Void

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var index = 0
    @State private var movingForward = true
    @State private var track: LearningTrack?
    @State private var kit: [GettingStartedItemDTO] = []
    @State private var kitLoadFailed = false
    @State private var firstMission: OnboardingMissionSummary?
    @State private var didLoad = false

    private var classicAvailable: Bool {
        dependencies.releaseSurface.isEnabled(.classicComingSoonEntry)
    }

    private var steps: [OnboardingStep] {
        OnboardingStep.steps(for: entry, classicAvailable: classicAvailable)
    }

    private var step: OnboardingStep {
        steps[min(index, steps.count - 1)]
    }

    private var isLastStep: Bool { index >= steps.count - 1 }

    /// The track that will be saved. Without the Classic entry there is only Alpha Strike.
    private var resolvedTrack: LearningTrack {
        classicAvailable ? (track ?? .alphaStrike) : .alphaStrike
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                ScrollView {
                    stepContent
                        .padding(.horizontal, TMSpace.lg)
                        .padding(.top, verticalSizeClass == .compact ? TMSpace.md : TMSpace.xl)
                        .padding(.bottom, TMSpace.xl)
                        .frame(maxWidth: 680)
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .id(step)
                .transition(stepTransition)
            }
            .frame(maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .background(Color(.systemBackground))
        .accessibilityIdentifier("onboarding.screen")
        .task { load() }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: TMSpace.sm) {
            if index > 0 {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("onboarding.back")
            } else {
                Color.clear.frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            OnboardingProgressBar(
                progress: OnboardingStep.progress(of: step, in: steps),
                position: index + 1,
                count: steps.count
            )
            if isLastStep {
                Color.clear.frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            } else {
                Button(entry == .firstRun ? "Skip" : "Close", action: skip)
                    .font(TMFont.detail.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityHint(entry == .firstRun ? "Goes straight to Play" : "Keeps your current game")
                    .accessibilityIdentifier("onboarding.skip")
            }
        }
        .padding(.horizontal, TMSpace.sm)
        .padding(.top, TMSpace.xs)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        Button(action: advance) {
            Text(continueTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: verticalSizeClass == .compact ? 44 : 50)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(TMColor.signal)
        .disabled(!canContinue)
        .accessibilityHint(canContinue ? "" : "Pick a game first")
        .accessibilityIdentifier("onboarding.continue")
        .padding(.horizontal, TMSpace.lg)
        .padding(.top, TMSpace.sm)
        .padding(.bottom, TMSpace.sm)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    private var continueTitle: String {
        switch step {
        case .welcome: "Get started"
        case .track, .kit: "Continue"
        case .firstMission: "Go to my mission path"
        }
    }

    private var canContinue: Bool {
        step != .track || track != nil
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            OnboardingWelcomeStep(upcoming: Array(steps.drop { $0 == .welcome }))
        case .track:
            OnboardingTrackStep(selection: $track)
        case .kit:
            OnboardingKitStep(items: kit, loadFailed: kitLoadFailed)
        case .firstMission:
            OnboardingFirstMissionStep(
                track: resolvedTrack,
                mission: firstMission,
                stillNeeded: stillNeededTitles
            )
        }
    }

    private var stillNeededTitles: [String] {
        let kitItems = kit.filter { $0.linkURL == nil }
        let missing = OnboardingKit.stillNeeded(
            kitIDs: kitItems.map(\.id),
            have: dependencies.preferences.gettingStartedChecks
        )
        return missing.compactMap { id in kitItems.first { $0.id == id }?.title }
    }

    // MARK: - Actions

    private func advance() {
        guard canContinue else { return }
        if isLastStep {
            finish()
            return
        }
        move(to: index + 1, forward: true)
    }

    private func goBack() {
        guard index > 0 else { return }
        move(to: index - 1, forward: false)
    }

    private func move(to newIndex: Int, forward: Bool) {
        movingForward = forward
        withAnimation(reduceMotion ? TMMotion.reduced : TMMotion.state) {
            index = newIndex
        }
    }

    private func finish() {
        let chosen = resolvedTrack
        dependencies.preferences.completeOnboarding(track: chosen)
        dependencies.logger.info("finished entry=\(entry.rawValue) track=\(chosen.rawValue)", category: "onboarding")
        dismiss()
        onFinish()
    }

    private func skip() {
        switch entry {
        case .firstRun:
            // Keep a pick if they made one; Play treats no pick as Alpha Strike.
            dependencies.preferences.completeOnboarding(track: classicAvailable ? track : .alphaStrike)
            dependencies.logger.info("skipped at=\(step.rawValue)", category: "onboarding")
            dismiss()
            onFinish()
        case .changeTrack:
            dismiss()
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if entry == .changeTrack {
            track = dependencies.preferences.learningTrack
        }
        do {
            kit = try dependencies.content.gettingStarted().items
            kitLoadFailed = false
        } catch {
            kitLoadFailed = true
            dependencies.logger.error("kit list: \(error)", category: "onboarding")
        }
        firstMission = loadMission()
    }

    private func loadMission() -> OnboardingMissionSummary? {
        do {
            let ladderEnabled = dependencies.releaseSurface.isEnabled(.missionLadder)
            let items = try dependencies.content.scenarios().scenarios
                .filter { ladderEnabled || $0.id == ScenarioId.ridgeLine.rawValue }
                .sorted { ($0.missionNumber ?? .max) < ($1.missionNumber ?? .max) }
            let nextID = OnboardingMissions.nextMissionID(
                ladder: items.map { (id: $0.id, playable: !$0.gated) },
                completed: dependencies.preferences.completedMissions
            ) ?? ScenarioId.ridgeLine.rawValue
            let item = items.first { $0.id == nextID }
            let mission = try dependencies.content.scenario(id: ScenarioId(rawValue: nextID))
            return OnboardingMissionSummary(
                id: nextID,
                number: mission.missionNumber ?? item?.missionNumber ?? 1,
                title: mission.title,
                icon: item?.icon ?? "scope",
                introduces: item?.introduces ?? mission.introduces ?? [],
                sizeLine: Self.sizeLine(for: mission),
                isFirst: dependencies.preferences.completedMissions.isEmpty
            )
        } catch {
            dependencies.logger.error("first mission: \(error)", category: "onboarding")
            return nil
        }
    }

    private static func sizeLine(for mission: GuidedScenarioDTO) -> String {
        var parts = ["\(mission.sides.lanceA.count) vs \(mission.sides.lanceB.count)"]
        if let minutes = mission.estimatedMinutes { parts.append("about \(minutes) min") }
        if let turns = mission.ruleset.maxTurns { parts.append("\(turns) turns") }
        return parts.joined(separator: " · ")
    }
}

/// What the last screen needs to show the mission the path will point at.
struct OnboardingMissionSummary: Equatable {
    var id: String
    var number: Int
    var title: String
    var icon: String
    var introduces: [String]
    var sizeLine: String
    /// No mission cleared yet: "Your first mission". Otherwise "Your next mission".
    var isFirst: Bool
}

/// Segmented-looking capsule bar. VoiceOver reads "Step 2 of 4".
private struct OnboardingProgressBar: View {
    var progress: Double
    var position: Int
    var count: Int

    var body: some View {
        Capsule()
            .fill(TMColor.readout)
            .frame(height: 12)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(TMColor.signal)
                        .frame(width: max(12, proxy.size.width * progress))
                }
            }
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .tmAnimation(TMMotion.state, value: progress)
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("Step \(position) of \(count)")
            .accessibilityIdentifier("onboarding.progress")
    }
}

#if DEBUG
#Preview("Onboarding") {
    PlayPreviewHost {
        OnboardingFlowView(entry: .firstRun, onFinish: {})
    }
}

#Preview("Onboarding — change game") {
    PlayPreviewHost {
        OnboardingFlowView(entry: .changeTrack, onFinish: {})
    }
}
#endif
