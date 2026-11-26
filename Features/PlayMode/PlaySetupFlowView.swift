import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// The six setup screens (PlayModeSpec § 5), one pushed screen with a step strip.
/// Back keeps everything; the draft autosaves on every change.
enum PlaySetupStep: Int, CaseIterable, Identifiable, Hashable {
    case sides, size, forces, map, rules, review

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .sides: "Players and sides"
        case .size: "Game size"
        case .forces: "Forces"
        case .map: "Battlefield"
        case .rules: "Rules and options"
        case .review: "Review"
        }
    }

    var identifier: String {
        switch self {
        case .sides: "as.play.setup.sides"
        case .size: "as.play.setup.size"
        case .forces: "as.play.setup.forces"
        case .map: "as.play.setup.map"
        case .rules: "as.play.setup.rules"
        case .review: "as.play.setup.review"
        }
    }
}

/// What Play home pushes: a setup and the step to open on.
struct PlaySetupRoute: Identifiable, Hashable {
    let id = UUID()
    var setup: PlaySetup
    var step: PlaySetupStep

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct PlaySetupFlowView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(PlayMatchCoordinator.self) private var matches
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var setup: PlaySetup
    @State private var step: PlaySetupStep
    @State private var forcesSide: SideId = .lanceA
    @State private var pickerSide: SideId?
    @State private var confirmCancel = false
    @State private var overBudgetSide: SideId?
    private let original: PlaySetup

    init(route: PlaySetupRoute) {
        _setup = State(initialValue: route.setup)
        _step = State(initialValue: route.step)
        original = route.setup
    }

    var body: some View {
        VStack(spacing: 0) {
            PlaySetupStepStrip(step: step, onSelect: { step = $0 })
            ScrollView {
                content
                    .padding(TMSpace.lg)
                    .frame(maxWidth: horizontalSizeClass == .regular ? 760 : 640)
                    .frame(maxWidth: .infinity)
            }
            .id(step)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if step == .sides {
                    Button("Cancel", action: cancel)
                        .accessibilityIdentifier("as.play.setup.cancel")
                } else {
                    Button {
                        goBack()
                    } label: {
                        Label("Back", systemImage: "chevron.backward")
                    }
                    .accessibilityIdentifier("as.play.setup.back")
                }
            }
            if step != .sides {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel", action: cancel)
                        .accessibilityIdentifier("as.play.setup.cancel")
                }
            }
        }
        .onChange(of: setup) { _, next in
            dependencies.preferences.playDraft = next
        }
        .confirmationDialog("Stop setting up?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Discard this setup", role: .destructive) {
                dependencies.preferences.playDraft = nil
                dismiss()
            }
            Button("Keep it for later") { dismiss() }
            Button("Keep setting up", role: .cancel) {}
        } message: {
            Text("Your choices are saved as a draft unless you discard them.")
        }
        .alert(
            overBudgetTitle,
            isPresented: Binding(get: { overBudgetSide != nil }, set: { if !$0 { overBudgetSide = nil } })
        ) {
            Button("Play anyway") {
                overBudgetSide = nil
                step = .map
            }
            Button("Change forces", role: .cancel) { overBudgetSide = nil }
        } message: {
            Text("Players can agree their own limits (p. 33).")
        }
        .sheet(item: $pickerSide) { side in
            PlayUnitPickerSheet(setup: $setup, side: side)
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        Group {
            switch step {
            case .sides: PlaySidesStep(setup: $setup)
            case .size: PlaySizeStep(setup: $setup, hasCollection: hasCollection)
            case .forces: PlayForcesStep(setup: $setup, side: $forcesSide, onAdd: { pickerSide = $0 })
            case .map: PlayMapStep(setup: $setup)
            case .rules: PlayRulesStep(setup: $setup)
            case .review: PlayReviewStep(setup: setup, onEdit: { step = $0 })
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(step.identifier)
    }

    private var footer: some View {
        VStack(spacing: TMSpace.xs) {
            if step == .review {
                if let reason = startBlockedReason {
                    Text(reason)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                PrimaryActionButton(
                    title: "Start game",
                    systemImage: "flag.checkered",
                    placement: .dock,
                    tint: TMColor.signal,
                    isDisabled: startBlockedReason != nil,
                    accessibilityIdentifier: "as.play.setup.start",
                    action: start
                )
            } else {
                PrimaryActionButton(
                    title: "Continue",
                    placement: .dock,
                    tint: TMColor.signal,
                    isDisabled: step == .forces && setup.sides.contains { setup.force($0.id).isEmpty },
                    accessibilityIdentifier: "as.play.setup.continue",
                    action: advance
                )
            }
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, TMSpace.sm)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var hasCollection: Bool {
        !(dependencies.preferences.collection?.isEmpty ?? true)
    }

    private var startBlockedReason: String? {
        if let empty = setup.sides.first(where: { setup.force($0.id).isEmpty }) {
            return "\(empty.name) needs at least one ’Mech."
        }
        if setup.unitCount > PlaySetup.maxUnitsPerGame {
            return "Up to \(PlaySetup.maxUnitsPerGame) ’Mechs in one game."
        }
        return nil
    }

    private var overBudgetTitle: String {
        guard let side = overBudgetSide else { return "" }
        let check = setup.budgetCheck(side)
        let name = setup.sides.first { $0.id == side }?.name ?? side.displayName
        return "\(name) is \(check.text). Play anyway?"
    }

    private func advance() {
        if step == .forces, let over = setup.sides.first(where: { setup.budgetCheck($0.id).isOver }) {
            overBudgetSide = over.id
            return
        }
        if let next = PlaySetupStep(rawValue: step.rawValue + 1) {
            step = next
        }
    }

    private func goBack() {
        if let previous = PlaySetupStep(rawValue: step.rawValue - 1) {
            step = previous
        } else {
            dismiss()
        }
    }

    private func cancel() {
        if setup == original && dependencies.preferences.playDraft == nil {
            dismiss()
        } else {
            confirmCancel = true
        }
    }

    private func start() {
        var ready = setup
        for index in ready.sides.indices {
            let trimmed = ready.sides[index].name.trimmingCharacters(in: .whitespaces)
            ready.sides[index].name = trimmed.isEmpty ? ready.sides[index].id.displayName : trimmed
        }
        matches.requestPlay(ready, using: dependencies)
    }
}

extension SideId: @retroactive Identifiable {
    public var id: String { rawValue }
}

// MARK: - Step strip

/// "2 of 6 · Game size", with a dot per step. Earlier steps can be tapped.
struct PlaySetupStepStrip: View {
    var step: PlaySetupStep
    var onSelect: (PlaySetupStep) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.xs) {
            Text("\(step.rawValue + 1) of \(PlaySetupStep.allCases.count) · \(step.title)")
                .font(TMFont.eyebrow)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(spacing: TMSpace.xs) {
                ForEach(PlaySetupStep.allCases) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Capsule()
                            .fill(item.rawValue <= step.rawValue ? TMColor.signal : TMColor.readout)
                            .frame(height: 6)
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(item.rawValue >= step.rawValue)
                    .accessibilityLabel("Step \(item.rawValue + 1), \(item.title)")
                }
            }
        }
        .padding(.horizontal, TMSpace.lg)
        .padding(.vertical, TMSpace.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("as.play.setup.steps")
    }
}

// MARK: - Shared bits

struct PlaySetupSection<Content: View>: View {
    var title: String
    var footnote: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Eyebrow(title)
            TMCard {
                VStack(alignment: .leading, spacing: TMSpace.md) {
                    content()
                }
            }
            if let footnote {
                Text(footnote)
                    .font(TMFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A label left, value right; stacks at accessibility sizes.
struct PlaySetupRow<Trailing: View>: View {
    var title: String
    var detail: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMSpace.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: TMSpace.md))
        layout {
            VStack(alignment: .leading, spacing: TMSpace.xxs) {
                Text(title).font(TMFont.body)
                if let detail {
                    Text(detail)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
    }
}
