import AppKit
import SwiftUI

/// Hosts the scroll view under a full-window overlay for cursors, clicks, and context menu.
struct ZoomableImageView: NSViewRepresentable {
    var image: NSImage
    var imageURL: URL?
    var zoomRequest: ZoomRequest?
    var onNavigate: (NavigateDirection) -> Void
    var onDelete: () -> Void
    var onEscape: () -> Void
    var onOpenImage: () -> Void
    var onOpenFolder: () -> Void
    var onRevealInFinder: () -> Void
    var onCopyPath: () -> Void
    var onOpenWithApp: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> ImageViewerHostView {
        let host = ImageViewerHostView()
        bind(host)
        host.scrollView.setImage(image, url: imageURL, resetZoom: true)
        return host
    }

    func updateNSView(_ host: ImageViewerHostView, context: Context) {
        bind(host)
        let urlChanged = host.scrollView.representedURL != imageURL
        if urlChanged || host.scrollView.image !== image {
            host.scrollView.setImage(image, url: imageURL, resetZoom: urlChanged)
        }
        if let zoomRequest, context.coordinator.lastZoomID != zoomRequest.id {
            context.coordinator.lastZoomID = zoomRequest.id
            host.scrollView.applyZoom(zoomRequest.kind)
        }
    }

    private func bind(_ host: ImageViewerHostView) {
        host.scrollView.onNavigate = onNavigate
        host.scrollView.onDelete = onDelete
        host.scrollView.onEscape = onEscape
        host.overlay.onNavigate = onNavigate
        host.overlay.isFitting = { [weak host] in host?.scrollView.isFittingMode ?? true }
        host.overlay.onOpenImage = onOpenImage
        host.overlay.onOpenFolder = onOpenFolder
        host.overlay.onRevealInFinder = onRevealInFinder
        host.overlay.onCopyPath = onCopyPath
        host.overlay.onOpenWithApp = onOpenWithApp
        host.overlay.onDelete = onDelete
        host.overlay.currentImageURL = { imageURL }
        host.overlay.onMouseDown = { [weak host] event in host?.scrollView.handleOverlayMouseDown(event) }
        host.overlay.onMouseDragged = { [weak host] event in host?.scrollView.handleOverlayMouseDragged(event) }
        host.overlay.onMouseUp = { [weak host] event in host?.scrollView.handleOverlayMouseUp(event) }
        host.overlay.onScrollWheel = { [weak host] event in host?.scrollView.scrollWheel(with: event) }
        host.overlay.onMagnify = { [weak host] event in host?.scrollView.magnify(with: event) }
        host.overlay.onSwipe = { [weak host] event in host?.scrollView.swipe(with: event) }
        host.overlay.onCursorMove = { [weak host] point in host?.applyPageCursor(atWindowPoint: point) }
    }

    final class Coordinator {
        var lastZoomID: UUID?
    }
}

final class ImageViewerHostView: NSView {
    let scrollView = ImageScrollView()
    let overlay = PageHitOverlay()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        addSubview(scrollView)
        addSubview(overlay)
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        overlay.frame = bounds
        window?.invalidateCursorRects(for: overlay)
    }

    func applyPageCursor(atWindowPoint point: NSPoint) {
        let local = convert(point, from: nil)
        guard bounds.contains(local) else {
            NSCursor.arrow.set()
            return
        }
        let third = bounds.width / 3
        if local.x <= third {
            ImageScrollView.pageLeftCursor.set()
        } else if local.x >= bounds.width - third {
            ImageScrollView.pageRightCursor.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}

final class PageHitOverlay: NSView {
    var onNavigate: ((NavigateDirection) -> Void)?
    var onDelete: (() -> Void)?
    var onOpenImage: (() -> Void)?
    var onOpenFolder: (() -> Void)?
    var onRevealInFinder: (() -> Void)?
    var onCopyPath: (() -> Void)?
    var onOpenWithApp: ((URL) -> Void)?
    var currentImageURL: (() -> URL?)?
    var isFitting: (() -> Bool)?

    var onMouseDown: ((NSEvent) -> Void)?
    var onMouseDragged: ((NSEvent) -> Void)?
    var onMouseUp: ((NSEvent) -> Void)?
    var onScrollWheel: ((NSEvent) -> Void)?
    var onMagnify: ((NSEvent) -> Void)?
    var onSwipe: ((NSEvent) -> Void)?
    var onCursorMove: ((NSPoint) -> Void)?

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        let options: NSTrackingArea.Options = [
            .activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect, .cursorUpdate, .enabledDuringMouseDrag
        ]
        addTrackingArea(NSTrackingArea(rect: .zero, options: options, owner: self, userInfo: nil))
    }

    override func resetCursorRects() {
        guard bounds.width > 0 else { return }
        let third = bounds.width / 3
        addCursorRect(NSRect(x: 0, y: 0, width: third, height: bounds.height), cursor: ImageScrollView.pageLeftCursor)
        addCursorRect(
            NSRect(x: bounds.width - third, y: 0, width: third, height: bounds.height),
            cursor: ImageScrollView.pageRightCursor
        )
    }

    override func cursorUpdate(with event: NSEvent) {
        onCursorMove?(event.locationInWindow)
    }

    override func mouseMoved(with event: NSEvent) {
        onCursorMove?(event.locationInWindow)
    }

    override func mouseEntered(with event: NSEvent) {
        onCursorMove?(event.locationInWindow)
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(event)
    }

    override func mouseUp(with event: NSEvent) {
        onMouseUp?(event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = buildContextMenu()
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func scrollWheel(with event: NSEvent) {
        onScrollWheel?(event)
    }

    override func magnify(with event: NSEvent) {
        onMagnify?(event)
    }

    override func swipe(with event: NSEvent) {
        onSwipe?(event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    private func buildContextMenu() -> NSMenu {
        let lang = LanguageManager.shared
        let menu = NSMenu()
        menu.addItem(withTitle: lang.t(.openImage), action: #selector(menuOpenImage), keyEquivalent: "")
        menu.addItem(withTitle: lang.t(.openFolder), action: #selector(menuOpenFolder), keyEquivalent: "")
        menu.addItem(.separator())

        let hasFile = currentImageURL?() != nil
        let reveal = menu.addItem(withTitle: lang.t(.revealInFinder), action: #selector(menuReveal), keyEquivalent: "")
        reveal.isEnabled = hasFile
        let copy = menu.addItem(withTitle: lang.t(.copyPath), action: #selector(menuCopyPath), keyEquivalent: "")
        copy.isEnabled = hasFile

        let openWith = NSMenuItem(title: lang.t(.openWith), action: nil, keyEquivalent: "")
        openWith.submenu = buildOpenWithMenu(enabled: hasFile)
        menu.addItem(openWith)

        menu.addItem(.separator())
        menu.addItem(withTitle: lang.t(.previousImage), action: #selector(menuPrevious), keyEquivalent: "")
        menu.addItem(withTitle: lang.t(.nextImage), action: #selector(menuNext), keyEquivalent: "")
        menu.addItem(.separator())
        let trash = menu.addItem(withTitle: lang.t(.moveToTrashEllipsis), action: #selector(menuDelete), keyEquivalent: "")
        trash.isEnabled = hasFile

        for item in menu.items {
            item.target = self
        }
        openWith.target = nil
        return menu
    }

    private func buildOpenWithMenu(enabled: Bool) -> NSMenu {
        let lang = LanguageManager.shared
        let menu = NSMenu()
        guard enabled, let url = currentImageURL?() else {
            let empty = menu.addItem(withTitle: lang.t(.noAppsToOpenWith), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            return menu
        }

        let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
        let selfBundle = Bundle.main.bundleURL.standardizedFileURL
        var added = 0
        for appURL in apps {
            if appURL.standardizedFileURL == selfBundle { continue }
            let name = FileManager.default.displayName(atPath: appURL.path)
            let item = menu.addItem(withTitle: name, action: #selector(menuOpenWith(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = appURL
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            added += 1
            if added >= 20 { break }
        }
        if added == 0 {
            let empty = menu.addItem(withTitle: lang.t(.noAppsToOpenWith), action: nil, keyEquivalent: "")
            empty.isEnabled = false
        }
        return menu
    }

    @objc private func menuOpenImage() { onOpenImage?() }
    @objc private func menuOpenFolder() { onOpenFolder?() }
    @objc private func menuReveal() { onRevealInFinder?() }
    @objc private func menuCopyPath() { onCopyPath?() }
    @objc private func menuPrevious() { onNavigate?(.previous) }
    @objc private func menuNext() { onNavigate?(.next) }
    @objc private func menuDelete() { onDelete?() }
    @objc private func menuOpenWith(_ sender: NSMenuItem) {
        guard let appURL = sender.representedObject as? URL else { return }
        onOpenWithApp?(appURL)
    }
}

final class ImageScrollView: NSScrollView {
    var representedURL: URL?
    private(set) var image: NSImage?

    var onNavigate: ((NavigateDirection) -> Void)?
    var onDelete: (() -> Void)?
    var onEscape: (() -> Void)?

    var isFittingMode: Bool { isFitting }

    private let canvas = NSView()
    private let imageView = NSImageView()
    private var userZoom: CGFloat = 1
    private var isFitting = true
    private var lastDragPoint: NSPoint?
    private var mouseDownPoint: NSPoint?
    private var didDrag = false
    private var navAccumX: CGFloat = 0
    private var navCommitted = false
    private var imagePointSize: NSSize = .zero
    private var isRelayouting = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = true
        backgroundColor = .black
        borderType = .noBorder
        allowsMagnification = false
        hasVerticalScroller = true
        hasHorizontalScroller = true
        scrollerStyle = .overlay
        autohidesScrollers = true
        usesPredominantAxisScrolling = false

        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor.black.cgColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = false
        imageView.wantsLayer = true
        imageView.refusesFirstResponder = true
        canvas.addSubview(imageView)
        documentView = canvas
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        relayout(keepUserZoom: true)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        super.setFrameSize(newSize)
        if changed { relayout(keepUserZoom: true) }
    }

    override func layout() {
        super.layout()
        if image != nil, !isRelayouting {
            relayout(keepUserZoom: true)
        }
    }

    func setImage(_ newImage: NSImage, url: URL?, resetZoom: Bool) {
        imageView.isHidden = true
        image = newImage
        representedURL = url
        imagePointSize = ImageLoader.pointSize(of: newImage)
        imageView.image = newImage
        if resetZoom {
            userZoom = 1
            isFitting = true
        }
        relayout(keepUserZoom: !resetZoom)
        imageView.isHidden = false
        window?.makeFirstResponder(self)
    }

    func applyZoom(_ kind: ZoomKind) {
        switch kind {
        case .fit:
            userZoom = 1
            isFitting = true
            relayout(keepUserZoom: false)
        case .actual:
            isFitting = false
            let base = baseScale(for: visibleSize())
            userZoom = base > 0 ? (1.0 / base) : 1
            relayout(keepUserZoom: true)
            centerDocument()
        case .in:
            isFitting = false
            userZoom = min(64, userZoom * 1.25)
            relayout(keepUserZoom: true)
        case .out:
            let next = userZoom / 1.25
            if next <= 1.02 {
                userZoom = 1
                isFitting = true
            } else {
                isFitting = false
                userZoom = next
            }
            relayout(keepUserZoom: true)
        }
    }

    private func visibleSize() -> NSSize {
        let size = contentView.bounds.size
        if size.width > 1, size.height > 1 { return size }
        return bounds.size
    }

    private func baseScale(for view: NSSize) -> CGFloat {
        guard imagePointSize.width > 0, imagePointSize.height > 0, view.width > 1, view.height > 1 else { return 1 }
        return min(1, min(view.width / imagePointSize.width, view.height / imagePointSize.height))
    }

    private func relayout(keepUserZoom: Bool) {
        guard !isRelayouting else { return }
        let view = visibleSize()
        guard imagePointSize.width > 0, imagePointSize.height > 0, view.width > 1, view.height > 1 else { return }
        isRelayouting = true
        defer { isRelayouting = false }
        if isFitting { userZoom = 1 }
        let scale = baseScale(for: view) * max(userZoom, 0.01)
        let disp = NSSize(width: imagePointSize.width * scale, height: imagePointSize.height * scale)
        let doc = NSSize(width: max(view.width, disp.width), height: max(view.height, disp.height))
        canvas.frame = NSRect(origin: .zero, size: doc)
        imageView.frame = NSRect(
            origin: NSPoint(x: (doc.width - disp.width) / 2, y: (doc.height - disp.height) / 2),
            size: disp
        )
        if isFitting || !keepUserZoom { centerDocument() }
        reflectScrolledClipView(contentView)
    }

    private func centerDocument() {
        let doc = canvas.frame.size
        var clip = contentView.bounds
        clip.origin.x = clip.width < doc.width ? (doc.width - clip.width) / 2 : 0
        clip.origin.y = clip.height < doc.height ? (doc.height - clip.height) / 2 : 0
        contentView.setBoundsOrigin(clip.origin)
        reflectScrolledClipView(contentView)
    }

    override func wantsForwardedScrollEvents(for axis: NSEvent.GestureAxis) -> Bool { axis == .horizontal }

    override func scrollWheel(with event: NSEvent) {
        if event.hasPreciseScrollingDeltas {
            let isMomentum = event.momentumPhase != []
            let ended = event.phase == .ended || event.phase == .cancelled
            if event.phase == .began {
                navAccumX = 0
                navCommitted = false
            }
            if isMomentum {
                if event.momentumPhase == .ended || event.momentumPhase == .cancelled {
                    navAccumX = 0
                    navCommitted = false
                }
                return
            }
            let ax = abs(event.scrollingDeltaX)
            let ay = abs(event.scrollingDeltaY)
            let horizontal = ax > ay && ax > 0.15
            if horizontal && (isFitting || event.modifierFlags.contains(.shift)) {
                if !navCommitted {
                    navAccumX += event.scrollingDeltaX
                    if abs(navAccumX) >= 28 {
                        onNavigate?(navAccumX > 0 ? .previous : .next)
                        navCommitted = true
                        navAccumX = 0
                    }
                }
                if ended {
                    navAccumX = 0
                    navCommitted = false
                }
                return
            }
            if !horizontal {
                navAccumX = 0
                if ended { navCommitted = false }
            }
        }

        let zooming = event.modifierFlags.contains(.command) || !event.hasPreciseScrollingDeltas
        if zooming {
            let delta = event.scrollingDeltaY
            guard delta != 0 else { return }
            isFitting = false
            let factor = pow(1.12, delta / (event.hasPreciseScrollingDeltas ? 12.0 : 1.0))
            userZoom = min(64, max(0.05, userZoom * factor))
            if abs(userZoom - 1) < 0.03 { userZoom = 1; isFitting = true }
            relayout(keepUserZoom: true)
            return
        }
        super.scrollWheel(with: event)
    }

    override func swipe(with event: NSEvent) {
        if event.deltaX > 0 { onNavigate?(.previous) }
        else if event.deltaX < 0 { onNavigate?(.next) }
    }

    override func magnify(with event: NSEvent) {
        isFitting = false
        userZoom = min(64, max(0.05, userZoom * (1 + event.magnification)))
        if event.phase == .ended || event.phase == .cancelled, abs(userZoom - 1) < 0.03 {
            userZoom = 1
            isFitting = true
        }
        relayout(keepUserZoom: true)
    }

    func handleOverlayMouseDown(_ event: NSEvent) {
        lastDragPoint = event.locationInWindow
        mouseDownPoint = event.locationInWindow
        didDrag = false
        window?.makeFirstResponder(self)
        if event.clickCount == 2 {
            applyZoom(isFitting ? .actual : .fit)
        }
    }

    func handleOverlayMouseDragged(_ event: NSEvent) {
        if let start = mouseDownPoint {
            let d = hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y)
            if d > 4 { didDrag = true }
        }
        guard !isFitting, let last = lastDragPoint else {
            lastDragPoint = event.locationInWindow
            return
        }
        let current = event.locationInWindow
        var origin = contentView.bounds.origin
        origin.x -= (current.x - last.x)
        origin.y -= (current.y - last.y)
        contentView.scroll(to: origin)
        lastDragPoint = current
    }

    func handleOverlayMouseUp(_ event: NSEvent) {
        defer {
            lastDragPoint = nil
            mouseDownPoint = nil
            didDrag = false
        }
        guard event.clickCount == 1, !didDrag else { return }
        guard let host = superview else { return }
        let local = host.convert(event.locationInWindow, from: nil)
        let third = host.bounds.width / 3
        if local.x <= third { onNavigate?(.previous) }
        else if local.x >= host.bounds.width - third { onNavigate?(.next) }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: onNavigate?(.previous)
        case 124: onNavigate?(.next)
        case 49:
            onNavigate?(event.modifierFlags.contains(.shift) ? .previous : .next)
        case 51, 117: onDelete?()
        case 53: onEscape?()
        default: super.keyDown(with: event)
        }
    }

    static let pageLeftCursor: NSCursor = makePageCursor(pointingLeft: true)
    static let pageRightCursor: NSCursor = makePageCursor(pointingLeft: false)

    /// Draw chevrons with paths so they stay visible on any background.
    private static func makePageCursor(pointingLeft: Bool) -> NSCursor {
        let size = NSSize(width: 36, height: 36)
        let image = NSImage(size: size, flipped: false) { rect in
            let plate = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
            NSColor.black.withAlphaComponent(0.65).setFill()
            plate.fill()
            NSColor.white.setStroke()
            plate.lineWidth = 1
            plate.stroke()

            let chevron = NSBezierPath()
            if pointingLeft {
                chevron.move(to: NSPoint(x: 22, y: 10))
                chevron.line(to: NSPoint(x: 14, y: 18))
                chevron.line(to: NSPoint(x: 22, y: 26))
            } else {
                chevron.move(to: NSPoint(x: 14, y: 10))
                chevron.line(to: NSPoint(x: 22, y: 18))
                chevron.line(to: NSPoint(x: 14, y: 26))
            }
            chevron.lineWidth = 2.5
            chevron.lineCapStyle = .round
            chevron.lineJoinStyle = .round
            NSColor.white.setStroke()
            chevron.stroke()
            return true
        }
        let hotX: CGFloat = pointingLeft ? 8 : size.width - 8
        return NSCursor(image: image, hotSpot: NSPoint(x: hotX, y: size.height / 2))
    }
}
