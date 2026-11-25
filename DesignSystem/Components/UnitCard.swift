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

    private var statCells: [StatCell] {
        let damage = unit.effectiveDamage
        return [
            StatCell(id: "mv", label: "MV", value: unit.effectiveMV, helpTitle: "Move", helpBody: "Inches this ’Mech can walk or jump."),
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
