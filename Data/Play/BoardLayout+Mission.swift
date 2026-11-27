import Foundation
import MechBuddyDomain

// Mission layouts and boards share one drawing (PlayModeSpec § 9.8). `MissionLayoutDTO` stays the mission
// JSON contract; a board is built from it without loss.

extension BoardLayout {
    public init(_ dto: MissionLayoutDTO) {
        self.init(
            width: dto.width,
            depth: dto.depth,
            sheets: dto.sheets.map { Sheet(name: $0.name, area: .init($0.area)) },
            zones: dto.zones.map { Zone(side: $0.side, area: .init($0.area)) },
            features: dto.features.compactMap { feature in
                guard let kind = FeatureKind(rawValue: feature.kind.rawValue) else { return nil }
                return Feature(kind: kind, area: .init(feature.area))
            },
            openTable: dto.openTable
        )
    }
}

extension BoardLayout.Rect {
    init(_ rect: MissionLayoutDTO.Rect) {
        self.init(x: rect.x, y: rect.y, width: rect.width, depth: rect.depth)
    }
}
