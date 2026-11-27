import SwiftUI
import MechBuddyDomain

// One drawing for a table: mission maps, the setup preview, the battle board sheet and the builder's canvas
// (PlayModeSpec § 9.6, § 9.8). Terrain is filled with its own colour and a pattern or glyph, so kinds are told
// apart without colour; zones are tinted in their side's colour and carry the side letter.

enum BoardDrawing {
    /// Terrain colours (§ 9.6): woods green, hill brown, water blue-grey, rough and rubble grey, buildings slate.
    /// Never side colours.
    static let woods = Color(red: 0.25, green: 0.55, blue: 0.3)
    static let hill = Color(red: 0.6, green: 0.47, blue: 0.3)
    static let water = Color(red: 0.36, green: 0.5, blue: 0.6)
    static let rough = Color(red: 0.52, green: 0.52, blue: 0.5)
    static let rubble = Color(red: 0.4, green: 0.4, blue: 0.42)
    static let slate = Color(red: 0.33, green: 0.38, blue: 0.46)

    static func color(for kind: BoardLayout.FeatureKind) -> Color {
        switch kind {
        case .woods, .tree: woods
        case .hill: hill
        case .water: water
        case .rough: rough
        case .rubble: rubble
        case .building, .wall: slate
        case .objectiveToken: Color.primary
        }
    }

    /// Zones name their side by letter ("A" to "D").
    static func color(forZone letter: String) -> Color {
        switch letter {
        case "B": TMColor.sideB
        case "C": TMColor.sideC
        case "D": TMColor.sideD
        default: TMColor.sideA
        }
    }

    /// Where the table sits in the canvas: inches times `scale`, from `origin`.
    struct Frame {
        var scale: CGFloat
        var origin: CGPoint = .zero

        func rect(_ r: BoardLayout.Rect) -> CGRect {
            CGRect(x: origin.x + r.x * scale, y: origin.y + r.y * scale, width: r.width * scale, height: r.depth * scale)
        }

        func point(_ p: BoardLayout.Point) -> CGPoint {
            CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
        }
    }

    /// Sheets, zones, terrain and sheet names, in that order. `zones` is the set for the game's sides.
    static func drawTable(
        _ board: BoardLayout,
        zones: [BoardLayout.Zone],
        in context: inout GraphicsContext,
        frame: Frame,
        highContrast: Bool = false,
        warned: Set<UUID> = [],
        selected: Set<UUID> = []
    ) {
        let line = Color.primary.opacity(highContrast ? 0.7 : 0.35)

        for sheet in board.sheets {
            let box = frame.rect(sheet.area).insetBy(dx: 1, dy: 1)
            context.fill(Path(roundedRect: box, cornerRadius: 4), with: .color(Color.primary.opacity(0.04)))
            context.stroke(Path(roundedRect: box, cornerRadius: 4), with: .color(line),
                           style: StrokeStyle(lineWidth: highContrast ? 2 : 1, dash: [4, 3]))
        }

        for zone in zones {
            let color = color(forZone: zone.side)
            let box = frame.rect(zone.area)
            context.fill(Path(box), with: .color(color.opacity(0.3)))
            context.stroke(Path(box), with: .color(color.opacity(0.8)), lineWidth: highContrast ? 2 : 1)
            context.draw(
                Text(zone.side).font(.headline.weight(.bold)).foregroundStyle(color),
                at: CGPoint(x: box.midX, y: box.midY)
            )
        }

        for (index, feature) in board.features.enumerated() {
            drawFeature(
                feature,
                level: BoardRules.hillLevel(at: index, in: board.features),
                in: &context,
                frame: frame,
                highContrast: highContrast,
                warned: feature.id.map(warned.contains) ?? false,
                selected: feature.id.map(selected.contains) ?? false
            )
        }

        for sheet in board.sheets {
            let box = frame.rect(sheet.area)
            drawLabel(
                Text(BoardRules.sheetCaption(sheet)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary),
                at: CGPoint(x: box.midX, y: box.minY + 10),
                in: &context
            )
        }
    }

    static func drawFeature(
        _ feature: BoardLayout.Feature,
        level: Double?,
        in context: inout GraphicsContext,
        frame: Frame,
        highContrast: Bool,
        warned: Bool = false,
        selected: Bool = false
    ) {
        let box = frame.rect(feature.area)
        let tint = color(for: feature.kind)
        let strokeWidth: CGFloat = highContrast ? 2 : 1

        // Everything but labels is drawn in the piece's own turned frame.
        var local = context
        local.translateBy(x: box.midX, y: box.midY)
        local.rotate(by: .degrees(feature.degrees))
        let r = CGRect(x: -box.width / 2, y: -box.height / 2, width: box.width, height: box.height)

        func outline(_ path: Path) {
            if selected {
                local.stroke(path, with: .color(TMColor.signal), lineWidth: 3)
            } else if warned {
                local.stroke(path, with: .color(TMColor.warning), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
        }

        switch feature.kind {
        case .hill:
            let path = shapePath(feature, in: r)
            local.fill(path, with: .color(tint.opacity(0.35)))
            local.stroke(path, with: .color(tint.opacity(0.7)), lineWidth: strokeWidth)
            // Contour lines: one ring per inch of level (up to 4).
            let rings = max(1, min(4, Int((level ?? feature.level ?? 1).rounded())))
            for ring in 1...rings {
                let inset = CGFloat(ring) / CGFloat(rings + 1) * 0.5
                let inner = r.insetBy(dx: r.width * inset, dy: r.height * inset)
                local.stroke(shapePath(feature, in: inner), with: .color(tint.opacity(0.6)), lineWidth: 1)
            }
            outline(path)
            let levelText = level.map { " \(BoardRules.plain($0))″" } ?? ""
            drawLabel(Text("Hill\(levelText)").font(.caption2).foregroundStyle(tint), at: CGPoint(x: box.midX, y: box.midY), in: &context)
        case .woods:
            let path = feature.shape == nil
                ? Path(roundedRect: r, cornerRadius: min(r.width, r.height) / 2)
                : shapePath(feature, in: r)
            local.fill(path, with: .color(tint.opacity(0.4)))
            local.stroke(path, with: .color(tint.opacity(0.7)), lineWidth: strokeWidth)
            outline(path)
            context.draw(Text(Image(systemName: "tree.fill")).font(.caption).foregroundStyle(tint), at: CGPoint(x: box.midX, y: box.midY))
        case .tree:
            let size = max(10, min(box.width, box.height))
            let dot = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
            local.fill(Path(ellipseIn: dot), with: .color(tint.opacity(0.8)))
            outline(Path(ellipseIn: dot.insetBy(dx: -2, dy: -2)))
        case .wall:
            var path = Path()
            if r.width >= r.height {
                path.move(to: CGPoint(x: r.minX, y: 0))
                path.addLine(to: CGPoint(x: r.maxX, y: 0))
            } else {
                path.move(to: CGPoint(x: 0, y: r.minY))
                path.addLine(to: CGPoint(x: 0, y: r.maxY))
            }
            local.stroke(path, with: .color(Color.primary.opacity(0.55)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            outline(Path(roundedRect: r.insetBy(dx: -4, dy: -4), cornerRadius: 3))
        case .building:
            let path = Path(roundedRect: r, cornerRadius: 2)
            local.fill(path, with: .color(tint.opacity(0.5)))
            local.stroke(path, with: .color(Color.primary.opacity(0.6)), lineWidth: strokeWidth)
            // Roof outline.
            if r.width > 10, r.height > 10 {
                local.stroke(Path(roundedRect: r.insetBy(dx: r.width * 0.2, dy: r.height * 0.2), cornerRadius: 1),
                             with: .color(Color.primary.opacity(0.35)), lineWidth: 1)
            }
            outline(path)
        case .water:
            let path = shapePath(feature, in: r)
            local.fill(path, with: .color(tint.opacity(0.4)))
            local.stroke(path, with: .color(tint.opacity(0.8)), lineWidth: strokeWidth)
            var waves = local
            waves.clip(to: path)
            for step in 1...3 {
                let y = r.minY + r.height * CGFloat(step) / 4
                var wave = Path()
                wave.move(to: CGPoint(x: r.minX, y: y))
                var x = r.minX
                while x < r.maxX {
                    wave.addQuadCurve(to: CGPoint(x: x + 8, y: y), control: CGPoint(x: x + 4, y: y - 3))
                    x += 8
                }
                waves.stroke(wave, with: .color(tint.opacity(0.9)), lineWidth: 1)
            }
            outline(path)
        case .rough, .rubble:
            let path = shapePath(feature, in: r)
            local.fill(path, with: .color(tint.opacity(0.35)))
            local.stroke(path, with: .color(tint.opacity(0.8)), lineWidth: strokeWidth)
            var dots = local
            dots.clip(to: path)
            let gap: CGFloat = feature.kind == .rough ? 7 : 9
            var y = r.minY + gap / 2
            while y < r.maxY {
                var x = r.minX + gap / 2
                while x < r.maxX {
                    let dot = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                    if feature.kind == .rough {
                        dots.fill(Path(ellipseIn: dot), with: .color(tint.opacity(0.9)))
                    } else {
                        dots.fill(Path(dot.insetBy(dx: -1, dy: -1)), with: .color(tint.opacity(0.9)))
                    }
                    x += gap
                }
                y += gap
            }
            outline(path)
        case .objectiveToken:
            let size = max(14, min(box.width, box.height))
            let side = feature.side ?? "A"
            let sideColor = color(forZone: side)
            var diamond = Path()
            diamond.move(to: CGPoint(x: 0, y: -size / 2))
            diamond.addLine(to: CGPoint(x: size / 2, y: 0))
            diamond.addLine(to: CGPoint(x: 0, y: size / 2))
            diamond.addLine(to: CGPoint(x: -size / 2, y: 0))
            diamond.closeSubpath()
            local.fill(diamond, with: .color(sideColor.opacity(0.8)))
            local.stroke(diamond, with: .color(Color.primary.opacity(0.6)), lineWidth: 1)
            outline(diamond)
            // The token's number, so Raid 1 and Raid 2 are told apart without colour.
            context.draw(
                Text(BoardTokens.badge(feature)).font(.system(size: max(8, size * 0.42), weight: .bold)).foregroundStyle(Color(.systemBackground)),
                at: CGPoint(x: box.midX, y: box.midY)
            )
        }
    }

    private static func shapePath(_ feature: BoardLayout.Feature, in rect: CGRect) -> Path {
        switch feature.drawnShape {
        case .ellipse: Path(ellipseIn: rect)
        case .rect: Path(roundedRect: rect, cornerRadius: 2)
        }
    }

    /// Draws a label on a small pill so a mapsheet seam or terrain edge never runs through the letters.
    static func drawLabel(_ text: Text, at point: CGPoint, in context: inout GraphicsContext) {
        let resolved = context.resolve(text)
        let size = resolved.measure(in: CGSize(width: 200, height: 50))
        let pill = CGRect(
            x: point.x - size.width / 2 - 4,
            y: point.y - size.height / 2 - 1,
            width: size.width + 8,
            height: size.height + 2
        )
        context.fill(Path(roundedRect: pill, cornerRadius: pill.height / 2), with: .color(Color(.systemBackground).opacity(0.85)))
        context.draw(resolved, at: point)
    }
}
