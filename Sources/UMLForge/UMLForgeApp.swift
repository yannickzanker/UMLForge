import SwiftUI
import AppKit

@main
struct UMLForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DiagramStore()

    var body: some Scene {
        Window("UMLForge", id: "main") {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1080, minHeight: 680)
                .onAppear { appDelegate.store = store }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1440, height: 900)
        .commands { AppCommands(store: store) }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: DiagramStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nötig, wenn die App per `swift run` ohne .app-Bundle startet
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store else { return .terminateNow }
        return store.confirmDiscardChanges() ? .terminateNow : .terminateCancel
    }
}

// MARK: - Root

struct RootView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Theme.background)

            // Inhalt startet rechts neben der eingeklappten Sidebar.
            // Die Sidebar klappt als Overlay auf – hier gibt es keinen Reflow.
            HStack(spacing: 0) {
                Color.clear.frame(width: HoverSidebar.collapsedWidth)
                DiagramCanvasView()
                InspectorPanel()
            }

            HoverSidebar()
        }
        .ignoresSafeArea()
    }
}

// MARK: - Menü

struct AppCommands: Commands {
    @ObservedObject var store: DiagramStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Neues Diagramm") { store.newDiagram() }
                .keyboardShortcut("n")
            Button("Öffnen …") { store.openDocument() }
                .keyboardShortcut("o")
        }

        CommandGroup(replacing: .saveItem) {
            Button("Speichern") { store.save() }
                .keyboardShortcut("s")
            Button("Speichern unter …") { store.saveAs() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("Als PNG exportieren …") { store.exportImage(.png) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            Button("Als PDF exportieren …") { store.exportImage(.pdf) }
            Button("PlantUML-Code kopieren") { store.copyPlantUML() }
                .keyboardShortcut("c", modifiers: [.command, .option])
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Widerrufen") { store.undo() }
                .keyboardShortcut("z")
                .disabled(!store.canUndo)
            Button("Wiederholen") { store.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!store.canRedo)
        }

        CommandMenu("Diagramm") {
            Button("Duplizieren") { store.duplicateSelection() }
                .keyboardShortcut("d")
                .disabled(store.selectedNodes.isEmpty)
            Button("Automatisch anordnen") { store.autoLayout() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Divider()
            Button("Vergrößern") { store.zoomIn() }
                .keyboardShortcut("+")
            Button("Verkleinern") { store.zoomOut() }
                .keyboardShortcut("-")
            Button("Einpassen") { store.fitToContent() }
                .keyboardShortcut("0")
            Button("Originalgröße") { store.resetZoom() }
                .keyboardShortcut("1")
            Divider()
            Toggle("Raster anzeigen", isOn: $store.showGrid)
                .keyboardShortcut("'")
            Toggle("Am Raster ausrichten", isOn: $store.snapToGrid)
        }
    }
}
