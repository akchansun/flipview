import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum NavigateDirection {
    case previous
    case next
}

enum ZoomKind: Equatable {
    case `in`
    case out
    case fit
    case actual
}

struct ZoomRequest: Equatable {
    let kind: ZoomKind
    let id = UUID()
}

/// Owns the current image, the sorted sibling list, slideshow, and trash.
@MainActor
final class ImageSession: ObservableObject {
    @Published var currentURL: URL?
    @Published var currentImage: NSImage?
    @Published var gallery: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsFolderPermission = false
    @Published var isSlideshow = false
    @Published var showDeleteConfirm = false
    @Published var zoomRequest: ZoomRequest?
    @Published var isDropTargeted = false
    @Published private(set) var isDirty = false
    @Published private(set) var markupTool: MarkupTool = .browse
    @Published var markupColor: MarkupColor = .red
    @Published var markupWeight: MarkupWeight = .regular
    @Published var markupFontSize: MarkupFontSize = .regular
    @Published var markupFilled = false
    @Published private(set) var selectedMarkupID: UUID?
    @Published private(set) var isEditingMarkupText = false
    @Published private(set) var markupItems: [MarkupItem] = []
    @Published var cropSelection: CGRect?
    @Published var showAdjustColor = false
    @Published var showAdjustSize = false
    @Published var showInspector = false
    @Published var colorAdjust = ColorAdjust()

    let folderAccess = FolderAccess()
    /// Display-sized decode without rotate/flip. Replay `pendingOps` from this on undo.
    private var sourceImage: NSImage?
    private var pendingOps: [ImageOp] = []
    private var loadGeneration = 0
    private var slideshowTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    /// Decoded images kept warm for snappy ←/→.
    private let imageCache = NSCache<NSString, NSImage>()
    private var undoStack: [(ops: [ImageOp], marks: [MarkupItem])] = []
    private var colorUndoPushed = false

    private var cacheConfigured = false

    private func ensureCacheConfigured() {
        guard !cacheConfigured else { return }
        cacheConfigured = true
        imageCache.countLimit = 24
        // Rough budget: keep a handful of large decoded images.
        imageCache.totalCostLimit = 256 * 1024 * 1024
    }

    var windowTitle: String {
        guard let name = currentURL?.lastPathComponent else {
            return LanguageManager.shared.t(.appName)
        }
        if gallery.isEmpty {
            if isDirty {
                return "\(name) \(LanguageManager.shared.t(.editedSuffix))"
            }
            return name
        }
        let position = "\(currentIndex + 1) / \(gallery.count)"
        var title = "\(name) — \(position)"
        if isDirty {
            title += " \(LanguageManager.shared.t(.editedSuffix))"
        }
        if isSlideshow {
            title += " \(LanguageManager.shared.t(.slideshowSuffix))"
        }
        return title
    }

    func refreshWindowTitle() {
        objectWillChange.send()
        applyWindowTitle()
    }

    func applyWindowTitle() {
        NSApp.windows.first?.title = windowTitle
    }

    var canNavigate: Bool { gallery.count > 1 }

    var hasImage: Bool { currentImage != nil }

    /// Opens a file (or a folder of files). Sibling discovery is non-recursive.
    func open(_ url: URL) {
        folderAccess.retain(url)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            openFolder(url)
            return
        }
        openFile(url)
    }

    func openPanelForImage() {
        guard confirmDiscardIfNeeded() else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = SupportedFormats.contentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = LanguageManager.shared.t(.chooseImageMessage)
        panel.prompt = LanguageManager.shared.t(.open)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folderAccess.retain(url)
        openFile(url)
    }

    func openPanelForFolder() {
        guard confirmDiscardIfNeeded() else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = LanguageManager.shared.t(.chooseFolderMessage)
        panel.prompt = LanguageManager.shared.t(.open)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folderAccess.retain(url)
        folderAccess.saveBookmark(for: url)
        openFolder(url)
    }

    func revealInFinder() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openWithApplication(at appURL: URL) {
        guard let url = currentURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func copyCurrentPath() {
        guard let url = currentURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

        func requestFolderAccess() {
        guard let file = currentURL else { return }
        let preferred = file.deletingLastPathComponent()
        guard let granted = folderAccess.promptForDirectory(preferred: preferred) else { return }
        refreshGallery(in: granted, selecting: file)
    }

    /// Previous / next in the sorted gallery. Wraps around at both ends.
    func navigate(_ direction: NavigateDirection) {
        guard canNavigate else { return }
        guard confirmDiscardIfNeeded() else { return }
        let count = gallery.count
        switch direction {
        case .next:
            currentIndex = (currentIndex + 1) % count
        case .previous:
            currentIndex = (currentIndex - 1 + count) % count
        }
        let url = gallery[currentIndex]
        currentURL = url
        loadImage(at: url, prefetchNeighbors: true)
    }

    func requestZoom(_ kind: ZoomKind) {
        zoomRequest = ZoomRequest(kind: kind)
    }

    func toggleSlideshow() {
        guard currentImage != nil else { return }
        if isSlideshow {
            stopSlideshow()
        } else {
            guard confirmDiscardIfNeeded() else { return }
            startSlideshow()
        }
    }

    func stopSlideshow() {
        isSlideshow = false
        slideshowTask?.cancel()
        slideshowTask = nil
    }

    func requestDelete() {
        guard currentURL != nil else { return }
        stopSlideshow()
        showDeleteConfirm = true
    }

    func deleteCurrent() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.recycle([url]) { [weak self] _, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                self.removeDeleted(url)
            }
        }
    }

    private func openFile(_ url: URL) {
        guard confirmDiscardIfNeeded() else { return }
        folderAccess.retain(url)
        stopSlideshow()
        currentURL = url
        loadImage(at: url)
        discoverSiblings(for: url)
    }

    private func openFolder(_ directory: URL) {
        guard confirmDiscardIfNeeded() else { return }
        folderAccess.retain(directory)
        folderAccess.saveBookmark(for: directory)
        stopSlideshow()
        cancelPrefetch()
        isLoading = true
        errorMessage = nil
        // Keep previous image until the first new frame arrives to avoid a long blank spinner.
        let dir = directory
        Task.detached(priority: .userInitiated) {
            let listed = Self.imageURLs(in: dir)
            await MainActor.run {
                self.applyGalleryListing(listed, in: dir, selecting: nil)
            }
        }
    }

    private func discoverSiblings(for file: URL) {
        let parent = file.deletingLastPathComponent()

        if folderAccess.canListContents(of: parent) {
            let fileURL = file
            let parentURL = parent
            Task.detached(priority: .userInitiated) {
                let listed = Self.imageURLs(in: parentURL)
                await MainActor.run {
                    self.applyGalleryListing(listed, in: parentURL, selecting: fileURL)
                }
            }
            return
        }

        if let restored = folderAccess.restoreBookmark(for: parent),
           folderAccess.canListContents(of: restored) {
            refreshGallery(in: restored, selecting: file)
            return
        }

        gallery = [file]
        currentIndex = 0
        needsFolderPermission = true
    }

        private func refreshGallery(in directory: URL, selecting selected: URL?) {
        // Sync path for cases that already have folder access on a snappy volume.
        let listed = Self.imageURLs(in: directory)
        applyGalleryListing(listed, in: directory, selecting: selected)
    }

    private func applyGalleryListing(_ listed: [URL]?, in directory: URL, selecting selected: URL?) {
        cancelPrefetch()
        needsFolderPermission = listed == nil
        var urls = listed ?? []

        if let selected {
            let selectedPath = selected.standardizedFileURL.path
            if !urls.contains(where: { $0.standardizedFileURL.path == selectedPath }),
               SupportedFormats.hasKnownImageExtension(selected) || FileManager.default.fileExists(atPath: selected.path) {
                urls.append(selected)
                urls.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            }
            gallery = urls
            currentIndex = gallery.firstIndex(where: { $0.standardizedFileURL.path == selectedPath }) ?? 0
            currentURL = gallery.indices.contains(currentIndex) ? gallery[currentIndex] : selected
        } else {
            gallery = urls
            currentIndex = 0
            if let first = gallery.first {
                currentURL = first
            } else {
                currentURL = nil
                currentImage = nil
                sourceImage = nil
                clearEdits(keepingImage: false)
                isLoading = false
                errorMessage = LanguageManager.shared.t(.noSupportedImages)
                return
            }
        }

        if let url = currentURL {
            loadImage(at: url, prefetchNeighbors: true)
        } else {
            isLoading = false
        }
    }


    /// Non-recursive. Finder-style natural sort (`img2` before `img10`).
        nonisolated static func imageURLs(in directory: URL) -> [URL]? {
        // Extension-only filter + no per-file resourceValues: critical on ExFAT with large folders.
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return contents
            .filter { SupportedFormats.hasKnownImageExtension($0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }


    private func cacheKey(for url: URL) -> NSString {
        url.standardizedFileURL.path as NSString
    }

    private func cachedImage(for url: URL) -> NSImage? {
        imageCache.object(forKey: cacheKey(for: url))
    }

    private func storeCached(_ image: NSImage, for url: URL) {
        let px = ImageLoader.pixelSize(of: image)
        let cost = Int(max(px.width, 1) * max(px.height, 1) * 4)
        imageCache.setObject(image, forKey: cacheKey(for: url), cost: cost)
    }

    private func cancelPrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
    }

    private func loadImage(at url: URL, prefetchNeighbors: Bool = true) {
        ensureCacheConfigured()
        // Sibling listing often re-calls load for the file already on screen; don't
        // wipe in-progress rotate/flip.
        if isDirty, currentURL?.standardizedFileURL.path == url.standardizedFileURL.path {
            if prefetchNeighbors {
                prefetchAroundCurrentIndex()
            }
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        errorMessage = nil
        cancelPrefetch()
        clearEdits(keepingImage: false)

        if let cached = cachedImage(for: url) {
            sourceImage = cached
            currentImage = cached
            isLoading = false
            if prefetchNeighbors {
                prefetchAroundCurrentIndex()
            }
            return
        }

        isLoading = true
        let maxPixel = ImageLoader.displayMaxPixelSize()
        let securityScoped = url.startAccessingSecurityScopedResource()
        Task.detached(priority: .userInitiated) {
            let image = ImageLoader.load(from: url, maxPixelSize: maxPixel)
            if securityScoped {
                url.stopAccessingSecurityScopedResource()
            }
            await MainActor.run {
                guard generation == self.loadGeneration else { return }
                if let image {
                    self.storeCached(image, for: url)
                }
                self.sourceImage = image
                self.currentImage = image
                self.isLoading = false
                if image == nil {
                    self.errorMessage = LanguageManager.shared.format(.couldNotLoadNamed, url.lastPathComponent)
                } else if prefetchNeighbors {
                    self.prefetchAroundCurrentIndex()
                }
            }
        }
    }

    /// Serial prefetch (±4). Parallel reads on ExFAT/USB often fight each other and feel slower.
    private func prefetchAroundCurrentIndex() {
        guard !gallery.isEmpty else { return }
        let count = gallery.count
        guard count >= 2 else { return }
        var offsets = [1, -1]
        if count >= 4 { offsets.append(contentsOf: [2, -2]) }

        var urls: [URL] = []
        for offset in offsets {
            let idx = (currentIndex + offset % count + count) % count
            let url = gallery[idx]
            if cachedImage(for: url) == nil {
                urls.append(url)
            }
        }
        guard !urls.isEmpty else { return }

        let maxPixel = ImageLoader.displayMaxPixelSize()
        // Let the first frame paint before touching the disk again.
        prefetchTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            for url in urls {
                guard let self else { return }
                guard !Task.isCancelled else { return }
                let already = await MainActor.run { self.cachedImage(for: url) != nil }
                if already { continue }
                let securityScoped = url.startAccessingSecurityScopedResource()
                let image = ImageLoader.load(from: url, maxPixelSize: maxPixel)
                if securityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
                guard !Task.isCancelled, let image else { continue }
                await MainActor.run {
                    self.storeCached(image, for: url)
                }
            }
        }
    }


    private func startSlideshow() {
        guard currentImage != nil else { return }
        isSlideshow = true
        slideshowTask?.cancel()
        slideshowTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self, self.isSlideshow else { return }
                    if self.canNavigate {
                        self.navigate(.next)
                    }
                }
            }
        }
    }

    private func removeDeleted(_ url: URL) {
        let path = url.standardizedFileURL.path
        gallery.removeAll { $0.standardizedFileURL.path == path }
        currentImage = nil
        sourceImage = nil
        clearEdits(keepingImage: false)
        if gallery.isEmpty {
            currentURL = nil
            currentIndex = 0
            return
        }
        if currentIndex >= gallery.count {
            currentIndex = 0
        }
        currentURL = gallery[currentIndex]
        loadImage(at: gallery[currentIndex])
    }

    func apply(_ op: ImageOp) {
        guard let source = sourceImage ?? currentImage else { return }
        stopSlideshow()
        if sourceImage == nil {
            sourceImage = source
        }
        pushUndo()
        pendingOps.append(op)
        if case .color(let adjust) = op {
            colorAdjust = adjust
        }
        markupItems = markupItems.map { $0.transformed(by: op) }
        currentImage = ImageEditing.apply(pendingOps, to: source)
        refreshDirty()
        if op.swapsDimensions {
            requestZoom(.fit)
        }
    }

    func applyCrop() {
        guard let frac = cropSelection?.standardized, frac.width > 0.01, frac.height > 0.01 else { return }
        apply(.crop(frac))
        cropSelection = nil
        markupTool = .browse
    }

    func setCropSelection(_ frac: CGRect?) {
        cropSelection = frac?.standardized
    }

    func selectEntireImage() {
        guard hasImage else { return }
        stopSlideshow()
        markupTool = .crop
        cropSelection = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    func removeBackground() {
        apply(.removeBackground)
    }

    func newFromClipboard() {
        guard confirmDiscardIfNeeded() else { return }
        guard let image = NSImage(pasteboard: .general),
              let cg = ImageLoader.cgImage(from: image) else {
            let lang = LanguageManager.shared
            if currentImage != nil {
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = lang.t(.newFromClipboard)
                alert.informativeText = lang.t(.clipboardEmpty)
                alert.runModal()
            } else {
                errorMessage = lang.t(.clipboardEmpty)
            }
            return
        }
        let name = LanguageManager.shared.t(.untitledImage)
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(Int(Date().timeIntervalSince1970)).png")
        do {
            try ImageEditing.write(cg, to: dest, type: .png)
        } catch {
            errorMessage = LanguageManager.shared.t(.clipboardEmpty)
            return
        }
        folderAccess.retain(dest)
        openFile(dest)
    }

    func beginColorAdjust() {
        colorUndoPushed = false
        colorAdjust = currentColorAdjust()
        showAdjustColor = true
    }

    func setColorAdjust(_ adjust: ColorAdjust) {
        guard let source = sourceImage ?? currentImage else { return }
        stopSlideshow()
        if sourceImage == nil {
            sourceImage = source
        }
        if !colorUndoPushed {
            pushUndo()
            colorUndoPushed = true
        }
        colorAdjust = adjust
        if let idx = pendingOps.lastIndex(where: { if case .color = $0 { return true }; return false }) {
            if adjust.isIdentity {
                pendingOps.remove(at: idx)
            } else {
                pendingOps[idx] = .color(adjust)
            }
        } else if !adjust.isIdentity {
            pendingOps.append(.color(adjust))
        }
        currentImage = pendingOps.isEmpty ? source : ImageEditing.apply(pendingOps, to: source)
        refreshDirty()
    }

    func resetColorAdjust() {
        setColorAdjust(ColorAdjust())
    }

    func applyResize(width: Int, height: Int) {
        let w = max(1, width)
        let h = max(1, height)
        apply(.resize(width: w, height: h))
        showAdjustSize = false
    }

    var displayedPixelSize: NSSize {
        guard let image = currentImage else { return .zero }
        return ImageLoader.pixelSize(of: image)
    }

    var inspectorRows: [(String, String)] {
        let lang = LanguageManager.shared
        var rows: [(String, String)] = []
        if let url = currentURL {
            rows.append((lang.t(.inspectorFile), url.lastPathComponent))
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize {
                rows.append((lang.t(.inspectorBytes), ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))
            }
            rows.append((lang.t(.inspectorFormat), url.pathExtension.uppercased()))
        }
        let px = displayedPixelSize
        if px.width > 0 {
            rows.append((lang.t(.inspectorPixels), "\(Int(px.width)) × \(Int(px.height))"))
        }
        if let image = currentImage, let cg = ImageLoader.cgImage(from: image), let space = cg.colorSpace {
            let name = (space.name as String?) ?? "RGB"
            rows.append((lang.t(.inspectorColor), name))
        }
        if let url = currentURL, let details = ImageEditing.sourceDetails(for: url) {
            if let dpi = formattedDPI(details) {
                rows.append((lang.t(.inspectorDPI), dpi))
            }
            if let profile = details.profile?.trimmingCharacters(in: .whitespacesAndNewlines), !profile.isEmpty {
                rows.append((lang.t(.inspectorProfile), profile))
            }
            if let camera = formattedCamera(details) {
                rows.append((lang.t(.inspectorCamera), camera))
            }
            if let lens = details.lens?.trimmingCharacters(in: .whitespacesAndNewlines), !lens.isEmpty {
                rows.append((lang.t(.inspectorLens), lens))
            }
            if let exposure = formattedExposure(details) {
                rows.append((lang.t(.inspectorExposure), exposure))
            }
            if let captured = details.captured {
                let formatter = DateFormatter()
                formatter.locale = lang.resolved == .chineseSimplified ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                rows.append((lang.t(.inspectorCaptured), formatter.string(from: captured)))
            }
        }
        return rows
    }

    var sourceDPILabel: String? {
        guard let url = currentURL, let details = ImageEditing.sourceDetails(for: url) else { return nil }
        return formattedDPI(details)
    }

    private func formattedDPI(_ details: ImageEditing.SourceDetails) -> String? {
        guard let x = details.dpiX, x > 0 else { return nil }
        let y = details.dpiY ?? x
        if abs(x - y) < 0.5 {
            return String(format: "%.0f", x)
        }
        return String(format: "%.0f × %.0f", x, y)
    }

    private func formattedCamera(_ details: ImageEditing.SourceDetails) -> String? {
        let make = details.make?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = details.model?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !model.isEmpty {
            if !make.isEmpty, !model.lowercased().hasPrefix(make.lowercased()) {
                return "\(make) \(model)"
            }
            return model
        }
        return make.isEmpty ? nil : make
    }

    private func formattedExposure(_ details: ImageEditing.SourceDetails) -> String? {
        var parts: [String] = []
        if let t = details.exposureTime, t > 0 {
            if t < 1 {
                parts.append("1/\(max(1, Int((1 / t).rounded())))")
            } else {
                parts.append(String(format: "%.1fs", t))
            }
        }
        if let f = details.fNumber, f > 0 {
            parts.append(String(format: "ƒ/%.1f", f))
        }
        if let iso = details.iso, iso > 0 {
            parts.append("ISO \(iso)")
        }
        if let focal = details.focalLength, focal > 0 {
            parts.append(String(format: "%.0f mm", focal))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func copyImage() {
        guard let image = currentImage else { return }
        var source = ImageMarkup.composite(image: image, items: markupItems)
        if let frac = cropSelection?.standardized, frac.width > 0.01, frac.height > 0.01,
           let cg = ImageLoader.cgImage(from: source),
           let cropped = ImageEditing.apply(.crop(frac), to: cg) {
            source = ImageLoader.image(from: cropped)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([source])
    }

    private func currentColorAdjust() -> ColorAdjust {
        for op in pendingOps.reversed() {
            if case .color(let adjust) = op { return adjust }
        }
        return ColorAdjust()
    }

    func setMarkupTool(_ tool: MarkupTool) {
        guard hasImage || tool == .browse else { return }
        if tool.isDrawing {
            stopSlideshow()
        }
        if tool != .crop {
            cropSelection = nil
        }
        markupTool = tool
    }

    func selectMarkup(id: UUID?) {
        selectedMarkupID = id
        guard let id, let item = markupItems.first(where: { $0.id == id }) else { return }
        markupColor = item.color
        markupWeight = item.weight
        markupFontSize = item.fontSize
        markupFilled = item.filled
    }

    func setMarkupTextEditing(_ editing: Bool) {
        isEditingMarkupText = editing
    }

    func undoTextEditorIfNeeded() -> Bool {
        guard isEditingMarkupText,
              let editor = NSApp.keyWindow?.firstResponder as? NSTextView,
              editor.undoManager?.canUndo == true else { return false }
        editor.undoManager?.undo()
        return true
    }

    func setMarkupColor(_ color: MarkupColor) {
        markupColor = color
        if restyleSelected(color: color, weight: nil, fontSize: nil) { return }
        if markupTool == .browse, hasImage {
            markupTool = .pen
        }
    }

    func setMarkupWeight(_ weight: MarkupWeight) {
        markupWeight = weight
        if restyleSelected(color: nil, weight: weight, fontSize: nil) { return }
        if markupTool == .browse, hasImage {
            markupTool = .pen
        }
    }

    func setMarkupFontSize(_ size: MarkupFontSize) {
        markupFontSize = size
        if restyleSelected(color: nil, weight: nil, fontSize: size) { return }
        if markupTool == .browse, hasImage {
            markupTool = .text
        }
    }

    func setMarkupFilled(_ filled: Bool) {
        markupFilled = filled
        if restyleSelected(color: nil, weight: nil, fontSize: nil, filled: filled) { return }
        if markupTool == .browse, hasImage {
            markupTool = .rect
        }
    }

    func setMarkupTextBackground(_ on: Bool) {
        markupFilled = on
        if isEditingMarkupText {
            return
        }
        if let id = selectedMarkupID,
           let item = markupItems.first(where: { $0.id == id }),
           item.isText {
            _ = restyleSelected(color: nil, weight: nil, fontSize: nil, filled: on)
            return
        }
        if markupTool == .browse, hasImage {
            markupTool = .text
        }
    }

    func addMarkup(_ item: MarkupItem) {
        stopSlideshow()
        pushUndo()
        markupItems.append(item)
        refreshDirty()
    }

    func replaceMarkup(_ item: MarkupItem) {
        guard let idx = markupItems.firstIndex(where: { $0.id == item.id }) else {
            addMarkup(item)
            return
        }
        if markupItems[idx] == item { return }
        stopSlideshow()
        pushUndo()
        markupItems[idx] = item
        refreshDirty()
    }

    func removeMarkup(id: UUID) {
        guard markupItems.contains(where: { $0.id == id }) else { return }
        stopSlideshow()
        pushUndo()
        markupItems.removeAll { $0.id == id }
        if selectedMarkupID == id {
            selectedMarkupID = nil
        }
        refreshDirty()
    }

    @discardableResult
    func removeSelectedMarkup() -> Bool {
        guard let id = selectedMarkupID else { return false }
        removeMarkup(id: id)
        return true
    }

    func undoLastEdit() {
        guard let prev = undoStack.popLast() else { return }
        let opsChanged = prev.ops != pendingOps
        pendingOps = prev.ops
        markupItems = prev.marks
        colorAdjust = currentColorAdjust()
        cropSelection = nil
        if let id = selectedMarkupID, !markupItems.contains(where: { $0.id == id }) {
            selectedMarkupID = nil
        }
        if let source = sourceImage {
            currentImage = pendingOps.isEmpty ? source : ImageEditing.apply(pendingOps, to: source)
        }
        refreshDirty()
        if opsChanged {
            requestZoom(.fit)
        }
    }

    func revertEdits() {
        guard isDirty else { return }
        undoStack = []
        pendingOps = []
        markupItems = []
        selectedMarkupID = nil
        isEditingMarkupText = false
        markupTool = .browse
        cropSelection = nil
        colorAdjust = ColorAdjust()
        colorUndoPushed = false
        currentImage = sourceImage
        refreshDirty()
        requestZoom(.fit)
    }

    @discardableResult
    func saveInPlace() -> Bool {
        guard isDirty, let url = currentURL else { return !isDirty }
        guard let type = ImageEditing.writableType(for: url) else {
            saveAs()
            return !isDirty
        }
        return writeEdited(from: url, to: url, type: type, reopenIfMoved: false)
    }

    func saveAs() {
        guard currentImage != nil, let url = currentURL else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = ImageEditing.exportTypes
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent
        panel.directoryURL = url.deletingLastPathComponent()
        panel.title = LanguageManager.shared.t(.saveAs)
        panel.prompt = LanguageManager.shared.t(.save)
        panel.message = LanguageManager.shared.t(.saveAsMessage)
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        folderAccess.retain(dest)
        let type = ImageEditing.normalizedWriteType(
            UTType(filenameExtension: dest.pathExtension) ?? ImageEditing.writableType(for: dest) ?? .jpeg
        )
        _ = writeEdited(from: url, to: dest, type: type, reopenIfMoved: true)
    }

    func printCurrent() {
        guard let url = currentURL, let preview = currentImage else { return }
        let ops = pendingOps
        let marks = markupItems
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        var image: NSImage
        if let printSource = ImageEditing.loadOriented(from: url, maxPixelSize: ImageEditing.printMaxPixelSize) {
            image = ops.isEmpty ? printSource : ImageEditing.apply(ops, to: printSource)
        } else {
            image = preview
        }
        if !marks.isEmpty {
            image = ImageMarkup.composite(image: image, items: marks)
        }
        ImageEditing.printImage(image, jobTitle: url.lastPathComponent)
    }

    /// Returns `false` when the user cancelled. Used before navigate / open / quit.
    @discardableResult
    func confirmDiscardIfNeeded() -> Bool {
        guard isDirty else { return true }
        let lang = LanguageManager.shared
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = lang.t(.unsavedTitle)
        if let name = currentURL?.lastPathComponent {
            alert.informativeText = lang.format(.unsavedMessageNamed, name)
        } else {
            alert.informativeText = lang.t(.unsavedMessage)
        }
        alert.addButton(withTitle: lang.t(.save))
        alert.addButton(withTitle: lang.t(.dontSave))
        alert.addButton(withTitle: lang.t(.cancel))
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveInPlace()
        case .alertSecondButtonReturn:
            revertEdits()
            return true
        default:
            return false
        }
    }

    private func writeEdited(from source: URL, to destination: URL, type: UTType, reopenIfMoved: Bool) -> Bool {
        let ops = pendingOps
        let marks = markupItems
        let scopedSource = source.startAccessingSecurityScopedResource()
        let scopedDest = destination.startAccessingSecurityScopedResource()
        defer {
            if scopedSource { source.stopAccessingSecurityScopedResource() }
            if scopedDest { destination.stopAccessingSecurityScopedResource() }
        }
        do {
            try ImageEditing.saveFullResolution(from: source, ops: ops, markup: marks, to: destination, type: type)
        } catch {
            errorMessage = LanguageManager.shared.format(
                .couldNotSaveNamed,
                destination.lastPathComponent
            )
            return false
        }

        imageCache.removeObject(forKey: cacheKey(for: source))
        imageCache.removeObject(forKey: cacheKey(for: destination))
        if !marks.isEmpty, let img = currentImage {
            currentImage = ImageMarkup.composite(image: img, items: marks)
        }
        pendingOps = []
        markupItems = []
        selectedMarkupID = nil
        isEditingMarkupText = false
        undoStack = []
        markupTool = .browse
        cropSelection = nil
        colorAdjust = ColorAdjust()
        colorUndoPushed = false
        sourceImage = currentImage
        refreshDirty()

        let moved = source.standardizedFileURL.path != destination.standardizedFileURL.path
        if reopenIfMoved, moved {
            openFile(destination)
        }
        return true
    }

    private func clearEdits(keepingImage: Bool) {
        pendingOps = []
        markupItems = []
        selectedMarkupID = nil
        isEditingMarkupText = false
        undoStack = []
        markupTool = .browse
        cropSelection = nil
        colorAdjust = ColorAdjust()
        colorUndoPushed = false
        isDirty = false
        if !keepingImage {
            sourceImage = nil
        }
        markDocumentEdited(false)
    }

    private func pushUndo() {
        undoStack.append((ops: pendingOps, marks: markupItems))
    }

    @discardableResult
    private func restyleSelected(color: MarkupColor?, weight: MarkupWeight?, fontSize: MarkupFontSize?, filled: Bool? = nil) -> Bool {
        guard let id = selectedMarkupID,
              let idx = markupItems.firstIndex(where: { $0.id == id }) else { return false }
        var item = markupItems[idx]
        if let color { item.color = color }
        if let weight, !item.isText { item.weight = weight }
        if let fontSize, item.isText { item.fontSize = fontSize }
        if let filled, item.canFill || item.isText { item.filled = filled }
        if item == markupItems[idx] { return true }
        stopSlideshow()
        pushUndo()
        markupItems[idx] = item
        refreshDirty()
        return true
    }

    private func refreshDirty() {
        isDirty = !pendingOps.isEmpty || !markupItems.isEmpty
        markDocumentEdited(isDirty)
        applyWindowTitle()
    }

    private func markDocumentEdited(_ edited: Bool) {
        NSApp.windows.first(where: { $0.frameAutosaveName == "Flip.Main" })?.isDocumentEdited = edited
        if NSApp.windows.first(where: { $0.frameAutosaveName == "Flip.Main" }) == nil {
            NSApp.windows.first?.isDocumentEdited = edited
        }
    }
}
