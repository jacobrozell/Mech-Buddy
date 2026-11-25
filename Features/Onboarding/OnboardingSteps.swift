import SwiftUI
import MechBuddyData

// The onboarding screens (box screens are in OnboardingCollectionSteps.swift). Each asks one thing. Spec: specs/features/OnboardingSpec.md

// MARK: - Welcome

struct OnboardingWelcomeStep: View {
    /// Screens after this one, previewed as a short roadmap.
    var upcoming: [OnboardingStep]

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            OnboardingHeader(
                heroSymbol: "dice.fill",
                title: "Learn BattleTech at your table",
                subtitle: "You move the miniatures. Mech Buddy tells you whose turn it is, does the shooting math, and tracks damage."
            )
            VStack(alignment: .leading, spacing: TMSpace.md) {
                ForEach(Array(upcoming.enumerated()), id: \.element) { offset, step in
                    roadmapRow(number: offset + 1, step: step)
                }
            }
        }
        .accessibilityIdentifier("onboarding.step.welcome")
    }

    private func roadmapRow(number: Int, step: OnboardingStep) -> some View {
        HStack(alignment: .center, spacing: TMSpace.md) {
            Text("\(number)")
                .font(TMFont.cardTitle.monospacedDigit())
                .foregroundStyle(TMColor.signal)
                .frame(width: 36, height: 36)
                .background(TMColor.signal.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            Text(roadmapTitle(step))
                .font(TMFont.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(roadmapTitle(step))")
    }

    private func roadmapTitle(_ step: OnboardingStep) -> String {
        switch step {
        case .welcome: "Welcome"
        case .track: "Pick the game you want to learn"
        case .boxes: "Tell us which boxes you own"
        case .mechs: "Check your ’Mechs"
        case .kit: "Check what you have"
        case .firstMission: "Start your first mission"
        }
    }
}

// MARK: - Track

struct OnboardingTrackStep: View {
    @ScaledMetric(relativeTo: .body) private var commitmentIconWidth: CGFloat = 26

    @Binding var selection: LearningTrack?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.hapticsEnabled) private var hapticsEnabled

    /// Side by side on iPad and iPhone landscape, stacked otherwise and at accessibility sizes.
    private var sideBySide: Bool {
        !dynamicTypeSize.isAccessibilitySize
            && (horizontalSizeClass == .regular || verticalSizeClass == .compact)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            OnboardingHeader(
                title: "Which BattleTech do you want to learn?",
                subtitle: "Both games use the same miniatures. Pick by how much time and how many rules you want."
            )
            Group {
                if sideBySide {
                    HStack(alignment: .top, spacing: TMSpace.md) { cards }
                } else {
                    VStack(spacing: TMSpace.md) { cards }
                }
            }
            if selection == .classic {
                classicNote
                    .transition(.opacity)
            }
        }
        .tmAnimation(TMMotion.state, value: selection)
        .sensoryFeedback(trigger: selection) { _, _ in hapticsEnabled ? .selection : nil }
        .accessibilityIdentifier("onboarding.step.track")
    }

    @ViewBuilder
    private var cards: some View {
        ForEach(LearningTrack.allCases) { track in
            ChoiceTile(
                title: track.title,
                detail: track.tagline,
                systemImage: track.systemImage,
                badge: track.badge,
                badgeTint: track.isPlayableInApp ? TMColor.success.opacity(0.22) : TMColor.readout,
                isSelected: selection == track,
                indicator: .single,
                accessibilityIdentifier: "onboarding.track.\(track.rawValue)",
                accessibilityHint: track.isPlayableInApp
                    ? "Playable in the app now"
                    : "Not playable in the app yet. You’ll start with Alpha Strike",
                action: { selection = track }
            ) {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    ForEach(track.commitments) { item in
                        Label {
                            Text(item.text)
                                .font(TMFont.detail)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            // One width for every icon, so each line's text starts at the same place.
                            Image(systemName: item.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: commitmentIconWidth)
                        }
                    }
                }
            }
            .frame(maxHeight: sideBySide ? .infinity : nil, alignment: .top)
        }
    }

    private var classicNote: some View {
        TMCard(edgeColor: TMColor.info) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Label("Classic isn’t in Mech Buddy yet", systemImage: "info.circle.fill")
                    .font(TMFont.cardTitle)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Start with Alpha Strike for now. It teaches the core of Classic: two dice against a target number, movement modifiers, terrain, heat, and critical hits. Classic adds record sheets and hex maps on top.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.track.classicNote")
    }
}

// MARK: - Kit

struct OnboardingKitStep: View {
    /// `as-getting-started.json` items. Rows with a link are optional reading, not gear.
    var items: [GettingStartedItemDTO]
    var loadFailed: Bool

    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.hapticsEnabled) private var hapticsEnabled

    private var gear: [GettingStartedItemDTO] { items.filter { $0.linkURL == nil } }
    private var links: [GettingStartedItemDTO] { items.filter { $0.linkURL != nil } }

    private var columns: [GridItem] {
        let twoUp = !dynamicTypeSize.isAccessibilitySize
            && (horizontalSizeClass == .regular || verticalSizeClass == .compact)
        let column = GridItem(.flexible(), spacing: TMSpace.md, alignment: .top)
        return twoUp ? [column, column] : [column]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            OnboardingHeader(
                heroSymbol: "shippingbox.fill",
                title: "What do you have?",
                subtitle: "Tap what’s already on your table. Missing something is fine."
            )
            if loadFailed {
                Text("The gear list didn’t load. You can still continue.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: TMSpace.md) {
                ForEach(gear) { item in
                    let have = dependencies.preferences.gettingStartedChecks.contains(item.id)
                    ChoiceTile(
                        title: item.title,
                        detail: item.detail,
                        systemImage: OnboardingKit.systemImage(for: item.id),
                        isSelected: have,
                        accessibilityIdentifier: "onboarding.kit.\(item.id)",
                        action: { dependencies.preferences.toggleGettingStarted(item.id) }
                    )
                }
            }
            .sensoryFeedback(trigger: dependencies.preferences.gettingStartedChecks) { _, _ in
                hapticsEnabled ? .selection : nil
            }
            builtInCards
            ForEach(links) { item in
                if let url = item.linkURL.flatMap(URL.init(string:)) {
                    linkRow(item, url: url)
                }
            }
        }
        .accessibilityIdentifier("onboarding.step.kit")
    }

    private var builtInCards: some View {
        HStack(alignment: .top, spacing: TMSpace.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(TMColor.success)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Text("Unit cards are built in")
                    .font(TMFont.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Every ’Mech’s card is on the Force tab, so you don’t need to print anything. Cards for other ’Mechs are free on the Master Unit List.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.kit.cards")
    }

    private func linkRow(_ item: GettingStartedItemDTO, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: TMSpace.md) {
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text(item.title)
                        .font(TMFont.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail = item.detail {
                        Text(detail)
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: TMSpace.sm)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .multilineTextAlignment(.leading)
        }
        .accessibilityLabel(item.title)
        .accessibilityHint("Opens in Safari")
        .accessibilityIdentifier("onboarding.kit.link.\(item.id)")
    }
}

// MARK: - First mission

struct OnboardingFirstMissionStep: View {
    var track: LearningTrack
    var mission: OnboardingMissionSummary?
    /// Gear titles not ticked on the previous screen.
    var stillNeeded: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            OnboardingHeader(
                eyebrow: track == .classic ? "Start with Alpha Strike" : "Alpha Strike",
                title: (mission?.isFirst ?? true) ? "Your first mission" : "Your next mission",
                subtitle: "It’s up next on your mission path. The app coaches every tap."
            )
            missionCard
            gearSummary
            if track == .classic {
                Label {
                    Text("Classic is coming to Mech Buddy. Everything you learn here carries over. You’ll find it on Play.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "hexagon")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("onboarding.step.firstMission")
    }

    private var missionCard: some View {
        VStack(spacing: TMSpace.lg) {
            if let mission {
                MissionNode(stop: MissionStop(
                    id: mission.id,
                    number: mission.number,
                    title: mission.title,
                    icon: mission.icon,
                    unlocks: mission.introduces,
                    state: .next
                ))
                .accessibilityHidden(true)
                VStack(spacing: TMSpace.xs) {
                    Text("Mission \(mission.number)")
                        .font(TMFont.eyebrow)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(mission.title)
                        .font(TMFont.stepTitle)
                        .multilineTextAlignment(.center)
                    Text(mission.sizeLine)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                if !mission.introduces.isEmpty {
                    VStack(spacing: TMSpace.xs) {
                        Text(mission.isFirst ? "You’ll learn" : "Unlocks")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        UnlockChips(rules: mission.introduces, centered: true)
                    }
                }
            } else {
                Text("Ridge Line")
                    .font(TMFont.stepTitle)
            }
        }
        .padding(TMSpace.lg)
        .frame(maxWidth: .infinity)
        .background(TMColor.surfaceCard, in: RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                .strokeBorder(TMColor.signal.opacity(0.55), lineWidth: 1.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.firstMission.card")
    }

    @ViewBuilder
    private var gearSummary: some View {
        if stillNeeded.isEmpty {
            Label("You have everything you need", systemImage: "checkmark.circle.fill")
                .font(TMFont.body.weight(.semibold))
                .foregroundStyle(TMColor.success)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow("Before you sit down, grab")
                ForEach(stillNeeded, id: \.self) { title in
                    Label(title, systemImage: "circle")
                        .font(TMFont.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Shared pieces

/// Hero symbol, eyebrow, title, and subtitle for one screen. VoiceOver lands on the title when the screen appears.
struct OnboardingHeader: View {
    var heroSymbol: String?
    var eyebrow: String?
    var title: String
    var subtitle: String?

    @AccessibilityFocusState private var titleFocused: Bool

    init(heroSymbol: String? = nil, eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.heroSymbol = heroSymbol
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            if let heroSymbol {
                OnboardingHero(systemImage: heroSymbol)
                    .frame(maxWidth: .infinity)
            }
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                if let eyebrow {
                    Eyebrow(eyebrow)
                }
                Text(title)
                    .font(TMFont.stepTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                if let subtitle {
                    Text(subtitle)
                        .font(TMFont.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task { titleFocused = true }
    }
}

/// Big round symbol at the top of a screen. Bounces once on arrival unless Reduce Motion is on.
private struct OnboardingHero: View {
    var systemImage: String

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var arrived = false

    private var diameter: CGFloat {
        if verticalSizeClass == .compact { return 64 }
        return dynamicTypeSize.isAccessibilitySize ? 88 : 116
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(TMColor.signal.mix(with: .black, by: 0.32))
                .offset(y: 6)
            Circle()
                .fill(TMColor.signal)
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.42, weight: .bold))
                .foregroundStyle(TMColor.onSignal)
                .tmSymbolBounce(value: arrived)
        }
        .frame(width: diameter, height: diameter)
        .padding(.bottom, 6)
        .accessibilityHidden(true)
        .onAppear { arrived = true }
    }
}

#if DEBUG
#Preview("Track step") {
    @Previewable @State var pick: LearningTrack? = .classic
    PlayPreviewHost {
        ScrollView {
            OnboardingTrackStep(selection: $pick)
                .padding(TMSpace.lg)
        }
    }
}

#Preview("First mission step") {
    ScrollView {
        OnboardingFirstMissionStep(
            track: .classic,
            mission: OnboardingMissionSummary(
                id: "ridge-line",
                number: 1,
                title: "Ridge Line",
                icon: "scope",
                introduces: ["Moving", "Shooting", "Woods", "Criticals"],
                sizeLine: "2 vs 2 · about 40 min · 6 turns",
                isFirst: true
            ),
            stillNeeded: ["Tape measure"]
        )
        .padding(TMSpace.lg)
    }
}
#endif
