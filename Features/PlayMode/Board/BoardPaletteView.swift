import SwiftUI
import MechBuddyDomain

/// The terrain palette (§ 9.3, § 9.5): a strip on iPhone portrait, a column in landscape and on iPad.
/// Touch and hold, then drag a piece onto the table; or tap it to drop it at the centre.
struct BoardPaletteView: View {
    var items: [TerrainPaletteItem]
    var axis: Axis
    var onTap: (TerrainPaletteItem) -> Void
    /// A drag from a tile: the item and the finger, in the editor's coordinate space. `ended` is true on lift.
    var onDrag: (TerrainPaletteItem, CGPoint, Bool) -> Void

    var body: some View {
        Group {
            if axis == .horizontal {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TMSpace.sm) { tiles }
                        .padding(.horizontal, TMSpace.lg)
                        .padding(.vertical, TMSpace.xs)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: TMSpace.sm)], spacing: TMSpace.sm) { tiles }
                        .padding(TMSpace.sm)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Terrain palette")
        .accessibilityIdentifier("as.board.palette")
    }

    @ViewBuilder
    private var tiles: some View {
        ForEach(items) { item in
            tile(item)
        }
    }

    private func tile(_ item: TerrainPaletteItem) -> some View {
        VStack(spacing: TMSpace.xs) {
            Image(systemName: item.glyph)
                .font(.title3)
                .foregroundStyle(BoardDrawing.color(for: item.kind))
                .accessibilityHidden(true)
            Text(item.title)
                .font(.caption2.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 72, maxWidth: axis == .vertical ? .infinity : 96, minHeight: 56)
        .padding(.vertical, TMSpace.xs)
        .padding(.horizontal, TMSpace.xs)
        .background(TMColor.surfaceCard, in: RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous).strokeBorder(Color(.separator).opacity(0.6)))
        .contentShape(Rectangle())
        .onTapGesture { onTap(item) }
        .gesture(
            LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("boardEditor")))
                .onChanged { value in
                    if case .second(true, let drag?) = value { onDrag(item, drag.location, false) }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value { onDrag(item, drag.location, true) }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityHint("Adds it at the centre of the table. Then move it with the actions.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap(item) }
        .accessibilityIdentifier("as.board.palette.\(item.id)")
    }
}
