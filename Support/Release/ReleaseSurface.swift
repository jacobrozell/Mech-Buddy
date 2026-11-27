import Foundation

public enum ReleaseFlag: String, CaseIterable, Sendable {
    case alphaStrikePlay
    case ridgeLineMission
    /// Missions after Ridge Line (Broken Ground on) and the ladder list on Play.
    case missionLadder
    case fullLancesScenario
    /// Learn | Play tabs, Play home, pickup-game setup and Play sessions (PlayModeSpec § 16). Was `freeBattle`.
    case playMode
    /// Three- and four-side presets in Play (PlayModeSpec § 16, PM7). Teams (1 v 2, 2 v 2) stay under `playMode`.
    case playModeMultiSide
    /// The objective picker and Score step in Play (PlayModeSpec § 16, PM8). Off = last side standing only.
    case playObjectives
    /// Terrain board builder and the board in setup, table setup and battle (PlayModeSpec § 16, PM12). Off = mat or mapsheets with generated zones only.
    case playBoards
    case physicalOvWithdrawal
    case classicComingSoonEntry
    case classicPlayTools
    case mulNetworkFetch
    case matchHistory
    case tipJar
}

public protocol ReleaseSurfaceProviding: Sendable {
    var isFullProductSurface: Bool { get }
    func isEnabled(_ flag: ReleaseFlag) -> Bool
}

public struct ReleaseSurface: ReleaseSurfaceProviding, Sendable {
    public var isFullProductSurface: Bool

    public init(isFullProductSurface: Bool = ProcessInfo.processInfo.arguments.contains("-enable_full_product_surface")) {
        self.isFullProductSurface = isFullProductSurface
    }

    public func isEnabled(_ flag: ReleaseFlag) -> Bool {
        switch flag {
        case .alphaStrikePlay, .ridgeLineMission, .missionLadder:
            return true
        case .classicComingSoonEntry:
            return true
        case .tipJar:
            return false
        case .fullLancesScenario, .playMode, .playModeMultiSide, .playObjectives, .playBoards, .physicalOvWithdrawal,
             .classicPlayTools, .mulNetworkFetch, .matchHistory:
            return isFullProductSurface
        }
    }
}
