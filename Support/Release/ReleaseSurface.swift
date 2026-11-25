import Foundation

public enum ReleaseFlag: String, CaseIterable, Sendable {
    case alphaStrikePlay
    case ridgeLineMission
    /// Missions after Ridge Line (Broken Ground on) and the ladder list on Play.
    case missionLadder
    case fullLancesScenario
    case freeBattle
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
        case .fullLancesScenario, .freeBattle, .physicalOvWithdrawal,
             .classicPlayTools, .mulNetworkFetch, .matchHistory:
            return isFullProductSurface
        }
    }
}
