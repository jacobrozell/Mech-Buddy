import SwiftUI
import UIKit
import MechBuddyDomain

/// How the battle screen is arranged (FUTURE-PLAN 1.7). `stacked` is the portrait column. `table` puts the
/// roster (sides in columns) on the left and the step with its dock on the right.
enum BattleStageLayout: Equatable {
    case stacked
    case table

    /// Width of the step-and-dock column on the right.
    static func toolColumnWidth(idiom: UIUserInterfaceIdiom) -> CGFloat {
        idiom == .pad ? 380 : 330
    }

    /// Narrowest a side column may get before the grid drops a column.
    static let minSideColumnWidth: CGFloat = 200

    /// Phone landscape is compact height (large phones can still report a regular width). iPad uses the idiom
    /// with a regular width, so Split View and Slide Over fall back to the portrait column. Accessibility text
    /// sizes never fit two columns of cards, so they stay stacked.
    static func resolve(
        idiom: UIUserInterfaceIdiom,
        horizontal: UserInterfaceSizeClass?,
        vertical: UserInterfaceSizeClass?,
        isAccessibilitySize: Bool = false
    ) -> BattleStageLayout {
        if isAccessibilitySize { return .stacked }
        if idiom == .pad { return horizontal == .regular ? .table : .stacked }
        if idiom == .phone, vertical == .compact { return .table }
        return .stacked
    }

    /// Steps that are about the table itself (set-up and placing minis) keep the full-width column.
    static func usesTable(_ layout: BattleStageLayout, step: BattleCoach.Step) -> Bool {
        guard layout == .table else { return false }
        return step != .tableSetup && step != .placeMiniatures
    }

    /// Side columns for `sideCount` sides in `width` points: one row of two for a 1 v 1, three across when
    /// there is room for three sides, and a 2 x 2 grid for four.
    static func columnCount(sideCount: Int, width: CGFloat) -> Int {
        guard sideCount > 1 else { return 1 }
        let fits = max(1, Int(width / minSideColumnWidth))
        let wanted = sideCount == 4 ? 2 : sideCount
        return max(1, min(wanted, fits))
    }

    /// Chunks `groups` (already pinned-first) into grid rows of `columns`, so the acting side leads the first row.
    static func rows<T>(_ groups: [T], columns: Int) -> [[T]] {
        let n = max(1, columns)
        return stride(from: 0, to: groups.count, by: n).map { Array(groups[$0..<min($0 + n, groups.count)]) }
    }

    /// 3 or 4 sides use the one-line rows, as the portrait lists do; a 1 v 1 column has room for two lines.
    static func usesDenseRows(sideCount: Int) -> Bool { sideCount > 2 }
}

struct BattleRoster: View {
    var session: MatchSession
    var coach: BattleCoach
    var landingUnitID: UUID?
    var onOpenUnit: (MatchUnitState) -> Void
    var onShoot: (MatchUnitState) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let groups = SideGrouping.groups(in: session, pinned: pinnedSide)
            let columns = BattleStageLayout.columnCount(sideCount: groups.count, width: geo.size.width - TMSpace.md * 2)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: TMSpace.md) {
                        ForEach(Array(BattleStageLayout.rows(groups, columns: columns).enumerated()), id: \.offset) { _, rowGroups in
                            HStack(alignment: .top, spacing: TMSpace.md) {
                                ForEach(rowGroups) { group in
                                    sideColumn(group)
                                }
                                // A short last row keeps its columns the same width as the rows above.
                                ForEach(0..<(columns - rowGroups.count), id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                                }
                            }
                        }
                    }
                    .padding(TMSpace.md)
                }
                .onChange(of: landingUnitID) { _, id in
                    scroll(proxy, to: id)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    private func sideColumn(_ group: SideGroup) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            sideHeader(group)
            ForEach(group.units) { unit in
                row(unit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func row(_ unit: MatchUnitState) -> some View {
        BattleUnitRow(
            unit: unit,
            isActiveSide: isRaised(unit),
            offersShoot: offersShoot(unit),
            landingUnitID: landingUnitID,
            onOpenUnit: { onOpenUnit(unit) },
            onShoot: { onShoot(unit) },
            isDense: BattleStageLayout.usesDenseRows(sideCount: session.sides.count)
        )
    }

    /// During Movement and Combat the side whose turn it is sits at the top.
    private var pinnedSide: SideId? {
        coach.step == .movement || coach.step == .combat ? session.activeSide : nil
    }

    /// Thin side-colour accent bar, the side's name and a unit count; one short line so 4 v 4 stays on one screen.
    private func sideHeader(_ group: SideGroup) -> some View {
        HStack(spacing: TMSpace.xs) {
            Capsule()
                .fill(TMColor.side(group.side))
                .frame(width: 4, height: 14)
                .accessibilityHidden(true)
            Eyebrow(group.name)
            Text("\(group.units.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("as.battle.side.\(group.side.rawValue)")
    }

    private func offersShoot(_ unit: MatchUnitState) -> Bool {
        coach.pendingCritical == nil
            && coach.step == .combat
            && unit.canAttackThisTurn
    }

    private func isRaised(_ unit: MatchUnitState) -> Bool {
        if let owed = coach.pendingCritical {
            return unit.id == owed.unitId
        }
        if coach.step == .movement {
            let moving = AlphaStrikePhaseEngine.unitsNeedingMove(
                side: session.activeSide,
                units: session.units
            ).first
            return unit.id == moving?.id
        }
        if coach.step == .combat {
            return unit.canAttackThisTurn
        }
        if BattleChrome.showsActiveSide(coach.step) {
            return unit.side == session.activeSide
        }
        return false
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: UUID?) {
        guard let id else { return }
        if reduceMotion {
            proxy.scrollTo(id, anchor: .center)
        } else {
            withAnimation(TMMotion.drain) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}

struct BattleUnitRow: View {
    var unit: MatchUnitState
    var isActiveSide: Bool
    var offersShoot: Bool
    var landingUnitID: UUID?
    var onOpenUnit: () -> Void
    var onShoot: () -> Void
    var isDense = false

    var body: some View {
        // Dense row with Shoot inside the card (FUTURE-PLAN §1.2); it used to float in its own row.
        UnitRowCard(
            unit: unit,
            isActiveSide: isActiveSide,
            accessibilityIdentifier: "as.battle.unit.\(unit.id.uuidString)",
            isDense: isDense,
            onShoot: offersShoot ? onShoot : nil,
            action: onOpenUnit
        )
        .overlay {
            if landingUnitID == unit.id {
                RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                    .strokeBorder(TMColor.damage, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
        .id(unit.id)
    }
}
