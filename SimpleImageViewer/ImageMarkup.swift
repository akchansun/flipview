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

    func translated(by delta: CGPoint) -> MarkupItem {
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x + delta.x, y: p.y + delta.y)
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

    static func hitTest(_ items: [MarkupItem], at viewPoint: CGPoint, imageRect: CGRect) -> MarkupItem? {
        guard imageRect.width > 1, imageRect.height > 1 else { return nil }
        let tol = max(12, min(imageRect.width, imageRect.height) * 0.02)
        for item in items.reversed() {
            if hit(item, at: viewPoint, imageRect: imageRect, tolerance: tol) {
                return item
            }
        }
        return nil
    }

    static func drawSelection(_ item: MarkupItem, in imageRect: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        var box = boundingBox(item, in: imageRect).insetBy(dx: -6, dy: -6)
        if box.width < 12 { box.size.width = 12 }
        if box.height < 12 { box.size.height = 12 }
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [4, 3])
        ctx.stroke(box)
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.setLineDash(phase: 3.5, lengths: [4, 3])
        ctx.stroke(box)
        ctx.restoreGState()
    }

    static func clampTranslation(_ item: MarkupItem, delta: CGPoint) -> CGPoint {
        let box = normalizedBounds(item)
        var dx = delta.x
        var dy = delta.y
        if box.minX + dx < 0 { dx = -box.minX }
        if box.maxX + dx > 1 { dx = 1 - box.maxX }
        if box.minY + dy < 0 { dy = -box.minY }
        if box.maxY + dy > 1 { dy = 1 - box.maxY }
        return CGPoint(x: dx, y: dy)
    }

    static func textAttributes(color: NSColor, imageRect: CGRect) -> [NSAttributedString.Key: Any] {
        let size = max(14, min(imageRect.width, imageRect.height) * 0.045)
        return [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: color,
            .strokeColor: NSColor.black.withAlphaComponent(0.55),
            .strokeWidth: -2.0
        ]
    }

    private static func hit(_ item: MarkupItem, at point: CGPoint, imageRect: CGRect, tolerance: CGFloat) -> Bool {
        switch item.kind {
        case .text(let origin, let string):
            return textFrame(string, origin: origin, color: item.color, imageRect: imageRect)
                .insetBy(dx: -6, dy: -6)
                .contains(point)
        case .rect(let start, let end):
            let a = denorm(start, in: imageRect)
            let b = denorm(end, in: imageRect)
            let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            return rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .arrow(let start, let end):
            return distance(point, segmentFrom: denorm(start, in: imageRect), to: denorm(end, in: imageRect)) <= tolerance
        case .stroke(let points):
            let mapped = points.map { denorm($0, in: imageRect) }
            if mapped.count == 1, let only = mapped.first {
                return hypot(point.x - only.x, point.y - only.y) <= tolerance
            }
            for pair in zip(mapped, mapped.dropFirst()) {
                if distance(point, segmentFrom: pair.0, to: pair.1) <= tolerance {
                    return true
                }
            }
            return false
        }
    }

    private static func boundingBox(_ item: MarkupItem, in imageRect: CGRect) -> CGRect {
        switch item.kind {
        case .text(let origin, let string):
            return textFrame(string, origin: origin, color: item.color, imageRect: imageRect)
        case .rect(let start, let end):
            let a = denorm(start, in: imageRect)
            let b = denorm(end, in: imageRect)
            return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
        case .arrow(let start, let end):
            let a = denorm(start, in: imageRect)
            let b = denorm(end, in: imageRect)
            return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
        case .stroke(let points):
            let mapped = points.map { denorm($0, in: imageRect) }
            guard let first = mapped.first else { return .zero }
            var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
            for p in mapped.dropFirst() {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
        }
    }

    private static func normalizedBounds(_ item: MarkupItem) -> CGRect {
        let pts: [CGPoint]
        switch item.kind {
        case .text(let origin, _):
            pts = [origin, CGPoint(x: origin.x + 0.08, y: origin.y + 0.04)]
        case .rect(let start, let end), .arrow(let start, let end):
            pts = [start, end]
        case .stroke(let points):
            pts = points
        }
        guard let first = pts.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for p in pts.dropFirst() {
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func textFrame(_ string: String, origin: CGPoint, color: MarkupColor, imageRect: CGRect) -> CGRect {
        let originView = denorm(origin, in: imageRect)
        let size = (string as NSString).size(withAttributes: textAttributes(color: color.nsColor, imageRect: imageRect))
        return CGRect(x: originView.x, y: originView.y, width: max(size.width, 12), height: max(size.height, 12))
    }

    private static func distance(_ p: CGPoint, segmentFrom a: CGPoint, to b: CGPoint) -> CGFloat {
        let abx = b.x - a.x, aby = b.y - a.y
        let apx = p.x - a.x, apy = p.y - a.y
        let ab2 = abx * abx + aby * aby
        if ab2 < 0.0001 { return hypot(apx, apy) }
        let t = max(0, min(1, (apx * abx + apy * aby) / ab2))
        return hypot(p.x - (a.x + t * abx), p.y - (a.y + t * aby))
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
        trimmed.draw(at: origin, withAttributes: textAttributes(color: color, imageRect: imageRect))
    }
}

/// Drawn in the image document so markup zooms/pans with the photo and stays under the toolbar.
final class MarkupCanvasView: NSView {
    var items: [MarkupItem] = [] {
        didSet { needsDisplay = true }
    }
    var draft: MarkupItem? {
        didSet { needsDisplay = true }
    }
    var selectedID: UUID? {
        didSet { needsDisplay = true }
    }
    var hiddenID: UUID? {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { false }
    override var clipsToBounds: Bool {
        get { true }
        set { }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        var visible = items.filter { $0.id != hiddenID }
        if let draft { visible.append(draft) }
        ImageMarkup.draw(visible, in: bounds)
        let selected: MarkupItem?
        if let draft, draft.id == selectedID {
            selected = draft
        } else if let id = selectedID, id != hiddenID {
            selected = items.first(where: { $0.id == id })
        } else {
            selected = nil
        }
        if let selected {
            ImageMarkup.drawSelection(selected, in: bounds)
        }
    }
}
