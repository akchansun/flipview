import SwiftUI

/// Always-on top bar: browse, zoom, rotate/flip, markup, save, print.
struct ViewerToolbarBar: View {
    @EnvironmentObject private var session: ImageSession
    @EnvironmentObject private var language: LanguageManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                group {
                    iconButton("chevron.left", key: .previousImage, enabled: session.canNavigate) {
                        session.navigate(.previous)
                    }
                    iconButton("chevron.right", key: .nextImage, enabled: session.canNavigate) {
                        session.navigate(.next)
                    }
                }

                hairline

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

                hairline

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

                hairline

                group {
                    Button {
                        if session.markupTool == .crop, session.cropSelection != nil {
                            session.applyCrop()
                        } else {
                            session.setMarkupTool(.crop)
                        }
                    } label: {
                        Image(systemName: "crop")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, height: 24)
                            .background(
                                session.markupTool == .crop ? Color.accentColor.opacity(0.28) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(language.t(session.cropSelection == nil ? .toolCrop : .crop))
                    .disabled(!session.hasImage)
                    Button {
                        session.beginColorAdjust()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(language.t(.adjustColor))
                    .disabled(!session.hasImage)
                    .popover(isPresented: $session.showAdjustColor, arrowEdge: .bottom) {
                        ColorAdjustPopover()
                            .environmentObject(session)
                            .environmentObject(language)
                    }
                    Button {
                        session.showAdjustSize = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(language.t(.adjustSize))
                    .disabled(!session.hasImage)
                    Button {
                        session.showInspector.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 28, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(language.t(.inspector))
                    .disabled(!session.hasImage)
                    .popover(isPresented: $session.showInspector, arrowEdge: .bottom) {
                        InspectorPopover()
                            .environmentObject(session)
                            .environmentObject(language)
                    }
                }

                hairline

                group {
                    toolButton(.browse, symbol: "hand.point.up.left", key: .toolBrowse)
                    toolButton(.pen, symbol: "pencil", key: .toolPen)
                    toolButton(.arrow, symbol: "arrow.up.right", key: .toolArrow)
                    toolButton(.rect, symbol: "rectangle", key: .toolRect)
                    toolButton(.oval, symbol: "oval", key: .toolOval)
                    toolButton(.text, symbol: "textformat", key: .toolText)
                }

                colorDots
                weightButtons
                fontSizeButtons

                Spacer(minLength: 12)

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
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .frame(height: 38)
        .background(.bar)
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
        return Button {
            session.setMarkupTool(tool)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
                .background(selected ? Color.accentColor.opacity(0.28) : Color.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(language.t(key))
        .disabled(!session.hasImage)
    }

    private func iconButton(_ symbol: String, key: L10n.Key, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .help(language.t(key))
        .disabled(!session.hasImage || !enabled)
    }

    private var colorDots: some View {
        HStack(spacing: 4) {
            ForEach(MarkupColor.allCases, id: \.self) { color in
                Button {
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
                .help(language.t(.markupColor))
                .disabled(!session.hasImage)
            }
        }
        .padding(.leading, 6)
    }

    private var weightButtons: some View {
        HStack(spacing: 2) {
            ForEach(MarkupWeight.allCases, id: \.self) { weight in
                Button {
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
                .help(language.t(weight.helpKey))
                .disabled(!session.hasImage)
            }
        }
        .padding(.leading, 4)
        .accessibilityLabel(language.t(.markupWeight))
    }

    private var fontSizeButtons: some View {
        HStack(spacing: 1) {
            ForEach(MarkupFontSize.allCases, id: \.self) { size in
                Button {
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
                .help(language.t(size.helpKey))
                .disabled(!session.hasImage)
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
                        .frame(width: 72, alignment: .trailing)
                    Text(row.1)
                        .textSelection(.enabled)
                }
                .font(.system(size: 12))
            }
        }
        .padding(14)
        .frame(minWidth: 240, alignment: .leading)
    }
}

struct AdjustSizeSheet: View {
    @EnvironmentObject private var session: ImageSession
    @EnvironmentObject private var language: LanguageManager
    @State private var widthText = ""
    @State private var heightText = ""
    @State private var keepAspect = true
    @State private var aspect: CGFloat = 1

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
                        guard keepAspect, let h = Double(new), h > 0, aspect > 0 else { return }
                        let next = String(max(1, Int((h * Double(aspect)).rounded())))
                        if next != widthText { widthText = next }
                    }
                Text("px")
                    .foregroundStyle(.secondary)
            }
            Toggle(language.t(.adjustKeepAspect), isOn: $keepAspect)
                .toggleStyle(.checkbox)
            HStack {
                ForEach([640, 1024, 1920], id: \.self) { preset in
                    Button("\(preset)") {
                        applyPreset(preset)
                    }
                }
                Button("50%") {
                    let px = session.displayedPixelSize
                    widthText = String(max(1, Int(px.width / 2)))
                    heightText = String(max(1, Int(px.height / 2)))
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
            widthText = String(Int(px.width))
            heightText = String(Int(px.height))
            aspect = px.height > 0 ? px.width / px.height : 1
        }
    }

    private func applyPreset(_ longest: Int) {
        let px = session.displayedPixelSize
        guard px.width > 0, px.height > 0 else { return }
        let scale = CGFloat(longest) / max(px.width, px.height)
        widthText = String(max(1, Int((px.width * scale).rounded())))
        heightText = String(max(1, Int((px.height * scale).rounded())))
    }
}
