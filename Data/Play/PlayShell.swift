import Foundation

/// The root tabs and which one the app opens on (PlayModeSpec § 3).
public enum RootTabRule {
    /// Raw values saved in `AppPreferences.lastRootTab`.
    public static let learn = "learn"
    public static let play = "play"
    public static let force = "force"
    public static let rules = "rules"
    public static let settings = "settings"

    /// The tab to open on launch.
    /// - Play mode off: the Play tab (today's mission path), or Rules when asked for.
    /// - Play mode on: a new player (onboarding not finished, or no mission cleared) lands on Learn;
    ///   anyone else on the last tab used.
    public static func landing(
        playMode: Bool,
        onboardingDone: Bool,
        missionsCleared: Int,
        lastTab: String?,
        openRules: Bool = false
    ) -> String {
        if openRules { return rules }
        guard playMode else { return play }
        guard onboardingDone, missionsCleared > 0 else { return learn }
        let known = [learn, play, force, rules, settings]
        guard let lastTab, known.contains(lastTab) else { return learn }
        return lastTab
    }
}
