import SwiftUI
import MechBuddyDomain

extension EnvironmentValues {
    /// The match uses Forced Withdrawal, so crippled ’Mechs show "Withdrawing". The battle screen sets it.
    @Entry var forcedWithdrawal: Bool = false
}

struct UnitCard: View {
    var unit: MatchUnitState
    var isActiveSide: Bool
    var showsStats: Bool = false
    var accessibilityIdentifier: String
    var isSelected: Bool = false
    var showsChevron: Bool = true
    var isEnabled: Bool = true
    var showsIdleStatus: Bool = true
    /// Clean up: shooting is over, so a wreck is just "Wrecked".
    var shootingOver: Bool = false
    var hint: String = "Opens this ’Mech"
    var note: String?
    var action: () -> Void

    @Environment(\.forcedWithdrawal) private var forcedWithdrawal

    var body: some View {
        Button(action: action) {
            UnitCardBody(
                unit: unit,
                isActiveSide: isActiveSide,
                showsStats: showsStats,
                showsChevron: showsChevron,
                showsIdleStatus: showsIdleStatus,
                shootingOver: shootingOver
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .overlay {
            RoundedRectangle(cornerRadius: TMRadius.card, style: .continuous)
                .strokeBorder(isSelected ? TMColor.signal : Color.clear, lineWidth: 3)
                .allowsHitTesting(false)
        }
        .accessibilityLabel(spoken)
        .accessibilityHint(hint)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityRemoveTraits(isSelected ? [] : .isSelected)
    }

    private var spoken: String {
        var text = Self.accessibilityLabel(for: unit, forcedWithdrawal: forcedWithdrawal)
        if let note, !note.isEmpty {
            text += ", \(note)"
        }
        return text
    }

    static func accessibilityLabel(for unit: MatchUnitState, forcedWithdrawal: Bool = false) -> String {
        var parts: [String] = [unit.name]
        if let mini = unit.mini {
            parts.append("\(mini.displayName) mini")
        }
        if unit.pendingCritical {
            parts.append(unit.criticalsOwed > 1 ? "\(unit.criticalsOwed) criticals waiting" : "Critical waiting")
        } else if unit.combatStatus == .destroyedPendingEnd {
            parts.append("Wrecked — still shoots")
        } else if unit.isShutdown {
            parts.append("Shut down from heat")
        } else if unit.isImmobile {
            parts.append("Can’t move")
        } else if forcedWithdrawal, unit.combatStatus == .active, unit.isCrippled {
            parts.append("Crippled, withdrawing")
        } else if unit.movementMode == .sprint {
            parts.append("Can’t shoot")
        } else if let shot = unit.turnShot {
            parts.append(shot.rowTitle)
            parts.append(shot.rowDetail)
        }
        if let conditions = UnitConditions.line(for: unit) {
            parts.append(conditions)
        }
        parts.append("Armor \(unit.remainingArmor) of \(unit.armorCap)")
        parts.append("Structure \(unit.remainingStructure) of \(unit.structureCap)")
        return parts.joined(separator: ", ")
    }
}

/// One dense row per ’Mech for battle lists (FUTURE-PLAN §1.2). Line 1: side, name, status chip and a
/// trailing Shoot button inside the card. Line 2: armor and structure pips together. A conditions line
/// only when there is one. About 66 pt a row, so a 4 vs 4 fits on one portrait screen; the old card plus
/// its own Shoot row was ~210 pt. Accessibility sizes stack each part on its own line.
struct UnitRowCard: View {
    var unit: MatchUnitState
    var isActiveSide: Bool
    var accessibilityIdentifier: String
    var showsIdleStatus: Bool = true
    var shootingOver: Bool = false
    var hint: String = "Opens this ’Mech"
    /// Shows the trailing Shoot button when set.
    var onShoot: (() -> Void)?
    var action: () -> Void

    @Environment(\.forcedWithdrawal) private var forcedWithdrawal
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private var isLarge: Bool { dynamicTypeSize.isAccessibilitySize }

    private var chip: StatusChip.Kind? {
        UnitStatus.chip(
            for: unit,
            isActiveSide: isActiveSide,
            // The Shoot button already says "ready", so the row skips that chip.
            showsIdleStatus: showsIdleStatus && onShoot == nil,
            shootingOver: shootingOver,
            forcedWithdrawal: forcedWithdrawal
        )
    }

    var body: some View {
        TMCard(edgeColor: TMColor.side(unit.side), isRaised: isActiveSide, isCompact: true) {
            VStack(alignment: .leading, spacing: TMSpace.xs) {
                if isLarge {
                    largeLayout
                } else {
                    HStack(alignment: .center, spacing: TMSpace.sm) {
                        openButton {
                            HStack(alignment: .center, spacing: TMSpace.sm) {
                                identity
                                Spacer(minLength: TMSpace.xs)
                                if let chip {
                                    StatusChip(kind: chip)
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                if onShoot == nil {
                                    chevron
                                }
                            }
                            .frame(minHeight: 30)
                        }
                        if let onShoot {
                            shootButton(onShoot)
                        }
                    }
                    openButton { details }
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .id(unit.id)
    }

    /// Accessibility sizes: name on its own line, then the chip, pips, and a full-width Shoot.
    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            openButton {
                VStack(alignment: .leading, spacing: TMSpace.sm) {
                    HStack(spacing: TMSpace.sm) {
                        SideBadge(side: unit.side)
                        if let mini = unit.mini {
                            MiniDot(marker: mini)
                        }
                        Spacer(minLength: 0)
                        if onShoot == nil {
                            chevron
                        }
                    }
                    Text(unit.name)
                        .font(TMFont.cardTitle)
                        .strikethrough(unit.combatStatus == .removed)
                        .fixedSize(horizontal: false, vertical: true)
                    if let chip {
                        StatusChip(kind: chip)
                    }
                    details
                }
            }
            if let onShoot {
                shootButton(onShoot)
            }
        }
    }

    /// The whole row except Shoot opens the ’Mech. Two buttons (identity line, then pips) rather than
    /// one wrapping Shoot: a button inside a button's label is not reachable by VoiceOver.
    private func openButton<Label: View>(@ViewBuilder _ label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(OpenRowAccessibility(
            label: UnitCard.accessibilityLabel(for: unit, forcedWithdrawal: forcedWithdrawal),
            hint: hint,
            identifier: accessibilityIdentifier
        ))
    }

    private var identity: some View {
        HStack(alignment: .center, spacing: TMSpace.sm) {
            SideBadge(side: unit.side)
            if let mini = unit.mini {
                MiniDot(marker: mini)
            }
            // Full name when it fits; "Wolverine" without the variant when the chip needs the room.
            ViewThatFits(in: .horizontal) {
                nameText(unit.name)
                nameText(StatusChip.Kind.short(unit.name))
            }
            .layoutPriority(-1)
        }
    }

    private func nameText(_ name: String) -> some View {
        Text(name)
            .font(TMFont.cardTitle)
            .strikethrough(unit.combatStatus == .removed)
            .lineLimit(1)
    }

    @ViewBuilder
    private var details: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            if unit.combatStatus == .removed {
                Text(unit.leftTable ? "Left the table" : "Off the table")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
            }
            // Armor and structure side by side; stacked only when they don't fit (large text, small phones).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TMSpace.md) {
                    armorTrack
                    structureTrack
                }
                VStack(alignment: .leading, spacing: TMSpace.xs) {
                    armorTrack
                    structureTrack
                }
            }
            if let conditions = UnitConditions.line(for: unit) {
                Label(conditions, systemImage: "exclamationmark.triangle.fill")
                    .font(TMFont.detail)
                    .foregroundStyle(TMColor.warning)
                    .labelStyle(.titleAndIcon)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var armorTrack: some View {
        track(icon: "shield.fill", remaining: unit.remainingArmor, capacity: unit.armorCap, kind: .armor)
    }

    private var structureTrack: some View {
        track(
            icon: "square.stack.3d.up.fill",
            remaining: unit.remainingStructure,
            capacity: unit.structureCap,
            kind: .structure
        )
    }

    private func track(icon: String, remaining: Int, capacity: Int, kind: PipTrack.Kind) -> some View {
        HStack(alignment: .center, spacing: TMSpace.xs) {
            Image(systemName: icon)
                .font(.caption2)
                // The pips don't scale, so the icon stops growing before it dwarfs them.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            PipTrack(remaining: remaining, capacity: capacity, kind: kind, size: isLarge ? .regular : .compact)
                .fixedSize()
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private func shootButton(_ onShoot: @escaping () -> Void) -> some View {
        Button(action: onShoot) {
            Text("Shoot")
                .font(TMFont.detail.weight(.semibold))
                // Dark mode's lighter side colours need a dark label (white was about 2.6:1).
                .foregroundStyle(colorScheme == .dark ? TMColor.onSignal : Color.white)
                .lineLimit(1)
                .padding(.horizontal, TMSpace.md)
                .frame(maxWidth: isLarge ? .infinity : nil, minHeight: isLarge ? 44 : 30)
                .background(TMColor.side(unit.side), in: Capsule())
                // 30 pt drawn, 44 pt to tap: the extra reaches into the card's own padding.
                .contentShape(Rectangle().inset(by: isLarge ? 0 : -7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shoot with \(unit.name)")
        .accessibilityIdentifier("as.battle.shoot.\(unit.id.uuidString)")
    }
}

private struct OpenRowAccessibility: ViewModifier {
    var label: String
    var hint: String
    var identifier: String

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityIdentifier(identifier)
    }
}

/// One line of lasting damage and heat for a unit row: "Heat 2 · Weapon ×1 · MP hit".
enum UnitConditions {
    static func line(for unit: MatchUnitState) -> String? {
        guard unit.combatStatus != .removed else { return nil }
        var parts: [String] = []
        if unit.isShutdown {
            parts.append("Shut down")
        } else if unit.heat > 0 {
            parts.append("Heat \(unit.heat)")
        }
        let crits = unit.crits
        if crits.engineHits > 0 { parts.append("Engine") }
        if crits.fireControlHits > 0 { parts.append("Fire control ×\(crits.fireControlHits)") }
        if crits.weaponHits > 0 { parts.append("Weapon ×\(crits.weaponHits)") }
        if crits.mpHit { parts.append("MP hit") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// The one status chip a unit row shows ("Walked", "Hit Locust · 2", "Withdrawing"…).
enum UnitStatus {
    static func chip(
        for unit: MatchUnitState,
        isActiveSide: Bool,
        showsIdleStatus: Bool,
        shootingOver: Bool,
        forcedWithdrawal: Bool
    ) -> StatusChip.Kind? {
        if unit.criticalsOwed > 0 {
            return .critOwed(unit.criticalsOwed)
        }
        if unit.combatStatus == .destroyedPendingEnd {
            return unit.canAttackThisTurn && !shootingOver ? .wrecked : .wreckedDone
        }
        if unit.combatStatus == .removed {
            return nil
        }
        if unit.isShutdown {
            return .shutdown
        }
        if unit.isImmobile {
            return .immobile
        }
        if forcedWithdrawal, unit.isCrippled {
            return .withdrawing
        }
        if unit.movementMode == .sprint, unit.hasMovedThisTurn {
            return .sprinted
        }
        if let shot = unit.turnShot {
            return shot.hit
                ? .hit(target: shot.targetName, damage: shot.damage)
                : .missed(target: shot.targetName)
        }
        if unit.hasMovedThisTurn, unit.movementMode != .unset {
            return .moved(unit.movementMode)
        }
        if isActiveSide, unit.canAttackThisTurn {
            return showsIdleStatus ? .ready : nil
        }
        if !isActiveSide {
            return showsIdleStatus ? .waiting : nil
        }
        return nil
    }
}

struct ForceUnitCard: View {
    var unit: MatchUnitState
    var accessibilityIdentifier: String
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    UnitCardBody(
                        unit: unit,
                        isActiveSide: true,
                        showsStats: true,
                        showsChevron: true,
                        showsAbilities: true,
                        showsIdleStatus: false
                    )
                }
                .buttonStyle(.plain)
            } else {
                UnitCardBody(
                    unit: unit,
                    isActiveSide: true,
                    showsStats: true,
                    showsChevron: false,
                    showsAbilities: true,
                    showsIdleStatus: false
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var label: String {
        var text = UnitCard.accessibilityLabel(for: unit)
        text += ", size \(unit.sz)"
        if !unit.abilities.isEmpty {
            text += ", \(UnitCardBody.abilitiesLine(unit.abilities))"
        }
        if unit.combatStatus == .removed {
            text += unit.leftTable ? ", Left the table" : ", Off the table"
        }
        return text
    }
}

private struct UnitCardBody: View {
    var unit: MatchUnitState
    var isActiveSide: Bool
    var showsStats: Bool
    var showsChevron: Bool
    var showsAbilities: Bool = false
    var showsIdleStatus: Bool = true
    var shootingOver: Bool = false

    @Environment(\.forcedWithdrawal) private var forcedWithdrawal
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var nameText: some View {
        Text(unit.name)
            .font(TMFont.cardTitle)
            .strikethrough(unit.combatStatus == .removed)
            .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        TMCard(edgeColor: TMColor.side(unit.side), isRaised: isActiveSide) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                // At accessibility sizes the name gets its own full-width line so words never break mid-word.
                HStack(alignment: .center, spacing: TMSpace.sm) {
                    SideBadge(side: unit.side)
                    if let mini = unit.mini {
                        MiniDot(marker: mini)
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        nameText
                    }
                    Spacer(minLength: TMSpace.sm)
                    if showsAbilities {
                        Text("SZ \(unit.sz)")
                            .font(TMFont.statLabel)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Size \(unit.sz)")
                    }
                    // At accessibility sizes the chip ("Walked …") gets its own line under the name; beside SZ it was cramped.
                    if let chip = chip, !dynamicTypeSize.isAccessibilitySize {
                        StatusChip(kind: chip)
                    }
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                if dynamicTypeSize.isAccessibilitySize {
                    nameText
                    if let chip = chip {
                        StatusChip(kind: chip)
                    }
                }
                if unit.combatStatus == .removed {
                    Text(unit.leftTable ? "Left the table" : "Off the table")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                HealthReadout(
                    armorRemaining: unit.remainingArmor,
                    armorCapacity: unit.armorCap,
                    structureRemaining: unit.remainingStructure,
                    structureCapacity: unit.structureCap,
                    size: showsStats ? .regular : .compact
                )
                if let conditions = UnitConditions.line(for: unit) {
                    Label(conditions, systemImage: "exclamationmark.triangle.fill")
                        .font(TMFont.detail)
                        .foregroundStyle(TMColor.warning)
                        .labelStyle(.titleAndIcon)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if showsStats {
                    StatStrip(cells: statCells)
                        .opacity(isActiveSide ? 1 : 0.85)
                }
                if showsAbilities, !unit.abilities.isEmpty {
                    Text(Self.abilitiesLine(unit.abilities))
                        .font(TMFont.statLabel)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    static func abilitiesLine(_ abilities: String) -> String {
        abilities
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var chip: StatusChip.Kind? {
        UnitStatus.chip(
            for: unit,
            isActiveSide: isActiveSide,
            showsIdleStatus: showsIdleStatus,
            shootingOver: shootingOver,
            forcedWithdrawal: forcedWithdrawal
        )
    }

    private var statCells: [StatCell] {
        let damage = unit.effectiveDamage
        return [
            StatCell(id: "mv", label: "MV", value: unit.displayMV, helpTitle: "Move", helpBody: "Inches this ’Mech can walk or jump."),
            StatCell(id: "tmm", label: "TMM", value: "\(unit.effectiveTMM)", helpTitle: "Harder to hit", helpBody: "Added to shots against this ’Mech."),
            StatCell(id: "skl", label: "SKL", value: "\(unit.skill)"),
            StatCell(
                id: "dmg",
                label: "DMG",
                value: "\(damage.s)·\(damage.m)·\(damage.l)",
                helpTitle: "Damage",
                helpBody: "Short, medium, and long range damage."
            )
        ] + StatCell.heat(for: unit)
    }
}

#if DEBUG
#Preview("Unit card") {
    PreviewPair {
        VStack(spacing: TMSpace.md) {
            UnitCard(
                unit: PreviewFixtures.shadowHawk,
                isActiveSide: true,
                accessibilityIdentifier: "preview.unit.a",
                action: {}
            )
            ForceUnitCard(
                unit: PreviewFixtures.locust,
                accessibilityIdentifier: "preview.unit.b"
            )
        }
    }
}
#endif
