import AppKit

enum MarkupTool: String, CaseIterable {
    case browse
    case pen
    case line
    case arrow
    case rect
    case roundRect
    case oval
    case highlight
    case text
    case crop

    var isDrawing: Bool { self != .browse }

    var isMarkupInk: Bool {
        switch self {
        case .pen, .line, .arrow, .rect, .roundRect, .oval, .highlight, .text: return true
        case .browse, .crop: return false
        }
    }

    var canFill: Bool {
        switch self {
        case .rect, .roundRect, .oval: return true
        default: return false
        }
    }

    var cursor: NSCursor {
        switch self {
        case .browse: return .arrow
        case .pen, .line, .arrow, .rect, .roundRect, .oval, .highlight, .crop: return .crosshair
        case .text: return .iBeam
        }
    }
}

enum CropHandle: Equatable {
    case n, s, e, w, ne, nw, se, sw, body
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
        case .red: return NSColor(srgbRed: 1, green: 0.231, blue: 0.188, alpha: 1)
        case .orange: return NSColor(srgbRed: 1, green: 0.584, blue: 0, alpha: 1)
        case .yellow: return NSColor(srgbRed: 1, green: 0.8, blue: 0, alpha: 1)
        case .green: return NSColor(srgbRed: 0.204, green: 0.78, blue: 0.349, alpha: 1)
        case .blue: return NSColor(srgbRed: 0, green: 0.478, blue: 1, alpha: 1)
        case .white: return .white
        case .black: return .black
        }
    }

    /// Ink on a WeChat-style color chip (dark on yellow/white, white otherwise).
    var contrastingInk: NSColor {
        switch self {
        case .yellow, .white:
            return NSColor(srgbRed: 0.12, green: 0.12, blue: 0.12, alpha: 1)
        default:
            return .white
        }
    }

    var helpKey: L10n.Key {
        switch self {
        case .red: return .colorRed
        case .orange: return .colorOrange
        case .yellow: return .colorYellow
        case .green: return .colorGreen
        case .blue: return .colorBlue
        case .white: return .colorWhite
        case .black: return .colorBlack
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
    case n, s, e, w, ne, nw, se, sw
}

extension CropHandle {
    var cursor: NSCursor {
        switch self {
        case .n, .s: return .resizeUpDown
        case .e, .w: return .resizeLeftRight
        case .ne, .nw, .se, .sw: return .crosshair
        case .body: return .openHand
        }
    }
}

extension MarkupHandle {
    var cursor: NSCursor {
        switch self {
        case .n, .s: return .resizeUpDown
        case .e, .w: return .resizeLeftRight
        case .ne, .nw, .se, .sw: return .crosshair
        case .start, .end: return .openHand
        }
    }
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
    var filled: Bool
    var kind: Kind

    enum Kind: Equatable {
        case stroke(points: [CGPoint])
        case line(start: CGPoint, end: CGPoint)
        case arrow(start: CGPoint, end: CGPoint)
        case rect(start: CGPoint, end: CGPoint)
        case roundRect(start: CGPoint, end: CGPoint)
        case oval(start: CGPoint, end: CGPoint)
        case highlight(start: CGPoint, end: CGPoint)
        case text(origin: CGPoint, string: String)

        func mapPoints(_ map: (CGPoint) -> CGPoint) -> Kind {
            switch self {
            case .stroke(let points): return .stroke(points: points.map(map))
            case .line(let start, let end): return .line(start: map(start), end: map(end))
            case .arrow(let start, let end): return .arrow(start: map(start), end: map(end))
            case .rect(let start, let end): return .rect(start: map(start), end: map(end))
            case .roundRect(let start, let end): return .roundRect(start: map(start), end: map(end))
            case .oval(let start, let end): return .oval(start: map(start), end: map(end))
            case .highlight(let start, let end): return .highlight(start: map(start), end: map(end))
            case .text(let origin, let string): return .text(origin: map(origin), string: string)
            }
        }
    }

    init(
        id: UUID = UUID(),
        color: MarkupColor,
        weight: MarkupWeight = .regular,
        fontSize: MarkupFontSize = .regular,
        filled: Bool = false,
        kind: Kind
    ) {
        self.id = id
        self.color = color
        self.weight = weight
        self.fontSize = fontSize
        self.filled = filled
        self.kind = kind
    }

    var isText: Bool {
        if case .text = kind { return true }
        return false
    }

    var canFill: Bool {
        switch kind {
        case .rect, .roundRect, .oval: return true
        default: return false
        }
    }

    func with(kind: Kind) -> MarkupItem {
        MarkupItem(id: id, color: color, weight: weight, fontSize: fontSize, filled: filled, kind: kind)
    }

    func translated(by delta: CGPoint) -> MarkupItem {
        with(kind: kind.mapPoints { CGPoint(x: $0.x + delta.x, y: $0.y + delta.y) })
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
            case .color, .resize, .removeBackground:
                return p
            }
        }
        return with(kind: kind.mapPoints(map))
    }
}

enum ImageMarkup {
    static func lineWidth(for item: MarkupItem, in imageRect: CGRect) -> CGFloat {
        // 0.5pt is one device pixel on Retina — a true hairline, not a marker.
        max(0.5, min(imageRect.width, imageRect.height) * 0.0026 * item.weight.scale)
    }

    static func draw(_ items: [MarkupItem], in imageRect: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, imageRect.width > 1, imageRect.height > 1 else { return }
        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        for item in items {
            let line = lineWidth(for: item, in: imageRect)
            ctx.saveGState()
            ctx.setStrokeColor(item.color.nsColor.cgColor)
            ctx.setFillColor(item.color.nsColor.cgColor)
            ctx.setLineWidth(line)
            switch item.kind {
            case .rect, .roundRect:
                ctx.setLineCap(.butt)
                ctx.setLineJoin(.miter)
            default:
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
            }
            switch item.kind {
            case .stroke(let points):
                drawStroke(points, in: imageRect, context: ctx, line: line)
            case .line(let start, let end):
                ctx.beginPath()
                ctx.move(to: denorm(start, in: imageRect))
                ctx.addLine(to: denorm(end, in: imageRect))
                ctx.strokePath()
            case .arrow(let start, let end):
                drawArrow(from: denorm(start, in: imageRect), to: denorm(end, in: imageRect), context: ctx, line: line)
            case .rect(let start, let end):
                fillOrStroke(ctx, rect: denormRect(start, end, in: imageRect), filled: item.filled, rounded: false)
            case .roundRect(let start, let end):
                fillOrStroke(ctx, rect: denormRect(start, end, in: imageRect), filled: item.filled, rounded: true)
            case .oval(let start, let end):
                let box = denormRect(start, end, in: imageRect)
                if item.filled {
                    ctx.setAlpha(0.9)
                    ctx.fillEllipse(in: box)
                    ctx.setAlpha(1)
                    ctx.strokeEllipse(in: box)
                } else {
                    ctx.strokeEllipse(in: box)
                }
            case .highlight(let start, let end):
                let box = denormRect(start, end, in: imageRect)
                let radius = min(3.5, min(box.width, box.height) / 2)
                ctx.setAlpha(0.4)
                ctx.setBlendMode(.multiply)
                ctx.addPath(CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius, transform: nil))
                ctx.fillPath()
            case .text(let origin, let string):
                drawText(
                    string,
                    at: denorm(origin, in: imageRect),
                    color: item.color,
                    imageRect: imageRect,
                    fontSize: item.fontSize,
                    background: item.filled
                )
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
        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        ctx.interpolationQuality = .high
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
                textFrame(string, origin: origin, color: item.color, fontSize: item.fontSize, imageRect: imageRect, background: item.filled)
            )
        case .rect(let start, let end), .highlight(let start, let end):
            strokeDashedRect(ctx, denormRect(start, end, in: imageRect).insetBy(dx: -outer, dy: -outer))
        case .roundRect(let start, let end):
            let box = denormRect(start, end, in: imageRect).insetBy(dx: -outer, dy: -outer)
            strokeDashedPath(ctx, roundRectPath(box), lineWidth: 1)
        case .oval(let start, let end):
            strokeDashedEllipse(ctx, denormRect(start, end, in: imageRect).insetBy(dx: -outer, dy: -outer))
        case .line(let start, let end):
            let path = CGMutablePath()
            path.move(to: denorm(start, in: imageRect))
            path.addLine(to: denorm(end, in: imageRect))
            strokeDashedPath(ctx, path, lineWidth: line + 1)
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
            drawKnob(ctx, at: point, radius: 3.4)
        }
        ctx.restoreGState()
    }

    static func handles(for item: MarkupItem, in imageRect: CGRect) -> [(MarkupHandle, CGPoint)] {
        switch item.kind {
        case .line(let start, let end), .arrow(let start, let end):
            return [(.start, denorm(start, in: imageRect)), (.end, denorm(end, in: imageRect))]
        case .rect(let start, let end), .roundRect(let start, let end), .oval(let start, let end), .highlight(let start, let end):
            return boxHandles(denormRect(start, end, in: imageRect))
        default:
            return []
        }
    }

    private static func boxHandles(_ rect: CGRect) -> [(MarkupHandle, CGPoint)] {
        [
            (.nw, CGPoint(x: rect.minX, y: rect.maxY)),
            (.n, CGPoint(x: rect.midX, y: rect.maxY)),
            (.ne, CGPoint(x: rect.maxX, y: rect.maxY)),
            (.e, CGPoint(x: rect.maxX, y: rect.midY)),
            (.se, CGPoint(x: rect.maxX, y: rect.minY)),
            (.s, CGPoint(x: rect.midX, y: rect.minY)),
            (.sw, CGPoint(x: rect.minX, y: rect.minY)),
            (.w, CGPoint(x: rect.minX, y: rect.midY))
        ]
    }

    static func handleHit(_ item: MarkupItem, at point: CGPoint, imageRect: CGRect) -> MarkupHandle? {
        for (handle, location) in handles(for: item, in: imageRect) {
            if hypot(point.x - location.x, point.y - location.y) <= 10 {
                return handle
            }
        }
        return nil
    }

    static func resized(_ item: MarkupItem, handle: MarkupHandle, to frac: CGPoint, shift: Bool = false) -> MarkupItem {
        let clamped = clamp01(frac)
        switch item.kind {
        case .line(let start, let end):
            let pair = resizedLine(start: start, end: end, handle: handle, to: clamped, shift: shift)
            return item.with(kind: .line(start: pair.0, end: pair.1))
        case .arrow(let start, let end):
            let pair = resizedLine(start: start, end: end, handle: handle, to: clamped, shift: shift)
            return item.with(kind: .arrow(start: pair.0, end: pair.1))
        case .rect(let start, let end):
            let pair = resizedBox(start: start, end: end, handle: handle, to: clamped, square: shift)
            return item.with(kind: .rect(start: pair.0, end: pair.1))
        case .roundRect(let start, let end):
            let pair = resizedBox(start: start, end: end, handle: handle, to: clamped, square: shift)
            return item.with(kind: .roundRect(start: pair.0, end: pair.1))
        case .oval(let start, let end):
            let pair = resizedBox(start: start, end: end, handle: handle, to: clamped, square: shift)
            return item.with(kind: .oval(start: pair.0, end: pair.1))
        case .highlight(let start, let end):
            let pair = resizedBox(start: start, end: end, handle: handle, to: clamped, square: shift)
            return item.with(kind: .highlight(start: pair.0, end: pair.1))
        default:
            return item
        }
    }

    static func clamp01(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), 1), y: min(max(p.y, 0), 1))
    }

    /// Snap a line to 45° increments (Preview: hold Shift).
    static func constrainAxis(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0.00001 else { return start }
        let snapped = (atan2(dy, dx) / (.pi / 4)).rounded() * (.pi / 4)
        return clamp01(CGPoint(x: start.x + cos(snapped) * length, y: start.y + sin(snapped) * length))
    }

    /// Keep width == height from `start` (Preview: hold Shift for square / circle).
    static func constrainSquare(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let side = max(abs(dx), abs(dy))
        return clamp01(CGPoint(
            x: start.x + side * (dx < 0 ? -1 : 1),
            y: start.y + side * (dy < 0 ? -1 : 1)
        ))
    }

    private static func resizedLine(start: CGPoint, end: CGPoint, handle: MarkupHandle, to point: CGPoint, shift: Bool) -> (CGPoint, CGPoint) {
        var s = start
        var e = end
        if handle == .start {
            s = shift ? constrainAxis(from: e, to: point) : point
        } else {
            e = shift ? constrainAxis(from: s, to: point) : point
        }
        return (clamp01(s), clamp01(e))
    }

    private static func resizedBox(start: CGPoint, end: CGPoint, handle: MarkupHandle, to point: CGPoint, square: Bool) -> (CGPoint, CGPoint) {
        if handle == .start || handle == .end {
            let s = handle == .start ? point : start
            let e = handle == .end ? point : end
            if square {
                return handle == .start
                    ? (constrainSquare(from: end, to: point), end)
                    : (start, constrainSquare(from: start, to: point))
            }
            return (s, e)
        }
        let origMinX = min(start.x, end.x)
        let origMaxX = max(start.x, end.x)
        let origMinY = min(start.y, end.y)
        let origMaxY = max(start.y, end.y)
        if square {
            switch handle {
            case .ne, .nw, .se, .sw:
                let opp: CGPoint
                switch handle {
                case .ne: opp = CGPoint(x: origMinX, y: origMinY)
                case .nw: opp = CGPoint(x: origMaxX, y: origMinY)
                case .se: opp = CGPoint(x: origMinX, y: origMaxY)
                default: opp = CGPoint(x: origMaxX, y: origMaxY)
                }
                return (opp, constrainSquare(from: opp, to: point))
            default:
                break
            }
        }
        var minX = origMinX, maxX = origMaxX, minY = origMinY, maxY = origMaxY
        switch handle {
        case .n, .ne, .nw: maxY = point.y
        case .s, .se, .sw: minY = point.y
        default: break
        }
        switch handle {
        case .e, .ne, .se: maxX = point.x
        case .w, .nw, .sw: minX = point.x
        default: break
        }
        minX = min(max(minX, 0), 1)
        maxX = min(max(maxX, 0), 1)
        minY = min(max(minY, 0), 1)
        maxY = min(max(maxY, 0), 1)
        return (CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: maxY))
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

    /// Caption-sized type that matches the in-place editor. ~2% of the short side,
    /// so a typical window stays around 16pt instead of jumping to banner size.
    static func textPointSize(fontSize: MarkupFontSize, in imageRect: CGRect) -> CGFloat {
        let minSide = min(imageRect.width, imageRect.height)
        return max(12, minSide * 0.02 * fontSize.scale)
    }

    static func textAttributes(
        color: NSColor,
        imageRect: CGRect,
        fontSize: MarkupFontSize = .regular,
        background: Bool = false
    ) -> [NSAttributedString.Key: Any] {
        let size = textPointSize(fontSize: fontSize, in: imageRect)
        if background {
            return [
                .font: NSFont.systemFont(ofSize: size, weight: .medium),
                .foregroundColor: color
            ]
        }
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -0.6)
        shadow.shadowBlurRadius = 1.2
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        return [
            .font: NSFont.systemFont(ofSize: size, weight: .regular),
            .foregroundColor: color,
            .strokeColor: NSColor.white.withAlphaComponent(0.45),
            .strokeWidth: -0.9,
            .shadow: shadow
        ]
    }

    static func textPadding(forFontHeight height: CGFloat) -> (x: CGFloat, y: CGFloat) {
        (max(6, height * 0.4), max(3, height * 0.22))
    }

    static func textChipRadius(forHeight height: CGFloat) -> CGFloat {
        min(max(height, 1) / 2, 18)
    }

    private static func hit(_ item: MarkupItem, at point: CGPoint, imageRect: CGRect, tolerance: CGFloat) -> Bool {
        switch item.kind {
        case .text(let origin, let string):
            return textFrame(string, origin: origin, color: item.color, fontSize: item.fontSize, imageRect: imageRect, background: item.filled)
                .insetBy(dx: -4, dy: -4)
                .contains(point)
        case .rect(let start, let end):
            return hitRect(denormRect(start, end, in: imageRect), point: point, tolerance: tolerance, filled: item.filled)
        case .roundRect(let start, let end):
            return hitRoundRect(denormRect(start, end, in: imageRect), point: point, tolerance: tolerance, filled: item.filled)
        case .highlight(let start, let end):
            return denormRect(start, end, in: imageRect).insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        case .oval(let start, let end):
            let rect = denormRect(start, end, in: imageRect)
            if item.filled {
                return ellipseContains(point, in: rect.insetBy(dx: -tolerance, dy: -tolerance))
            }
            if !ellipseContains(point, in: rect.insetBy(dx: -tolerance, dy: -tolerance)) {
                return false
            }
            let inner = rect.insetBy(dx: tolerance, dy: tolerance)
            if inner.width <= 0 || inner.height <= 0 {
                return true
            }
            return !ellipseContains(point, in: inner)
        case .line(let start, let end):
            return distance(point, segmentFrom: denorm(start, in: imageRect), to: denorm(end, in: imageRect)) <= tolerance
        case .arrow(let start, let end):
            let from = denorm(start, in: imageRect)
            let to = denorm(end, in: imageRect)
            if distance(point, segmentFrom: from, to: to) <= tolerance {
                return true
            }
            let line = lineWidth(for: item, in: imageRect)
            let head = arrowHead(from: from, to: to, line: line)
            return distance(point, segmentFrom: to, to: head.left) <= tolerance
                || distance(point, segmentFrom: to, to: head.right) <= tolerance
                || triangleContains(point, a: to, b: head.left, c: head.right)
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

    private static func hitRect(_ rect: CGRect, point: CGPoint, tolerance: CGFloat, filled: Bool) -> Bool {
        let outer = rect.insetBy(dx: -tolerance, dy: -tolerance)
        guard outer.contains(point) else { return false }
        if filled { return true }
        let inner = rect.insetBy(dx: tolerance, dy: tolerance)
        if inner.width <= 0 || inner.height <= 0 { return true }
        return !inner.contains(point)
    }

    private static func hitRoundRect(_ rect: CGRect, point: CGPoint, tolerance: CGFloat, filled: Bool) -> Bool {
        let path = roundRectPath(rect)
        if filled {
            return path.contains(point) || hitStroked(path, point: point, width: tolerance * 2)
        }
        return hitStroked(path, point: point, width: max(tolerance * 2, 1))
    }

    private static func hitStroked(_ path: CGPath, point: CGPoint, width: CGFloat) -> Bool {
        let stroked = path.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        return stroked.contains(point)
    }

    private static func normalizedBounds(_ item: MarkupItem) -> CGRect {
        let pts: [CGPoint]
        switch item.kind {
        case .text(let origin, _):
            pts = [origin, CGPoint(x: origin.x + 0.08, y: origin.y + 0.04)]
        case .rect(let start, let end), .roundRect(let start, let end), .oval(let start, let end),
             .highlight(let start, let end), .arrow(let start, let end), .line(let start, let end):
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

    static func textFrame(
        _ string: String,
        origin: CGPoint,
        color: MarkupColor,
        fontSize: MarkupFontSize,
        imageRect: CGRect,
        background: Bool = false
    ) -> CGRect {
        let originView = denorm(origin, in: imageRect)
        let ink = background ? color.contrastingInk : color.nsColor
        let size = (string as NSString).size(withAttributes: textAttributes(color: ink, imageRect: imageRect, fontSize: fontSize, background: background))
        var frame = CGRect(x: originView.x, y: originView.y, width: max(size.width, 1), height: max(size.height, 1))
        if background {
            let pad = textPadding(forFontHeight: frame.height)
            frame = frame.insetBy(dx: -pad.x, dy: -pad.y)
        }
        return frame
    }

    private static func strokeDashedRect(_ ctx: CGContext, _ rect: CGRect) {
        ctx.setLineWidth(0.8)
        ctx.setLineDash(phase: 0, lengths: [2.5, 2])
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor)
        ctx.stroke(rect)
        ctx.setLineDash(phase: 2.25, lengths: [2.5, 2])
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.42).cgColor)
        ctx.stroke(rect)
    }

    private static func strokeDashedEllipse(_ ctx: CGContext, _ rect: CGRect) {
        ctx.setLineWidth(0.8)
        ctx.setLineDash(phase: 0, lengths: [2.5, 2])
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor)
        ctx.strokeEllipse(in: rect)
        ctx.setLineDash(phase: 2.25, lengths: [2.5, 2])
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.42).cgColor)
        ctx.strokeEllipse(in: rect)
    }

    private static func strokeDashedPath(_ ctx: CGContext, _ path: CGPath, lineWidth: CGFloat) {
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(min(lineWidth, 1.6))
        ctx.addPath(path)
        ctx.setLineDash(phase: 0, lengths: [2.5, 2])
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor)
        ctx.strokePath()
        ctx.addPath(path)
        ctx.setLineDash(phase: 2.25, lengths: [2.5, 2])
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.42).cgColor)
        ctx.strokePath()
    }

    private static func arrowHead(from start: CGPoint, to end: CGPoint, line: CGFloat) -> (left: CGPoint, right: CGPoint, back: CGPoint, length: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length = max(line * 5.1, 7)
        let wing: CGFloat = .pi * 0.17
        let left = CGPoint(x: end.x - cos(angle - wing) * length, y: end.y - sin(angle - wing) * length)
        let right = CGPoint(x: end.x - cos(angle + wing) * length, y: end.y - sin(angle + wing) * length)
        let back = CGPoint(x: end.x - cos(angle) * length * 0.68, y: end.y - sin(angle) * length * 0.68)
        return (left, right, back, length)
    }

    private static func arrowCGPath(from start: CGPoint, to end: CGPoint, line: CGFloat) -> CGPath {
        let head = arrowHead(from: start, to: end, line: line)
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: head.back)
        path.move(to: end)
        path.addLine(to: head.left)
        path.addLine(to: head.right)
        path.closeSubpath()
        return path
    }

    private static func triangleContains(_ p: CGPoint, a: CGPoint, b: CGPoint, c: CGPoint) -> Bool {
        func sign(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGFloat {
            (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
        }
        let b1 = sign(p, a, b) < 0
        let b2 = sign(p, b, c) < 0
        let b3 = sign(p, c, a) < 0
        return b1 == b2 && b2 == b3
    }

    private static func drawKnob(_ ctx: CGContext, at point: CGPoint, radius: CGFloat) {
        let knob = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.2).cgColor)
        ctx.fillEllipse(in: knob.insetBy(dx: -0.55, dy: -0.55))
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: knob)
        ctx.setStrokeColor(NSColor.controlAccentColor.cgColor)
        ctx.setLineWidth(1.1)
        ctx.strokeEllipse(in: knob)
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

    static func cropHandles(for frac: CGRect, in imageRect: CGRect) -> [(CropHandle, CGPoint)] {
        let box = viewRect(from: frac, imageRect: imageRect)
        return [
            (.nw, CGPoint(x: box.minX, y: box.maxY)),
            (.n, CGPoint(x: box.midX, y: box.maxY)),
            (.ne, CGPoint(x: box.maxX, y: box.maxY)),
            (.e, CGPoint(x: box.maxX, y: box.midY)),
            (.se, CGPoint(x: box.maxX, y: box.minY)),
            (.s, CGPoint(x: box.midX, y: box.minY)),
            (.sw, CGPoint(x: box.minX, y: box.minY)),
            (.w, CGPoint(x: box.minX, y: box.midY))
        ]
    }

    static func cropHandleHit(_ frac: CGRect, at point: CGPoint, imageRect: CGRect) -> CropHandle? {
        for (handle, location) in cropHandles(for: frac, in: imageRect) {
            if hypot(point.x - location.x, point.y - location.y) <= 11 {
                return handle
            }
        }
        let box = viewRect(from: frac, imageRect: imageRect)
        if box.insetBy(dx: -3, dy: -3).contains(point) {
            return .body
        }
        return nil
    }

    static func resizedCrop(_ rect: CGRect, handle: CropHandle, to point: CGPoint, square: Bool) -> CGRect {
        let box = rect.standardized
        let origMinX = box.minX, origMaxX = box.maxX, origMinY = box.minY, origMaxY = box.maxY
        if square {
            switch handle {
            case .ne, .nw, .se, .sw:
                let opp: CGPoint
                switch handle {
                case .ne: opp = CGPoint(x: origMinX, y: origMinY)
                case .nw: opp = CGPoint(x: origMaxX, y: origMinY)
                case .se: opp = CGPoint(x: origMinX, y: origMaxY)
                default: opp = CGPoint(x: origMaxX, y: origMaxY)
                }
                return clampNormalized(CGRect(origin: opp, size: CGSize(width: constrainSquare(from: opp, to: point).x - opp.x, height: constrainSquare(from: opp, to: point).y - opp.y)))
            default:
                break
            }
        }
        var minX = origMinX, maxX = origMaxX, minY = origMinY, maxY = origMaxY
        switch handle {
        case .n, .ne, .nw: maxY = point.y
        case .s, .se, .sw: minY = point.y
        default: break
        }
        switch handle {
        case .e, .ne, .se: maxX = point.x
        case .w, .nw, .sw: minX = point.x
        default: break
        }
        return clampNormalized(CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY))
    }

    static func translatedCrop(_ rect: CGRect, by delta: CGPoint) -> CGRect {
        let box = rect.standardized
        var dx = delta.x
        var dy = delta.y
        if box.minX + dx < 0 { dx = -box.minX }
        if box.maxX + dx > 1 { dx = 1 - box.maxX }
        if box.minY + dy < 0 { dy = -box.minY }
        if box.maxY + dy > 1 { dy = 1 - box.maxY }
        return CGRect(x: box.minX + dx, y: box.minY + dy, width: box.width, height: box.height)
    }

    static func clampNormalized(_ rect: CGRect) -> CGRect {
        var r = rect.standardized
        if r.minX < 0 { r.origin.x = 0 }
        if r.minY < 0 { r.origin.y = 0 }
        if r.maxX > 1 { r.size.width = max(0.002, 1 - r.origin.x) }
        if r.maxY > 1 { r.size.height = max(0.002, 1 - r.origin.y) }
        r.size.width = max(r.size.width, 0.002)
        r.size.height = max(r.size.height, 0.002)
        if r.maxX > 1 { r.origin.x = max(0, 1 - r.size.width) }
        if r.maxY > 1 { r.origin.y = max(0, 1 - r.size.height) }
        return r
    }

    static func drawCropSelection(_ frac: CGRect, in imageRect: CGRect, pixelSize: CGSize = .zero) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let box = viewRect(from: frac, imageRect: imageRect)
        ctx.saveGState()
        ctx.setShouldAntialias(true)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.42).cgColor)
        ctx.addRect(imageRect)
        ctx.addRect(box)
        ctx.drawPath(using: .eoFill)
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.96).cgColor)
        ctx.setLineWidth(1.15)
        ctx.stroke(box)
        for (_, point) in cropHandles(for: frac, in: imageRect) {
            drawKnob(ctx, at: point, radius: 3.6)
        }
        if pixelSize.width > 0, pixelSize.height > 0 {
            let pxW = max(1, Int((frac.standardized.width * pixelSize.width).rounded()))
            let pxH = max(1, Int((frac.standardized.height * pixelSize.height).rounded()))
            drawCropHUD("\(pxW) × \(pxH)", near: box, in: imageRect, context: ctx)
        }
        ctx.restoreGState()
    }

    private static func drawCropHUD(_ text: String, near box: CGRect, in imageRect: CGRect, context ctx: CGContext) {
        let label = text as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let textSize = label.size(withAttributes: attrs)
        var hud = CGRect(
            x: box.minX + 6,
            y: box.maxY + 8,
            width: textSize.width + 12,
            height: textSize.height + 6
        )
        if hud.maxY > imageRect.maxY - 2 {
            hud.origin.y = min(box.maxY, imageRect.maxY) - hud.height - 8
        }
        if hud.minY < imageRect.minY + 2 {
            hud.origin.y = imageRect.minY + 2
        }
        if hud.maxX > imageRect.maxX - 2 {
            hud.origin.x = max(imageRect.minX + 2, box.maxX - hud.width - 6)
        }
        if hud.minX < imageRect.minX + 2 {
            hud.origin.x = imageRect.minX + 2
        }
        let pill = CGPath(roundedRect: hud, cornerWidth: 5, cornerHeight: 5, transform: nil)
        ctx.addPath(pill)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.78).cgColor)
        ctx.fillPath()
        label.draw(
            at: CGPoint(x: hud.minX + 6, y: hud.minY + 3),
            withAttributes: attrs
        )
    }

    private static func fillOrStroke(_ ctx: CGContext, rect: CGRect, filled: Bool, rounded: Bool) {
        if rounded {
            ctx.addPath(roundRectPath(rect))
            if filled {
                ctx.setAlpha(0.9)
                ctx.fillPath()
                ctx.setAlpha(1)
                ctx.addPath(roundRectPath(rect))
            }
            ctx.strokePath()
            return
        }
        if filled {
            ctx.setAlpha(0.9)
            ctx.fill(rect)
            ctx.setAlpha(1)
        }
        ctx.stroke(rect)
    }

    private static func roundRectPath(_ rect: CGRect) -> CGPath {
        let r = min(max(min(rect.width, rect.height) * 0.12, 3), 14)
        return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
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
        if mapped.count == 2 {
            ctx.addLine(to: mapped[1])
        } else {
            for index in 1..<mapped.count {
                let previous = mapped[index - 1]
                let current = mapped[index]
                let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
                ctx.addQuadCurve(to: mid, control: previous)
            }
            ctx.addLine(to: mapped[mapped.count - 1])
        }
        ctx.strokePath()
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, context ctx: CGContext, line: CGFloat) {
        let head = arrowHead(from: start, to: end, line: line)
        ctx.beginPath()
        ctx.move(to: start)
        ctx.addLine(to: head.back)
        ctx.strokePath()
        ctx.beginPath()
        ctx.move(to: end)
        ctx.addLine(to: head.left)
        ctx.addLine(to: head.right)
        ctx.closePath()
        ctx.fillPath()
    }

    private static func drawText(
        _ string: String,
        at origin: CGPoint,
        color: MarkupColor,
        imageRect: CGRect,
        fontSize: MarkupFontSize,
        background: Bool
    ) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let ink = background ? color.contrastingInk : color.nsColor
        let attrs = textAttributes(color: ink, imageRect: imageRect, fontSize: fontSize, background: background)
        if background, let ctx = NSGraphicsContext.current?.cgContext {
            let size = (trimmed as NSString).size(withAttributes: attrs)
            let pad = textPadding(forFontHeight: max(size.height, 1))
            let box = CGRect(
                x: origin.x - pad.x,
                y: origin.y - pad.y,
                width: size.width + pad.x * 2,
                height: size.height + pad.y * 2
            )
            let radius = textChipRadius(forHeight: box.height)
            ctx.setFillColor(color.nsColor.cgColor)
            ctx.addPath(CGPath(roundedRect: box, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.fillPath()
        }
        trimmed.draw(at: origin, withAttributes: attrs)
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
        NSGraphicsContext.current?.shouldAntialias = true
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
