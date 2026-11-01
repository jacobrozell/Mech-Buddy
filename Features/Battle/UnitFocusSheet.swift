import SwiftUI
import TableMechDomain

struct UnitFocusSheet: View {
    let unit: MatchUnitState
    let session: MatchSession
    var isReadOnly: Bool = false
    var onResolveAttack: (() -> Void)?
    var onRollCrit: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let action = focusAction {
                    scroll.safeAreaInset(edge: .bottom, spacing: 0) {
                        actionBar(action)
                    }
                } else {
                    scroll
                }
            }
            .navigationTitle(unit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("as.unitFocus.sheet")
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.lg) {
                header
                StatStrip(cells: statCells)
                track(title: "Armor", kind: .armor, remaining: unit.remainingArmor, capacity: unit.armorCap, identifier: "as.unitFocus.wounds.\(unit.id.uuidString)")
                track(title: "Structure", kind: .structure, remaining: unit.remainingStructure, capacity: unit.structureCap, identifier: nil)
                if hasCrits {
                    crits
                }
                if !isReadOnly {
                    thisTurn
                }
                if !abilitiesLine.isEmpty {
                    VStack(alignment: .leading, spacing: TMSpace.sm) {
                        Eyebrow("Abilities")
                        Text(abilitiesLine)
                            .font(TMFont.statLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(TMSpace.lg)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            HStack(spacing: TMSpace.sm) {
                SideBadge(side: unit.side)
                Text("\(unit.side.displayName) · Size \(unit.sz)")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            if let headerChip {
                StatusChip(kind: headerChip)
            }
        }
    }

    private func track(
        title: String,
        kind: PipTrack.Kind,
        remaining: Int,
        capacity: Int,
        identifier: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Eyebrow(title)
            PipTrack(
                remaining: remaining,
                capacity: capacity,
                kind: kind,
                size: .large,
                accessibilityIdentifier: identifier
            )
        }
    }

    private var crits: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow("Criticals")
            FlowLayout(spacing: TMSpace.sm) {
                if unit.crits.engineHits > 0 {
                    StatusChip(kind: .recordedCrit(title: "Engine ×\(unit.crits.engineHits)", systemImage: "engine.combustion.fill"))
                }
                if unit.crits.weaponHits > 0 {
                    StatusChip(kind: .recordedCrit(title: "Weapon ×\(unit.crits.weaponHits)", systemImage: "target"))
                }
                if unit.crits.fireControlHits > 0 {
                    StatusChip(kind: .recordedCrit(title: "Fire control ×\(unit.crits.fireControlHits)", systemImage: "scope"))
                }
                if unit.crits.mpHit {
                    StatusChip(kind: .recordedCrit(title: "Motive", systemImage: "figure.walk"))
                }
            }
            if !critNotes.isEmpty {
                Text(critNotes)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var thisTurn: some View {
        VStack(alignment: .leading, spacing: TMSpace.md) {
            Eyebrow("This turn")
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Text("Moved")
                    .font(TMFont.statLabel)
                    .foregroundStyle(.secondary)
                if unit.hasMovedThisTurn, unit.movementMode != .unset {
                    StatusChip(kind: .moved(unit.movementMode))
                } else {
                    Text("Not yet")
                        .font(TMFont.body)
                }
            }
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                Text("Shot")
                    .font(TMFont.statLabel)
                    .foregroundStyle(.secondary)
                if let shot = unit.turnShot {
                    StatusChip(kind: shot.hit
                        ? .hit(target: shot.targetName, damage: shot.damage)
                        : .missed(target: shot.targetName))
                    Text(shot.rowDetail)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                } else {
                    Text(unit.hasAttackedThisTurn ? "Already shot" : "Not yet")
                        .font(TMFont.body)
                }
            }
        }
    }

    private func actionBar(_ action: FocusAction) -> some View {
        GlassEffectContainer(spacing: TMSpace.md) {
            PrimaryActionButton(
                title: action.title,
                placement: .dock,
                tint: TMColor.side(unit.side),
                accessibilityIdentifier: action.identifier,
                accessibilityHint: action.hint,
                action: {
                    action.run()
                    dismiss()
                }
            )
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, TMSpace.sm)
    }

    private var headerChip: StatusChip.Kind? {
        if unit.criticalsOwed > 0 { return .critOwed(unit.criticalsOwed) }
        if unit.combatStatus == .destroyedPendingEnd { return .wrecked }
        if unit.isImmobile { return .immobile }
        if unit.movementMode == .sprint { return .sprinted }
        return nil
    }

    private var hasCrits: Bool {
        unit.crits.engineHits > 0
            || unit.crits.weaponHits > 0
            || unit.crits.fireControlHits > 0
            || unit.crits.mpHit
    }

    private var critNotes: String {
        var lines: [String] = []
        if unit.crits.weaponHits > 0 {
            lines.append("Weapon hits reduce damage.")
        }
        if unit.crits.fireControlHits > 0 {
            lines.append("Fire control adds 2 to its shots.")
        }
        if unit.crits.mpHit {
            lines.append("A motive hit halves move and harder to hit.")
        }
        if unit.crits.engineHits > 0 {
            lines.append("A second engine hit wrecks it.")
        }
        return lines.joined(separator: " ")
    }

    private var abilitiesLine: String {
        unit.abilities
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var statCells: [StatCell] {
        let damage = unit.effectiveDamage
        let weaponHits = unit.crits.weaponHits
        return [
            StatCell(
                id: "mv",
                label: "MV",
                value: marked(unit.effectiveMV, changed: unit.effectiveMV != unit.mv),
                helpTitle: "Move",
                helpBody: unit.crits.mpHit
                    ? "Halved by a motive hit."
                    : "Inches this ’Mech can walk or jump."
            ),
            StatCell(
                id: "tmm",
                label: "TMM",
                value: marked("\(unit.effectiveTMM)", changed: unit.effectiveTMM != unit.tmm),
                helpTitle: "Harder to hit",
                helpBody: unit.crits.mpHit
                    ? "Halved by a motive hit."
                    : "Added to shots against this ’Mech."
            ),
            StatCell(id: "skl", label: "SKL", value: "\(unit.skill)"),
            StatCell(
                id: "dmg",
                label: "DMG",
                value: marked("\(damage.s)·\(damage.m)·\(damage.l)", changed: weaponHits > 0),
                helpTitle: "Damage",
                helpBody: weaponHits > 0
                    ? "−\(weaponHits) from \(weaponHits == 1 ? "a weapon hit" : "weapon hits")."
                    : "Short, medium, and long range damage."
            )
        ]
    }

    private func marked(_ value: String, changed: Bool) -> String {
        changed ? "\(value) ↓" : value
    }

    private var focusAction: FocusAction? {
        if isReadOnly { return nil }
        if unit.pendingCritical, let onRollCrit {
            return FocusAction(
                title: "Roll critical",
                hint: "Opens the critical roll",
                identifier: nil,
                run: onRollCrit
            )
        }
        if session.phase == .combat,
           !session.units.contains(where: \.pendingCritical),
           unit.side == session.activeSide,
           unit.canAttackThisTurn,
           let onResolveAttack {
            return FocusAction(
                title: "Shoot with \(unit.name)",
                hint: "Opens the shot solver",
                identifier: "as.unitFocus.resolve.\(unit.id.uuidString)",
                run: onResolveAttack
            )
        }
        return nil
    }
}

private struct FocusAction {
    var title: String
    var hint: String
    var identifier: String?
    var run: () -> Void
}

#if DEBUG
#Preview("Unit focus") {
    UnitFocusSheet(
        unit: PreviewFixtures.shadowHawk,
        session: PreviewFixtures.session(),
        isReadOnly: false,
        onResolveAttack: {},
        onRollCrit: {}
    )
}
#endif
