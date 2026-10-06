import SwiftUI

struct SidebarItem: Identifiable {
    let id: String
    let title: String
    let icon: Icon
    var shortcut: String? = nil
    var isActive = false
    var isEnabled = true
    let action: () -> Void
}

struct SidebarSection: Identifiable {
    let id: String
    let title: String
    let items: [SidebarItem]
}

/// Schmale Icon-Spalte (60px), klappt beim Hovern als Overlay auf 250px auf – ohne Reflow des Inhalts.
struct HoverSidebar: View {
    static let collapsedWidth: CGFloat = 60
    static let expandedWidth: CGFloat = 250

    @EnvironmentObject private var store: DiagramStore
    @State private var progress: CGFloat = 0          // 0 = eingeklappt, 1 = aufgeklappt
    @State private var pinned = false
    @State private var collapseTask: Task<Void, Never>?

    /// 210 ms, easeOutCubic
    private let animation = Animation.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.21)

    private var width: CGFloat {
        Self.collapsedWidth + (Self.expandedWidth - Self.collapsedWidth) * progress
    }
    private var rowWidth: CGFloat { width - 16 }
    private var sectionTitleOpacity: Double { Double(max(0, (progress - 0.45) / 0.55)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WindowDragArea().frame(height: 38)       // Platz für die Fenster-Ampel
            brandRow
            Hairline().padding(.horizontal, 14).padding(.top, 10)

            ThemedScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        if index > 0 {
                            Hairline().padding(.horizontal, 14).padding(.vertical, 7)
                        }
                        sectionTitle(section.title)
                        ForEach(section.items) { item in
                            SidebarRow(item: item, progress: progress, rowWidth: rowWidth)
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Hairline().padding(.horizontal, 14)
            VStack(spacing: 2) {
                SidebarRow(item: SidebarItem(id: "undo", title: "Widerrufen", icon: .undo, shortcut: "⌘Z",
                                             isEnabled: store.canUndo) { store.undo() },
                           progress: progress, rowWidth: rowWidth)
                SidebarRow(item: SidebarItem(id: "redo", title: "Wiederholen", icon: .redo, shortcut: "⇧⌘Z",
                                             isEnabled: store.canRedo) { store.redo() },
                           progress: progress, rowWidth: rowWidth)
            }
            .padding(.vertical, 8)
        }
        .frame(width: width, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.panel)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.border).frame(width: 1) }
        .clipped()
        // Schatten proportional zum Aufklapp-Fortschritt
        .shadow(color: .black.opacity(0.55 * progress), radius: 26 * progress, x: 10 * progress, y: 0)
        .contentShape(Rectangle())
        .onHover(perform: hoverChanged)
    }

    // MARK: Kopfzeile

    private var brandRow: some View {
        ZStack(alignment: .leading) {
            IconView(icon: .logo, size: 22, color: Theme.textPrimary)
                .frame(width: 24, height: 24)
                .padding(.leading, 18)
            Text("UMLForge")
                .font(Typo.title)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: max(0, width - 50 - 52), alignment: .leading)
                .padding(.leading, 50)
                .opacity(Double(progress))
            Button { togglePin() } label: {
                IconView(icon: .pin, size: 16)
            }
            .buttonStyle(IconButtonStyle(size: 28, active: pinned))
            .help(pinned ? "Sidebar lösen" : "Sidebar anheften")
            .opacity(Double(progress))
            .allowsHitTesting(progress > 0.6)
            .padding(.leading, max(0, width - 40))
        }
        .frame(width: width, height: 30, alignment: .leading)
    }

    private func sectionTitle(_ title: String) -> some View {
        SectionTitle(title)
            .frame(width: max(0, width - 36), alignment: .leading)
            .padding(.leading, 18)
            .frame(height: 24, alignment: .leading)
            .opacity(sectionTitleOpacity)
    }

    // MARK: Einträge

    private var sections: [SidebarSection] {
        [
            SidebarSection(id: "werkzeug", title: "Werkzeug", items: [toolItem(.select)]),
            SidebarSection(id: "elemente", title: "Elemente",
                           items: NodeKind.allCases.map { toolItem(.node($0)) }),
            SidebarSection(id: "beziehungen", title: "Beziehungen",
                           items: RelationKind.allCases.map { toolItem(.relation($0)) }),
            SidebarSection(id: "anordnen", title: "Anordnen", items: [
                SidebarItem(id: "layout", title: "Automatisch anordnen", icon: .layout, shortcut: "⇧⌘L") { store.autoLayout() },
                SidebarItem(id: "dup", title: "Duplizieren", icon: .duplicate, shortcut: "⌘D",
                            isEnabled: !store.selectedNodes.isEmpty) { store.duplicateSelection() },
                SidebarItem(id: "del", title: "Löschen", icon: .trash, shortcut: "⌫",
                            isEnabled: !store.selectedNodes.isEmpty || store.selectedRelation != nil) { store.deleteSelection() }
            ]),
            SidebarSection(id: "ansicht", title: "Ansicht", items: [
                SidebarItem(id: "zin", title: "Vergrößern", icon: .zoomIn, shortcut: "⌘+") { store.zoomIn() },
                SidebarItem(id: "zout", title: "Verkleinern", icon: .zoomOut, shortcut: "⌘−") { store.zoomOut() },
                SidebarItem(id: "fit", title: "Einpassen", icon: .fit, shortcut: "⌘0") { store.fitToContent() },
                SidebarItem(id: "grid", title: "Raster anzeigen", icon: .grid, isActive: store.showGrid) { store.showGrid.toggle() },
                SidebarItem(id: "snap", title: "Am Raster ausrichten", icon: .magnet, isActive: store.snapToGrid) { store.snapToGrid.toggle() }
            ]),
            SidebarSection(id: "datei", title: "Datei", items: [
                SidebarItem(id: "new", title: "Neues Diagramm", icon: .newDoc, shortcut: "⌘N") { store.newDiagram() },
                SidebarItem(id: "open", title: "Öffnen …", icon: .open, shortcut: "⌘O") { store.openDocument() },
                SidebarItem(id: "save", title: "Speichern", icon: .save, shortcut: "⌘S") { store.save() },
                SidebarItem(id: "png", title: "Als PNG exportieren", icon: .image, shortcut: "⇧⌘E") { store.exportImage(.png) },
                SidebarItem(id: "pdf", title: "Als PDF exportieren", icon: .pdf) { store.exportImage(.pdf) },
                SidebarItem(id: "puml", title: "PlantUML kopieren", icon: .code, shortcut: "⌥⌘C") { store.copyPlantUML() }
            ])
        ]
    }

    private func toolItem(_ tool: Tool) -> SidebarItem {
        SidebarItem(id: "tool-\(tool)", title: tool.title, icon: tool.icon, shortcut: tool.shortcut,
                    isActive: store.tool == tool) {
            store.tool = (store.tool == tool && tool != .select) ? .select : tool
        }
    }

    // MARK: Hover-Logik

    private func hoverChanged(_ inside: Bool) {
        collapseTask?.cancel()
        if inside {
            setExpanded(true)
        } else if !pinned {
            // 220 ms Verzögerung verhindert Flackern beim kurzen Drüberstreifen
            collapseTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                setExpanded(false)
            }
        }
    }

    private func setExpanded(_ expanded: Bool) {
        let target: CGFloat = expanded ? 1 : 0
        guard progress != target else { return }
        store.sidebarCover = expanded ? Self.expandedWidth - Self.collapsedWidth : 0
        withAnimation(animation) { progress = target }
    }

    private func togglePin() {
        pinned.toggle()
        if pinned {
            collapseTask?.cancel()
            setExpanded(true)
        }
    }
}

// MARK: - Zeile

private struct SidebarRow: View {
    let item: SidebarItem
    let progress: CGFloat
    let rowWidth: CGFloat
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
        let highlighted = item.isActive || hovering
        // Icon fix bei x = 18 (8 Außen- + 10 Innenabstand), Beschriftung ab x = 50
        let labelWidth = max(0, rowWidth - 42 - 10)

        Button(action: item.action) {
            ZStack(alignment: .leading) {
                IconView(icon: item.icon, size: 20)
                    .frame(width: 24, height: 24)
                    .padding(.leading, 10)
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(Typo.body)
                        .foregroundStyle(highlighted ? Theme.textPrimary : Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    if let s = item.shortcut, labelWidth > 120 {
                        Text(s)
                            .font(Typo.monoSmall)
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize()
                    }
                }
                .frame(width: labelWidth, alignment: .leading)
                .padding(.leading, 42)
                .opacity(Double(progress))                       // proportionaler Reveal
            }
            .frame(width: max(rowWidth, 0), height: 34, alignment: .leading)
            .background(shape.fill(item.isActive ? Theme.accentFill(0.2) : (hovering ? Theme.panelHover : .clear)))
            .overlay(shape.strokeBorder(item.isActive ? Theme.accent : .clear, lineWidth: 1))
            .clipShape(shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .environment(\.iconHighlighted, highlighted)
        .disabled(!item.isEnabled)
        .opacity(item.isEnabled ? 1 : 0.38)
        .padding(.horizontal, 8)
        .onHover { hovering = item.isEnabled && $0 }
        .help(item.title)
    }
}
