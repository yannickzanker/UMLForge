import SwiftUI
import AppKit

// MARK: - Vektor-Helfer

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
    var length: CGFloat { (x * x + y * y).squareRoot() }
    var normalized: CGPoint {
        let l = length
        return l < 0.0001 ? CGPoint(x: 1, y: 0) : CGPoint(x: x / l, y: y / l)
    }
    var perpendicular: CGPoint { CGPoint(x: -y, y: x) }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

// MARK: - Knotenmaße

/// Berechnet die Knotengröße exakt aus den echten Schriftmetriken.
/// NodeCard rendert mit denselben Konstanten → Kanten treffen exakt die Ränder.
enum NodeMetrics {
    static let header: CGFloat = 34
    static let stereotypeExtra: CGFloat = 14
    static let row: CGFloat = 19
    static let pad: CGFloat = 7
    static let emptyCompartment: CGFloat = 12
    static let hPad: CGFloat = 14
    static let visWidth: CGFloat = 12
    static let minWidth: CGFloat = 160
    static let maxAutoWidth: CGFloat = 440
    static let notePad: CGFloat = 12
    static let noteFold: CGFloat = 14
    static let noteLineSpacing: CGFloat = 3

    static var nameFont: NSFont { Fonts.ns(13, .semibold) }
    static var nameFontItalic: NSFont { Fonts.ns(13, .semibold, italic: true) }
    static var stereoFont: NSFont { Fonts.ns(10.5) }
    static var memberFont: NSFont { Fonts.ns(12, mono: true) }
    static var memberFontItalic: NSFont { Fonts.ns(12, mono: true, italic: true) }
    static var noteFont: NSFont { Fonts.ns(12) }

    struct Compartment: Identifiable {
        let id: String
        let members: [Member]
        let isOperations: Bool
    }

    static func compartments(_ n: UMLNode) -> [Compartment] {
        let attrs = Compartment(id: "attr", members: n.attributes, isOperations: false)
        let ops = Compartment(id: "ops", members: n.operations, isOperations: true)
        switch n.kind {
        case .note: return []
        case .classType, .abstractClass: return [attrs, ops]
        case .interface: return (n.attributes.isEmpty ? [] : [attrs]) + [ops]
        case .enumeration: return [attrs] + (n.operations.isEmpty ? [] : [ops])
        }
    }

    static func compartmentHeight(_ c: Compartment) -> CGFloat {
        c.members.isEmpty ? emptyCompartment : CGFloat(c.members.count) * row + pad * 2
    }

    static func headerHeight(_ n: UMLNode) -> CGFloat {
        header + (n.kind.stereotype != nil ? stereotypeExtra : 0)
    }

    /// Enum-Literale werden ohne Sichtbarkeitssymbol dargestellt.
    static func showsVisibility(_ n: UMLNode, _ c: Compartment) -> Bool {
        !(n.kind == .enumeration && !c.isOperations)
    }

    private static var cache: [Int: CGSize] = [:]

    static func size(of n: UMLNode) -> CGSize {
        var h = Hasher()
        h.combine(n.kind)
        h.combine(n.name)
        h.combine(n.attributes)
        h.combine(n.operations)
        h.combine(n.noteText)
        h.combine(n.customWidth)
        let key = h.finalize()
        if let s = cache[key] { return s }
        let s = computeSize(n)
        if cache.count > 4000 { cache.removeAll(keepingCapacity: true) }
        cache[key] = s
        return s
    }

    private static func textWidth(_ s: String, _ font: NSFont) -> CGFloat {
        ceil((s as NSString).size(withAttributes: [.font: font]).width)
    }

    static func noteTextHeight(_ text: String, width: CGFloat) -> CGFloat {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = noteLineSpacing
        let r = ((text.isEmpty ? "Notiz" : text) as NSString).boundingRect(
            with: CGSize(width: max(width, 10), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: noteFont, .paragraphStyle: ps])
        return ceil(r.height)
    }

    private static func computeSize(_ n: UMLNode) -> CGSize {
        if n.kind == .note {
            let lines = (n.noteText.isEmpty ? "Notiz" : n.noteText).components(separatedBy: "\n")
            let longest = lines.map { textWidth($0, noteFont) }.max() ?? 60
            let auto = min(max(longest + notePad * 2 + noteFold, 140), 360)
            let w = max(n.customWidth ?? auto, 120)
            let textW = w - notePad * 2 - noteFold * 0.6
            let h = noteTextHeight(n.noteText, width: textW) + notePad * 2 + 4
            return CGSize(width: ceil(w), height: ceil(max(h, 56)))
        }

        let w: CGFloat
        if let cw = n.customWidth {
            w = max(cw, 120)
        } else {
            var m = textWidth(n.name.isEmpty ? "Unbenannt" : n.name,
                              n.kind == .abstractClass ? nameFontItalic : nameFont)
            if let st = n.kind.stereotype { m = max(m, textWidth(st, stereoFont)) }
            for c in compartments(n) {
                let vis: CGFloat = showsVisibility(n, c) ? visWidth + 6 : 0
                for member in c.members {
                    m = max(m, textWidth(member.text, memberFont) + vis)
                }
            }
            w = min(max(m + hPad * 2 + 6, minWidth), maxAutoWidth)
        }

        var h = headerHeight(n)
        for c in compartments(n) { h += 1 + compartmentHeight(c) }
        return CGSize(width: ceil(w), height: ceil(h))
    }
}

// MARK: - Kanten-Geometrie

enum EdgeGeometry {
    static func rect(of n: UMLNode) -> CGRect {
        CGRect(origin: n.origin, size: NodeMetrics.size(of: n))
    }

    private static func pairKey(_ r: UMLRelation) -> String {
        let a = r.from.uuidString, b = r.to.uuidString
        return a < b ? a + b : b + a
    }

    /// Polylinien aller Beziehungen in Weltkoordinaten. Parallele Kanten werden aufgefächert.
    static func polylines(for d: Diagram) -> [UUID: [CGPoint]] {
        var rects: [UUID: CGRect] = [:]
        for n in d.nodes { rects[n.id] = rect(of: n) }

        var groups: [String: [UUID]] = [:]
        for r in d.relations { groups[pairKey(r), default: []].append(r.id) }

        var result: [UUID: [CGPoint]] = [:]
        for r in d.relations {
            guard let a = rects[r.from], let b = rects[r.to] else { continue }
            let group = groups[pairKey(r)] ?? [r.id]
            let index = group.firstIndex(of: r.id) ?? 0

            if r.from == r.to {
                result[r.id] = selfLoop(a, index: index)
                continue
            }

            let ca = a.center, cb = b.center
            let dir = (cb - ca).normalized
            var normal = dir.perpendicular
            if r.from.uuidString > r.to.uuidString { normal = normal * -1 }   // pro Paar konsistent

            let limit = min(a.width, a.height, b.width, b.height) * 0.35
            let spread: CGFloat = 18
            let shift = max(-limit, min(limit, (CGFloat(index) - CGFloat(group.count - 1) / 2) * spread))

            let start = exitPoint(origin: ca + normal * shift, dir: dir, rect: a)
            let end = exitPoint(origin: cb + normal * shift, dir: dir * -1, rect: b)
            result[r.id] = [start, end]
        }
        return result
    }

    private static func selfLoop(_ r: CGRect, index: Int) -> [CGPoint] {
        let s: CGFloat = 24 + CGFloat(index) * 14
        let p1 = CGPoint(x: r.maxX - s - 10, y: r.minY)
        let p2 = CGPoint(x: r.maxX, y: r.minY + s + 10)
        return [p1,
                CGPoint(x: p1.x, y: r.minY - s - 8),
                CGPoint(x: r.maxX + s + 8, y: r.minY - s - 8),
                CGPoint(x: r.maxX + s + 8, y: p2.y),
                p2]
    }

    /// Austrittspunkt eines Strahls (Ursprung innerhalb von `rect`) am Rechteckrand.
    static func exitPoint(origin p: CGPoint, dir d: CGPoint, rect r: CGRect) -> CGPoint {
        var t = CGFloat.infinity
        if d.x > 1e-6 { t = min(t, (r.maxX - p.x) / d.x) } else if d.x < -1e-6 { t = min(t, (r.minX - p.x) / d.x) }
        if d.y > 1e-6 { t = min(t, (r.maxY - p.y) / d.y) } else if d.y < -1e-6 { t = min(t, (r.minY - p.y) / d.y) }
        guard t.isFinite, t >= 0 else { return p }
        return p + d * t
    }

    static func distance(from p: CGPoint, to pts: [CGPoint]) -> CGFloat {
        guard pts.count >= 2 else { return .infinity }
        var best = CGFloat.infinity
        for i in 0..<(pts.count - 1) {
            best = min(best, segmentDistance(p, pts[i], pts[i + 1]))
        }
        return best
    }

    private static func segmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = b - a
        let len2 = ab.x * ab.x + ab.y * ab.y
        guard len2 > 0 else { return (p - a).length }
        let t = max(0, min(1, ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / len2))
        return (p - (a + ab * t)).length
    }

    /// Mittelpunkt entlang der Bogenlänge.
    static func midpoint(_ pts: [CGPoint]) -> CGPoint {
        guard pts.count >= 2 else { return pts.first ?? .zero }
        var total: CGFloat = 0
        for i in 0..<(pts.count - 1) { total += (pts[i + 1] - pts[i]).length }
        var remaining = total / 2
        for i in 0..<(pts.count - 1) {
            let seg = (pts[i + 1] - pts[i]).length
            if remaining <= seg, seg > 0 { return pts[i] + (pts[i + 1] - pts[i]) * (remaining / seg) }
            remaining -= seg
        }
        return pts[0]
    }
}

// MARK: - Automatisches Layout (Ebenen + Baryzentrum-Sortierung)

enum AutoLayout {
    static func arrange(_ d: Diagram) -> [UUID: CGPoint] {
        let hierarchical: Set<RelationKind> = [.inheritance, .realization, .aggregation, .composition]
        let classNodes = d.nodes.filter { $0.kind != .note }
        let ids = Set(classNodes.map(\.id))
        guard !classNodes.isEmpty || !d.nodes.isEmpty else { return [:] }

        var parents: [UUID: [UUID]] = [:]
        var children: [UUID: [UUID]] = [:]
        var neighbors: [UUID: [UUID]] = [:]
        for r in d.relations where r.from != r.to && ids.contains(r.from) && ids.contains(r.to) {
            neighbors[r.from, default: []].append(r.to)
            neighbors[r.to, default: []].append(r.from)
            if hierarchical.contains(r.kind) {
                parents[r.from, default: []].append(r.to)
                children[r.to, default: []].append(r.from)
            }
        }

        // Ebene = längster Pfad zur Wurzel (Zyklen werden abgefangen)
        var level: [UUID: Int] = [:]
        var visiting = Set<UUID>()
        func depth(_ id: UUID) -> Int {
            if let l = level[id] { return l }
            if visiting.contains(id) { return 0 }
            visiting.insert(id)
            let l = (parents[id] ?? []).map { depth($0) + 1 }.max() ?? 0
            visiting.remove(id)
            level[id] = l
            return l
        }
        for n in classNodes { _ = depth(n.id) }

        // Elemente ohne Hierarchie neben ihren Assoziationspartnern einordnen
        for n in classNodes where parents[n.id] == nil && children[n.id] == nil {
            if let partner = neighbors[n.id]?.first(where: { parents[$0] != nil || children[$0] != nil }),
               let l = level[partner] {
                level[n.id] = l
            }
        }

        let maxLevel = level.values.max() ?? 0
        var rows: [[UUID]] = Array(repeating: [], count: maxLevel + 1)
        for n in classNodes.sorted(by: { $0.origin.x < $1.origin.x }) {
            rows[level[n.id] ?? 0].append(n.id)
        }

        var fraction: [UUID: CGFloat] = [:]
        func reindex() {
            for row in rows {
                for (i, id) in row.enumerated() { fraction[id] = (CGFloat(i) + 0.5) / CGFloat(max(row.count, 1)) }
            }
        }
        func barycenter(_ id: UUID, refs: [UUID]?) -> CGFloat {
            let values = (refs ?? []).compactMap { fraction[$0] }
            return values.isEmpty ? (fraction[id] ?? 0.5) : values.reduce(0, +) / CGFloat(values.count)
        }
        reindex()

        if rows.count > 1 {
            for _ in 0..<4 {
                for li in 1..<rows.count {
                    let keyed = rows[li].map { ($0, barycenter($0, refs: parents[$0] ?? neighbors[$0])) }
                    rows[li] = keyed.sorted { $0.1 < $1.1 }.map(\.0)
                    reindex()
                }
                for li in stride(from: rows.count - 2, through: 0, by: -1) {
                    let keyed = rows[li].map { ($0, barycenter($0, refs: children[$0] ?? neighbors[$0])) }
                    rows[li] = keyed.sorted { $0.1 < $1.1 }.map(\.0)
                    reindex()
                }
            }
        }

        var sizes: [UUID: CGSize] = [:]
        for n in d.nodes { sizes[n.id] = NodeMetrics.size(of: n) }

        let gapX: CGFloat = 70, gapY: CGFloat = 100
        var result: [UUID: CGPoint] = [:]
        var y: CGFloat = 0
        for row in rows where !row.isEmpty {
            let total = row.reduce(CGFloat(0)) { $0 + (sizes[$1]?.width ?? 0) } + gapX * CGFloat(row.count - 1)
            var x = -total / 2
            let rowHeight = row.map { sizes[$0]?.height ?? 0 }.max() ?? 0
            for id in row {
                result[id] = CGPoint(x: (x / 10).rounded() * 10, y: (y / 10).rounded() * 10)
                x += (sizes[id]?.width ?? 0) + gapX
            }
            y += rowHeight + gapY
        }

        // Notizen rechts neben dem Diagramm, möglichst auf Höhe ihres Ankers
        let rightEdge = result.map { $0.value.x + (sizes[$0.key]?.width ?? 0) }.max() ?? 0
        var noteY: CGFloat = 0
        for n in d.nodes where n.kind == .note {
            let anchorY = d.relations
                .first { ($0.from == n.id || $0.to == n.id) && $0.from != $0.to }
                .flatMap { result[$0.from == n.id ? $0.to : $0.from]?.y }
            let yPos = max(anchorY ?? noteY, noteY)
            result[n.id] = CGPoint(x: ((rightEdge + gapX) / 10).rounded() * 10, y: (yPos / 10).rounded() * 10)
            noteY = yPos + (sizes[n.id]?.height ?? 60) + 30
        }
        return result
    }
}
