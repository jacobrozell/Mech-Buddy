import SwiftUI
import TableMechDomain

struct UnitCard: View {
    var unit: MatchUnitState
    var isActiveSide: Bool
    var showsStats: Bool = false
    var accessibilityIdentifier: String
    var isSelected: Bool = false
    var showsChevron: Bool = true
    var isEnabled: Bool = true
    var showsIdleStatus: Bool = true
    var hint: String = "Opens this ’Mech"
    var note: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            UnitCardBody(
                unit: unit,
                isActiveSide: isActiveSide,
                showsStats: showsStats,
                showsChevron: showsChevron,
                showsIdleStatus: showsIdleStatus
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
        var text = Self.accessibilityLabel(for: unit)
        if let note, !note.isEmpty {
            text += ", \(note)"
        }
        return text
    }

    static func accessibilityLabel(for unit: MatchUnitState) -> String {
        var parts: [String] = [unit.name]
        if unit.pendingCritical {
            parts.append(unit.criticalsOwed > 1 ? "\(unit.criticalsOwed) criticals waiting" : "Critical waiting")
        } else if unit.combatStatus == .destroyedPendingEnd {
            parts.append("Wrecked — still shoots")
        } else if unit.isImmobile {
            parts.append("Can’t move")
        } else if unit.movementMode == .sprint {
            parts.append("Can’t shoot")
        } else if let shot = unit.turnShot {
            parts.append(shot.rowTitle)
            parts.append(shot.rowDetail)
        }
        parts.append("Armor \(unit.remainingArmor) of \(unit.armorCap)")
        parts.append("Structure \(unit.remainingStructure) of \(unit.structureCap)")
        return parts.joined(separator: ", ")
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
            text += ", Off the table"
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

    var body: some View {
        TMCard(edgeColor: TMColor.side(unit.side), isRaised: isActiveSide) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                HStack(alignment: .center, spacing: TMSpace.sm) {
                    SideBadge(side: unit.side)
                    Text(unit.name)
                        .font(TMFont.cardTitle)
                        .strikethrough(unit.combatStatus == .removed)
                    Spacer(minLength: TMSpace.sm)
                    if showsAbilities {
                        Text("SZ \(unit.sz)")
                            .font(TMFont.statLabel)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Size \(unit.sz)")
                    }
                    if let chip = chip {
                        StatusChip(kind: chip)
                    }
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                if unit.combatStatus == .removed {
                    Text("Off the table")
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
            return .wrecked
        }
        if unit.combatStatus == .removed {
            return nil
        }
        if unit.isImmobile {
            return .immobile
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
        ]
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
