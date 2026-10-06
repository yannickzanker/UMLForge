import SwiftUI
import AppKit

// MARK: - Werkzeuge

enum Tool: Hashable {
    case select
    case node(NodeKind)
    case relation(RelationKind)

    var title: String {
        switch self {
        case .select: "Auswahl"
        case .node(let k): k.longTitle
        case .relation(let k): k.title
        }
    }

    var icon: Icon {
        switch self {
        case .select: .select
        case .node(let k): k.icon
        case .relation(let k): k.icon
        }
    }

    static let shortcutMap: [String: Tool] = [
        "v": .select,
        "c": .node(.classType), "a": .node(.abstractClass), "i": .node(.interface),
        "e": .node(.enumeration), "n": .node(.note),
        "l": .relation(.association), "p": .relation(.directedAssociation),
        "g": .relation(.inheritance), "r": .relation(.realization),
        "o": .relation(.aggregation), "k": .relation(.composition),
        "d": .relation(.dependency), "t": .relation(.anchor)
    ]

    var shortcut: String? {
        Tool.shortcutMap.first { $0.value == self }?.key.uppercased()
    }
}

struct Toast: Identifiable, Equatable {
    enum Kind: Equatable { case success, error, info }
    let id = UUID()
    let text: String
    let kind: Kind
}

enum ExportFormat { case png, pdf }

// MARK: - Store

@MainActor
final class DiagramStore: ObservableObject {
    @Published var diagram: Diagram {
        didSet { if !suppressDirty { isDirty = true } }
    }
    @Published var selectedNodes: Set<UUID> = []
    @Published var selectedRelation: UUID?
    @Published var tool: Tool = .select {
        didSet { if oldValue != tool { pendingSource = nil } }
    }
    @Published var pendingSource: UUID?
    @Published var zoom: CGFloat = 1
    @Published var offset: CGPoint = .zero          // View = Welt · zoom + offset
    @Published var showGrid = true
    @Published var snapToGrid = true
    @Published var toast: Toast?
    @Published var fileURL: URL?
    @Published private(set) var isDirty = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false

    var canvasSize: CGSize = .zero
    /// Breite, um die die aufgeklappte Sidebar den Canvas überdeckt (für Scroll-Events).
    var sidebarCover: CGFloat = 0

    static let gridSize: CGFloat = 10
    static let zoomRange: ClosedRange<CGFloat> = 0.2...3

    private var suppressDirty = false
    private var needsInitialFit = true
    private var undoStack: [Diagram] = []
    private var redoStack: [Diagram] = []
    private var coalesceKey: String?
    private var coalesceTime = Date.distantPast
    private var toastTask: Task<Void, Never>?
    private var animationTask: Task<Void, Never>?

    init() {
        diagram = .sample()
    }

    // MARK: Koordinaten

    func toView(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * zoom + offset.x, y: p.y * zoom + offset.y) }
    func toWorld(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - offset.x) / zoom, y: (p.y - offset.y) / zoom) }
    var viewCenter: CGPoint { CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2) }

    // MARK: Lookup

    func node(_ id: UUID) -> UMLNode? { diagram.nodes.first { $0.id == id } }
    func relation(_ id: UUID) -> UMLRelation? { diagram.relations.first { $0.id == id } }

    // MARK: Undo / Redo

    /// Änderung mit Undo-Schnappschuss. Gleicher `coalesce`-Schlüssel innerhalb 1,2 s → ein Undo-Schritt
    /// (z. B. Tippen im Namensfeld oder Regler ziehen).
    func mutate(coalesce key: String? = nil, _ body: (inout Diagram) -> Void) {
        var d = diagram
        body(&d)
        guard d != diagram else { return }
        let now = Date()
        if key == nil || key != coalesceKey || now.timeIntervalSince(coalesceTime) > 1.2 {
            pushUndo()
        }
        coalesceKey = key
        coalesceTime = now
        diagram = d
    }

    /// Für kontinuierliche Interaktionen (Ziehen): einmal Schnappschuss, dann live ändern.
    func beginInteraction() {
        pushUndo()
        coalesceKey = nil
    }

    func mutateLive(_ body: (inout Diagram) -> Void) {
        var d = diagram
        body(&d)
        if d != diagram { diagram = d }
    }

    private func pushUndo() {
        undoStack.append(diagram)
        if undoStack.count > 300 { undoStack.removeFirst() }
        redoStack.removeAll()
        updateUndoFlags()
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(diagram)
        diagram = previous
        coalesceKey = nil
        sanitizeSelection()
        updateUndoFlags()
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(diagram)
        diagram = next
        coalesceKey = nil
        sanitizeSelection()
        updateUndoFlags()
    }

    private func updateUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }

    private func sanitizeSelection() {
        let ids = Set(diagram.nodes.map(\.id))
        selectedNodes = selectedNodes.intersection(ids)
        if let r = selectedRelation, relation(r) == nil { selectedRelation = nil }
        if let p = pendingSource, !ids.contains(p) { pendingSource = nil }
    }

    // MARK: Laden / Status

    func load(_ d: Diagram, url: URL?) {
        animationTask?.cancel()
        suppressDirty = true
        diagram = d
        suppressDirty = false
        isDirty = false
        fileURL = url
        undoStack.removeAll()
        redoStack.removeAll()
        coalesceKey = nil
        updateUndoFlags()
        clearSelection()
        tool = .select
    }

    func markClean() { isDirty = false }

    // MARK: Auswahl

    func selectOnly(_ id: UUID) {
        selectedNodes = [id]
        selectedRelation = nil
    }

    func toggleSelection(_ id: UUID) {
        if selectedNodes.contains(id) { selectedNodes.remove(id) } else { selectedNodes.insert(id) }
        selectedRelation = nil
    }

    func selectRelation(_ id: UUID) {
        selectedRelation = id
        selectedNodes = []
    }

    func clearSelection() {
        selectedNodes = []
        selectedRelation = nil
    }

    func cancelInteraction() {
        if pendingSource != nil { pendingSource = nil }
        else if tool != .select { tool = .select }
        else { clearSelection() }
    }

    // MARK: Knoten

    func snapped(_ p: CGPoint) -> CGPoint {
        guard snapToGrid else { return CGPoint(x: p.x.rounded(), y: p.y.rounded()) }
        let g = Self.gridSize
        return CGPoint(x: (p.x / g).rounded() * g, y: (p.y / g).rounded() * g)
    }

    func addNode(_ kind: NodeKind, centeredAt world: CGPoint) {
        let index = diagram.nodes.filter { $0.kind == kind }.count + 1
        var n = UMLNode.template(kind, index: index)
        let s = NodeMetrics.size(of: n)
        n.origin = snapped(CGPoint(x: world.x - s.width / 2, y: world.y - s.height / 2))
        mutate { $0.nodes.append(n) }
        selectOnly(n.id)
    }

    func addNodeAtCenter(_ kind: NodeKind) {
        addNode(kind, centeredAt: toWorld(viewCenter))
    }

    func moveNodes(from origins: [UUID: CGPoint], by delta: CGSize) {
        mutateLive { d in
            for i in d.nodes.indices {
                if let o = origins[d.nodes[i].id] {
                    d.nodes[i].origin = snapped(CGPoint(x: o.x + delta.width, y: o.y + delta.height))
                }
            }
        }
    }

    func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        let ids = selectedNodes
        guard !ids.isEmpty else { return }
        mutate(coalesce: "nudge") { d in
            for i in d.nodes.indices where ids.contains(d.nodes[i].id) {
                d.nodes[i].origin.x += dx
                d.nodes[i].origin.y += dy
            }
        }
    }

    func deleteSelection() {
        if let r = selectedRelation {
            mutate { $0.relations.removeAll { $0.id == r } }
            selectedRelation = nil
            return
        }
        let ids = selectedNodes
        guard !ids.isEmpty else { return }
        mutate { d in
            d.nodes.removeAll { ids.contains($0.id) }
            d.relations.removeAll { ids.contains($0.from) || ids.contains($0.to) }
        }
        selectedNodes = []
    }

    func duplicateSelection() {
        guard !selectedNodes.isEmpty else { return }
        var map: [UUID: UUID] = [:]
        var copies: [UMLNode] = []
        for n in diagram.nodes where selectedNodes.contains(n.id) {
            var c = n
            c.id = UUID()
            c.origin = CGPoint(x: n.origin.x + 30, y: n.origin.y + 30)
            c.attributes = n.attributes.map { var m = $0; m.id = UUID(); return m }
            c.operations = n.operations.map { var m = $0; m.id = UUID(); return m }
            if c.kind != .note { c.name = n.name + "Kopie" }
            map[n.id] = c.id
            copies.append(c)
        }
        let relCopies = diagram.relations.compactMap { r -> UMLRelation? in
            guard let f = map[r.from], let t = map[r.to] else { return nil }
            var c = r
            c.id = UUID(); c.from = f; c.to = t
            return c
        }
        mutate { d in
            d.nodes += copies
            d.relations += relCopies
        }
        selectedNodes = Set(copies.map(\.id))
        selectedRelation = nil
    }

    func bringToFront(_ id: UUID) {
        mutate { d in
            if let i = d.nodes.firstIndex(where: { $0.id == id }) {
                let n = d.nodes.remove(at: i)
                d.nodes.append(n)
            }
        }
    }

    enum AlignEdge { case left, top }

    func align(_ edge: AlignEdge) {
        let ids = selectedNodes
        let nodes = diagram.nodes.filter { ids.contains($0.id) }
        guard nodes.count > 1 else { return }
        let minX = nodes.map(\.origin.x).min() ?? 0
        let minY = nodes.map(\.origin.y).min() ?? 0
        mutate { d in
            for i in d.nodes.indices where ids.contains(d.nodes[i].id) {
                switch edge {
                case .left: d.nodes[i].origin.x = minX
                case .top: d.nodes[i].origin.y = minY
                }
            }
        }
    }

    // MARK: Beziehungen

    @discardableResult
    func addRelation(_ kind: RelationKind, from: UUID, to: UUID) -> Bool {
        guard let a = node(from), let b = node(to) else { return false }
        var k = kind
        if a.kind == .note || b.kind == .note { k = .anchor }
        if from == to && (k == .inheritance || k == .realization || k == .anchor) {
            showToast("\(k.title) auf dasselbe Element ist nicht möglich", .error)
            return false
        }
        if k == .realization && b.kind != .interface {
            showToast("Realisierung zeigt normalerweise auf ein Interface", .info)
        }
        let r = UMLRelation(kind: k, from: from, to: to)
        mutate { $0.relations.append(r) }
        selectRelation(r.id)
        return true
    }

    func swapDirection(_ id: UUID) {
        mutate { d in
            guard let i = d.relations.firstIndex(where: { $0.id == id }) else { return }
            let r = d.relations[i]
            d.relations[i].from = r.to
            d.relations[i].to = r.from
            d.relations[i].fromMultiplicity = r.toMultiplicity
            d.relations[i].toMultiplicity = r.fromMultiplicity
        }
    }

    func handleNodeTap(_ id: UUID, shift: Bool, option: Bool) {
        switch tool {
        case .relation(let kind):
            if let source = pendingSource {
                let ok = addRelation(kind, from: source, to: id)
                pendingSource = nil
                if ok && !option { tool = .select }
            } else {
                pendingSource = id
            }
        case .node:
            selectOnly(id)
            tool = .select
        case .select:
            if shift { toggleSelection(id) } else { selectOnly(id) }
        }
    }

    // MARK: Hit-Tests (View-Koordinaten)

    func nodeAt(view p: CGPoint) -> UUID? {
        let w = toWorld(p)
        return diagram.nodes.reversed().first { EdgeGeometry.rect(of: $0).contains(w) }?.id
    }

    func relationAt(view p: CGPoint) -> UUID? {
        let w = toWorld(p)
        let tolerance = 7 / zoom
        let lines = EdgeGeometry.polylines(for: diagram)
        var best: (id: UUID, dist: CGFloat)?
        for r in diagram.relations {
            guard let pts = lines[r.id] else { continue }
            let dist = EdgeGeometry.distance(from: w, to: pts)
            if dist < tolerance, dist < (best?.dist ?? .infinity) { best = (r.id, dist) }
        }
        return best?.id
    }

    func nodes(intersecting viewRect: CGRect) -> Set<UUID> {
        let a = toWorld(viewRect.origin)
        let b = toWorld(CGPoint(x: viewRect.maxX, y: viewRect.maxY))
        let world = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        return Set(diagram.nodes.filter { EdgeGeometry.rect(of: $0).intersects(world) }.map(\.id))
    }

    // MARK: Kamera

    func pan(by delta: CGSize) {
        animationTask?.cancel()
        offset = CGPoint(x: offset.x + delta.width, y: offset.y + delta.height)
    }

    func setOffset(_ p: CGPoint) {
        animationTask?.cancel()
        offset = p
    }

    func applyZoom(factor: CGFloat, around p: CGPoint) {
        animationTask?.cancel()
        let newZoom = min(max(zoom * factor, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        guard abs(newZoom - zoom) > 0.0001 else { return }
        let w = toWorld(p)
        zoom = newZoom
        offset = CGPoint(x: p.x - w.x * newZoom, y: p.y - w.y * newZoom)
    }

    func zoomIn() { animateZoom(to: zoom * 1.25) }
    func zoomOut() { animateZoom(to: zoom / 1.25) }
    func resetZoom() { animateZoom(to: 1) }

    private func animateZoom(to target: CGFloat) {
        let p = viewCenter
        let w = toWorld(p)
        let z = min(max(target, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        animateCamera(zoom: z, offset: CGPoint(x: p.x - w.x * z, y: p.y - w.y * z))
    }

    func contentBounds() -> CGRect? {
        guard !diagram.nodes.isEmpty else { return nil }
        var r = CGRect.null
        for n in diagram.nodes { r = r.union(EdgeGeometry.rect(of: n)) }
        for pts in EdgeGeometry.polylines(for: diagram).values {
            for p in pts { r = r.union(CGRect(x: p.x, y: p.y, width: 0.1, height: 0.1)) }
        }
        return r.insetBy(dx: -24, dy: -24)
    }

    func fitToContent(animated: Bool = true) {
        guard canvasSize.width > 10, canvasSize.height > 10 else { needsInitialFit = true; return }
        guard let b = contentBounds() else {
            animateCamera(zoom: 1, offset: viewCenter, animated: animated)
            return
        }
        let margin: CGFloat = 60
        let availW = max(canvasSize.width - margin * 2, 100)
        let availH = max(canvasSize.height - margin * 2 - 40, 100)   // Platz für HUD oben/unten
        let z = min(max(min(availW / b.width, availH / b.height, 1.25), Self.zoomRange.lowerBound),
                    Self.zoomRange.upperBound)
        let o = CGPoint(x: canvasSize.width / 2 - b.midX * z, y: canvasSize.height / 2 - b.midY * z)
        animateCamera(zoom: z, offset: o, animated: animated)
    }

    func canvasDidResize(_ size: CGSize) {
        canvasSize = size
        if needsInitialFit, size.width > 10 {
            needsInitialFit = false
            fitToContent(animated: false)
        }
    }

    // MARK: Animation (manuell getaktet, damit Canvas-Ebenen synchron mitlaufen)

    private func animate(duration: Double, _ step: @escaping (CGFloat) -> Void) {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled {
                let t = min(Date().timeIntervalSince(start) / duration, 1)
                let eased = 1 - pow(1 - t, 3)          // easeOutCubic
                step(CGFloat(eased))
                if t >= 1 { break }
                try? await Task.sleep(for: .milliseconds(8))
            }
        }
    }

    func animateCamera(zoom z: CGFloat, offset o: CGPoint, animated: Bool = true) {
        guard animated else {
            animationTask?.cancel()
            zoom = z; offset = o
            return
        }
        let z0 = zoom, o0 = offset
        animate(duration: 0.28) { [weak self] e in
            guard let self else { return }
            self.zoom = z0 + (z - z0) * e
            self.offset = CGPoint(x: o0.x + (o.x - o0.x) * e, y: o0.y + (o.y - o0.y) * e)
        }
    }

    func autoLayout() {
        let targets = AutoLayout.arrange(diagram)
        guard !targets.isEmpty else { return }
        beginInteraction()
        let starts = Dictionary(uniqueKeysWithValues: diagram.nodes.map { ($0.id, $0.origin) })
        animate(duration: 0.45) { [weak self] e in
            guard let self else { return }
            self.mutateLive { d in
                for i in d.nodes.indices {
                    let id = d.nodes[i].id
                    if let s = starts[id], let t = targets[id] {
                        d.nodes[i].origin = CGPoint(x: s.x + (t.x - s.x) * e, y: s.y + (t.y - s.y) * e)
                    }
                }
            }
            if e >= 1 {
                Task { @MainActor in self.fitToContent() }
            }
        }
    }

    // MARK: Toast

    func showToast(_ text: String, _ kind: Toast.Kind = .success) {
        withAnimation(.easeOut(duration: 0.2)) { toast = Toast(text: text, kind: kind) }
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.toast = nil }
        }
    }

    // MARK: Bindings für den Inspector

    func nodeBinding(_ id: UUID) -> Binding<UMLNode> {
        Binding(
            get: { [weak self] in self?.node(id) ?? .placeholder },
            set: { [weak self] newValue in
                self?.mutate(coalesce: "node-\(id)") { d in
                    if let i = d.nodes.firstIndex(where: { $0.id == id }) { d.nodes[i] = newValue }
                }
            }
        )
    }

    func relationBinding(_ id: UUID) -> Binding<UMLRelation> {
        Binding(
            get: { [weak self] in
                self?.relation(id) ?? UMLRelation(kind: .association, from: UUID(), to: UUID())
            },
            set: { [weak self] newValue in
                guard let self else { return }
                var value = newValue
                // Notizen dürfen nur über Anker verbunden werden
                if let a = self.node(value.from), let b = self.node(value.to),
                   (a.kind == .note || b.kind == .note) {
                    value.kind = .anchor
                }
                self.mutate(coalesce: "rel-\(id)") { d in
                    if let i = d.relations.firstIndex(where: { $0.id == id }) { d.relations[i] = value }
                }
            }
        )
    }

    var diagramNameBinding: Binding<String> {
        Binding(
            get: { [weak self] in self?.diagram.name ?? "" },
            set: { [weak self] v in self?.mutate(coalesce: "diagram-name") { $0.name = v } }
        )
    }

    var sanitizedFileName: String {
        let base = diagram.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = base.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        return cleaned.isEmpty ? "Diagramm" : cleaned
    }
}
