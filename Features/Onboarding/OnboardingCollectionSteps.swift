import SwiftUI
import MechBuddyData

// "Which boxes do you own?" and "Your ’Mechs". Spec: specs/features/OnboardingSpec.md

// MARK: - Boxes

struct OnboardingBoxesStep: View {
    /// `as-box-sets.json`, in catalog order.
    var boxes: [BoxSetDTO]
    @Binding var collection: OwnedCollection
    @Binding var noneYet: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.hapticsEnabled) private var hapticsEnabled

    private var columns: [GridItem] {
        let twoUp = !dynamicTypeSize.isAccessibilitySize
            && (horizontalSizeClass == .regular || verticalSizeClass == .compact)
        let column = GridItem(.flexible(), spacing: TMSpace.md, alignment: .top)
        return twoUp ? [column, column] : [column]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            OnboardingHeader(
                heroSymbol: "square.stack.3d.up.fill",
                title: "Which boxes do you own?",
                subtitle: "Pick every box on your shelf. Each mission will then say which minis you have."
            )
            if boxes.isEmpty {
                Text("The box list didn’t load. Pick None yet, or add your ’Mechs on the next screen.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: TMSpace.md) {
                ForEach(boxes) { box in
                    ChoiceTile(
                        title: box.title,
                        detail: box.subtitle,
                        systemImage: "shippingbox",
                        badge: box.game.badge,
                        isSelected: collection.owns(box: box.id),
                        accessibilityIdentifier: "onboarding.box.\(box.id)",
                        accessibilityHint: box.contentsConfirmed
                            ? nil
                            : "Its list isn’t confirmed yet. You can add its ’Mechs by hand",
                        action: { toggle(box) }
                    ) {
                        Label("\(box.miniCount) minis", systemImage: "figure.stand")
                            .font(TMFont.detail)
                            .foregroundStyle(.secondary)
                    }
                }
                ChoiceTile(
                    title: "None yet",
                    detail: "Coins or any minis work for your first game.",
                    systemImage: "circle.dashed",
                    isSelected: noneYet,
                    accessibilityIdentifier: "onboarding.box.none",
                    action: pickNone
                )
            }
        }
        .sensoryFeedback(trigger: collection.boxes) { _, _ in hapticsEnabled ? .selection : nil }
        .sensoryFeedback(trigger: noneYet) { _, _ in hapticsEnabled ? .selection : nil }
        .accessibilityIdentifier("onboarding.step.boxes")
    }

    private func toggle(_ box: BoxSetDTO) {
        collection.toggleBox(box.id)
        if !collection.boxes.isEmpty {
            noneYet = false
        }
    }

    private func pickNone() {
        noneYet.toggle()
        if noneYet {
            for id in collection.boxes.keys {
                collection.setCopies(0, ofBox: id)
            }
        }
    }
}

// MARK: - Your ’Mechs

struct OnboardingMechsStep: View {
    var boxes: [BoxSetDTO]
    @Binding var collection: OwnedCollection

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var owned: [BoxSetDTO] { boxes.filter { collection.owns(box: $0.id) } }

    private var singles: [CollectionUnit] {
        CollectionMath.groups(OwnedCollection(singles: collection.singles), boxes: []).first?.units ?? []
    }

    private var columns: [GridItem] {
        let twoUp = !dynamicTypeSize.isAccessibilitySize
            && (horizontalSizeClass == .regular || verticalSizeClass == .compact)
        let column = GridItem(.flexible(), spacing: TMSpace.md, alignment: .top)
        return twoUp ? [column, column] : [column]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xl) {
            OnboardingHeader(
                title: "Your ’Mechs",
                subtitle: owned.isEmpty
                    ? "Add any ’Mechs you already have. None is fine too."
                    : "Untick any that are missing. Add ’Mechs you have outside a box."
            )
            ForEach(owned) { box in
                boxSection(box)
            }
            VStack(alignment: .leading, spacing: TMSpace.sm) {
                Eyebrow("Add a ’Mech")
                Text("Just the name. “Atlas” covers any Atlas.")
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                CollectionAddField(idPrefix: "onboarding.mechs") { collection.addSingle($0) }
                ForEach(singles) { unit in
                    CollectionSingleRow(
                        unit: unit,
                        idPrefix: "onboarding.mechs",
                        onRemove: { collection.setSingle(unit.name, copies: 0) }
                    )
                }
            }
        }
        .accessibilityIdentifier("onboarding.step.mechs")
    }

    @ViewBuilder
    private func boxSection(_ box: BoxSetDTO) -> some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow(box.title)
            if box.contentsConfirmed {
                LazyVGrid(columns: columns, alignment: .leading, spacing: TMSpace.xs) {
                    ForEach(uniqueUnits(box), id: \.self) { unit in
                        CollectionCheckRow(
                            title: unit,
                            isOn: collection.have(unit, in: box) > 0,
                            accessibilityIdentifier: "onboarding.mechs.unit.\(box.id).\(unit)",
                            action: {
                                collection.setUnit(unit, in: box, owned: collection.have(unit, in: box) == 0)
                            }
                        )
                    }
                }
            } else {
                CollectionUnconfirmedNote(identifier: "onboarding.mechs.unconfirmed.\(box.id)")
            }
        }
    }

    private func uniqueUnits(_ box: BoxSetDTO) -> [String] {
        var seen = Set<String>()
        return box.units.filter { seen.insert($0).inserted }
    }
}

#if DEBUG
#Preview("Boxes step") {
    @Previewable @State var owned = OwnedCollection(boxes: ["agoac": 1])
    @Previewable @State var none = false
    PlayPreviewHost {
        ScrollView {
            OnboardingBoxesStep(
                boxes: (try? BundleContentCatalogRepository().boxSets().boxes) ?? [],
                collection: $owned,
                noneYet: $none
            )
            .padding(TMSpace.lg)
        }
    }
}

#Preview("Mechs step") {
    @Previewable @State var owned = OwnedCollection(boxes: ["agoac": 1, "mercenaries-box": 1], singles: ["Atlas": 1])
    PlayPreviewHost {
        ScrollView {
            OnboardingMechsStep(
                boxes: (try? BundleContentCatalogRepository().boxSets().boxes) ?? [],
                collection: $owned
            )
            .padding(TMSpace.lg)
        }
    }
}
#endif
