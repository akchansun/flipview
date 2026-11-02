import AppKit

enum MarkupTool: String, CaseIterable {
    case browse
    case pen
    case arrow
    case rect
    case text

    var isDrawing: Bool { self != .browse }

    var cursor: NSCursor {
        switch self {
        case .browse: return .arrow
        case .pen, .arrow, .rect: return .crosshair
        case .text: return .iBeam
        }
    }
}

enum MarkupColor: String, CaseIterable, Equatable {
    case red
    case orange
    case yellow
    case green
    case blue
    case white
    case black

    var nsColor: NSColor {
        switch self {
        case .red: return NSColor(srgbRed: 1, green: 0.23, blue: 0.19, alpha: 1)
        case .orange: return NSColor(srgbRed: 1, green: 0.58, blue: 0, alpha: 1)
        case .yellow: return NSColor(srgbRed: 1, green: 0.8, blue: 0, alpha: 1)
        case .green: return NSColor(srgbRed: 0.2, green: 0.84, blue: 0.29, alpha: 1)
        case .blue: return NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
        case .white: return .white
        case .black: return .black
        }
    }
}

/// One markup object in **image-normalized** coordinates (origin bottom-left, 0…1).
struct MarkupItem: Identifiable, Equatable {
    let id: UUID
    var color: MarkupColor
    var kind: Kind

    enum Kind: Equatable {
        case stroke(points: [CGPoint])
        case arrow(start: CGPoint, end: CGPoint)
        case rect(start: CGPoint, end: CGPoint)
        case text(origin: CGPoint, string: String)
    }

    init(id: UUID = UUID(), color: MarkupColor, kind: Kind) {
        self.id = id
        self.color = color
        self.kind = kind
    }

    func transformed(by op: ImageOp) -> MarkupItem {
        func map(_ p: CGPoint) -> CGPoint {
            switch op {
            case .rotateRight: return CGPoint(x: p.y, y: 1 - p.x)
            case .rotateLeft: return CGPoint(x: 1 - p.y, y: p.x)
            case .flipHorizontal: return CGPoint(x: 1 - p.x, y: p.y)
            case .flipVertical: return CGPoint(x: p.x, y: 1 - p.y)
            }
        }
        switch kind {
        case .stroke(let points):
            return MarkupItem(id: id, color: color, kind: .stroke(points: points.map(map)))
        case .arrow(let start, let end):
            return MarkupItem(id: id, color: color, kind: .arrow(start: map(start), end: map(end)))
        case .rect(let start, let end):
            return MarkupItem(id: id, color: color, kind: .rect(start: map(start), end: map(end)))
        case .text(let origin, let string):
            return MarkupItem(id: id, color: color, kind: .text(origin: map(origin), string: string))
        }
    }
}

enum ImageMarkup {
    static func draw(_ items: [MarkupItem], in imageRect: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, imageRect.width > 1, imageRect.height > 1 else { return }
        let line = max(2, min(imageRect.width, imageRect.height) * 0.01)
        for item in items {
            ctx.saveGState()
            ctx.setStrokeColor(item.color.nsColor.cgColor)
            ctx.setFillColor(item.color.nsColor.cgColor)
            ctx.setLineWidth(line)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            switch item.kind {
            case .stroke(let points):
                drawStroke(points, in: imageRect, context: ctx, line: line)
            case .arrow(let start, let end):
                drawArrow(from: denorm(start, in: imageRect), to: denorm(end, in: imageRect), context: ctx, line: line)
            case .rect(let start, let end):
                let a = denorm(start, in: imageRect)
                let b = denorm(end, in: imageRect)
                let rect = CGRect(
                    x: min(a.x, b.x),
                    y: min(a.y, b.y),
                    width: abs(a.x - b.x),
                    height: abs(a.y - b.y)
                )
                ctx.stroke(rect)
            case .text(let origin, let string):
                drawText(string, at: denorm(origin, in: imageRect), color: item.color.nsColor, imageRect: imageRect)
            }
            ctx.restoreGState()
        }
    }

    static func bake(_ items: [MarkupItem], onto image: CGImage) -> CGImage? {
        guard !items.isEmpty else { return image }
        let width = image.width
        let height = image.height
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        draw(items, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage() ?? image
    }

    static func composite(image: NSImage, items: [MarkupItem]) -> NSImage {
        guard !items.isEmpty, let cg = ImageLoader.cgImage(from: image) else { return image }
        guard let baked = bake(items, onto: cg) else { return image }
        return ImageLoader.image(from: baked)
    }

    private static func denorm(_ p: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
    }

    private static func drawStroke(_ points: [CGPoint], in imageRect: CGRect, context ctx: CGContext, line: CGFloat) {
        let mapped = points.map { denorm($0, in: imageRect) }
        guard let first = mapped.first else { return }
        if mapped.count == 1 {
            ctx.fillEllipse(in: CGRect(x: first.x - line / 2, y: first.y - line / 2, width: line, height: line))
            return
        }
        ctx.beginPath()
        ctx.move(to: first)
        for point in mapped.dropFirst() {
            ctx.addLine(to: point)
        }
        ctx.strokePath()
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, context ctx: CGContext, line: CGFloat) {
        ctx.beginPath()
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = line * 4.2
        let a1 = angle + .pi * 0.82
        let a2 = angle - .pi * 0.82
        ctx.beginPath()
        ctx.move(to: end)
        ctx.addLine(to: CGPoint(x: end.x + cos(a1) * head, y: end.y + sin(a1) * head))
        ctx.move(to: end)
        ctx.addLine(to: CGPoint(x: end.x + cos(a2) * head, y: end.y + sin(a2) * head))
        ctx.strokePath()
    }

    private static func drawText(_ string: String, at origin: CGPoint, color: NSColor, imageRect: CGRect) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let size = max(14, min(imageRect.width, imageRect.height) * 0.045)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: color,
            .strokeColor: NSColor.black.withAlphaComponent(0.55),
            .strokeWidth: -2.0
        ]
        trimmed.draw(at: origin, withAttributes: attrs)
    }
}
