import SwiftUI

// Monochrome Strich-Icons, definiert in einem 20×20-Raster.
// Gerendert als Vektor über Canvas → auf Retina automatisch in 2–3-facher Auflösung scharf.

struct IconPart {
    var path: Path
    var dashed = false
    var filled = false
}

enum Icon: Hashable {
    case select, classBox, abstractClass, interface, enumeration, note
    case association, directed, inheritance, realization, aggregation, composition, dependency, anchor
    case zoomIn, zoomOut, fit, grid, magnet, layout, alignLeft, alignTop
    case newDoc, open, save, image, pdf, code
    case trash, duplicate, pin, undo, redo, plus, minus, xmark, swap, logo
}

// MARK: - Environment

private struct IconHighlightedKey: EnvironmentKey { static let defaultValue = false }
private struct IconTintKey: EnvironmentKey { static let defaultValue: Color? = nil }

extension EnvironmentValues {
    /// Hover/Aktiv → Icon in Textfarbe primär
    var iconHighlighted: Bool {
        get { self[IconHighlightedKey.self] }
        set { self[IconHighlightedKey.self] = newValue }
    }
    /// Erzwungene Icon-Farbe (z. B. dunkel auf primärem Akzent-Button)
    var iconTint: Color? {
        get { self[IconTintKey.self] }
        set { self[IconTintKey.self] = newValue }
    }
}

// MARK: - View

struct IconView: View {
    let icon: Icon
    var size: CGFloat = 20
    var color: Color? = nil
    var lineWidth: CGFloat = 1.7

    @Environment(\.iconHighlighted) private var highlighted
    @Environment(\.iconTint) private var tint

    var body: some View {
        let c = color ?? tint ?? (highlighted ? Theme.textPrimary : Theme.textSecondary)
        let parts = icon.parts
        let lw = lineWidth
        Canvas { ctx, sz in
            let s = sz.width / 20
            let t = CGAffineTransform(scaleX: s, y: s)
            for part in parts {
                let p = part.path.applying(t)
                if part.filled { ctx.fill(p, with: .color(c)) }
                ctx.stroke(p, with: .color(c),
                           style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round,
                                              dash: part.dashed ? [1.2 * s, 3.3 * s] : []))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Geometrie

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

private func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> Path {
    var p = Path(); p.move(to: pt(x1, y1)); p.addLine(to: pt(x2, y2)); return p
}

private func poly(_ pts: [CGPoint], closed: Bool = false) -> Path {
    var p = Path(); p.addLines(pts); if closed { p.closeSubpath() }; return p
}

private func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
}

private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}

private func solid(_ paths: Path...) -> [IconPart] { paths.map { IconPart(path: $0) } }

private func page() -> [Path] {
    [poly([pt(5, 3), pt(11.5, 3), pt(15, 6.5), pt(15, 17), pt(5, 17)], closed: true),
     poly([pt(11.5, 3), pt(11.5, 6.5), pt(15, 6.5)])]
}

/// Diagonale Beziehungslinie (unten links → oben rechts) mit UML-Endsymbol.
private func relationParts(_ deco: Decoration, dashed: Bool) -> [IconPart] {
    let tip = pt(16.5, 3.5), start = pt(3.5, 16.5)
    let u = pt(0.7071, -0.7071), n = pt(0.7071, 0.7071)
    func at(_ along: CGFloat, _ across: CGFloat) -> CGPoint {
        pt(tip.x - u.x * along + n.x * across, tip.y - u.y * along + n.y * across)
    }
    func shaft(to end: CGPoint) -> IconPart { IconPart(path: poly([start, end]), dashed: dashed) }

    switch deco {
    case .none:
        return [shaft(to: tip)]
    case .openArrow:
        return [shaft(to: tip), IconPart(path: poly([at(6, -3.6), tip, at(6, 3.6)]))]
    case .hollowTriangle:
        return [shaft(to: at(7, 0)), IconPart(path: poly([tip, at(7, -4), at(7, 4)], closed: true))]
    case .hollowDiamond, .filledDiamond:
        return [shaft(to: at(9, 0)),
                IconPart(path: poly([tip, at(4.5, -2.8), at(9, 0), at(4.5, 2.8)], closed: true),
                         filled: deco == .filledDiamond)]
    }
}

extension Icon {
    var parts: [IconPart] {
        switch self {
        case .select:
            return solid(poly([pt(5, 3), pt(5, 16.2), pt(8.6, 12.9), pt(11, 18), pt(13.2, 17), pt(10.8, 12), pt(15.4, 12)], closed: true))
        case .classBox:
            return solid(rrect(3, 3, 14, 14, 2.5), line(3, 7.6, 17, 7.6), line(3, 12.2, 17, 12.2))
        case .abstractClass:
            return solid(rrect(3, 3, 14, 14, 2.5), line(3, 7.6, 17, 7.6), line(7, 14.8, 9, 10.4), line(11, 14.8, 13, 10.4))
        case .interface:
            return solid(circle(10, 6.2, 3.4), line(10, 9.6, 10, 16.8), line(6, 16.8, 14, 16.8))
        case .enumeration:
            return solid(rrect(3, 3, 14, 14, 2.5), line(3, 7.6, 17, 7.6), line(6.2, 11, 13.8, 11), line(6.2, 14, 11, 14))
        case .note:
            return solid(poly([pt(4, 3), pt(12.5, 3), pt(16, 6.5), pt(16, 17), pt(4, 17)], closed: true),
                         poly([pt(12.5, 3), pt(12.5, 6.5), pt(16, 6.5)]),
                         line(7, 10.5, 13, 10.5), line(7, 13.5, 11, 13.5))

        case .association: return relationParts(.none, dashed: false)
        case .directed: return relationParts(.openArrow, dashed: false)
        case .inheritance: return relationParts(.hollowTriangle, dashed: false)
        case .realization: return relationParts(.hollowTriangle, dashed: true)
        case .aggregation: return relationParts(.hollowDiamond, dashed: false)
        case .composition: return relationParts(.filledDiamond, dashed: false)
        case .dependency: return relationParts(.openArrow, dashed: true)
        case .anchor: return relationParts(.none, dashed: true) + solid(circle(16.5, 3.5, 1.2))

        case .zoomIn:
            return solid(circle(9, 9, 5.6), line(13.2, 13.2, 16.8, 16.8), line(6.6, 9, 11.4, 9), line(9, 6.6, 9, 11.4))
        case .zoomOut:
            return solid(circle(9, 9, 5.6), line(13.2, 13.2, 16.8, 16.8), line(6.6, 9, 11.4, 9))
        case .fit:
            return solid(poly([pt(3, 7.5), pt(3, 3), pt(7.5, 3)]), poly([pt(12.5, 3), pt(17, 3), pt(17, 7.5)]),
                         poly([pt(17, 12.5), pt(17, 17), pt(12.5, 17)]), poly([pt(7.5, 17), pt(3, 17), pt(3, 12.5)]),
                         rrect(7, 7, 6, 6, 1.5))
        case .grid:
            return solid(rrect(3, 3, 14, 14, 2.5), line(7.67, 3, 7.67, 17), line(12.33, 3, 12.33, 17),
                         line(3, 7.67, 17, 7.67), line(3, 12.33, 17, 12.33))
        case .magnet:
            var outer = Path()
            outer.move(to: pt(8.4, 4)); outer.addLine(to: pt(5, 4)); outer.addLine(to: pt(5, 10))
            outer.addQuadCurve(to: pt(10, 15.5), control: pt(5, 15.5))
            outer.addQuadCurve(to: pt(15, 10), control: pt(15, 15.5))
            outer.addLine(to: pt(15, 4)); outer.addLine(to: pt(11.6, 4))
            var inner = Path()
            inner.move(to: pt(8.4, 4)); inner.addLine(to: pt(8.4, 10))
            inner.addQuadCurve(to: pt(10, 11.8), control: pt(8.4, 11.8))
            inner.addQuadCurve(to: pt(11.6, 10), control: pt(11.6, 11.8))
            inner.addLine(to: pt(11.6, 4))
            return solid(outer, inner, line(5, 7, 8.4, 7), line(11.6, 7, 15, 7))
        case .layout:
            return solid(rrect(7, 3, 6, 4.5, 1.2), rrect(3, 12.5, 6, 4.5, 1.2), rrect(11, 12.5, 6, 4.5, 1.2),
                         poly([pt(10, 7.5), pt(10, 10), pt(6, 10), pt(6, 12.5)]),
                         poly([pt(10, 10), pt(14, 10), pt(14, 12.5)]))
        case .alignLeft:
            return solid(line(3.5, 3, 3.5, 17), rrect(6.5, 5, 10, 3.6, 1.2), rrect(6.5, 11.4, 6.5, 3.6, 1.2))
        case .alignTop:
            return solid(line(3, 3.5, 17, 3.5), rrect(5, 6.5, 3.6, 10, 1.2), rrect(11.4, 6.5, 3.6, 6.5, 1.2))

        case .newDoc:
            return solid(page()[0], page()[1], line(10, 9.5, 10, 14.5), line(7.5, 12, 12.5, 12))
        case .open:
            var f = Path()
            f.move(to: pt(3, 15.5)); f.addLine(to: pt(3, 5))
            f.addQuadCurve(to: pt(4.5, 3.5), control: pt(3, 3.5))
            f.addLine(to: pt(8, 3.5)); f.addLine(to: pt(9.8, 5.8)); f.addLine(to: pt(15.5, 5.8))
            f.addQuadCurve(to: pt(17, 7.3), control: pt(17, 5.8))
            f.addLine(to: pt(17, 15.5))
            f.addQuadCurve(to: pt(15.5, 17), control: pt(17, 17))
            f.addLine(to: pt(4.5, 17))
            f.addQuadCurve(to: pt(3, 15.5), control: pt(3, 17))
            f.closeSubpath()
            return solid(f, line(3, 9, 17, 9))
        case .save:
            var tray = Path()
            tray.move(to: pt(3.5, 12)); tray.addLine(to: pt(3.5, 15.5))
            tray.addQuadCurve(to: pt(5, 17), control: pt(3.5, 17))
            tray.addLine(to: pt(15, 17))
            tray.addQuadCurve(to: pt(16.5, 15.5), control: pt(16.5, 17))
            tray.addLine(to: pt(16.5, 12))
            return solid(line(10, 3, 10, 12), poly([pt(6.5, 8.5), pt(10, 12), pt(13.5, 8.5)]), tray)
        case .image:
            return solid(rrect(3, 4, 14, 12, 2.5),
                         poly([pt(5.5, 14), pt(9, 10), pt(11.5, 12.5), pt(13, 11), pt(15, 13.5)]),
                         circle(12.8, 7.6, 1.3))
        case .pdf:
            return solid(page()[0], page()[1], line(7.5, 10.5, 12.5, 10.5), line(7.5, 13.5, 11, 13.5))
        case .code:
            return solid(poly([pt(7, 6), pt(3, 10), pt(7, 14)]), poly([pt(13, 6), pt(17, 10), pt(13, 14)]),
                         line(11.4, 4.5, 8.6, 15.5))

        case .trash:
            return solid(line(3.5, 6, 16.5, 6), poly([pt(8, 6), pt(8, 3.8), pt(12, 3.8), pt(12, 6)]),
                         poly([pt(5.3, 6), pt(6.3, 16.8), pt(13.7, 16.8), pt(14.7, 6)]),
                         line(8.6, 9, 8.6, 14), line(11.4, 9, 11.4, 14))
        case .duplicate:
            var back = Path()
            back.move(to: pt(13, 7)); back.addLine(to: pt(13, 4.5))
            back.addQuadCurve(to: pt(11.5, 3), control: pt(13, 3))
            back.addLine(to: pt(4.5, 3))
            back.addQuadCurve(to: pt(3, 4.5), control: pt(3, 3))
            back.addLine(to: pt(3, 11.5))
            back.addQuadCurve(to: pt(4.5, 13), control: pt(3, 13))
            back.addLine(to: pt(7, 13))
            return solid(rrect(7, 7, 10, 10, 2), back)
        case .pin:
            return solid(line(7, 3, 13, 3),
                         poly([pt(8.5, 3), pt(8.5, 8), pt(6, 11), pt(14, 11), pt(11.5, 8), pt(11.5, 3)]),
                         line(10, 11, 10, 17))
        case .undo:
            var p = Path()
            p.move(to: pt(4, 8.5)); p.addLine(to: pt(12, 8.5))
            p.addQuadCurve(to: pt(16, 12.5), control: pt(16, 8.5))
            p.addQuadCurve(to: pt(12, 16.5), control: pt(16, 16.5))
            p.addLine(to: pt(9, 16.5))
            return solid(poly([pt(7.5, 5), pt(4, 8.5), pt(7.5, 12)]), p)
        case .redo:
            var p = Path()
            p.move(to: pt(16, 8.5)); p.addLine(to: pt(8, 8.5))
            p.addQuadCurve(to: pt(4, 12.5), control: pt(4, 8.5))
            p.addQuadCurve(to: pt(8, 16.5), control: pt(4, 16.5))
            p.addLine(to: pt(11, 16.5))
            return solid(poly([pt(12.5, 5), pt(16, 8.5), pt(12.5, 12)]), p)
        case .plus:
            return solid(line(10, 4.5, 10, 15.5), line(4.5, 10, 15.5, 10))
        case .minus:
            return solid(line(4.5, 10, 15.5, 10))
        case .xmark:
            return solid(line(5.5, 5.5, 14.5, 14.5), line(14.5, 5.5, 5.5, 14.5))
        case .swap:
            return solid(line(4, 7, 16, 7), poly([pt(13, 4), pt(16, 7), pt(13, 10)]),
                         line(16, 13, 4, 13), poly([pt(7, 10), pt(4, 13), pt(7, 16)]))
        case .logo:
            return solid(rrect(2.5, 2.5, 8.5, 6.5, 1.8), rrect(9, 11, 8.5, 6.5, 1.8),
                         poly([pt(6.75, 9), pt(6.75, 14.25), pt(9, 14.25)]))
        }
    }
}
