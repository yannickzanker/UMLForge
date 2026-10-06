import SwiftUI

struct NodeCard: View {
    let node: UMLNode
    let size: CGSize
    var selected = false
    var hovered = false
    var highlighted = false

    var body: some View {
        Group {
            if node.kind == .note { note } else { classifier }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var borderColor: Color {
        if selected || highlighted { return Theme.accent }
        return hovered ? Theme.borderStrong : Theme.border
    }

    // MARK: Klasse / Interface / Enum

    private var classifier: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
        return VStack(spacing: 0) {
            header
                .frame(height: NodeMetrics.headerHeight(node))
            ForEach(NodeMetrics.compartments(node)) { comp in
                Rectangle().fill(Theme.border).frame(height: 1)
                compartment(comp)
                    .frame(height: NodeMetrics.compartmentHeight(comp), alignment: .top)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(Theme.panel)
        .clipShape(shape)
        .overlay(shape.strokeBorder(borderColor, lineWidth: selected ? 1.5 : 1))
        .background {
            if selected || highlighted {
                shape.inset(by: -3).stroke(Theme.accentFill(0.22), lineWidth: 4)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
    }

    private var header: some View {
        VStack(spacing: 1) {
            if let st = node.kind.stereotype {
                Text(st)
                    .font(Font(ns: NodeMetrics.stereoFont))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            Text(node.name.isEmpty ? "Unbenannt" : node.name)
                .font(Font(ns: node.kind == .abstractClass ? NodeMetrics.nameFontItalic : NodeMetrics.nameFont))
                .foregroundStyle(node.name.isEmpty ? Theme.textMuted : Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, NodeMetrics.hPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(selected ? Theme.accentFill(0.12) : Theme.panelRaised)
    }

    private func compartment(_ c: NodeMetrics.Compartment) -> some View {
        let showVisibility = NodeMetrics.showsVisibility(node, c)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(c.members) { m in
                HStack(spacing: 6) {
                    if showVisibility {
                        Text(m.visibility.rawValue)
                            .font(Font(ns: NodeMetrics.memberFont))
                            .foregroundStyle(Theme.textMuted)
                            .frame(width: NodeMetrics.visWidth)
                    }
                    Text(m.text.isEmpty ? "–" : m.text)
                        .font(Font(ns: m.isAbstract ? NodeMetrics.memberFontItalic : NodeMetrics.memberFont))
                        .underline(m.isStatic, color: Theme.textSecondary)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(height: NodeMetrics.row, alignment: .leading)
            }
        }
        .padding(.vertical, c.members.isEmpty ? 0 : NodeMetrics.pad)
        .padding(.horizontal, NodeMetrics.hPad - 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Notiz

    private var note: some View {
        let shape = NoteShape(fold: NodeMetrics.noteFold, radius: Theme.radiusCard)
        return Text(node.noteText.isEmpty ? "Notiz" : node.noteText)
            .font(Font(ns: NodeMetrics.noteFont))
            .lineSpacing(NodeMetrics.noteLineSpacing)
            .foregroundStyle(node.noteText.isEmpty ? Theme.textMuted : Theme.textSecondary)
            .multilineTextAlignment(.leading)
            .padding(.leading, NodeMetrics.notePad)
            .padding(.vertical, NodeMetrics.notePad)
            .padding(.trailing, NodeMetrics.notePad + NodeMetrics.noteFold * 0.6)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .background(shape.fill(Theme.panelRaised))
            .overlay(shape.stroke(borderColor, lineWidth: selected ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                NoteFold()
                    .stroke(borderColor, style: StrokeStyle(lineWidth: 1, lineJoin: .round))
                    .frame(width: NodeMetrics.noteFold, height: NodeMetrics.noteFold)
            }
            .background {
                if selected || highlighted {
                    shape.stroke(Theme.accentFill(0.22), lineWidth: 6)
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 5)
    }
}

/// Notizblatt mit Eselsohr oben rechts.
struct NoteShape: Shape {
    var fold: CGFloat
    var radius: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - fold, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + fold))
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: radius)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: radius)
        p.closeSubpath()
        return p
    }
}

struct NoteFold: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}
