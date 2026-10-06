import SwiftUI

struct InspectorPanel: View {
    @EnvironmentObject private var store: DiagramStore
    static let width: CGFloat = 320

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Hairline()
            ThemedScrollView {
                content
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity)
        .background(Theme.panel)
        .overlay(alignment: .leading) { Rectangle().fill(Theme.border).frame(width: 1) }
    }

    private var headerInfo: (icon: Icon, title: String, subtitle: String) {
        if let rid = store.selectedRelation, let r = store.relation(rid) {
            return (r.kind.icon, r.kind.title, "Beziehung")
        }
        if store.selectedNodes.count == 1, let id = store.selectedNodes.first, let n = store.node(id) {
            return (n.kind.icon, n.displayName, n.kind.longTitle)
        }
        if store.selectedNodes.count > 1 {
            return (.duplicate, "\(store.selectedNodes.count) Elemente", "Mehrfachauswahl")
        }
        return (.logo, store.diagram.name.isEmpty ? "Unbenannt" : store.diagram.name, "Diagramm")
    }

    private var header: some View {
        let info = headerInfo
        return HStack(spacing: 10) {
            IconView(icon: info.icon, size: 20, color: Theme.textPrimary)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous).fill(Theme.panelRaised))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .font(Typo.bodySemibold)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(info.subtitle)
                    .font(Typo.label)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(WindowDragArea())
    }

    @ViewBuilder private var content: some View {
        if let rid = store.selectedRelation, store.relation(rid) != nil {
            RelationInspector(id: rid).id(rid)
        } else if store.selectedNodes.count == 1, let id = store.selectedNodes.first, store.node(id) != nil {
            NodeInspector(id: id).id(id)
        } else if store.selectedNodes.count > 1 {
            MultiSelectionInspector()
        } else {
            DiagramInspector()
        }
    }
}

// MARK: - Knoten

private struct NodeInspector: View {
    @EnvironmentObject private var store: DiagramStore
    let id: UUID

    var body: some View {
        let node = store.nodeBinding(id)
        let n = node.wrappedValue

        VStack(alignment: .leading, spacing: 22) {
            InspectorSection("Typ") {
                ChoiceGrid(items: NodeKind.allCases, selection: node.kind, columns: 2,
                           title: { $0.title }, icon: { $0.icon })
            }

            if n.kind == .note {
                InspectorSection("Text") {
                    ThemedTextEditor(text: node.noteText)
                }
            } else {
                InspectorSection("Name") {
                    ThemedTextField("Name", text: node.name)
                }
                MemberListEditor(title: n.kind == .enumeration ? "Werte" : "Attribute",
                                 members: node.attributes, kind: n.kind, isOperations: false)
                MemberListEditor(title: "Operationen",
                                 members: node.operations, kind: n.kind, isOperations: true)
            }

            InspectorSection("Darstellung") {
                ThemedToggle(title: "Automatische Breite", isOn: Binding(
                    get: { node.wrappedValue.customWidth == nil },
                    set: { auto in
                        node.wrappedValue.customWidth = auto ? nil : NodeMetrics.size(of: node.wrappedValue).width
                    }))
                if let w = n.customWidth {
                    HStack(spacing: 10) {
                        ThemedSlider(value: Binding(
                            get: { w },
                            set: { node.wrappedValue.customWidth = ($0 / 2).rounded() * 2 }),
                                     range: 120...600)
                        Text("\(Int(w)) px")
                            .font(Typo.monoSmall)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }

            connections

            InspectorSection("Aktionen") {
                HStack(spacing: 8) {
                    Button { store.duplicateSelection() } label: { ButtonLabel(icon: .duplicate, title: "Duplizieren") }
                        .buttonStyle(ThemedButtonStyle(fullWidth: true))
                    Button { store.deleteSelection() } label: { ButtonLabel(icon: .trash, title: "Löschen") }
                        .buttonStyle(ThemedButtonStyle(kind: .danger, fullWidth: true))
                }
            }
        }
    }

    @ViewBuilder private var connections: some View {
        let relations = store.diagram.relations.filter { $0.from == id || $0.to == id }
        if !relations.isEmpty {
            InspectorSection("Beziehungen") {
                VStack(spacing: 2) {
                    ForEach(relations) { r in
                        let otherID = r.from == id ? r.to : r.from
                        let other = store.node(otherID)?.displayName ?? "?"
                        let outgoing = r.from == id
                        ListRow(action: { store.selectRelation(r.id) }) {
                            HStack(spacing: 8) {
                                IconView(icon: r.kind.icon, size: 18)
                                Text(outgoing ? "→" : "←")
                                    .font(Typo.mono)
                                    .foregroundStyle(Theme.textMuted)
                                Text(otherID == id ? "sich selbst" : other)
                                    .font(Typo.body)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(r.kind.shortTitle)
                                    .font(Typo.label)
                                    .foregroundStyle(Theme.textMuted)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct MemberListEditor: View {
    let title: String
    @Binding var members: [Member]
    let kind: NodeKind
    let isOperations: Bool

    private var placeholder: String {
        if isOperations { return "methode(): void" }
        return kind == .enumeration ? "WERT" : "attribut: Typ"
    }

    private var emptyText: String {
        if isOperations { return "Keine Operationen" }
        return kind == .enumeration ? "Keine Werte" : "Keine Attribute"
    }

    var body: some View {
        InspectorSection(title, trailing: {
            Button(action: add) { IconView(icon: .plus, size: 15) }
                .buttonStyle(IconButtonStyle(size: 24))
                .help("\(title) hinzufügen")
        }) {
            if members.isEmpty {
                Text(emptyText)
                    .font(Typo.label)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.vertical, 2)
            }
            VStack(spacing: 6) {
                ForEach($members) { $member in
                    MemberRow(member: $member,
                              showVisibility: !(kind == .enumeration && !isOperations),
                              isOperation: isOperations,
                              placeholder: placeholder) {
                        let removeID = member.id
                        members.removeAll { $0.id == removeID }
                    }
                }
            }
        }
    }

    private func add() {
        let visibility: Visibility = (isOperations || kind == .interface || kind == .enumeration)
            ? .publicAccess : .privateAccess
        members.append(Member(visibility: visibility, text: placeholder, isAbstract: kind == .interface && isOperations))
    }
}

private struct MemberRow: View {
    @Binding var member: Member
    let showVisibility: Bool
    let isOperation: Bool
    let placeholder: String
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            if showVisibility {
                VisibilityPicker(selection: $member.visibility)
            }
            ThemedTextField(placeholder, text: $member.text, mono: true)
            if showVisibility {
                FlagChip(label: "S", help: "Statisch (unterstrichen)", isOn: $member.isStatic)
            }
            if isOperation {
                FlagChip(label: "A", help: "Abstrakt (kursiv)", isOn: $member.isAbstract)
            }
            Button(action: onDelete) { IconView(icon: .xmark, size: 13) }
                .buttonStyle(IconButtonStyle(size: 26))
                .help("Entfernen")
        }
    }
}

// MARK: - Beziehung

private struct RelationInspector: View {
    @EnvironmentObject private var store: DiagramStore
    let id: UUID

    var body: some View {
        let rel = store.relationBinding(id)
        let r = rel.wrappedValue

        VStack(alignment: .leading, spacing: 22) {
            InspectorSection("Typ") {
                ChoiceGrid(items: RelationKind.allCases, selection: rel.kind, columns: 2,
                           title: { $0.shortTitle }, icon: { $0.icon })
                Text(r.kind.hint)
                    .font(Typo.label)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            InspectorSection("Richtung") {
                VStack(spacing: 6) {
                    endpoint("Quelle", r.from)
                    endpoint("Ziel", r.to)
                }
                Button { store.swapDirection(id) } label: { ButtonLabel(icon: .swap, title: "Richtung tauschen") }
                    .buttonStyle(ThemedButtonStyle(fullWidth: true))
            }

            InspectorSection("Beschriftung") {
                ThemedTextField("z. B. verwaltet", text: rel.label)
            }

            InspectorSection("Multiplizität") {
                HStack(spacing: 10) {
                    multiplicityField("Quelle", text: rel.fromMultiplicity)
                    multiplicityField("Ziel", text: rel.toMultiplicity)
                }
            }

            InspectorSection("Aktionen") {
                Button { store.deleteSelection() } label: { ButtonLabel(icon: .trash, title: "Beziehung löschen") }
                    .buttonStyle(ThemedButtonStyle(kind: .danger, fullWidth: true))
            }
        }
    }

    private func endpoint(_ label: String, _ nodeID: UUID) -> some View {
        let n = store.node(nodeID)
        return ListRow(action: { store.selectOnly(nodeID) }) {
            HStack(spacing: 8) {
                Text(label)
                    .font(Typo.label)
                    .foregroundStyle(Theme.textMuted)
                    .frame(width: 44, alignment: .leading)
                IconView(icon: n?.kind.icon ?? .classBox, size: 16)
                Text(n?.displayName ?? "–")
                    .font(Typo.body)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous).fill(Theme.panelRaised))
    }

    private func multiplicityField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Typo.label).foregroundStyle(Theme.textSecondary)
            ThemedTextField("–", text: text, mono: true)
            HStack(spacing: 4) {
                ForEach(["1", "0..1", "*", "1..*"], id: \.self) { preset in
                    Button { text.wrappedValue = preset } label: {
                        Text(preset)
                            .font(Typo.monoSmall)
                            .foregroundStyle(text.wrappedValue == preset ? Theme.textPrimary : Theme.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 22)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(text.wrappedValue == preset ? Theme.accentFill(0.25) : Theme.panelRaised))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(text.wrappedValue == preset ? Theme.accent : .clear, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Mehrfachauswahl

private struct MultiSelectionInspector: View {
    @EnvironmentObject private var store: DiagramStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            InspectorSection("Ausrichten") {
                HStack(spacing: 8) {
                    Button { store.align(.left) } label: { ButtonLabel(icon: .alignLeft, title: "Links") }
                        .buttonStyle(ThemedButtonStyle(fullWidth: true))
                    Button { store.align(.top) } label: { ButtonLabel(icon: .alignTop, title: "Oben") }
                        .buttonStyle(ThemedButtonStyle(fullWidth: true))
                }
            }
            InspectorSection("Aktionen") {
                HStack(spacing: 8) {
                    Button { store.duplicateSelection() } label: { ButtonLabel(icon: .duplicate, title: "Duplizieren") }
                        .buttonStyle(ThemedButtonStyle(fullWidth: true))
                    Button { store.deleteSelection() } label: { ButtonLabel(icon: .trash, title: "Löschen") }
                        .buttonStyle(ThemedButtonStyle(kind: .danger, fullWidth: true))
                }
            }
        }
    }
}

// MARK: - Diagramm

private struct DiagramInspector: View {
    @EnvironmentObject private var store: DiagramStore

    var body: some View {
        let d = store.diagram
        VStack(alignment: .leading, spacing: 22) {
            InspectorSection("Diagramm") {
                ThemedTextField("Name des Diagramms", text: store.diagramNameBinding)
            }

            InspectorSection("Übersicht") {
                VStack(spacing: 0) {
                    stat("Klassen", d.nodes.filter { $0.kind == .classType || $0.kind == .abstractClass }.count)
                    stat("Interfaces", d.nodes.filter { $0.kind == .interface }.count)
                    stat("Enums", d.nodes.filter { $0.kind == .enumeration }.count)
                    stat("Notizen", d.nodes.filter { $0.kind == .note }.count)
                    stat("Beziehungen", d.relations.count)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous).fill(Theme.panelRaised))
            }

            InspectorSection("Werkzeuge") {
                VStack(spacing: 8) {
                    Button { store.autoLayout() } label: { ButtonLabel(icon: .layout, title: "Automatisch anordnen") }
                        .buttonStyle(ThemedButtonStyle(kind: .primary, fullWidth: true))
                    Button { store.copyPlantUML() } label: { ButtonLabel(icon: .code, title: "PlantUML kopieren") }
                        .buttonStyle(ThemedButtonStyle(fullWidth: true))
                    HStack(spacing: 8) {
                        Button { store.exportImage(.png) } label: { ButtonLabel(icon: .image, title: "PNG") }
                            .buttonStyle(ThemedButtonStyle(fullWidth: true))
                        Button { store.exportImage(.pdf) } label: { ButtonLabel(icon: .pdf, title: "PDF") }
                            .buttonStyle(ThemedButtonStyle(fullWidth: true))
                    }
                }
            }

            InspectorSection("Tastenkürzel") {
                VStack(alignment: .leading, spacing: 7) {
                    keyRow("V", "Auswahl")
                    keyRow("C  A  I  E  N", "Klasse, Abstrakt, Interface, Enum, Notiz")
                    keyRow("L  P  G  R", "Assoziation, gerichtet, Vererbung, Realisierung")
                    keyRow("O  K  D  T", "Aggregation, Komposition, Abhängigkeit, Anker")
                    keyRow("⌫", "Auswahl löschen")
                    keyRow("←↑→↓", "Verschieben (⇧ = 10 px)")
                    keyRow("Esc", "Abbrechen")
                    keyRow("⌥", "Ziehen verschiebt Ansicht")
                }
            }
        }
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).font(Typo.body).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text("\(value)").font(Typo.mono).foregroundStyle(Theme.textPrimary)
        }
        .frame(height: 28)
    }

    private func keyRow(_ keys: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            KeyCap(text: keys)
            Text(text)
                .font(Typo.label)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
            Spacer(minLength: 0)
        }
    }
}
