import SwiftUI

enum EdgeRenderer {
    static func draw(_ d: Diagram, in ctx: inout GraphicsContext, zoom z: CGFloat, offset: CGPoint, selected: UUID?) {
        let lines = EdgeGeometry.polylines(for: d)
        // Ausgewählte Kante zuletzt → liegt oben
        let ordered = d.relations.sorted { ($0.id == selected ? 1 : 0) < ($1.id == selected ? 1 : 0) }
        for rel in ordered {
            guard let world = lines[rel.id], world.count >= 2 else { continue }
            let pts = world.map { CGPoint(x: $0.x * z + offset.x, y: $0.y * z + offset.y) }
            drawEdge(rel, pts: pts, zoom: z, selected: rel.id == selected, ctx: &ctx)
        }
    }

    private static func drawEdge(_ rel: UMLRelation, pts: [CGPoint], zoom z: CGFloat, selected: Bool,
                                 ctx: inout GraphicsContext) {
        let color = selected ? Theme.accent : Theme.textSecondary
        let lw = max(1, 1.5 * z)
        let end = pts[pts.count - 1]
        let prev = pts[pts.count - 2]
        let dir = (end - prev).normalized
        let n = dir.perpendicular
        let deco = rel.kind.decoration

        let len: CGFloat = switch deco {
        case .hollowTriangle: 14 * z
        case .hollowDiamond, .filledDiamond: 18 * z
        case .openArrow: 11 * z
        case .none: 0
        }

        // Linie endet an der Basis geschlossener Symbole
        var linePts = pts
        if deco == .hollowTriangle || deco == .hollowDiamond || deco == .filledDiamond {
            linePts[linePts.count - 1] = end - dir * len
        }
        var path = Path()
        path.addLines(linePts)

        if selected {
            ctx.stroke(path, with: .color(Theme.accentFill(0.22)),
                       style: StrokeStyle(lineWidth: lw + 6 * max(z, 0.6), lineCap: .round, lineJoin: .round))
        }
        ctx.stroke(path, with: .color(color),
                   style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round,
                                      dash: rel.kind.isDashed ? [6 * z, 4.5 * z] : []))

        let solid = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
        switch deco {
        case .none:
            break
        case .openArrow:
            var p = Path()
            p.move(to: end - dir * len + n * (len * 0.55))
            p.addLine(to: end)
            p.addLine(to: end - dir * len - n * (len * 0.55))
            ctx.stroke(p, with: .color(color), style: solid)
        case .hollowTriangle:
            let base = end - dir * len
            var p = Path()
            p.move(to: end)
            p.addLine(to: base + n * (len * 0.6))
            p.addLine(to: base - n * (len * 0.6))
            p.closeSubpath()
            ctx.fill(p, with: .color(Theme.panel))
            ctx.stroke(p, with: .color(color), style: solid)
        case .hollowDiamond, .filledDiamond:
            let mid = end - dir * (len / 2)
            let back = end - dir * len
            var p = Path()
            p.move(to: end)
            p.addLine(to: mid + n * (len * 0.33))
            p.addLine(to: back)
            p.addLine(to: mid - n * (len * 0.33))
            p.closeSubpath()
            ctx.fill(p, with: .color(deco == .filledDiamond ? color : Theme.panel))
            ctx.stroke(p, with: .color(color), style: solid)
        }

        // Multiplizitäten
        let startDir = (pts[1] - pts[0]).normalized
        if !rel.fromMultiplicity.isEmpty {
            drawText(rel.fromMultiplicity, at: pts[0] + startDir * (16 * z) + startDir.perpendicular * (11 * z),
                     zoom: z, color: Theme.textSecondary, pill: false, ctx: &ctx)
        }
        if !rel.toMultiplicity.isEmpty {
            drawText(rel.toMultiplicity, at: end - dir * (len + 14 * z) + n * (11 * z),
                     zoom: z, color: Theme.textSecondary, pill: false, ctx: &ctx)
        }

        // Beschriftung als Pille in der Mitte
        if !rel.label.isEmpty {
            drawText(rel.label, at: EdgeGeometry.midpoint(pts), zoom: z,
                     color: selected ? Theme.textPrimary : Theme.textSecondary,
                     pill: true, border: selected ? Theme.accent : Theme.border, ctx: &ctx)
        }
    }

    static func drawText(_ s: String, at p: CGPoint, zoom z: CGFloat, color: Color, pill: Bool,
                         border: Color = Theme.border, ctx: inout GraphicsContext) {
        let fontSize = (11 * z * 2).rounded() / 2          // halbe Punkte → begrenzter Font-Cache
        let text = Text(s).font(Fonts.font(max(fontSize, 2), .medium)).foregroundStyle(color)
        let resolved = ctx.resolve(text)
        let size = resolved.measure(in: CGSize(width: 800 * max(z, 0.3), height: 200))
        if pill {
            let r = CGRect(x: p.x - size.width / 2 - 6 * z, y: p.y - size.height / 2 - 2.5 * z,
                           width: size.width + 12 * z, height: size.height + 5 * z)
            let shape = Path(roundedRect: r, cornerRadius: 7 * z, style: .continuous)
            ctx.fill(shape, with: .color(Theme.panel))
            ctx.stroke(shape, with: .color(border), lineWidth: 1)
        }
        ctx.draw(resolved, at: p, anchor: .center)
    }
}
