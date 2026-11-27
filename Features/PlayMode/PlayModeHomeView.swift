import SwiftUI
import MechBuddyData
import MechBuddyDomain

/// Play mode home, `as.play.home` (PlayModeSpec § 4). Shown as the Play tab when `playMode` is on.
struct PlayModeHomeView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(PlayMatchCoordinator.self) private var matches
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var editingCollection = false
    @State private var route: PlaySetupRoute?
    @State private var confirmDiscardDraft = false
    @State private var managingSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMSpace.xl) {
                if let notice = matches.unreadableNotice {
                    ErrorBanner(message: notice)
                }
                if let resume = matches.resumeSession {
                    resumeCard(resume)
                }
                if let draft = dependencies.preferences.playDraft, canOpen(draft) {
                    draftCard(draft)
                }
                newGameBlock
                if let last = dependencies.preferences.playLastSetup, canOpen(last) {
                    lastSetupRow(last)
                }
                savedForcesRow
                if dependencies.preferences.collection == nil {
                    collectionNote
                }
            }
            .padding(TMSpace.lg)
            .frame(maxWidth: horizontalSizeClass == .regular ? 720 : 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Play")
        .accessibilityIdentifier("as.play.home")
        .navigationDestination(item: $route) { route in
            PlaySetupFlowView(route: route)
        }
        .onChange(of: matches.matchStore == nil) { _, closed in
            // Play game started: leave setup so Play home shows Resume when the cover closes.
            if !closed { route = nil }
        }
        .onChange(of: matches.editSetup) { _, setup in
            guard let setup else { return }
            matches.editSetup = nil
            route = PlaySetupRoute(setup: setup, step: .review)
        }
        .confirmationDialog("Discard this setup?", isPresented: $confirmDiscardDraft, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dependencies.preferences.playDraft = nil }
            Button("Keep", role: .cancel) {}
        }
        .sheet(isPresented: $managingSaved) {
            PlaySavedForcesSheet()
        }
        .sheet(isPresented: $editingCollection) {
            CollectionEditSheet(
                boxes: dependencies.boxSets,
                initial: dependencies.preferences.collection,
                onSave: { owned in
                    dependencies.preferences.recordCollection(owned)
                }
            )
        }
    }

    // MARK: Resume

    private func resumeCard(_ session: MatchSession) -> some View {
        let title = PlayModeText.title(for: session, missionTitle: missionTitle(session))
        let detail = PlayModeText.progress(for: session)
        return TMCard(edgeColor: TMColor.signal, isRaised: true) {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                Eyebrow("In progress")
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text(title)
                        .font(TMFont.cardTitle)
                    Text(detail)
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .fixedSize(horizontal: false, vertical: true)
                if session.isPlayGame {
                    sideLine(session)
                }
                Button {
                    matches.resume(using: dependencies)
                } label: {
                    Text("Continue")
                        .foregroundStyle(TMColor.onSignal)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(TMColor.signal)
                .controlSize(.large)
                .accessibilityIdentifier("as.play.resume")
                .accessibilityLabel("Continue \(title), \(detail)")
            }
        }
        .playZoomSource("resume")
    }

    private func sideLine(_ session: MatchSession) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: TMSpace.xs))
            : AnyLayout(HStackLayout(spacing: TMSpace.md))
        return layout {
            ForEach(session.sides) { side in
                HStack(spacing: TMSpace.xs) {
                    SideBadge(side: side.id)
                    Text(side.name)
                        .font(TMFont.detail.weight(.semibold))
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func missionTitle(_ session: MatchSession) -> String {
        let id = (session.scenarioId ?? .ridgeLine).rawValue
        let item = (try? dependencies.content.scenarios().scenarios)?.first { $0.id == id }
        return item?.title ?? "Ridge Line"
    }

    /// A saved setup with three or four sides opens only while `playModeMultiSide` is on (a downgrade keeps
    /// the save but can't start new free-for-all games, § 16).
    private func canOpen(_ setup: PlaySetup) -> Bool {
        setup.sides.count <= 2 || dependencies.releaseSurface.isEnabled(.playModeMultiSide)
    }

    // MARK: New game

    @ViewBuilder
    private var newGameBlock: some View {
        if matches.resumeSession == nil && dependencies.preferences.playDraft == nil {
            hero
        } else {
            SecondaryActionButton(
                title: "New game",
                systemImage: "plus",
                accessibilityIdentifier: "as.play.new",
                action: startNewGame
            )
        }
    }

    /// First visit (§ 4): what Play is, and New game.
    private var hero: some View {
        TMCard {
            VStack(spacing: TMSpace.lg) {
                Image(systemName: "flag.checkered.2.crossed")
                    .font(.system(size: 48))
                    .foregroundStyle(TMColor.signal)
                    .accessibilityHidden(true)
                VStack(spacing: TMSpace.xs) {
                    Text("Play a full game of Alpha Strike")
                        .font(TMFont.stepTitle)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick the players, the ’Mechs and the map. The app keeps score.")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .fixedSize(horizontal: false, vertical: true)
                PrimaryActionButton(
                    title: "New game",
                    systemImage: "plus",
                    tint: TMColor.signal,
                    accessibilityIdentifier: "as.play.new",
                    action: startNewGame
                )
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("as.play.empty")
    }

    private func startNewGame() {
        let owned = !(dependencies.preferences.collection?.isEmpty ?? true)
        let setup = PlaySetup.pickup(
            pool: owned ? .owned : .anyCard,
            diceMode: dependencies.preferences.defaultDiceMode
        )
        dependencies.preferences.playDraft = nil
        route = PlaySetupRoute(setup: setup, step: .sides)
    }

    // MARK: Draft and last setup (§ 11)

    private func draftCard(_ draft: PlaySetup) -> some View {
        TMCard {
            VStack(alignment: .leading, spacing: TMSpace.md) {
                Eyebrow("Setting up")
                Text("\(draft.formatName) · \(draft.budget.summary) · \(PlayModeText.mechs(draft.unitCount)) picked")
                    .font(TMFont.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: TMSpace.md) { draftButtons(draft) }
                    VStack(alignment: .leading, spacing: TMSpace.sm) { draftButtons(draft) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("as.play.draft")
    }

    @ViewBuilder
    private func draftButtons(_ draft: PlaySetup) -> some View {
        Button {
            let ready = draft.sides.allSatisfy { !draft.force($0.id).isEmpty }
            route = PlaySetupRoute(setup: draft, step: ready ? .review : .sides)
        } label: {
            Text("Finish setting up").frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(TMColor.signal)
        .foregroundStyle(TMColor.onSignal)
        .accessibilityIdentifier("as.play.draft.continue")
        Button("Discard", role: .destructive) { confirmDiscardDraft = true }
            .frame(minHeight: 44)
            .accessibilityIdentifier("as.play.draft.discard")
    }

    private func lastSetupRow(_ last: PlaySetup) -> some View {
        Button {
            var fresh = last
            fresh.diceMode = last.diceMode
            route = PlaySetupRoute(setup: fresh, step: .review)
        } label: {
            HStack(spacing: TMSpace.md) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(TMColor.signal)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text("Last setup").font(TMFont.cardTitle)
                    Text("\(last.formatName) · \(last.budget.summary) · \(last.battlefield.summary)")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: TMSpace.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("as.play.lastSetup")
    }

    // MARK: Saved forces (PM9)

    private var savedForcesRow: some View {
        let count = dependencies.userContent.savedForces().count
        let cards = dependencies.cardLibrary.userFaces.count
        return Button {
            managingSaved = true
        } label: {
            HStack(spacing: TMSpace.md) {
                Image(systemName: "tray.full")
                    .foregroundStyle(TMColor.signal)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: TMSpace.xxs) {
                    Text("Saved forces").font(TMFont.cardTitle)
                    Text("\(count) saved · \(cards) hand-entered \(cards == 1 ? "card" : "cards")")
                        .font(TMFont.detail)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: TMSpace.sm)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("as.play.savedForces")
    }

    // MARK: Collection

    private var collectionNote: some View {
        VStack(alignment: .leading, spacing: TMSpace.sm) {
            Text("Tell us which boxes you own to build forces from your minis.")
                .font(TMFont.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Add your boxes") { editingCollection = true }
                .font(TMFont.detail.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("as.play.addBoxes")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("as.play.collectionNote")
    }
}

/// Words for a game in progress, shared by the Learn and Play homes (PlayModeSpec § 3, Resume row).
enum PlayModeText {
    /// "Play · 1 v 1" for a Play game, else the mission's title.
    static func title(for session: MatchSession, missionTitle: String) -> String {
        guard let play = session.play else { return missionTitle }
        return "Play · \(play.formatName)"
    }

    /// "1 ’Mech", "3 ’Mechs".
    static func mechs(_ count: Int) -> String {
        count == 1 ? "1 ’Mech" : "\(count) ’Mechs"
    }

    /// "Turn 2 · Movement", with the turn limit when there is one.
    static func progress(for session: MatchSession) -> String {
        let turns = session.ruleset.maxTurns.map { "Turn \(session.turn) of \($0)" } ?? "Turn \(session.turn)"
        return "\(turns)\u{00A0}· \(session.phase.displayName)"
    }
}
