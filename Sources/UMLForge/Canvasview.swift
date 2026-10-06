import SwiftUI
import AppKit

struct DiagramCanvasView: View {
    @EnvironmentObject private var store: DiagramStore
    @FocusState private var focused: Bool

    @State private var hoverPoint: CGPoint?
    @State private var dragOrigins: [UUID: CGPoint] = [:]
    @State private var backgroundDrag: BackgroundDrag = .none
    @State private var marqueeRect: CGRect?

    private enum BackgroundDrag {
        case none
        case pan(start: CGPoint)
        case marquee(start: CGPoint, base: Set<UUID>)
    }

    private static let space = "canvas"

    var body: some View {
        GeometryReader { geo in
            let hovered = hoverPoint.flatMap { store.nodeAt(view: $0) }

            ZStack(alignment: .topLeading) {
                GridLayer(zoom: store.zoom, offset: store.offset, visible: store.showGrid)
                backgroundLayer
                EdgeLayer(diagram: store.diagram, zoom: store.zoom, offset: store.offset,
                          selected: store.selectedRelation)
                nodesLayer(hovered: hovered)
                connectionPreview
                if let r = marqueeRect {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.accentFill(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Theme.accent, lineWidth: 1))
                        .frame(width: r.width, height: r.height)
                        .offset(x: r.minX, y: r.minY)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .onContinuousHover(coordinateSpace: .named(Self.space)) { phase in
                switch phase {
                case .active(let p): hoverPoint = p
                case .ended: hoverPoint = nil
                }
            }
            .coordinateSpace(.named(Self.space))
            .clipped()
            .overlay(alignment: .top) { CanvasHeader().allowsHitTesting(false) }
            .overlay(alignment: .bottom) { CanvasStatusBar() }
            .background(ScrollWheelCatcher { event, point in handleScroll(event, point) })
            .onAppear {
                store.canvasDidResize(geo.size)
                focused = true
            }
            .onChange(of: geo.size) { _, size in store.canvasDidResize(size) }
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onDeleteCommand { store.deleteSelection() }
        .onExitCommand { store.cancelInteraction() }
        .onKeyPress(phases: [.down, .repeat]) { press in handleKey(press) }
    }

    // MARK: Hintergrund (Klicken, Rahmenauswahl, Verschieben)

    private var backgroundLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
                    .onChanged(backgroundDragChanged)
                    .onEnded { _ in
                        if case .pan = backgroundDrag { NSCursor.pop() }
                        backgroundDrag = .none
                        marqueeRect = nil
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .named(Self.space))
                    .onEnded { v in backgroundTap(v.location) }
            )
    }

    private func backgroundDragChanged(_ v: DragGesture.Value) {
        focused = true
        if case .none = backgroundDrag {
            let flags = NSEvent.modifierFlags
            if flags.contains(.option) || store.tool != .select {
                backgroundDrag = .pan(start: store.offset)
                NSCursor.closedHand.push()
            } else {
                let shift = flags.contains(.shift)
                backgroundDrag = .marquee(start: v.startLocation, base: shift ? store.selectedNodes : [])
                if !shift { store.clearSelection() }
            }
        }
        switch backgroundDrag {
        case .pan(let start):
            store.setOffset(CGPoint(x: start.x + v.translation.width, y: start.y + v.translation.height))
        case .marquee(let s, let base):
            let r = CGRect(x: min(s.x, v.location.x), y: min(s.y, v.location.y),
                           width: abs(v.location.x - s.x), height: abs(v.location.y - s.y))
            marqueeRect = r
            store.selectedNodes = base.union(store.nodes(intersecting: r))
            store.selectedRelation = nil
        case .none:
            break
        }
    }

    private func backgroundTap(_ p: CGPoint) {
        focused = true
        let option = NSEvent.modifierFlags.contains(.option)
        switch store.tool {
        case .node(let kind):
            store.addNode(kind, centeredAt: store.toWorld(p))
            if !option { store.tool = .select }
        case .relation:
            store.pendingSource = nil
        case .select:
            if let r = store.relationAt(view: p) {
                store.selectRelation(r)
            } else if !NSEvent.modifierFlags.contains(.shift) {
                store.clearSelection()
            }
        }
    }

    // MARK: Knoten

    private func nodesLayer(hovered: UUID?) -> some View {
        ForEach(store.diagram.nodes) { node in
            let size = NodeMetrics.size(of: node)
            let z = store.zoom
            let center = store.toView(CGPoint(x: node.origin.x + size.width / 2, y: node.origin.y + size.height / 2))
            let isPending = store.pendingSource == node.id
            let isTarget: Bool = {
                if case .relation = store.tool { return store.pendingSource != nil && hovered == node.id }
                return false
            }()

            NodeCard(node: node, size: size,
                     selected: store.selectedNodes.contains(node.id),
                     hovered: hovered == node.id,
                     highlighted: isPending || isTarget)
                .scaleEffect(z, anchor: .topLeading)
                // Layout-Rahmen = sichtbare Größe → Hit-Test und Gesten passen bei jedem Zoom
                .frame(width: size.width * z, height: size.height * z, alignment: .topLeading)
                .contentShape(RoundedRectangle(cornerRadius: Theme.radiusCard * z, style: .continuous))
                .position(center)
                .gesture(nodeDrag(node))
                .simultaneousGesture(TapGesture().onEnded {
                    focused = true
                    let flags = NSEvent.modifierFlags
                    store.handleNodeTap(node.id, shift: flags.contains(.shift), option: flags.contains(.option))
                })
                .contextMenu { nodeMenu(node) }
        }
    }

    private func nodeDrag(_ node: UMLNode) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
            .onChanged { v in
                focused = true
                if case .relation = store.tool {
                    // Beziehung per Ziehen von Quelle zu Ziel
                    if store.pendingSource == nil { store.pendingSource = node.id }
                    hoverPoint = v.location
                    return
                }
                if dragOrigins.isEmpty {
                    if !store.selectedNodes.contains(node.id) { store.selectOnly(node.id) }
                    if case .node = store.tool { store.tool = .select }
                    store.beginInteraction()
                    var origins: [UUID: CGPoint] = [:]
                    for n in store.diagram.nodes where store.selectedNodes.contains(n.id) { origins[n.id] = n.origin }
                    dragOrigins = origins
                }
                store.moveNodes(from: dragOrigins,
                                by: CGSize(width: v.translation.width / store.zoom,
                                           height: v.translation.height / store.zoom))
            }
            .onEnded { v in
                if case .relation(let kind) = store.tool {
                    if let source = store.pendingSource, let target = store.nodeAt(view: v.location) {
                        let ok = store.addRelation(kind, from: source, to: target)
                        if ok && !NSEvent.modifierFlags.contains(.option) { store.tool = .select }
                    }
                    store.pendingSource = nil
                }
                dragOrigins = [:]
            }
    }

    @ViewBuilder
    private func nodeMenu(_ node: UMLNode) -> some View {
        Button("Duplizieren") {
            if !store.selectedNodes.contains(node.id) { store.selectOnly(node.id) }
            store.duplicateSelection()
        }
        Button("In den Vordergrund") { store.bringToFront(node.id) }
        Menu("Beziehung beginnen") {
            ForEach(RelationKind.allCases) { kind in
                Button(kind.title) {
                    store.tool = .relation(kind)
                    store.pendingSource = node.id
                }
            }
        }
        Divider()
        Button("Löschen", role: .destructive) {
            if !store.selectedNodes.contains(node.id) { store.selectOnly(node.id) }
            store.deleteSelection()
        }
    }

    // MARK: Vorschau beim Verbinden

    @ViewBuilder
    private var connectionPreview: some View {
        if let source = store.pendingSource, let n = store.node(source), let p = hoverPoint {
            let s = NodeMetrics.size(of: n)
            let c = store.toView(CGPoint(x: n.origin.x + s.width / 2, y: n.origin.y + s.height / 2))
            Canvas { ctx, _ in
                var path = Path()
                path.move(to: c)
                path.addLine(to: p)
                ctx.stroke(path, with: .color(Theme.accent),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 5]))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)),
                         with: .color(Theme.accent))
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: Eingabe

    private func handleScroll(_ e: NSEvent, _ p: CGPoint) -> Bool {
        if p.x < store.sidebarCover { return false }      // Ereignis gehört der aufgeklappten Sidebar
        switch e.type {
        case .magnify:
            store.applyZoom(factor: 1 + e.magnification, around: p)
            return true
        case .scrollWheel:
            if e.modifierFlags.contains(.command) {
                let dy = e.hasPreciseScrollingDeltas ? e.scrollingDeltaY : e.scrollingDeltaY * 6
                store.applyZoom(factor: exp(dy * 0.012), around: p)
            } else {
                let m: CGFloat = e.hasPreciseScrollingDeltas ? 1 : 10
                store.pan(by: CGSize(width: e.scrollingDeltaX * m, height: e.scrollingDeltaY * m))
            }
            return true
        default:
            return false
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let step: CGFloat = press.modifiers.contains(.shift) ? 10 : 1
        switch press.key {
        case .leftArrow: store.nudgeSelection(dx: -step, dy: 0); return .handled
        case .rightArrow: store.nudgeSelection(dx: step, dy: 0); return .handled
        case .upArrow: store.nudgeSelection(dx: 0, dy: -step); return .handled
        case .downArrow: store.nudgeSelection(dx: 0, dy: step); return .handled
        default: break
        }
        guard press.modifiers.isEmpty, press.phase == .down else { return .ignored }
        if let tool = Tool.shortcutMap[press.characters.lowercased()] {
            store.tool = tool
            return .handled
        }
        return .ignored
    }
}

// MARK: - Ebenen

struct GridLayer: View {
    let zoom: CGFloat
    let offset: CGPoint
    let visible: Bool

    var body: some View {
        Canvas { ctx, size in
            guard visible else { return }
            var stepWorld: CGFloat = 20
            while stepWorld * zoom < 12 { stepWorld *= 2 }
            let step = stepWorld * zoom
            let firstI = Int(floor(-offset.x / step)), lastI = Int(ceil((size.width - offset.x) / step))
            let firstJ = Int(floor(-offset.y / step)), lastJ = Int(ceil((size.height - offset.y) / step))
            guard firstI <= lastI, firstJ <= lastJ else { return }

            let r = max(0.7, min(1.3, zoom))
            var minor = Path(), major = Path()
            for i in firstI...lastI {
                let x = offset.x + CGFloat(i) * step
                for j in firstJ...lastJ {
                    let y = offset.y + CGFloat(j) * step
                    let isMajor = i % 5 == 0 && j % 5 == 0
                    let rr = isMajor ? r * 1.5 : r
                    let rect = CGRect(x: x - rr, y: y - rr, width: rr * 2, height: rr * 2)
                    if isMajor { major.addEllipse(in: rect) } else { minor.addEllipse(in: rect) }
                }
            }
            ctx.fill(minor, with: .color(Theme.gridDot))
            ctx.fill(major, with: .color(Theme.gridDotMajor))
        }
        .allowsHitTesting(false)
    }
}

struct EdgeLayer: View {
    let diagram: Diagram
    let zoom: CGFloat
    let offset: CGPoint
    let selected: UUID?

    var body: some View {
        Canvas { ctx, _ in
            EdgeRenderer.draw(diagram, in: &ctx, zoom: zoom, offset: offset, selected: selected)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - HUD

private struct CanvasHeader: View {
    @EnvironmentObject private var store: DiagramStore

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                IconView(icon: .logo, size: 16)
                Text(store.diagram.name.isEmpty ? "Unbenannt" : store.diagram.name)
                    .font(Typo.bodySemibold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if store.isDirty {
                    Circle().fill(Theme.warning).frame(width: 6, height: 6)
                }
                Text(store.fileURL?.lastPathComponent ?? "Nicht gespeichert")
                    .font(Typo.label)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)

            if let toast = store.toast {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top, 14)
    }
}

private struct ToastView: View {
    let toast: Toast

    private var color: Color {
        switch toast.kind {
        case .success: Theme.success
        case .error: Theme.error
        case .info: Theme.warning
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(toast.text).font(Typo.label).foregroundStyle(Theme.textPrimary).lineLimit(2)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 30)
        .background(shape.fill(Theme.panel))
        .overlay(shape.strokeBorder(color.opacity(0.55), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}

private struct CanvasStatusBar: View {
    @EnvironmentObject private var store: DiagramStore

    private var hint: String {
        switch store.tool {
        case .select:
            return "Ziehen: Rahmenauswahl  ·  ⌥-Ziehen / Scrollen: verschieben  ·  ⌘-Scrollen / Pinch: zoomen"
        case .node(let k):
            return "Klicke auf die Fläche, um \(k.longTitle) zu platzieren  ·  ⌥ hält das Werkzeug aktiv"
        case .relation(let k):
            return store.pendingSource == nil
                ? "\(k.title): Quelle anklicken oder von der Quelle zum Ziel ziehen"
                : "\(k.title): Ziel anklicken  ·  Esc bricht ab"
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            HStack(spacing: 8) {
                IconView(icon: store.tool.icon, size: 16)
                Text(hint)
                    .font(Typo.label)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(pill)
            .allowsHitTesting(false)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Button { store.zoomOut() } label: { IconView(icon: .zoomOut, size: 18) }
                    .buttonStyle(IconButtonStyle(size: 26)).help("Verkleinern (⌘−)")
                Button { store.resetZoom() } label: {
                    Text("\(Int((store.zoom * 100).rounded())) %")
                        .font(Typo.monoSmall)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 50, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Auf 100 % setzen (⌘1)")
                Button { store.zoomIn() } label: { IconView(icon: .zoomIn, size: 18) }
                    .buttonStyle(IconButtonStyle(size: 26)).help("Vergrößern (⌘+)")
                Rectangle().fill(Theme.border).frame(width: 1, height: 18).padding(.horizontal, 2)
                Button { store.fitToContent() } label: { IconView(icon: .fit, size: 18) }
                    .buttonStyle(IconButtonStyle(size: 26)).help("Einpassen (⌘0)")
            }
            .padding(4)
            .background(pill)
        }
        .padding(14)
    }

    private var pill: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.panel)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}

// MARK: - Scrollrad / Trackpad

/// Fängt Scroll- und Pinch-Ereignisse über dem Canvas ab (SwiftUI bietet dafür keine direkte API).
struct ScrollWheelCatcher: NSViewRepresentable {
    var handler: (NSEvent, CGPoint) -> Bool

    func makeNSView(context: Context) -> CatcherView {
        let v = CatcherView()
        v.handler = handler
        return v
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        nsView.handler = handler
    }

    final class CatcherView: NSView {
        var handler: ((NSEvent, CGPoint) -> Bool)?
        private var monitor: Any?

        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self, let window = self.window, event.window === window,
                      let handler = self.handler else { return event }
                let p = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(p) else { return event }
                return handler(event, p) ? nil : event
            }
        }

        deinit {
            if let monitor { NSEvent.removeMonitor(monitor) }
        }
    }
}
