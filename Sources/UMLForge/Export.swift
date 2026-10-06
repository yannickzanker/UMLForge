import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension DiagramStore {
    static let fileType = UTType(filenameExtension: "umlforge", conformingTo: .json) ?? .json

    /// Fragt bei ungespeicherten Änderungen nach. `true` = darf fortfahren.
    func confirmDiscardChanges() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Änderungen an „\(diagram.name.isEmpty ? "Unbenannt" : diagram.name)“ speichern?"
        alert.informativeText = "Ohne Speichern gehen die Änderungen verloren."
        alert.addButton(withTitle: "Speichern")
        alert.addButton(withTitle: "Nicht speichern")
        alert.addButton(withTitle: "Abbrechen")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save()
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }

    func newDiagram() {
        guard confirmDiscardChanges() else { return }
        load(Diagram(name: "Neues Diagramm"), url: nil)
        animateCamera(zoom: 1, offset: viewCenter)
    }

    func openDocument() {
        guard confirmDiscardChanges() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [Self.fileType, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let d = try JSONDecoder().decode(Diagram.self, from: data)
            load(d, url: url)
            fitToContent(animated: false)
            showToast("„\(url.lastPathComponent)“ geöffnet")
        } catch {
            showToast("Datei ist kein gültiges UMLForge-Diagramm", .error)
        }
    }

    @discardableResult
    func save() -> Bool {
        if let url = fileURL { return write(to: url) }
        return saveAs()
    }

    @discardableResult
    func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [Self.fileType]
        panel.nameFieldStringValue = sanitizedFileName + ".umlforge"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return write(to: url)
    }

    private func write(to url: URL) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(diagram).write(to: url, options: .atomic)
            fileURL = url
            markClean()
            showToast("Gespeichert: \(url.lastPathComponent)")
            return true
        } catch {
            showToast("Speichern fehlgeschlagen: \(error.localizedDescription)", .error)
            return false
        }
    }

    func exportImage(_ format: ExportFormat) {
        guard !diagram.nodes.isEmpty, let content = contentBounds() else {
            showToast("Das Diagramm ist leer – nichts zu exportieren", .info)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format == .png ? .png : .pdf]
        panel.nameFieldStringValue = sanitizedFileName + (format == .png ? ".png" : ".pdf")
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let bounds = content.insetBy(dx: -32, dy: -32).integral
        let view = DiagramSnapshotView(diagram: diagram, bounds: bounds)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(bounds.size)

        switch format {
        case .png:
            renderer.scale = 3      // scharf auf Retina und im Druck
            guard let cg = renderer.cgImage,
                  let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
                showToast("PNG konnte nicht erzeugt werden", .error)
                return
            }
            do {
                try data.write(to: url, options: .atomic)
                showToast("Exportiert: \(url.lastPathComponent)")
            } catch {
                showToast("Export fehlgeschlagen: \(error.localizedDescription)", .error)
            }

        case .pdf:
            var ok = false
            renderer.render { size, draw in
                var box = CGRect(origin: .zero, size: size)
                guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
                ctx.beginPDFPage(nil)
                draw(ctx)
                ctx.endPDFPage()
                ctx.closePDF()
                ok = true
            }
            if ok { showToast("Exportiert: \(url.lastPathComponent)") }
            else { showToast("PDF konnte nicht erzeugt werden", .error) }
        }
    }

    func copyPlantUML() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(diagram.plantUML(), forType: .string)
        showToast("PlantUML-Code in die Zwischenablage kopiert")
    }
}

/// Statische, nicht interaktive Darstellung für den Export (Zoom 1, kein HUD).
struct DiagramSnapshotView: View {
    let diagram: Diagram
    let bounds: CGRect

    var body: some View {
        let offset = CGPoint(x: -bounds.minX, y: -bounds.minY)
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Theme.background)
            Canvas { ctx, _ in
                EdgeRenderer.draw(diagram, in: &ctx, zoom: 1, offset: offset, selected: nil)
            }
            ForEach(diagram.nodes) { n in
                let s = NodeMetrics.size(of: n)
                NodeCard(node: n, size: s)
                    .position(x: n.origin.x + offset.x + s.width / 2, y: n.origin.y + offset.y + s.height / 2)
            }
        }
        .frame(width: bounds.width, height: bounds.height)
    }
}
