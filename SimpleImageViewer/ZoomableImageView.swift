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
    var onRotateLeft: () -> Void
    var onRotateRight: () -> Void
    var onFlipHorizontal: () -> Void
    var onFlipVertical: () -> Void
    var onCopyImage: () -> Void
    var onSave: () -> Void
    var onSaveAs: () -> Void
    var onPrint: () -> Void
    var onUndoEdit: () -> Void
    var isDirty: Bool = false
    var markupItems: [MarkupItem] = []
    var markupTool: MarkupTool = .browse
    var markupColor: MarkupColor = .red
    var markupWeight: MarkupWeight = .regular
    var markupFontSize: MarkupFontSize = .regular
    var onAddMarkup: (MarkupItem) -> Void = { _ in }
    var onReplaceMarkup: (MarkupItem) -> Void = { _ in }
    var onRemoveMarkup: (UUID) -> Void = { _ in }
    var onSelectMarkup: (UUID?) -> Void = { _ in }
    var onMarkupTextEditing: (Bool) -> Void = { _ in }
    var cropSelection: CGRect? = nil
    var onCropSelection: (CGRect?) -> Void = { _ in }
    var onApplyCrop: () -> Void = {}

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
        let imageChanged = host.scrollView.image !== image
        if urlChanged || imageChanged {
            let resetZoom = urlChanged || dimensionsSwapped(host.scrollView.image, image)
            host.scrollView.setImage(image, url: imageURL, resetZoom: resetZoom)
        }
        if urlChanged {
            host.overlay.resetMarkupInteraction()
        } else if imageChanged, host.overlay.isEditingText {
            host.overlay.commitTextEditor()
        }
        if let zoomRequest, context.coordinator.lastZoomID != zoomRequest.id {
            context.coordinator.lastZoomID = zoomRequest.id
            host.scrollView.applyZoom(zoomRequest.kind)
        }
        host.overlay.markupItems = markupItems
        host.overlay.markupTool = markupTool
        host.overlay.markupColor = markupColor
        host.overlay.markupWeight = markupWeight
        host.overlay.markupFontSize = markupFontSize
        if host.overlay.cropSelection != cropSelection {
            host.overlay.cropSelection = cropSelection
        }
        host.overlay.syncCanvas()
        host.window?.invalidateCursorRects(for: host.overlay)
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
        host.overlay.onRotateLeft = onRotateLeft
        host.overlay.onRotateRight = onRotateRight
        host.overlay.onFlipHorizontal = onFlipHorizontal
        host.overlay.onFlipVertical = onFlipVertical
        host.overlay.onCopyImage = onCopyImage
        host.overlay.onSave = onSave
        host.overlay.onSaveAs = onSaveAs
        host.overlay.onPrint = onPrint
        host.overlay.onUndoEdit = onUndoEdit
        host.overlay.isDirty = isDirty
        host.overlay.onDelete = onDelete
        host.overlay.currentImageURL = { imageURL }
        host.overlay.onAddMarkup = onAddMarkup
        host.overlay.onReplaceMarkup = onReplaceMarkup
        host.overlay.onRemoveMarkup = onRemoveMarkup
        host.overlay.onSelectMarkup = onSelectMarkup
        host.overlay.onMarkupTextEditing = onMarkupTextEditing
        host.overlay.onCropSelection = onCropSelection
        host.overlay.onApplyCrop = onApplyCrop
        host.overlay.markupCanvas = host.scrollView.markupCanvas
        host.overlay.imageRectInOverlay = { [weak host] in
            guard let host else { return .zero }
            return host.scrollView.displayedImageRect(in: host.overlay)
        }
        host.scrollView.onDeleteMarkup = { [weak host] in
            host?.overlay.deleteSelectedMarkup() ?? false
        }
        host.scrollView.onEscapeMarkup = { [weak host] in
            host?.overlay.handleMarkupEscape() ?? false
        }
        host.scrollView.onReturnMarkup = { [weak host] in
            host?.overlay.handleMarkupReturn() ?? false
        }
        host.scrollView.onLayout = { [weak host] in
            host?.overlay.repositionTextEditor()
        }
        host.overlay.onMouseDown = { [weak host] event in
            guard let host else { return }
            if host.overlay.handleMarkupMouseDown(event) {
                if !host.overlay.isEditingText {
                    host.window?.makeFirstResponder(host.scrollView)
                }
                return
            }
            host.scrollView.handleOverlayMouseDown(event)
        }
        host.overlay.onMouseDragged = { [weak host] event in
            guard let host else { return }
            if host.overlay.handleMarkupMouseDragged(event) { return }
            host.scrollView.handleOverlayMouseDragged(event)
        }
        host.overlay.onMouseUp = { [weak host] event in
            guard let host else { return }
            if host.overlay.handleMarkupMouseUp(event) { return }
            host.scrollView.handleOverlayMouseUp(event)
        }
        host.overlay.onScrollWheel = { [weak host] event in host?.scrollView.scrollWheel(with: event) }
        host.overlay.onMagnify = { [weak host] event in host?.scrollView.magnify(with: event) }
        host.overlay.onSwipe = { [weak host] event in host?.scrollView.swipe(with: event) }
        host.overlay.onCursorMove = { [weak host] point in host?.applyPageCursor(atWindowPoint: point) }
    }

    private func dimensionsSwapped(_ old: NSImage?, _ new: NSImage) -> Bool {
        guard let old else { return false }
        let a = ImageLoader.pixelSize(of: old)
        let b = ImageLoader.pixelSize(of: new)
        return abs(a.width - b.height) < 0.5 && abs(a.height - b.width) < 0.5 && abs(a.width - a.height) > 0.5
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
        overlay.clipsToBounds = true
        overlay.layer?.backgroundColor = NSColor.clear.cgColor
        overlay.layer?.masksToBounds = true
        overlay.layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        overlay.frame = bounds
        overlay.needsDisplay = true
        window?.invalidateCursorRects(for: overlay)
    }

    func applyPageCursor(atWindowPoint point: NSPoint) {
        if overlay.isMovingMarkup || overlay.isResizingMarkup {
            NSCursor.closedHand.set()
            return
        }
        if overlay.markupTool != .crop, overlay.isHoveringMarkup(atWindowPoint: point) {
            NSCursor.openHand.set()
            return
        }
        if overlay.markupTool.isDrawing {
            overlay.markupTool.cursor.set()
            return
        }
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
    var onRotateLeft: (() -> Void)?
    var onRotateRight: (() -> Void)?
    var onFlipHorizontal: (() -> Void)?
    var onFlipVertical: (() -> Void)?
    var onCopyImage: (() -> Void)?
    var onSave: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onPrint: (() -> Void)?
    var onUndoEdit: (() -> Void)?
    var isDirty = false
    var currentImageURL: (() -> URL?)?
    var isFitting: (() -> Bool)?

    var onMouseDown: ((NSEvent) -> Void)?
    var onMouseDragged: ((NSEvent) -> Void)?
    var onMouseUp: ((NSEvent) -> Void)?
    var onScrollWheel: ((NSEvent) -> Void)?
    var onMagnify: ((NSEvent) -> Void)?
    var onSwipe: ((NSEvent) -> Void)?
    var onCursorMove: ((NSPoint) -> Void)?
    var onAddMarkup: ((MarkupItem) -> Void)?
    var onReplaceMarkup: ((MarkupItem) -> Void)?
    var onRemoveMarkup: ((UUID) -> Void)?
    var onSelectMarkup: ((UUID?) -> Void)?
    var onMarkupTextEditing: ((Bool) -> Void)?
    var onCropSelection: ((CGRect?) -> Void)?
    var onApplyCrop: (() -> Void)?
    var imageRectInOverlay: (() -> NSRect)?
    weak var markupCanvas: MarkupCanvasView?
    var markupItems: [MarkupItem] = [] {
        didSet {
            if let id = selectedID, !markupItems.contains(where: { $0.id == id }) {
                selectedID = nil
                hiddenID = nil
                draft = nil
                movingOriginal = nil
            }
            syncCanvas()
        }
    }
    var markupTool: MarkupTool = .browse {
        didSet {
            if oldValue == .text, markupTool != .text {
                commitTextEditor()
            }
            if markupTool != .crop, cropSelection != nil {
                cropSelection = nil
                onCropSelection?(nil)
            }
            window?.invalidateCursorRects(for: self)
            needsDisplay = true
        }
    }
    var markupColor: MarkupColor = .red {
        didSet {
            if let field = textEditor {
                field.textColor = markupColor.nsColor
                editingColor = markupColor
            }
        }
    }
    var markupWeight: MarkupWeight = .regular
    var markupFontSize: MarkupFontSize = .regular {
        didSet {
            editingFontSize = markupFontSize
            if let field = textEditor {
                field.font = .systemFont(ofSize: 16 * markupFontSize.scale, weight: .semibold)
            }
        }
    }

    private var draft: MarkupItem?
    private var dragStartFrac: CGPoint?
    private var movingOriginal: MarkupItem?
    private var resizeOriginal: MarkupItem?
    private var resizeHandle: MarkupHandle?
    private var selectedBeforeClick: UUID?
    private var selectedID: UUID? {
        didSet {
            if oldValue != selectedID {
                onSelectMarkup?(selectedID)
            }
        }
    }
    private var hiddenID: UUID?
    private var textEditor: NSTextField?
    private var textEditorFrac: CGPoint?
    private var editingItemID: UUID?
    private var editingColor: MarkupColor?
    private var editingWeight: MarkupWeight?
    private var editingFontSize: MarkupFontSize?
    var cropSelection: CGRect? {
        didSet { needsDisplay = true }
    }

    var isMovingMarkup: Bool { movingOriginal != nil }
    var isResizingMarkup: Bool { resizeOriginal != nil }

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override var clipsToBounds: Bool {
        get { true }
        set { }
    }

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
        if markupTool.isDrawing {
            addCursorRect(bounds, cursor: markupTool.cursor)
            return
        }
        let third = bounds.width / 3
        addCursorRect(NSRect(x: 0, y: 0, width: third, height: bounds.height), cursor: ImageScrollView.pageLeftCursor)
        addCursorRect(
            NSRect(x: bounds.width - third, y: 0, width: third, height: bounds.height),
            cursor: ImageScrollView.pageRightCursor
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard markupTool == .crop, let cropSelection else { return }
        let imageRect = imageRectInOverlay?() ?? .zero
        guard imageRect.width > 1 else { return }
        ImageMarkup.drawCropSelection(cropSelection, in: imageRect)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let editor = textEditor, !editor.isHidden, editor.frame.contains(point) {
            return editor.hitTest(convert(point, to: editor)) ?? editor
        }
        return bounds.contains(point) ? self : nil
    }

    func isHoveringMarkup(atWindowPoint point: NSPoint) -> Bool {
        let imageRect = imageRectInOverlay?() ?? .zero
        let local = convert(point, from: nil)
        return ImageMarkup.hitTest(markupItems, at: local, imageRect: imageRect) != nil
    }

    func syncCanvas() {
        markupCanvas?.items = markupItems
        markupCanvas?.draft = draft
        markupCanvas?.selectedID = selectedID
        markupCanvas?.hiddenID = hiddenID ?? editingItemID
    }

    func resetMarkupInteraction() {
        cancelTextEditor()
        selectedID = nil
        hiddenID = nil
        draft = nil
        movingOriginal = nil
        dragStartFrac = nil
        cropSelection = nil
        onCropSelection?(nil)
        editingItemID = nil
        editingColor = nil
        editingWeight = nil
        editingFontSize = nil
        textEditorFrac = nil
        resizeOriginal = nil
        resizeHandle = nil
        selectedBeforeClick = nil
        syncCanvas()
    }

    @discardableResult
    func handleMarkupEscape() -> Bool {
        if textEditor != nil {
            cancelTextEditor()
            return true
        }
        if movingOriginal != nil || resizeOriginal != nil {
            movingOriginal = nil
            resizeOriginal = nil
            resizeHandle = nil
            dragStartFrac = nil
            hiddenID = nil
            draft = nil
            syncCanvas()
            return true
        }
        if selectedID != nil {
            selectedID = nil
            hiddenID = nil
            draft = nil
            syncCanvas()
            return true
        }
        if cropSelection != nil {
            cropSelection = nil
            onCropSelection?(nil)
            return true
        }
        return false
    }

    @discardableResult
    func handleMarkupReturn() -> Bool {
        guard markupTool == .crop, let box = cropSelection?.standardized, box.width > 0.01, box.height > 0.01 else {
            return false
        }
        onApplyCrop?()
        return true
    }

    @discardableResult
    func deleteSelectedMarkup() -> Bool {
        if textEditor != nil {
            cancelTextEditor()
            return true
        }
        guard let id = selectedID else { return false }
        markupItems.removeAll { $0.id == id }
        onRemoveMarkup?(id)
        selectedID = nil
        hiddenID = nil
        draft = nil
        movingOriginal = nil
        resizeOriginal = nil
        resizeHandle = nil
        dragStartFrac = nil
        syncCanvas()
        return true
    }

    @discardableResult
    func handleMarkupMouseDown(_ event: NSEvent) -> Bool {
        if textEditor != nil {
            if event.clickCount >= 2, let editingItemID {
                let imageRect = imageRectInOverlay?() ?? .zero
                let local = convert(event.locationInWindow, from: nil)
                if ImageMarkup.hitTest(markupItems, at: local, imageRect: imageRect)?.id == editingItemID {
                    return true
                }
            }
            commitTextEditor()
            return true
        }
        selectedBeforeClick = selectedID
        resizeOriginal = nil
        resizeHandle = nil
        if markupTool == .crop {
            selectedID = nil
            movingOriginal = nil
            guard let frac = imageFraction(for: event) else { return true }
            dragStartFrac = frac
            cropSelection = CGRect(origin: frac, size: .zero)
            onCropSelection?(cropSelection)
            needsDisplay = true
            return true
        }
        let imageRect = imageRectInOverlay?() ?? .zero
        let local = convert(event.locationInWindow, from: nil)
        if let selected = markupItems.first(where: { $0.id == selectedID }),
           let handle = ImageMarkup.handleHit(selected, at: local, imageRect: imageRect) {
            resizeOriginal = selected
            resizeHandle = handle
            movingOriginal = nil
            dragStartFrac = imageFraction(for: event)
            draft = nil
            hiddenID = nil
            syncCanvas()
            return true
        }
        if let hit = ImageMarkup.hitTest(markupItems, at: local, imageRect: imageRect) {
            selectedID = hit.id
            if event.clickCount >= 2, case .text = hit.kind {
                movingOriginal = nil
                dragStartFrac = nil
                beginTextEditor(for: hit)
                return true
            }
            if markupTool == .text, case .text = hit.kind {
                beginTextEditor(for: hit)
                return true
            }
            movingOriginal = hit
            dragStartFrac = imageFraction(for: event)
            draft = nil
            hiddenID = nil
            syncCanvas()
            return true
        }

        selectedID = nil
        hiddenID = nil
        draft = nil
        movingOriginal = nil
        syncCanvas()

        guard markupTool.isDrawing else { return false }
        guard let frac = imageFraction(for: event) else { return true }
        dragStartFrac = frac
        switch markupTool {
        case .browse:
            return false
        case .pen:
            draft = MarkupItem(color: markupColor, weight: markupWeight, fontSize: markupFontSize, kind: .stroke(points: [frac]))
        case .arrow:
            draft = MarkupItem(color: markupColor, weight: markupWeight, fontSize: markupFontSize, kind: .arrow(start: frac, end: frac))
        case .rect:
            draft = MarkupItem(color: markupColor, weight: markupWeight, fontSize: markupFontSize, kind: .rect(start: frac, end: frac))
        case .oval:
            draft = MarkupItem(color: markupColor, weight: markupWeight, fontSize: markupFontSize, kind: .oval(start: frac, end: frac))
        case .crop:
            break
        case .text:
            beginTextEditor(at: frac, existing: nil)
            dragStartFrac = nil
        }
        syncCanvas()
        return true
    }

    @discardableResult
    func handleMarkupMouseDragged(_ event: NSEvent) -> Bool {
        if textEditor != nil { return true }
        if let original = resizeOriginal, let handle = resizeHandle {
            guard let frac = imageFraction(for: event) else { return true }
            hiddenID = original.id
            draft = ImageMarkup.resized(original, handle: handle, to: frac)
            selectedID = original.id
            syncCanvas()
            return true
        }
        if markupTool == .crop, let start = dragStartFrac {
            guard let frac = imageFraction(for: event) else { return true }
            cropSelection = CGRect(
                x: min(start.x, frac.x),
                y: min(start.y, frac.y),
                width: abs(frac.x - start.x),
                height: abs(frac.y - start.y)
            )
            onCropSelection?(cropSelection)
            needsDisplay = true
            return true
        }
        if let original = movingOriginal, let start = dragStartFrac {
            guard let frac = imageFraction(for: event) else { return true }
            let delta = CGPoint(x: frac.x - start.x, y: frac.y - start.y)
            let imageRect = imageRectInOverlay?() ?? .zero
            let pixels = hypot(delta.x * imageRect.width, delta.y * imageRect.height)
            if pixels < 4, draft == nil {
                return true
            }
            let clamped = ImageMarkup.clampTranslation(original, delta: delta)
            hiddenID = original.id
            draft = original.translated(by: clamped)
            selectedID = original.id
            syncCanvas()
            return true
        }
        guard markupTool.isDrawing else { return false }
        if markupTool == .text { return true }
        guard let start = dragStartFrac else { return true }
        guard let frac = imageFraction(for: event) else { return true }
        switch markupTool {
        case .pen:
            if var current = draft, case .stroke(var points) = current.kind {
                points.append(frac)
                current.kind = .stroke(points: points)
                draft = current
            }
        case .arrow:
            if var current = draft {
                current.kind = .arrow(start: start, end: frac)
                draft = current
            }
        case .rect:
            if var current = draft {
                current.kind = .rect(start: start, end: frac)
                draft = current
            }
        case .oval:
            if var current = draft {
                current.kind = .oval(start: start, end: frac)
                draft = current
            }
        default:
            break
        }
        syncCanvas()
        return true
    }

    @discardableResult
    func handleMarkupMouseUp(_ event: NSEvent) -> Bool {
        if textEditor != nil { return true }
        if let original = resizeOriginal {
            if let draft, draft != original {
                if let idx = markupItems.firstIndex(where: { $0.id == original.id }) {
                    markupItems[idx] = draft
                }
                onReplaceMarkup?(draft)
                selectedID = draft.id
            }
            resizeOriginal = nil
            resizeHandle = nil
            dragStartFrac = nil
            hiddenID = nil
            self.draft = nil
            syncCanvas()
            return true
        }
        if markupTool == .crop {
            if let box = cropSelection?.standardized, box.width < 0.01 || box.height < 0.01 {
                cropSelection = nil
                onCropSelection?(nil)
            }
            dragStartFrac = nil
            needsDisplay = true
            return true
        }
        if let original = movingOriginal {
            if let draft, draft != original {
                if let idx = markupItems.firstIndex(where: { $0.id == original.id }) {
                    markupItems[idx] = draft
                }
                onReplaceMarkup?(draft)
                selectedID = draft.id
            } else if case .text = original.kind,
                      selectedBeforeClick == original.id || event.clickCount >= 2 {
                beginTextEditor(for: original)
                movingOriginal = nil
                dragStartFrac = nil
                hiddenID = nil
                self.draft = nil
                return true
            }
            movingOriginal = nil
            dragStartFrac = nil
            hiddenID = nil
            self.draft = nil
            syncCanvas()
            return true
        }
        guard markupTool.isDrawing else { return false }
        if markupTool == .text { return true }
        defer {
            dragStartFrac = nil
            draft = nil
            syncCanvas()
        }
        if let draft, isMeaningful(draft) {
            markupItems.append(draft)
            onAddMarkup?(draft)
            selectedID = draft.id
        }
        return true
    }

    private func imageFraction(for event: NSEvent) -> CGPoint? {
        let imageRect = imageRectInOverlay?() ?? .zero
        guard imageRect.width > 1, imageRect.height > 1 else { return nil }
        let local = convert(event.locationInWindow, from: nil)
        let frac = CGPoint(
            x: (local.x - imageRect.minX) / imageRect.width,
            y: (local.y - imageRect.minY) / imageRect.height
        )
        return CGPoint(x: min(max(frac.x, 0), 1), y: min(max(frac.y, 0), 1))
    }

    private func isMeaningful(_ item: MarkupItem) -> Bool {
        switch item.kind {
        case .stroke(let points):
            return !points.isEmpty
        case .arrow(let start, let end), .rect(let start, let end), .oval(let start, let end):
            let dx = end.x - start.x
            let dy = end.y - start.y
            return (dx * dx + dy * dy) > 0.0002
        case .text(_, let string):
            return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func beginTextEditor(for item: MarkupItem) {
        guard case .text(let origin, _) = item.kind else { return }
        beginTextEditor(at: origin, existing: item)
    }

    private func beginTextEditor(at frac: CGPoint, existing: MarkupItem?) {
        commitTextEditor()
        let imageRect = imageRectInOverlay?() ?? .zero
        let origin = NSPoint(
            x: imageRect.minX + frac.x * imageRect.width,
            y: imageRect.minY + frac.y * imageRect.height
        )
        let existingText: String
        if let existing, case .text(_, let string) = existing.kind {
            existingText = string
        } else {
            existingText = ""
        }
        let color = existing?.color ?? markupColor
        let weight = existing?.weight ?? markupWeight
        let fontSize = existing?.fontSize ?? markupFontSize
        let attrs = ImageMarkup.textAttributes(color: color.nsColor, imageRect: imageRect, fontSize: fontSize)
        let textSize = (existingText as NSString).size(withAttributes: attrs)
        let width = max(260, min(max(120, bounds.width - 16), textSize.width + 56))
        let fieldHeight = max(30, 22 * fontSize.scale)
        var fieldX = origin.x
        var fieldY = origin.y - 4
        fieldX = min(max(6, fieldX), max(6, bounds.width - width - 6))
        fieldY = min(max(4, fieldY), max(4, bounds.height - fieldHeight - 4))
        let field = NSTextField(frame: NSRect(x: fieldX, y: fieldY, width: width, height: fieldHeight))
        field.placeholderString = LanguageManager.shared.t(.textPlaceholder)
        field.font = .systemFont(ofSize: 16 * fontSize.scale, weight: .semibold)
        field.textColor = color.nsColor
        field.backgroundColor = NSColor.black.withAlphaComponent(0.55)
        field.drawsBackground = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.isEditable = true
        field.isSelectable = true
        field.focusRingType = .none
        field.stringValue = existingText
        field.target = self
        field.action = #selector(textEditorEnded(_:))
        field.delegate = self
        field.tag = 9401
        addSubview(field)
        textEditor = field
        textEditorFrac = frac
        editingItemID = existing?.id
        editingColor = color
        editingWeight = weight
        editingFontSize = fontSize
        if let existing {
            hiddenID = existing.id
            selectedID = existing.id
        }
        syncCanvas()
        onMarkupTextEditing?(true)
        window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
    }

    func repositionTextEditor() {
        guard let field = textEditor, let frac = textEditorFrac else { return }
        let imageRect = imageRectInOverlay?() ?? .zero
        guard imageRect.width > 1, imageRect.height > 1 else { return }
        var frame = field.frame
        frame.origin = NSPoint(
            x: imageRect.minX + frac.x * imageRect.width,
            y: imageRect.minY + frac.y * imageRect.height - 4
        )
        field.frame = frame
    }

    @objc private func textEditorEnded(_ sender: NSTextField) {
        commitTextEditor()
    }

    @discardableResult
    func commitTextEditor() -> Bool {
        guard let field = textEditor else { return false }
        let text = field.stringValue
        let replaceID = editingItemID
        let color = editingColor ?? markupColor
        let weight = editingWeight ?? markupWeight
        let fontSize = editingFontSize ?? markupFontSize
        let frac = textEditorFrac ?? .zero
        field.delegate = nil
        field.removeFromSuperview()
        textEditor = nil
        textEditorFrac = nil
        editingItemID = nil
        editingColor = nil
        editingWeight = nil
        editingFontSize = nil
        hiddenID = nil
        onMarkupTextEditing?(false)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { syncCanvas() }
        if let replaceID {
            if trimmed.isEmpty {
                markupItems.removeAll { $0.id == replaceID }
                onRemoveMarkup?(replaceID)
                selectedID = nil
            } else {
                let item = MarkupItem(
                    id: replaceID,
                    color: color,
                    weight: weight,
                    fontSize: fontSize,
                    kind: .text(origin: frac, string: text)
                )
                if let idx = markupItems.firstIndex(where: { $0.id == replaceID }) {
                    markupItems[idx] = item
                }
                onReplaceMarkup?(item)
                selectedID = replaceID
            }
            return true
        }
        guard !trimmed.isEmpty else { return true }
        let item = MarkupItem(color: color, weight: weight, fontSize: fontSize, kind: .text(origin: frac, string: text))
        markupItems.append(item)
        onAddMarkup?(item)
        selectedID = item.id
        return true
    }

    func cancelTextEditor() {
        textEditor?.delegate = nil
        textEditor?.removeFromSuperview()
        textEditor = nil
        textEditorFrac = nil
        editingItemID = nil
        editingColor = nil
        editingWeight = nil
        editingFontSize = nil
        hiddenID = nil
        onMarkupTextEditing?(false)
        syncCanvas()
    }

    var isEditingText: Bool { textEditor != nil }

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

    private func buildContextMenu() -> NSMenu {
        let lang = LanguageManager.shared
        let menu = NSMenu()
        menu.addItem(withTitle: lang.t(.openImage), action: #selector(menuOpenImage), keyEquivalent: "")
        menu.addItem(withTitle: lang.t(.openFolder), action: #selector(menuOpenFolder), keyEquivalent: "")
        menu.addItem(.separator())

        let hasFile = currentImageURL?() != nil
        let rotateLeft = menu.addItem(withTitle: lang.t(.rotateLeft), action: #selector(menuRotateLeft), keyEquivalent: "")
        rotateLeft.isEnabled = hasFile
        let rotateRight = menu.addItem(withTitle: lang.t(.rotateRight), action: #selector(menuRotateRight), keyEquivalent: "")
        rotateRight.isEnabled = hasFile
        let flipH = menu.addItem(withTitle: lang.t(.flipHorizontal), action: #selector(menuFlipHorizontal), keyEquivalent: "")
        flipH.isEnabled = hasFile
        let flipV = menu.addItem(withTitle: lang.t(.flipVertical), action: #selector(menuFlipVertical), keyEquivalent: "")
        flipV.isEnabled = hasFile
        menu.addItem(.separator())

        let copyImage = menu.addItem(withTitle: lang.t(.copyImage), action: #selector(menuCopyImage), keyEquivalent: "")
        copyImage.isEnabled = hasFile
        let undo = menu.addItem(withTitle: lang.t(.undoEdit), action: #selector(menuUndoEdit), keyEquivalent: "")
        undo.isEnabled = hasFile && isDirty
        let save = menu.addItem(withTitle: lang.t(.save), action: #selector(menuSave), keyEquivalent: "")
        save.isEnabled = hasFile && isDirty
        let saveAs = menu.addItem(withTitle: lang.t(.saveAsEllipsis), action: #selector(menuSaveAs), keyEquivalent: "")
        saveAs.isEnabled = hasFile
        let printItem = menu.addItem(withTitle: lang.t(.printEllipsis), action: #selector(menuPrint), keyEquivalent: "")
        printItem.isEnabled = hasFile
        menu.addItem(.separator())

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
    @objc private func menuRotateLeft() { onRotateLeft?() }
    @objc private func menuRotateRight() { onRotateRight?() }
    @objc private func menuFlipHorizontal() { onFlipHorizontal?() }
    @objc private func menuFlipVertical() { onFlipVertical?() }
    @objc private func menuCopyImage() { onCopyImage?() }
    @objc private func menuUndoEdit() { onUndoEdit?() }
    @objc private func menuSave() { onSave?() }
    @objc private func menuSaveAs() { onSaveAs?() }
    @objc private func menuPrint() { onPrint?() }
    @objc private func menuPrevious() { onNavigate?(.previous) }
    @objc private func menuNext() { onNavigate?(.next) }
    @objc private func menuDelete() { onDelete?() }
    @objc private func menuOpenWith(_ sender: NSMenuItem) {
        guard let appURL = sender.representedObject as? URL else { return }
        onOpenWithApp?(appURL)
    }
}

extension PageHitOverlay: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        commitTextEditor()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelTextEditor()
            return true
        }
        return false
    }
}

final class ImageScrollView: NSScrollView {
    var representedURL: URL?
    private(set) var image: NSImage?

    var onNavigate: ((NavigateDirection) -> Void)?
    var onDelete: (() -> Void)?
    var onEscape: (() -> Void)?
    var onLayout: (() -> Void)?
    var onDeleteMarkup: (() -> Bool)?
    var onEscapeMarkup: (() -> Bool)?
    var onReturnMarkup: (() -> Bool)?
    let markupCanvas = MarkupCanvasView()

    var isFittingMode: Bool { isFitting }

    func displayedImageRect(in view: NSView) -> NSRect {
        view.convert(imageView.frame, from: canvas)
    }

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
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets()

        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor.black.cgColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = false
        imageView.wantsLayer = true
        imageView.refusesFirstResponder = true
        markupCanvas.wantsLayer = true
        markupCanvas.clipsToBounds = true
        markupCanvas.layer?.backgroundColor = NSColor.clear.cgColor
        markupCanvas.layer?.masksToBounds = true
        canvas.addSubview(imageView)
        canvas.addSubview(markupCanvas)
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
        markupCanvas.isHidden = true
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
        markupCanvas.isHidden = false
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
            relayout(keepUserZoom: true, anchorWindowPoint: nil)
        case .out:
            let next = userZoom / 1.25
            if next <= 1.02 {
                userZoom = 1
                isFitting = true
            } else {
                isFitting = false
                userZoom = next
            }
            relayout(keepUserZoom: true, anchorWindowPoint: nil)
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

    /// Keep the image point under `anchorWindowPoint` (or the visible center) fixed.
    /// Without this, zoom is anchored at the document origin, so the picture jumps left
    /// as the centered letterbox padding disappears.
    private func relayout(keepUserZoom: Bool, anchorWindowPoint: NSPoint? = nil) {
        guard !isRelayouting else { return }
        let view = visibleSize()
        guard imagePointSize.width > 0, imagePointSize.height > 0, view.width > 1, view.height > 1 else { return }
        isRelayouting = true
        defer { isRelayouting = false }

        let oldImageFrame = imageView.frame
        let oldVisible = contentView.documentVisibleRect
        let hasOldLayout = oldImageFrame.width > 1 && oldImageFrame.height > 1
        let anchorInDoc: NSPoint
        if hasOldLayout, let windowPoint = anchorWindowPoint {
            anchorInDoc = canvas.convert(windowPoint, from: nil)
        } else if hasOldLayout {
            anchorInDoc = NSPoint(x: oldVisible.midX, y: oldVisible.midY)
        } else {
            anchorInDoc = .zero
        }
        let fracX = hasOldLayout ? (anchorInDoc.x - oldImageFrame.minX) / oldImageFrame.width : 0.5
        let fracY = hasOldLayout ? (anchorInDoc.y - oldImageFrame.minY) / oldImageFrame.height : 0.5
        let offsetInVisible = NSPoint(x: anchorInDoc.x - oldVisible.minX, y: anchorInDoc.y - oldVisible.minY)

        if isFitting { userZoom = 1 }
        let scale = baseScale(for: view) * max(userZoom, 0.01)
        let disp = NSSize(width: imagePointSize.width * scale, height: imagePointSize.height * scale)
        let doc = NSSize(width: max(view.width, disp.width), height: max(view.height, disp.height))
        canvas.frame = NSRect(origin: .zero, size: doc)
        imageView.frame = NSRect(
            origin: NSPoint(x: (doc.width - disp.width) / 2, y: (doc.height - disp.height) / 2),
            size: disp
        )
        markupCanvas.frame = imageView.frame
        if isFitting || !keepUserZoom || !hasOldLayout {
            centerDocument()
        } else {
            let newAnchor = NSPoint(
                x: imageView.frame.minX + fracX * imageView.frame.width,
                y: imageView.frame.minY + fracY * imageView.frame.height
            )
            var origin = NSPoint(x: newAnchor.x - offsetInVisible.x, y: newAnchor.y - offsetInVisible.y)
            origin.x = min(max(origin.x, 0), max(0, doc.width - view.width))
            origin.y = min(max(origin.y, 0), max(0, doc.height - view.height))
            contentView.setBoundsOrigin(origin)
            reflectScrolledClipView(contentView)
        }
        onLayout?()
    }

    private func centerDocument() {
        let doc = canvas.frame.size
        var clip = contentView.bounds
        clip.origin.x = clip.width < doc.width ? (doc.width - clip.width) / 2 : 0
        clip.origin.y = clip.height < doc.height ? (doc.height - clip.height) / 2 : 0
        contentView.setBoundsOrigin(clip.origin)
        reflectScrolledClipView(contentView)
        onLayout?()
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
            relayout(keepUserZoom: true, anchorWindowPoint: event.locationInWindow)
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
        relayout(keepUserZoom: true, anchorWindowPoint: event.locationInWindow)
    }

    func handleOverlayMouseDown(_ event: NSEvent) {
        lastDragPoint = event.locationInWindow
        mouseDownPoint = event.locationInWindow
        didDrag = false
        window?.makeFirstResponder(self)
        if event.clickCount == 2 {
            if isFitting {
                isFitting = false
                let base = baseScale(for: visibleSize())
                userZoom = base > 0 ? (1.0 / base) : 1
                relayout(keepUserZoom: true, anchorWindowPoint: event.locationInWindow)
            } else {
                applyZoom(.fit)
            }
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
        case 51, 117:
            if onDeleteMarkup?() == true { return }
            onDelete?()
        case 53:
            if onEscapeMarkup?() == true { return }
            onEscape?()
        case 36, 76:
            if onReturnMarkup?() == true { return }
            super.keyDown(with: event)
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
