import SwiftUI
import AppKit

// MARK: - Buttons

struct ThemedButtonStyle: ButtonStyle {
    enum Kind { case normal, primary, danger, ghost }
    var kind: Kind = .normal
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        ThemedButtonBody(configuration: configuration, kind: kind, fullWidth: fullWidth)
    }
}

private struct ThemedButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: ThemedButtonStyle.Kind
    let fullWidth: Bool
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
        configuration.label
            .font(Typo.bodyMedium)
            .foregroundStyle(foreground)
            .environment(\.iconHighlighted, hovering)
            .environment(\.iconTint, iconTint)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 30)
            .background(shape.fill(background))
            .overlay(shape.strokeBorder(stroke, lineWidth: 1))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering = isEnabled && $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var pressed: Bool { configuration.isPressed }

    private var foreground: Color {
        switch kind {
        case .primary: Theme.bgBottom          // dunkler Text auf Orange (Kontrast)
        case .danger: Theme.error
        case .normal, .ghost: Theme.textPrimary
        }
    }

    private var iconTint: Color? {
        switch kind {
        case .primary: Theme.bgBottom
        case .danger: Theme.error
        default: nil
        }
    }

    private var background: Color {
        switch kind {
        case .primary: pressed ? Theme.accentPressed : (hovering ? Theme.accentHover : Theme.accent)
        case .normal, .danger: pressed ? Theme.input : (hovering ? Theme.panelHover : Theme.panel)
        case .ghost: pressed ? Theme.input : (hovering ? Theme.panelHover : .clear)
        }
    }

    private var stroke: Color {
        switch kind {
        case .primary, .ghost: .clear
        case .normal: pressed ? Theme.accentPressed : (hovering ? Theme.accent : Theme.border)
        case .danger: hovering ? Theme.error : Theme.border
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, size: size, active: active)
    }
}

private struct IconButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let size: CGFloat
    let active: Bool
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
        configuration.label
            .environment(\.iconHighlighted, hovering || active)
            .frame(width: size, height: size)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(active || hovering ? Theme.accent : Theme.border, lineWidth: 1))
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering = isEnabled && $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var fill: Color {
        if active { return Theme.accentFill(0.2) }
        if configuration.isPressed { return Theme.input }
        return hovering ? Theme.panelHover : Theme.panel
    }
}

struct ButtonLabel: View {
    let icon: Icon
    let title: String
    var body: some View {
        HStack(spacing: 7) {
            IconView(icon: icon, size: 16)
            Text(title)
        }
    }
}

// MARK: - Eingaben

struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String
    var mono = false

    @FocusState private var focused: Bool
    @State private var hovering = false

    init(_ placeholder: String, text: Binding<String>, mono: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.mono = mono
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.textMuted))
            .textFieldStyle(.plain)
            .font(mono ? Typo.mono : Typo.body)
            .foregroundStyle(Theme.textPrimary)
            .focused($focused)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(shape.fill(Theme.input))
            .overlay(shape.strokeBorder(focused ? Theme.accent : (hovering ? Theme.borderStrong : Theme.border), lineWidth: 1))
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: focused)
    }
}

struct ThemedTextEditor: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
        TextEditor(text: $text)
            .font(Typo.body)
            .foregroundStyle(Theme.textPrimary)
            .scrollContentBackground(.hidden)
            .focused($focused)
            .padding(.horizontal, 5)
            .padding(.vertical, 7)
            .frame(minHeight: 120)
            .background(shape.fill(Theme.input))
            .overlay(shape.strokeBorder(focused ? Theme.accent : Theme.border, lineWidth: 1))
            .animation(.easeOut(duration: 0.12), value: focused)
    }
}

struct ThemedToggle: View {
    let title: String
    @Binding var isOn: Bool
    @State private var hovering = false

    var body: some View {
        HStack {
            Text(title).font(Typo.body).foregroundStyle(Theme.textPrimary)
            Spacer()
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Theme.accent : Theme.input)
                    .overlay(Capsule().strokeBorder(isOn || hovering ? Theme.accent : Theme.border, lineWidth: 1))
                Circle()
                    .fill(isOn ? Theme.bgBottom : Theme.textSecondary)
                    .frame(width: 12, height: 12)
                    .padding(3)
            }
            .frame(width: 32, height: 18)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeOut(duration: 0.16)) { isOn.toggle() } }
        .onHover { hovering = $0 }
    }
}

struct ThemedSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let knob: CGFloat = 14
            let w = max(geo.size.width - knob, 1)
            let fraction = (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound)
                / (range.upperBound - range.lowerBound)
            let x = fraction * w
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.input)
                    .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                    .frame(height: 6)
                Capsule().fill(Theme.accentFill(0.25))
                    .overlay(Capsule().strokeBorder(Theme.accent, lineWidth: 1))
                    .frame(width: x + knob / 2, height: 6)
                Circle()
                    .fill(dragging ? Theme.accentPressed : (hovering ? Theme.accentHover : Theme.accent))
                    .frame(width: knob, height: knob)
                    .offset(x: x)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        dragging = true
                        let f = min(max((v.location.x - knob / 2) / w, 0), 1)
                        value = range.lowerBound + f * (range.upperBound - range.lowerBound)
                    }
                    .onEnded { _ in dragging = false }
            )
            .onHover { hovering = $0 }
        }
        .frame(height: 20)
    }
}

// MARK: - Auswahl-Chips

struct ChoiceGrid<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    var columns = 2
    let title: (Item) -> String
    let icon: (Item) -> Icon

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(items, id: \.self) { item in
                ChoiceChip(title: title(item), icon: icon(item), selected: item == selection) {
                    selection = item
                }
            }
        }
    }
}

struct ChoiceChip: View {
    let title: String
    let icon: Icon
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
        Button(action: action) {
            HStack(spacing: 7) {
                IconView(icon: icon, size: 18)
                Text(title)
                    .font(Typo.labelMedium)
                    .foregroundStyle(selected || hovering ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background(shape.fill(selected ? Theme.accentFill(0.25) : (hovering ? Theme.panelHover : Theme.panelRaised)))
            .overlay(shape.strokeBorder(selected ? Theme.accent : .clear, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .environment(\.iconHighlighted, selected || hovering)
        .onHover { hovering = $0 }
    }
}

struct FlagChip: View {
    let label: String
    let help: String
    @Binding var isOn: Bool
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
        Text(label)
            .font(Typo.monoSmall)
            .foregroundStyle(isOn ? Theme.textPrimary : (hovering ? Theme.textSecondary : Theme.textMuted))
            .frame(width: 24, height: 30)
            .background(shape.fill(isOn ? Theme.accentFill(0.25) : (hovering ? Theme.panelHover : Theme.panelRaised)))
            .overlay(shape.strokeBorder(isOn ? Theme.accent : .clear, lineWidth: 1))
            .contentShape(shape)
            .onTapGesture { isOn.toggle() }
            .onHover { hovering = $0 }
            .help(help)
    }
}

struct ListRow<Content: View>: View {
    var selected = false
    let action: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusChip, style: .continuous)
        Button(action: action) {
            content()
                .padding(.horizontal, 8)
                .frame(minHeight: 30)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(shape.fill(selected ? Theme.accentFill(0.25) : (hovering ? Theme.panelHover : .clear)))
                .overlay(shape.strokeBorder(selected ? Theme.accent : .clear, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .environment(\.iconHighlighted, selected || hovering)
        .onHover { hovering = $0 }
    }
}

struct VisibilityPicker: View {
    @Binding var selection: Visibility
    @State private var open = false
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
        Button { open.toggle() } label: {
            Text(selection.rawValue)
                .font(Typo.mono)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 28, height: 30)
                .background(shape.fill(hovering ? Theme.panelHover : Theme.panel))
                .overlay(shape.strokeBorder(hovering || open ? Theme.accent : Theme.border, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Sichtbarkeit: \(selection.title)")
        .popover(isPresented: $open, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Visibility.allCases) { v in
                    ListRow(selected: v == selection, action: { selection = v; open = false }) {
                        HStack(spacing: 10) {
                            Text(v.rawValue).font(Typo.mono).foregroundStyle(Theme.textPrimary).frame(width: 12)
                            Text(v.title).font(Typo.body).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .padding(6)
            .frame(width: 168)
            .background(Theme.panel)
            .presentationBackground(Theme.panel)
        }
    }
}

// MARK: - Struktur

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(Typo.section)
            .tracking(Typo.sectionTracking)
            .foregroundStyle(Theme.textMuted)
            .lineLimit(1)
    }
}

struct InspectorSection<Content: View, Trailing: View>: View {
    let title: String
    let trailing: () -> Trailing
    let content: () -> Content

    init(_ title: String,
         @ViewBuilder trailing: @escaping () -> Trailing,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(title)
                Spacer()
                trailing()
            }
            .frame(minHeight: 20)
            content()
        }
    }
}

extension InspectorSection where Trailing == EmptyView {
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title, trailing: { EmptyView() }, content: content)
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(Theme.border).frame(height: 1) }
}

struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typo.monoSmall)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.input))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}

/// Fläche, über die sich das Fenster verschieben lässt (versteckte Titelleiste).
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 { window?.performZoom(nil) } else { window?.performDrag(with: event) }
        }
    }
}

// MARK: - Scrollbereich mit schlanker Scrollbar

/// ScrollView mit eigener Scrollbar: ~10px, transparent im Ruhezustand,
/// Griff in Rahmenfarbe, Akzentfarbe beim Hovern/Ziehen.
struct ThemedScrollView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    private struct Metrics: Equatable {
        var content: CGFloat = 0
        var visible: CGFloat = 0
        var offset: CGFloat = 0
    }

    @State private var position = ScrollPosition(edge: .top)
    @State private var metrics = Metrics()
    @State private var hoveringArea = false
    @State private var hoveringThumb = false
    @State private var dragStart: CGFloat?
    @State private var recentlyScrolled = false
    @State private var fadeTask: Task<Void, Never>?

    var body: some View {
        ScrollView(.vertical) {
            content()
        }
        .scrollIndicators(.never)
        .scrollPosition($position)
        .onScrollGeometryChange(for: Metrics.self) { g in
            Metrics(content: g.contentSize.height,
                    visible: g.containerSize.height,
                    offset: g.contentOffset.y + g.contentInsets.top)
        } action: { old, new in
            metrics = new
            if old.offset != new.offset { flashScrollbar() }
        }
        .overlay(alignment: .topTrailing) { scrollbar }
        .onHover { hoveringArea = $0 }
    }

    private func flashScrollbar() {
        recentlyScrolled = true
        fadeTask?.cancel()
        fadeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { recentlyScrolled = false }
        }
    }

    @ViewBuilder private var scrollbar: some View {
        if metrics.content > metrics.visible + 1, metrics.visible > 20 {
            let track = metrics.visible - 8
            let thumbHeight = max(28, track * metrics.visible / metrics.content)
            let maxOffset = metrics.content - metrics.visible
            let progress = min(max(metrics.offset / maxOffset, 0), 1)
            let y = 4 + progress * (track - thumbHeight)
            let active = hoveringThumb || dragStart != nil

            Capsule()
                .fill(active ? Theme.accent : Theme.border)
                .frame(width: active ? 7 : 5, height: thumbHeight)
                .frame(width: 10, height: thumbHeight)
                .contentShape(Rectangle())
                .offset(y: y)
                .opacity(active || hoveringArea || recentlyScrolled ? 1 : 0)
                .onHover { hoveringThumb = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { v in
                            if dragStart == nil { dragStart = metrics.offset }
                            let ratio = maxOffset / max(track - thumbHeight, 1)
                            let target = min(max((dragStart ?? 0) + v.translation.height * ratio, 0), maxOffset)
                            position.scrollTo(y: target)
                        }
                        .onEnded { _ in dragStart = nil }
                )
                .padding(.trailing, 1)
                .animation(.easeOut(duration: 0.15), value: active)
                .animation(.easeOut(duration: 0.2), value: hoveringArea)
        }
    }
}
