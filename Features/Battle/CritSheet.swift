import SwiftUI
import MechBuddyDomain

struct CritSheet: View {
    let unit: MatchUnitState
    @Bindable var store: MatchStore
    @Environment(\.dismiss) private var dismiss
    @State private var d1: Int?
    @State private var d2: Int?
    @State private var tableOpen = false
    /// Per-roll: tapping "Let the app roll" here must not switch later shots to app-rolled dice.
    @State private var diceMode: DiceMode = .manual
    @State private var isApplying = false

    private var tableRows: [(total: Int, name: String)] {
        (2...12).map { total in
            let id = AlphaStrikeCriticals.resultId(forTotal: total)
            return (total, AlphaStrikeCriticals.title(for: id))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: TMSpace.lg) {
                        header
                        DiceTray(
                            mode: Binding(
                                get: { diceMode },
                                set: { newMode in
                                    guard newMode != diceMode else { return }
                                    d1 = nil
                                    d2 = nil
                                    diceMode = newMode
                                }
                            ),
                            die1: $d1,
                            die2: $d2,
                            manualPrompt: "Roll two dice on the table, then tap the faces.",
                            autoPrompt: "The app rolls two dice.",
                            identifierPrefix: "as.crit"
                        )
                        if let d1, let d2 {
                            resultCard(total: d1 + d2)
                        }
                        referenceTable
                    }
                    .padding(TMSpace.lg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                applyBar
                    .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
            }
            .navigationTitle("Critical hit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("as.crit.sheet")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            HStack(spacing: TMSpace.sm) {
                SideBadge(side: unit.side)
                Text(unit.name)
                    .font(TMFont.cardTitle)
                Spacer(minLength: TMSpace.sm)
                if unit.criticalsOwed > 0 {
                    StatusChip(kind: .critOwed(unit.criticalsOwed))
                }
            }
            Text("\(unit.side.other.displayName) rolls, as the side that hit the \(unit.name). This is a critical check, not a shot. The app applies the result, including a wreck or no effect.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultCard(total: Int) -> some View {
        let id = AlphaStrikeCriticals.resultId(forTotal: total)
        return TMCard(edgeColor: tone(for: id)) {
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                if let d1, let d2 {
                    DiceReadout(die1: d1, die2: d2)
                }
                HStack(spacing: TMSpace.md) {
                    Image(systemName: icon(for: id))
                        .font(.system(size: 36))
                        .foregroundStyle(tone(for: id))
                        .accessibilityHidden(true)
                        .tmSymbolBounce(value: total)
                    Text(displayName(for: id))
                        .font(TMFont.readoutM)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(explanation(for: id))
                    .font(TMFont.detail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var referenceTable: some View {
        DisclosureGroup(isExpanded: $tableOpen) {
            VStack(spacing: TMSpace.xxs) {
                ForEach(tableRows, id: \.total) { row in
                    let selected = rolledTotal == row.total
                    HStack(spacing: TMSpace.sm) {
                        Text("\(row.total)")
                            .font(TMFont.stat)
                            .frame(width: 32, alignment: .trailing)
                        Text(row.name)
                            .font(TMFont.body)
                        Spacer(minLength: TMSpace.sm)
                    }
                    .padding(.vertical, TMSpace.xs)
                    .padding(.horizontal, TMSpace.sm)
                    .background(
                        selected ? TMColor.signal : Color.clear,
                        in: RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous)
                    )
                    .foregroundStyle(selected ? TMColor.onSignal : Color.primary)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityRemoveTraits(selected ? [] : .isSelected)
                }
            }
            .padding(.top, TMSpace.sm)
        } label: {
            Text("Critical table")
                .font(TMFont.cardTitle)
        }
        .accessibilityHint("Reference for the roll")
    }

    private var applyBar: some View {
        GlassEffectContainer(spacing: TMSpace.md) {
            PrimaryActionButton(
                title: confirmTitle,
                placement: .dock,
                tint: TMColor.signal,
                isDisabled: d1 == nil || d2 == nil || isApplying,
                accessibilityIdentifier: "as.crit.confirm",
                accessibilityHint: "Records this critical",
                action: apply
            )
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, TMSpace.sm)
    }

    private var rolledTotal: Int? {
        guard let d1, let d2 else { return nil }
        return d1 + d2
    }

    private var confirmTitle: String {
        guard let rolledTotal else { return "Apply this critical" }
        return applyTitle(for: AlphaStrikeCriticals.resultId(forTotal: rolledTotal))
    }

    private func apply() {
        // A second tap while the sheet dismisses must not re-submit (it raised "No critical owed").
        guard let d1, let d2, !isApplying else { return }
        isApplying = true
        if store.applyPendingCrit(unitId: unit.id, die1: d1, die2: d2) {
            dismiss()
        } else {
            isApplying = false
        }
    }

    private func displayName(for id: CritResultId) -> String {
        AlphaStrikeCriticals.title(for: id)
    }

    private func applyTitle(for id: CritResultId) -> String {
        if id == .none { return "Apply — no effect" }
        return "Apply \(AlphaStrikeCriticals.title(for: id))"
    }

    private func explanation(for id: CritResultId) -> String {
        switch id {
        case .ammo:
            switch unit.ammoProtection {
            case .full: "Ammo hit. This ’Mech has ENE or CASE II, so nothing happens."
            case .caseOne: "Ammo hit. CASE saves it: it takes 1 extra damage instead."
            case .none: "Ammo hit. Without CASE or ENE, this ’Mech is wrecked."
            }
        case .engine: "Engine hit. It takes 1 heat whenever it fires, and a second engine hit wrecks it."
        case .fireControl: "Fire control hit. Its shots get harder."
        case .none: "No critical."
        case .weapon: "Weapon hit. Its damage goes down by 1. If it already does no damage, it takes 1 damage instead."
        case .mp: "MP hit. Move and TMM are halved. Each further MP hit halves them again. At 0″ it can’t move."
        case .destroyed: "Destroyed. It is wrecked, and it can still shoot this turn."
        }
    }

    private func icon(for id: CritResultId) -> String {
        switch id {
        case .none: "checkmark.circle.fill"
        case .ammo: unit.hasAmmoImmunity ? "checkmark.shield.fill" : "flame.fill"
        case .engine: "engine.combustion.fill"
        case .fireControl: "scope"
        case .weapon: "target"
        case .mp: "figure.walk"
        case .destroyed: "flame.fill"
        }
    }

    private func tone(for id: CritResultId) -> Color {
        switch id {
        case .none: TMColor.success
        case .destroyed: TMColor.danger
        case .ammo: unit.hasAmmoImmunity ? TMColor.warning : TMColor.danger
        case .engine, .fireControl, .weapon, .mp: TMColor.warning
        }
    }
}

#if DEBUG
#Preview("Critical sheet") {
    CritSheet(
        unit: {
            var unit = PreviewFixtures.locust
            unit.criticalsOwed = 1
            return unit
        }(),
        store: BattlePreview.store()
    )
}
#endif
