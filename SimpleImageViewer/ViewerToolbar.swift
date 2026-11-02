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
                    toolButton(.browse, symbol: "hand.point.up.left", key: .toolBrowse)
                    toolButton(.pen, symbol: "pencil", key: .toolPen)
                    toolButton(.arrow, symbol: "arrow.up.right", key: .toolArrow)
                    toolButton(.rect, symbol: "rectangle", key: .toolRect)
                    toolButton(.text, symbol: "textformat", key: .toolText)
                }

                colorDots

                Spacer(minLength: 12)

                group {
                    iconButton("arrow.uturn.backward", key: .undoEdit, enabled: session.isDirty) {
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
                .buttonStyle(.plain)
                .help(language.t(.markupColor))
                .disabled(!session.hasImage)
            }
        }
        .padding(.leading, 6)
    }
}
