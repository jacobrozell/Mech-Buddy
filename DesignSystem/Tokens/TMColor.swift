import SwiftUI

/// Asset-catalog colors. Call sites use this namespace instead of raw hues.
enum TMColor {
    static let signal = Color("brand.signal")
    static let coolant = Color("brand.coolant")
    static let damage = Color("brand.damage")
    static let structure = Color("brand.structure")

    static let sideA = Color("side.a")
    static let sideAFill = Color("side.a.fill")
    static let sideB = Color("side.b")
    static let sideBFill = Color("side.b.fill")
    /// Cobalt and orchid (PlayModeSpec § 14, D18). Contrast checked in PM7: text on fill 6.1 / 5.5 (light) and
    /// 6.9 / 7.0 (dark); fill on background the same, all above 4.5.
    static let sideC = Color("side.c")
    static let sideCFill = Color("side.c.fill")
    static let sideD = Color("side.d")
    static let sideDFill = Color("side.d.fill")

    static let pipArmor = Color("pip.armor")
    static let pipStructure = Color("pip.structure")
    static let pipEmpty = Color("pip.empty")
    static let pipLost = Color("pip.lost")

    static let success = Color("state.success")
    static let warning = Color("state.warning")
    static let danger = Color("state.danger")
    static let info = Color("state.info")

    static let surfaceCard = Color("surface.card")
    static let surfaceCardRaised = Color("surface.cardRaised")
    static let readout = Color("surface.readout")

    static let onSignal = Color("text.onSignal")
    static let onSide = Color("text.onSide")
}

extension ShapeStyle where Self == Color {
    static var tmSignal: Color { TMColor.signal }
    static var tmOnSignal: Color { TMColor.onSignal }
    static var tmCoolant: Color { TMColor.coolant }
    static var tmDamage: Color { TMColor.damage }
    static var tmReadout: Color { TMColor.readout }
}

#if DEBUG
#Preview("Tokens") {
    PreviewPair {
        TokenSwatchGrid()
    }
}

private struct TokenSwatchGrid: View {
    private let swatches: [(String, Color)] = [
        ("Signal", TMColor.signal),
        ("Coolant", TMColor.coolant),
        ("Damage", TMColor.damage),
        ("Structure", TMColor.structure),
        ("Side A", TMColor.sideA),
        ("Side B", TMColor.sideB),
        ("Side C", TMColor.sideC),
        ("Side D", TMColor.sideD),
        ("Success", TMColor.success),
        ("Readout", TMColor.readout)
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: TMSpace.sm)], spacing: TMSpace.sm) {
            ForEach(swatches, id: \.0) { name, color in
                VStack(spacing: TMSpace.xxs) {
                    RoundedRectangle(cornerRadius: TMRadius.chip, style: .continuous)
                        .fill(color)
                        .frame(height: 36)
                    Text(name)
                        .font(TMFont.detail)
                }
            }
        }
    }
}
#endif
