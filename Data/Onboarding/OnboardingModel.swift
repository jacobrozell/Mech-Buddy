import Foundation

// Non-view onboarding logic. Lives in MechBuddyData so the unit tests can import it.
// Spec: specs/features/OnboardingSpec.md

/// Which BattleTech the player wants to learn.
public enum LearningTrack: String, CaseIterable, Identifiable, Sendable {
    case alphaStrike
    case classic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .alphaStrike: "Alpha Strike"
        case .classic: "Classic BattleTech"
        }
    }

    public var tagline: String {
        switch self {
        case .alphaStrike: "Quick and card-based"
        case .classic: "The full-detail game"
        }
    }

    public var systemImage: String {
        switch self {
        case .alphaStrike: "rectangle.portrait.on.rectangle.portrait"
        case .classic: "hexagon"
        }
    }

    /// Whether Mech Buddy can run this game today.
    public var isPlayableInApp: Bool { self == .alphaStrike }

    public var badge: String { isPlayableInApp ? "Play now" : "Coming soon" }

    /// What the game asks of you: time, rules, and gear.
    public var commitments: [TrackCommitment] {
        switch self {
        case .alphaStrike:
            [
                TrackCommitment(id: "time", systemImage: "clock", text: "About an hour for 4 vs 4"),
                TrackCommitment(id: "rules", systemImage: "book.closed", text: "One card per ’Mech, one roll to hit"),
                TrackCommitment(id: "gear", systemImage: "ruler", text: "Any table and a tape measure. Cards are free online")
            ]
        case .classic:
            [
                TrackCommitment(id: "time", systemImage: "clock", text: "A few hours a game"),
                TrackCommitment(id: "rules", systemImage: "books.vertical", text: "Record sheets, hit locations, and every weapon rolled"),
                TrackCommitment(id: "gear", systemImage: "map", text: "Hex maps and a full heat scale")
            ]
        }
    }
}

public struct TrackCommitment: Identifiable, Equatable, Sendable {
    public var id: String
    public var systemImage: String
    public var text: String

    public init(id: String, systemImage: String, text: String) {
        self.id = id
        self.systemImage = systemImage
        self.text = text
    }
}

/// Why the flow is open.
public enum OnboardingEntry: String, Identifiable, Sendable {
    /// First launch. Starts at Welcome.
    case firstRun
    /// Reopened from Settings or Play to switch games. Starts at the track question.
    case changeTrack

    public var id: String { rawValue }
}

/// One question per screen.
public enum OnboardingStep: String, CaseIterable, Sendable {
    case welcome
    case track
    case kit
    case firstMission

    /// The screens to show, in order. The track question needs Classic to be visible
    /// (`ReleaseFlag.classicComingSoonEntry`); without it there is only one game to pick.
    public static func steps(for entry: OnboardingEntry, classicAvailable: Bool) -> [OnboardingStep] {
        switch (entry, classicAvailable) {
        case (.firstRun, true): [.welcome, .track, .kit, .firstMission]
        case (.changeTrack, true): [.track, .kit, .firstMission]
        case (_, false): [.welcome, .kit, .firstMission]
        }
    }

    /// Fill of the progress bar after reaching `step`: 1 of n … n of n.
    public static func progress(of step: OnboardingStep, in steps: [OnboardingStep]) -> Double {
        guard let index = steps.firstIndex(of: step), !steps.isEmpty else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }
}

/// What the flow has saved. Lives in `UserDefaults` through `AppPreferences`.
public struct OnboardingRecord: Equatable, Sendable {
    public var track: LearningTrack?
    public var isComplete: Bool

    public init(track: LearningTrack?, isComplete: Bool) {
        self.track = track
        self.isComplete = isComplete
    }

    public static let fresh = OnboardingRecord(track: nil, isComplete: false)
}

public enum OnboardingStore {
    public static let trackKey = "onboarding.track"
    public static let completedKey = "onboarding.completed"
    /// Set by builds before onboarding existed, when a game was started or resumed.
    /// Those players already know the app, so it counts as done with Alpha Strike.
    public static let legacyIntroKey = "settings.hasSeenIntro"

    /// Every key this store reads. `AppPreferences.reset()` removes them all.
    public static let ownedKeys = [trackKey, completedKey, legacyIntroKey]

    public static func load(from defaults: UserDefaults) -> OnboardingRecord {
        let legacy = defaults.bool(forKey: legacyIntroKey)
        let complete: Bool
        if defaults.object(forKey: completedKey) != nil {
            complete = defaults.bool(forKey: completedKey)
        } else {
            complete = legacy
        }
        let stored = defaults.string(forKey: trackKey).flatMap(LearningTrack.init(rawValue:))
        let track = stored ?? (legacy ? .alphaStrike : nil)
        return OnboardingRecord(track: track, isComplete: complete)
    }

    public static func save(_ record: OnboardingRecord, to defaults: UserDefaults) {
        if let track = record.track {
            defaults.set(track.rawValue, forKey: trackKey)
        } else {
            defaults.removeObject(forKey: trackKey)
        }
        defaults.set(record.isComplete, forKey: completedKey)
    }
}

/// How Play arranges itself for the chosen track.
public struct PlayTrackLayout: Equatable, Sendable {
    /// Large Classic card above the mission path: the player picked Classic, which isn't playable yet,
    /// so the card says so and points at the Alpha Strike path as the way to start.
    public var showsClassicSpotlight: Bool
    /// The small "More modes" Classic row under the path.
    public var showsClassicRow: Bool

    public init(showsClassicSpotlight: Bool, showsClassicRow: Bool) {
        self.showsClassicSpotlight = showsClassicSpotlight
        self.showsClassicRow = showsClassicRow
    }

    public static func make(track: LearningTrack?, classicEntryEnabled: Bool) -> PlayTrackLayout {
        guard classicEntryEnabled else {
            return PlayTrackLayout(showsClassicSpotlight: false, showsClassicRow: false)
        }
        switch track {
        case .classic:
            return PlayTrackLayout(showsClassicSpotlight: true, showsClassicRow: false)
        case .alphaStrike, nil:
            return PlayTrackLayout(showsClassicSpotlight: false, showsClassicRow: true)
        }
    }
}

/// The "What do you have?" screen. Items come from `as-getting-started.json`; ids match its `id`s.
public enum OnboardingKit {
    public static func systemImage(for id: String) -> String {
        switch id {
        case "minis": "figure.stand"
        case "dice": "dice"
        case "tape": "ruler"
        case "maps": "table.furniture"
        default: "checkmark.circle"
        }
    }

    /// Kit ids not ticked yet, in screen order.
    public static func stillNeeded(kitIDs: [String], have: Set<String>) -> [String] {
        kitIDs.filter { !have.contains($0) }
    }
}

public enum OnboardingMissions {
    /// The mission the path points at: the first playable one not cleared yet, else the last playable one.
    /// `ladder` is in mission order.
    public static func nextMissionID(ladder: [(id: String, playable: Bool)], completed: Set<String>) -> String? {
        let playable = ladder.filter(\.playable).map(\.id)
        return playable.first { !completed.contains($0) } ?? playable.last
    }
}
