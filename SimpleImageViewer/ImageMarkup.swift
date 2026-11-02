import AppKit

enum MarkupTool: String, CaseIterable {
    case browse
    case pen
    case arrow
    case rect
    case oval
    case text
    case crop

    var isDrawing: Bool { self != .browse }

    var isMarkupInk: Bool {
        switch self {
        case .pen, .arrow, .rect, .oval, .text: return true
        case .browse, .crop: return false
        }
    }

    var cursor: NSCursor {
        switch self {
        case .browse: return .arrow
        case .pen, .arrow, .rect, .oval, .crop: return .crosshair
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

enum MarkupFontSize: String, CaseIterable, Equatable {
    case small
    case regular
    case large
    case extra

    var scale: CGFloat {
        switch self {
        case .small: return 0.7
        case .regular: return 1
        case .large: return 1.5
        case .extra: return 2.15
        }
    }

    var samplePointSize: CGFloat {
        switch self {
        case .small: return 9
        case .regular: return 12
        case .large: return 16
        case .extra: return 20
        }
    }

    var helpKey: L10n.Key {
        switch self {
        case .small: return .fontSmall
        case .regular: return .fontRegular
        case .large: return .fontLarge
        case .extra: return .fontExtra
        }
    }
}

enum MarkupHandle: Equatable {
    case start
    case end
}

enum MarkupWeight: String, CaseIterable, Equatable {
    case thin
    case regular
    case thick
    case heavy

    /// Multiplier on a hairline base (~0.38% of the shorter image side).
    var scale: CGFloat {
        switch self {
        case .thin: return 0.16
        case .regular: return 1
        case .thick: return 2.3
        case .heavy: return 4
        }
    }

    var textScale: CGFloat {
        switch self {
        case .thin: return 0.78
        case .regular: return 1
        case .thick: return 1.4
        case .heavy: return 1.85
        }
    }

    var sampleHeight: CGFloat {
        switch self {
        case .thin: return 1
        case .regular: return 2.5
        case .thick: return 4
        case .heavy: return 6.5
        }
    }

    var helpKey: L10n.Key {
        switch self {
        case .thin: return .weightThin
        case .regular: return .weightRegular
        case .thick: return .weightThick
        case .heavy: return .weightHeavy
        }
    }
}

/// One markup object in **image-normalized** coordinates (origin bottom-left, 0…1).
struct MarkupItem: Identifiable, Equatable {
    let id: UUID
    var color: MarkupColor
    var weight: MarkupWeight
    var fontSize: MarkupFontSize
    var kind: Kind

    enum Kind: Equatable {
        case stroke(points: [CGPoint])
        case arrow(start: CGPoint, end: CGPoint)
        case rect(start: CGPoint, end: CGPoint)
        case oval(start: CGPoint, end: CGPoint)
        case text(origin: CGPoint, string: String)
    }

    init(
        id: UUID = UUID(),
        color: MarkupColor,
        weight: MarkupWeight = .regular,
        fontSize: MarkupFontSize = .regular,
        kind: Kind
    ) {
        self.id = id
        self.color = color
        self.weight = weight
        self.fontSize = fontSize
        self.kind = kind
    }

    var isText: Bool {
        if case .text = kind { return true }
        return false
    }

    func with(kind: Kind) -> MarkupItem {
        MarkupItem(id: id, color: color, weight: weight, fontSize: fontSize, kind: kind)
    }

    func translated(by delta: CGPoint) -> MarkupItem {
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x + delta.x, y: p.y + delta.y)
        }
        switch kind {
        case .stroke(let points):
            return with(kind: .stroke(points: points.map(map)))
        case .arrow(let start, let end):
            return with(kind: .arrow(start: map(start), end: map(end)))
        case .rect(let start, let end):
            return with(kind: .rect(start: map(start), end: map(end)))
        case .oval(let start, let end):
            return with(kind: .oval(start: map(start), end: map(end)))
        case .text(let origin, let string):
            return with(kind: .text(origin: map(origin), string: string))
        }
    }

    func transformed(by op: ImageOp) -> MarkupItem {
        func map(_ p: CGPoint) -> CGPoint {
            switch op {
            case .rotateRight: return CGPoint(x: p.y, y: 1 - p.x)
            case .rotateLeft: return CGPoint(x: 1 - p.y, y: p.x)
            case .flipHorizontal: return CGPoint(x: 1 - p.x, y: p.y)
            case .flipVertical: return CGPoint(x: p.x, y: 1 - p.y)
            case .crop(let rect):
                let box = rect.standardized
                let w = max(box.width, 0.0001)
                let h = max(box.height, 0.0001)
                return CGPoint(x: (p.x - box.minX) / w, y: (p.y - box.minY) / h)
            case .color, .resize:
                return p
            }
        }
        switch kind {
        case .stroke(let points):
            return with(kind: .stroke(points: points.map(map)))
        case .arrow(let start, let end):
            return with(kind: .arrow(start: map(start), end: map(end)))
        case .rect(let start, let end):
            return with(kind: .rect(start: map(start), end: map(end)))
        case .oval(let start, let end):
            return with(kind: .oval(start: map(start), end: map(end)))
        case .text(let origin, let string):
            return with(kind: .text(origin: map(origin), string: string))
        }
    }
}

enum ImageMarkup {
    static func lineWidth(for item: MarkupItem, in imageRect: CGRect) -> CGFloat {
        // 0.5pt is one device pixel on Retina — a true hairline, not a marker.
        max(0.5, min(imageRect.width, imageRect.height) * 0.0038 * item.weight.scale)
    }

    static func draw(_ items: [MarkupItem], in imageRect: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, imageRect.width > 1, imageRect.height > 1 else { return }
        for item in items {
            let line = lineWidth(for: item, in: imageRect)
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
                ctx.stroke(denormRect(start, end, in: imageRect))
            case .oval(let start, let end):
                ctx.strokeEllipse(in: denormRect(start, end, in: imageRect))
            case .text(let origin, let string):
                drawText(string, at: denorm(origin, in: imageRect), color: item.color.nsColor, imageRect: imageRect, fontSize: item.fontSize)
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
        for item in items.reversed() {
            let line = lineWidth(for: item, in: imageRect)
            if hit(item, at: viewPoint, imageRect: imageRect, tolerance: line / 2) {
                return item
            }
        }
        return nil
    }

    static func drawSelection(_ item: MarkupItem, in imageRect: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let line = lineWidth(for: item, in: imageRect)
        let outer = line / 2
        ctx.saveGState()
        switch item.kind {
        case .text(let origin, let string):
            strokeDashedRect(
                ctx,
                textFrame(string, origin: origin, color: item.color, fontSize: item.fontSize, imageRect: imageRect)
            )
        case .rect(let start, let end):
            strokeDashedRect(ctx, denormRect(start, end, in: imageRect).insetBy(dx: -outer, dy: -outer))
        case .oval(let start, let end):
            strokeDashedEllipse(ctx, denormRect(start, end, in: imageRect).insetBy(dx: -outer, dy: -outer))
        case .arrow(let start, let end):
            let path = arrowCGPath(
                from: denorm(start, in: imageRect),
                to: denorm(end, in: imageRect),
                line: line
            )
            strokeDashedPath(ctx, path, lineWidth: line + 1)
        case .stroke(let points):
            let mapped = points.map { denorm($0, in: imageRect) }
            if mapped.count == 1, let only = mapped.first {
                let d = line + 1
                strokeDashedEllipse(ctx, CGRect(x: only.x - d / 2, y: only.y - d / 2, width: d, height: d))
            } else {
                let path = CGMutablePath()
                if let first = mapped.first {
                    path.move(to: first)
                    for point in mapped.dropFirst() { path.addLine(to: point) }
                }
                strokeDashedPath(ctx, path, lineWidth: line + 1)
            }
        }
        ctx.setLineDash(phase: 0, lengths: [])
        for (_, point) in handles(for: item, in: imageRect) {
            let knob = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(knob)
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.75).cgColor)
            ctx.setLineWidth(1)
            ctx.stroke(knob)
        }
        ctx.restoreGState()
    }

    static func handles(for item: MarkupItem, in imageRect: CGRect) -> [(MarkupHandle, CGPoint)] {
        switch item.kind {
        case .arrow(let start, let end), .rect(let start, let end), .oval(let start, let end):
            return [(.start, denorm(start, in: imageRect)), (.end, denorm(end, in: imageRect))]
        default:
            return []
        }
    }

    static func handleHit(_ item: MarkupItem, at point: CGPoint, imageRect: CGRect) -> MarkupHandle? {
        for (handle, location) in handles(for: item, in: imageRect) {
            if hypot(point.x - location.x, point.y - location.y) <= 10 {
                return handle
            }
        }
        return nil
    }

    static func resized(_ item: MarkupItem, handle: MarkupHandle, to frac: CGPoint) -> MarkupItem {
        let clamped = CGPoint(x: min(max(frac.x, 0), 1), y: min(max(frac.y, 0), 1))
        switch item.kind {
        case .arrow(let start, let end):
            return item.with(kind: handle == .start ? .arrow(start: clamped, end: end) : .arrow(start: start, end: clamped))
        case .rect(let start, let end):
            return item.with(kind: handle == .start ? .rect(start: clamped, end: end) : .rect(start: start, end: clamped))
        case .oval(let start, let end):
            return item.with(kind: handle == .start ? .oval(start: clamped, end: end) : .oval(start: start, end: clamped))
        default:
            return item
        }
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

    static func textAttributes(color: NSColor, imageRect: CGRect, fontSize: MarkupFontSize = .regular) -> [NSAttributedString.Key: Any] {
        let size = max(12, min(imageRect.width, imageRect.height) * 0.042 * fontSize.scale)
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
            return textFrame(string, origin: origin, color: item.color, fontSize: item.fontSize, imageRect: imageRect)
                .contains(point)
        case .rect(let start, let end):
            let rect = denormRect(start, end, in: imageRect)
            let outer = rect.insetBy(dx: -tolerance, dy: -tolerance)
            guard outer.contains(point) else { return false }
            let inner = rect.insetBy(dx: tolerance, dy: tolerance)
            if inner.width <= 0 || inner.height <= 0 {
                return true
            }
            return !inner.contains(point)
        case .oval(let start, let end):
            let rect = denormRect(start, end, in: imageRect)
            if !ellipseContains(point, in: rect.insetBy(dx: -tolerance, dy: -tolerance)) {
                return false
            }
            let inner = rect.insetBy(dx: tolerance, dy: tolerance)
            if inner.width <= 0 || inner.height <= 0 {
                return true
            }
            return !ellipseContains(point, in: inner)
        case .arrow(let start, let end):
            let from = denorm(start, in: imageRect)
            let to = denorm(end, in: imageRect)
            if distance(point, segmentFrom: from, to: to) <= tolerance {
                return true
            }
            let line = lineWidth(for: item, in: imageRect)
            let angle = atan2(to.y - from.y, to.x - from.x)
            let head = line * 4.2
            let a1 = CGPoint(x: to.x + cos(angle + .pi * 0.82) * head, y: to.y + sin(angle + .pi * 0.82) * head)
            let a2 = CGPoint(x: to.x + cos(angle - .pi * 0.82) * head, y: to.y + sin(angle - .pi * 0.82) * head)
            return distance(point, segmentFrom: to, to: a1) <= tolerance
                || distance(point, segmentFrom: to, to: a2) <= tolerance
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

    private static func normalizedBounds(_ item: MarkupItem) -> CGRect {
        let pts: [CGPoint]
        switch item.kind {
        case .text(let origin, _):
            pts = [origin, CGPoint(x: origin.x + 0.08, y: origin.y + 0.04)]
        case .rect(let start, let end), .arrow(let start, let end), .oval(let start, let end):
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

    private static func textFrame(_ string: String, origin: CGPoint, color: MarkupColor, fontSize: MarkupFontSize, imageRect: CGRect) -> CGRect {
        let originView = denorm(origin, in: imageRect)
        let size = (string as NSString).size(withAttributes: textAttributes(color: color.nsColor, imageRect: imageRect, fontSize: fontSize))
        return CGRect(x: originView.x, y: originView.y, width: max(size.width, 1), height: max(size.height, 1))
    }

    private static func strokeDashedRect(_ ctx: CGContext, _ rect: CGRect) {
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [3, 2])
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.stroke(rect)
        ctx.setLineDash(phase: 2.5, lengths: [3, 2])
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.stroke(rect)
    }

    private static func strokeDashedEllipse(_ ctx: CGContext, _ rect: CGRect) {
        ctx.setLineWidth(1)
        ctx.setLineDash(phase: 0, lengths: [3, 2])
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.strokeEllipse(in: rect)
        ctx.setLineDash(phase: 2.5, lengths: [3, 2])
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.strokeEllipse(in: rect)
    }

    private static func strokeDashedPath(_ ctx: CGContext, _ path: CGPath, lineWidth: CGFloat) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(lineWidth)
        ctx.addPath(path)
        ctx.setLineDash(phase: 0, lengths: [3, 2])
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setLineDash(phase: 2.5, lengths: [3, 2])
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.strokePath()
    }

    private static func arrowCGPath(from start: CGPoint, to end: CGPoint, line: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let head = line * 4.2
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x + cos(angle + .pi * 0.82) * head, y: end.y + sin(angle + .pi * 0.82) * head))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x + cos(angle - .pi * 0.82) * head, y: end.y + sin(angle - .pi * 0.82) * head))
        return path
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

    private static func denormRect(_ start: CGPoint, _ end: CGPoint, in imageRect: CGRect) -> CGRect {
        let a = denorm(start, in: imageRect)
        let b = denorm(end, in: imageRect)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    static func viewRect(from frac: CGRect, imageRect: CGRect) -> CGRect {
        let box = frac.standardized
        return CGRect(
            x: imageRect.minX + box.minX * imageRect.width,
            y: imageRect.minY + box.minY * imageRect.height,
            width: box.width * imageRect.width,
            height: box.height * imageRect.height
        )
    }

    static func drawCropSelection(_ frac: CGRect, in imageRect: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let box = viewRect(from: frac, imageRect: imageRect)
        ctx.saveGState()
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.38).cgColor)
        ctx.addRect(imageRect)
        ctx.addRect(box)
        ctx.drawPath(using: .eoFill)
        strokeDashedRect(ctx, box)
        ctx.restoreGState()
    }

    private static func ellipseContains(_ point: CGPoint, in rect: CGRect) -> Bool {
        guard rect.width > 0.5, rect.height > 0.5 else { return rect.insetBy(dx: -1, dy: -1).contains(point) }
        let nx = (point.x - rect.midX) / (rect.width / 2)
        let ny = (point.y - rect.midY) / (rect.height / 2)
        return nx * nx + ny * ny <= 1
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
        ctx.addPath(arrowCGPath(from: start, to: end, line: line))
        ctx.strokePath()
    }

    private static func drawText(_ string: String, at origin: CGPoint, color: NSColor, imageRect: CGRect, fontSize: MarkupFontSize) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        trimmed.draw(at: origin, withAttributes: textAttributes(color: color, imageRect: imageRect, fontSize: fontSize))
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
