import SwiftUI

struct ToolbarHoverTip: Equatable {
    var text: String
    var x: CGFloat
    var y: CGFloat
}

/// Always-on top bar: browse, zoom, rotate/flip, markup, save, print.
struct ViewerToolbarBar: View {
    @EnvironmentObject private var session: ImageSession
    @EnvironmentObject private var language: LanguageManager
    @Binding var hoverTip: ToolbarHoverTip?
    @State private var hoverTask: Task<Void, Never>?
    @State private var barWidth: CGFloat = 1600
    @State private var showMarkupPad = false
    @State private var showMorePad = false

    private enum Density: Equatable {
        case full
        case twoRow
        case compact
    }

    private var density: Density {
        if barWidth >= 1360 { return .full }
        if barWidth >= 900 { return .twoRow }
        return .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if density == .twoRow {
                Divider()
                markupRow
            }
        }
        .background(.bar)
        .coordinateSpace(name: "toolbar")
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear { barWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, width in
                        barWidth = width
                    }
            }
        }
        .popover(isPresented: $session.showAdjustColor, arrowEdge: .bottom) {
            ColorAdjustPopover()
                .environmentObject(session)
                .environmentObject(language)
        }
        .popover(isPresented: $session.showInspector, arrowEdge: .bottom) {
            InspectorPopover()
                .environmentObject(session)
                .environmentObject(language)
        }
        .onChange(of: density) { _, new in
            if new != .compact {
                showMarkupPad = false
                showMorePad = false
            }
        }
        .onChange(of: session.showAdjustColor) { _, on in
            if on { showMorePad = false }
        }
        .onChange(of: session.showInspector) { _, on in
            if on { showMorePad = false }
        }
        .onChange(of: session.showAdjustSize) { _, on in
            if on { showMorePad = false }
        }
        .onDisappear {
            hoverTask?.cancel()
            hoverTip = nil
        }
    }

    private var mainRow: some View {
        HStack(spacing: 3) {
            navGroup
            hairline
            zoomGroup
            switch density {
            case .full:
                hairline
                transformGroup
                hairline
                adjustGroup
                hairline
                markupToolGroup
                styleCluster
            case .twoRow:
                hairline
                transformGroup
                hairline
                adjustGroup
            case .compact:
                hairline
                overflowButton(
                    symbol: markupGlyph,
                    key: .toolbarMarkup,
                    selected: session.markupTool.isMarkupInk || showMarkupPad
                ) {
                    showMorePad = false
                    showMarkupPad.toggle()
                }
                .popover(isPresented: $showMarkupPad, arrowEdge: .bottom) {
                    markupPad
                }
                overflowButton(symbol: "ellipsis.circle", key: .toolbarMore, selected: showMorePad) {
                    showMarkupPad = false
                    showMorePad.toggle()
                }
                .popover(isPresented: $showMorePad, arrowEdge: .bottom) {
                    morePad
                }
            }
            Spacer(minLength: 8)
            fileGroup
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(height: 38)
    }

    private var markupRow: some View {
        HStack(spacing: 3) {
            markupToolGroup
            styleCluster
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(height: 38)
    }

    private var navGroup: some View {
        group {
            iconButton("chevron.left", key: .previousImage, enabled: session.canNavigate) {
                session.navigate(.previous)
            }
            iconButton("chevron.right", key: .nextImage, enabled: session.canNavigate) {
                session.navigate(.next)
            }
        }
    }

    private var zoomGroup: some View {
        group {
            iconButton("minus.magnifyingglass", key: .zoomOut) {
                session.requestZoom(.out)
            }
            iconButton("arrow.down.right.and.arrow.up.left", key: .fitToWindow) {
                session.requestZoom(.fit)
            }
            iconButton("plus.magnifyingglass", key: .zoomIn) {
                session.requestZoom(.in)
            }
            iconButton("square", key: .actualSize) {
                session.requestZoom(.actual)
            }
        }
    }

    private var transformGroup: some View {
        group {
            iconButton("rotate.left", key: .rotateLeft) {
                session.apply(.rotateLeft)
            }
            iconButton("rotate.right", key: .rotateRight) {
                session.apply(.rotateRight)
            }
            iconButton("arrow.left.and.right.righttriangle.left.righttriangle.right", key: .flipHorizontal) {
                session.apply(.flipHorizontal)
            }
            iconButton("arrow.up.and.down.righttriangle.up.righttriangle.down", key: .flipVertical) {
                session.apply(.flipVertical)
            }
        }
    }

    private var adjustGroup: some View {
        group {
            cropButton
            iconButton("slider.horizontal.3", key: .adjustColor) {
                session.beginColorAdjust()
            }
            iconButton("arrow.up.left.and.arrow.down.right", key: .adjustSize) {
                session.showAdjustSize = true
            }
            iconButton("info.circle", key: .inspector) {
                session.showInspector.toggle()
            }
            iconButton("person.fill.viewfinder", key: .removeBackground) {
                session.removeBackground()
            }
        }
    }

    private var markupToolGroup: some View {
        group {
            toolButton(.browse, symbol: "hand.point.up.left", key: .toolBrowse)
            toolButton(.pen, symbol: "pencil", key: .toolPen)
            toolButton(.line, symbol: "line.diagonal", key: .toolLine)
            toolButton(.arrow, symbol: "arrow.up.right", key: .toolArrow)
            toolButton(.rect, symbol: "rectangle", key: .toolRect)
            toolButton(.roundRect, symbol: "rectangle.roundedtop", key: .toolRoundRect)
            toolButton(.oval, symbol: "oval", key: .toolOval)
            toolButton(.highlight, symbol: "highlighter", key: .toolHighlight)
            toolButton(.text, symbol: "textformat", key: .toolText)
        }
    }

    private var styleCluster: some View {
        HStack(spacing: 3) {
            fillToggle
            textBackgroundButton
            colorDots
            weightButtons
            fontSizeButtons
        }
    }

    private var fileGroup: some View {
        group {
            iconButton("arrow.uturn.backward", key: .undoEdit, enabled: session.isDirty || session.isEditingMarkupText) {
                if session.undoTextEditorIfNeeded() { return }
                session.undoLastEdit()
            }
            iconButton("square.and.arrow.down", key: .save, enabled: session.isDirty) {
                session.saveInPlace()
            }
            iconButton("square.and.arrow.up", key: .saveAsEllipsis) {
                session.saveAs()
            }
            iconButton("printer", key: .printEllipsis) {
                session.printCurrent()
            }
            iconButton("trash", key: .moveToTrashEllipsis) {
                session.requestDelete()
            }
        }
    }

    private var cropButton: some View {
        Button {
            guard session.hasImage else { return }
            if session.markupTool == .crop, session.cropSelection != nil {
                session.applyCrop()
            } else {
                session.setMarkupTool(.crop)
            }
        } label: {
            Image(systemName: "crop")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
                .opacity(session.hasImage ? 1 : 0.35)
                .background(
                    session.markupTool == .crop ? Color.accentColor.opacity(0.28) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .toolbarHoverTip(language.t(session.cropSelection == nil ? .toolCrop : .crop), schedule: scheduleHoverTip)
    }

    private var markupGlyph: String {
        switch session.markupTool {
        case .browse, .crop: return "scribble.variable"
        case .pen: return "pencil"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rect: return "rectangle"
        case .roundRect: return "rectangle.roundedtop"
        case .oval: return "oval"
        case .highlight: return "highlighter"
        case .text: return "textformat"
        }
    }

    private var markupPad: some View {
        VStack(alignment: .leading, spacing: 8) {
            markupToolGroup
            styleCluster
        }
        .padding(12)
    }

    private var morePad: some View {
        VStack(alignment: .leading, spacing: 8) {
            transformGroup
            adjustGroup
        }
        .padding(12)
    }

    private func overflowButton(symbol: String, key: L10n.Key, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
                .background(
                    selected ? Color.accentColor.opacity(0.28) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .toolbarHoverTip(language.t(key), schedule: scheduleHoverTip)
    }

    private func scheduleHoverTip(_ tip: ToolbarHoverTip?) {
        hoverTask?.cancel()
        if let tip {
            if hoverTip != nil {
                hoverTip = tip
                return
            }
            hoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(240))
                guard !Task.isCancelled else { return }
                hoverTip = tip
            }
        } else {
            hoverTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                guard !Task.isCancelled else { return }
                hoverTip = nil
            }
        }
    }

    private var hairline: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 5)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 1, content: content)
    }

    private func toolButton(_ tool: MarkupTool, symbol: String, key: L10n.Key) -> some View {
        let selected = session.markupTool == tool
        let tip = language.t(key)
        return Button {
            guard session.hasImage else { return }
            session.setMarkupTool(tool)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
                .opacity(session.hasImage ? 1 : 0.35)
                .background(selected ? Color.accentColor.opacity(0.28) : Color.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .toolbarHoverTip(tip, schedule: scheduleHoverTip)
    }

    private func iconButton(_ symbol: String, key: L10n.Key, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        let active = session.hasImage && enabled
        let tip = language.t(key)
        return Button {
            guard active else { return }
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
                .opacity(active ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .toolbarHoverTip(tip, schedule: scheduleHoverTip)
    }

    private var fillToggle: some View {
        let selectedCanFill = session.markupItems.first(where: { $0.id == session.selectedMarkupID })?.canFill == true
        let enabled = session.hasImage && (session.markupTool.canFill || selectedCanFill)
        let filled = enabled && session.markupFilled
        return Button {
            guard enabled else { return }
            session.setMarkupFilled(!session.markupFilled)
        } label: {
            Image(systemName: filled ? "square.fill" : "square")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
                .opacity(enabled ? 1 : 0.35)
                .background(
                    filled ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .toolbarHoverTip(language.t(session.markupFilled ? .markupFill : .markupStroke), schedule: scheduleHoverTip)
        .padding(.leading, 4)
    }

    private var textBackgroundButton: some View {
        let selectedIsText = session.markupItems.first(where: { $0.id == session.selectedMarkupID })?.isText == true
        let active = session.markupTool == .text || session.isEditingMarkupText || selectedIsText
        return Button {
            guard session.hasImage else { return }
            session.setMarkupTextBackground(!session.markupFilled)
        } label: {
            Text("A")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(session.markupFilled ? Color.white : Color.primary)
                .frame(width: 22, height: 16)
                .background(
                    session.markupFilled ? Color.accentColor : Color.primary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                )
                .frame(width: 28, height: 24)
                .opacity(session.hasImage ? 1 : 0.35)
                .background(
                    session.markupFilled && active
                        ? Color.accentColor.opacity(0.18)
                        : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .toolbarHoverTip(language.t(.textBackground), schedule: scheduleHoverTip)
        .padding(.leading, 2)
    }

    private var colorDots: some View {
        HStack(spacing: 4) {
            ForEach(MarkupColor.allCases, id: \.self) { color in
                Button {
                    guard session.hasImage else { return }
                    session.setMarkupColor(color)
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(nsColor: color.nsColor))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle().strokeBorder(
                                    session.markupColor == color ? Color.primary : Color.primary.opacity(0.25),
                                    lineWidth: session.markupColor == color ? 2 : 0.5
                                )
                            )
                    }
                    .frame(width: 22, height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(session.hasImage ? 1 : 0.35)
                .toolbarHoverTip(language.t(color.helpKey), schedule: scheduleHoverTip)
            }
        }
        .padding(.leading, 6)
    }

    private var weightButtons: some View {
        HStack(spacing: 2) {
            ForEach(MarkupWeight.allCases, id: \.self) { weight in
                Button {
                    guard session.hasImage else { return }
                    session.setMarkupWeight(weight)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(session.markupWeight == weight ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.06))
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: 14, height: weight.sampleHeight)
                    }
                    .frame(width: 28, height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(session.hasImage ? 1 : 0.35)
                .toolbarHoverTip(language.t(weight.helpKey), schedule: scheduleHoverTip)
            }
        }
        .padding(.leading, 4)
        .accessibilityLabel(language.t(.markupWeight))
    }

    private var fontSizeButtons: some View {
        HStack(spacing: 1) {
            ForEach(MarkupFontSize.allCases, id: \.self) { size in
                Button {
                    guard session.hasImage else { return }
                    session.setMarkupFontSize(size)
                } label: {
                    Text("A")
                        .font(.system(size: size.samplePointSize, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 26, height: 24)
                        .background(
                            session.markupFontSize == size ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(session.hasImage ? 1 : 0.35)
                .toolbarHoverTip(language.t(size.helpKey), schedule: scheduleHoverTip)
            }
        }
        .padding(.leading, 4)
        .accessibilityLabel(language.t(.markupFontSize))
    }
}

private struct ColorAdjustPopover: View {
    @EnvironmentObject private var session: ImageSession
    @EnvironmentObject private var language: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.t(.adjustColor))
                .font(.headline)
            slider(.adjustExposure, value: binding(\.exposure), range: -2...2)
            slider(.adjustContrast, value: binding(\.contrast), range: 0.5...2)
            slider(.adjustBrightness, value: binding(\.brightness), range: -0.5...0.5)
            slider(.adjustSaturation, value: binding(\.saturation), range: 0...2)
            slider(.adjustHighlights, value: binding(\.highlights), range: 0...1)
            slider(.adjustShadows, value: binding(\.shadows), range: -1...1)
            slider(.adjustTemperature, value: binding(\.temperature), range: -1...1)
            slider(.adjustTint, value: binding(\.tint), range: -1...1)
            slider(.adjustSepia, value: binding(\.sepia), range: 0...1)
            slider(.adjustSharpness, value: binding(\.sharpness), range: 0...2)
            HStack {
                Toggle(language.t(.adjustAutoLevels), isOn: autoBinding)
                    .toggleStyle(.checkbox)
                Spacer()
                Button(language.t(.adjustReset)) {
                    session.resetColorAdjust()
                }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func binding(_ keyPath: WritableKeyPath<ColorAdjust, Double>) -> Binding<Double> {
        Binding(
            get: { session.colorAdjust[keyPath: keyPath] },
            set: { value in
                var next = session.colorAdjust
                next[keyPath: keyPath] = value
                session.setColorAdjust(next)
            }
        )
    }

    private var autoBinding: Binding<Bool> {
        Binding(
            get: { session.colorAdjust.autoLevels },
            set: { value in
                var next = session.colorAdjust
                next.autoLevels = value
                session.setColorAdjust(next)
            }
        )
    }

    private func slider(_ key: L10n.Key, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(language.t(key))
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: value, in: range)
        }
    }
}

private struct InspectorPopover: View {
    @EnvironmentObject private var session: ImageSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(session.inspectorRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.0)
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .trailing)
                    Text(row.1)
                        .textSelection(.enabled)
                }
                .font(.system(size: 12))
            }
        }
        .padding(14)
        .frame(minWidth: 280, alignment: .leading)
    }
}

struct AdjustSizeSheet: View {
    @EnvironmentObject private var session: ImageSession
    @EnvironmentObject private var language: LanguageManager
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var percentText = "100"
    @State private var keepAspect = true
    @State private var aspect: CGFloat = 1
    @State private var original = NSSize.zero
    @State private var syncingSize = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.t(.adjustSize))
                .font(.headline)
            HStack {
                Text(language.t(.adjustWidth))
                    .frame(width: 56, alignment: .trailing)
                TextField("", text: $widthText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .onChange(of: widthText) { _, new in
                        guard !syncingSize else { return }
                        syncPercentFromWidth(new)
                        guard keepAspect, let w = Double(new), w > 0, aspect > 0 else { return }
                        let next = String(max(1, Int((w / Double(aspect)).rounded())))
                        if next != heightText { heightText = next }
                    }
                Text("px")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(language.t(.adjustHeight))
                    .frame(width: 56, alignment: .trailing)
                TextField("", text: $heightText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .onChange(of: heightText) { _, new in
                        guard !syncingSize else { return }
                        guard keepAspect, let h = Double(new), h > 0, aspect > 0 else { return }
                        let next = String(max(1, Int((h * Double(aspect)).rounded())))
                        if next != widthText { widthText = next }
                        syncPercentFromWidth(next)
                    }
                Text("px")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(language.t(.adjustPercent))
                    .frame(width: 56, alignment: .trailing)
                TextField("", text: $percentText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .onChange(of: percentText) { _, new in
                        applyPercent(new)
                    }
                Text("%")
                    .foregroundStyle(.secondary)
            }
            Toggle(language.t(.adjustKeepAspect), isOn: $keepAspect)
                .toggleStyle(.checkbox)
            if let dpi = session.sourceDPILabel {
                Text("\(language.t(.inspectorDPI)): \(dpi)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                ForEach([640, 1024, 1920], id: \.self) { preset in
                    Button("\(preset)") {
                        applyPreset(preset)
                    }
                }
                Button("50%") {
                    applyPercent("50")
                }
                Button("100%") {
                    applyPercent("100")
                }
            }
            .buttonStyle(.bordered)
            HStack {
                Spacer()
                Button(language.t(.cancel)) {
                    session.showAdjustSize = false
                }
                Button(language.t(.ok)) {
                    let w = Int(widthText) ?? Int(session.displayedPixelSize.width)
                    let h = Int(heightText) ?? Int(session.displayedPixelSize.height)
                    session.applyResize(width: w, height: h)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            let px = session.displayedPixelSize
            original = px
            widthText = String(Int(px.width))
            heightText = String(Int(px.height))
            percentText = "100"
            aspect = px.height > 0 ? px.width / px.height : 1
        }
    }

    private func applyPreset(_ longest: Int) {
        let px = original.width > 0 ? original : session.displayedPixelSize
        guard px.width > 0, px.height > 0 else { return }
        let scale = CGFloat(longest) / max(px.width, px.height)
        syncingSize = true
        widthText = String(max(1, Int((px.width * scale).rounded())))
        heightText = String(max(1, Int((px.height * scale).rounded())))
        percentText = String(max(1, Int((scale * 100).rounded())))
        syncingSize = false
    }

    private func applyPercent(_ raw: String) {
        guard !syncingSize, let p = Double(raw), p > 0, original.width > 0, original.height > 0 else { return }
        syncingSize = true
        percentText = raw
        widthText = String(max(1, Int((original.width * p / 100).rounded())))
        heightText = String(max(1, Int((original.height * p / 100).rounded())))
        syncingSize = false
    }

    private func syncPercentFromWidth(_ raw: String) {
        guard original.width > 0, let w = Double(raw), w > 0 else { return }
        let next = String(max(1, Int((w / Double(original.width) * 100).rounded())))
        if next != percentText {
            syncingSize = true
            percentText = next
            syncingSize = false
        }
    }
}

private extension View {
    func toolbarHoverTip(_ text: String, schedule: @escaping (ToolbarHoverTip?) -> Void) -> some View {
        modifier(ToolbarHoverTipModifier(text: text, schedule: schedule))
    }
}

private struct ToolbarHoverTipModifier: ViewModifier {
    let text: String
    let schedule: (ToolbarHoverTip?) -> Void
    @State private var anchor = CGPoint(x: 40, y: 50)

    func body(content: Content) -> some View {
        content
            .accessibilityLabel(text)
            .background(
                GeometryReader { geo in
                    let frame = geo.frame(in: .named("toolbar"))
                    Color.clear
                        .onAppear { anchor = CGPoint(x: frame.midX, y: frame.maxY + 14) }
                        .onChange(of: frame) { _, new in
                            anchor = CGPoint(x: new.midX, y: new.maxY + 14)
                        }
                }
            )
            .onHover { inside in
                if inside {
                    schedule(ToolbarHoverTip(text: text, x: anchor.x, y: anchor.y))
                } else {
                    schedule(nil)
                }
            }
    }
}
