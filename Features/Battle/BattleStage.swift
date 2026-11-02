import SwiftUI
import UIKit
import MechBuddyDomain

enum BattleStageLayout: Equatable {
    case stacked
    case phoneLandscape
    case padColumns

    static let rosterColumnWidth: CGFloat = 360
    static let unitStripWidth: CGFloat = 248

    /// iPad uses the idiom, and only when the width can hold a 360 pt roster.
    /// Phone landscape is compact height, including large phones with a regular width.
    static func resolve(
        idiom: UIUserInterfaceIdiom,
        horizontal: UserInterfaceSizeClass?,
        vertical: UserInterfaceSizeClass?
    ) -> BattleStageLayout {
        if idiom == .pad, horizontal == .regular {
            return .padColumns
        }
        if idiom == .phone, vertical == .compact {
            return .phoneLandscape
        }
        return .stacked
    }

    var showsSideRoster: Bool { self != .stacked }
}

struct BattleRoster: View {
    var session: MatchSession
    var coach: BattleCoach
    var layout: BattleStageLayout
    var landingUnitID: UUID?
    var onOpenUnit: (MatchUnitState) -> Void
    var onShoot: (MatchUnitState) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if layout == .phoneLandscape {
                strip
            } else {
                column
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    private var column: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack(alignment: .leading, spacing: TMSpace.lg) {
                    ForEach(SideId.allCases, id: \.self) { side in
                        let sideUnits = units(on: side)
                        if !sideUnits.isEmpty {
                            VStack(alignment: .leading, spacing: TMSpace.sm) {
                                Eyebrow(side.displayName)
                                ForEach(sideUnits) { unit in
                                    row(unit)
                                }
                            }
                        }
                    }
                }
                .padding(TMSpace.lg)
                .onChange(of: landingUnitID) { _, id in
                    scroll(proxy, to: id)
                }
            }
        }
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: TMSpace.sm) {
                    ForEach(rosterUnits) { unit in
                        row(unit)
                            .frame(width: 200)
                    }
                }
                .padding(TMSpace.sm)
                .onChange(of: landingUnitID) { _, id in
                    scroll(proxy, to: id)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(_ unit: MatchUnitState) -> some View {
        BattleUnitRow(
            unit: unit,
            isActiveSide: isRaised(unit),
            offersShoot: offersShoot(unit),
            landingUnitID: landingUnitID,
            onOpenUnit: { onOpenUnit(unit) },
            onShoot: { onShoot(unit) }
        )
    }

    private var rosterUnits: [MatchUnitState] {
        SideId.allCases.flatMap { units(on: $0) }
    }

    private func units(on side: SideId) -> [MatchUnitState] {
        session.units.filter { $0.side == side && $0.combatStatus != .removed }
    }

    private func offersShoot(_ unit: MatchUnitState) -> Bool {
        coach.pendingCritical == nil
            && coach.step == .combat
            && unit.side == session.activeSide
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

    var body: some View {
        VStack(alignment: .trailing, spacing: TMSpace.sm) {
            UnitCard(
                unit: unit,
                isActiveSide: isActiveSide,
                accessibilityIdentifier: "as.battle.unit.\(unit.id.uuidString)",
                action: onOpenUnit
            )
            .overlay {
                if landingUnitID == unit.id {
                    RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                        .strokeBorder(TMColor.damage, lineWidth: 3)
                        .allowsHitTesting(false)
                }
            }
            if offersShoot {
                Button(action: onShoot) {
                    Text("Shoot")
                        .font(TMFont.detail.weight(.semibold))
                        .padding(.horizontal, TMSpace.md)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(TMColor.side(unit.side))
                .accessibilityLabel("Shoot with \(unit.name)")
            }
        }
        .id(unit.id)
    }
}
