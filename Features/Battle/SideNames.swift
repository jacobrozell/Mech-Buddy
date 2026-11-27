import SwiftUI
import MechBuddyDomain

/// The session's side names, for battle chrome that has no `MatchSession` of its own (PlayModeSpec § 8, PM6).
/// Falls back to "Side A" for a side it doesn't know, so previews and missions read as before.
struct SideNames: Equatable {
    var names: [SideId: String] = [:]

    init(_ session: MatchSession? = nil) {
        guard let session else { return }
        for side in session.sides { names[side.id] = session.displayName(of: side.id) }
    }

    func callAsFunction(_ side: SideId) -> String { names[side] ?? side.displayName }
}

private struct SideNamesKey: EnvironmentKey {
    static let defaultValue = SideNames()
}

extension EnvironmentValues {
    var sideNames: SideNames {
        get { self[SideNamesKey.self] }
        set { self[SideNamesKey.self] = newValue }
    }
}
