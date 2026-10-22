import AppKit
import Foundation
import SwiftUI

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

    let folderAccess = FolderAccess()
    private var loadGeneration = 0
    private var slideshowTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    /// Decoded images kept warm for snappy ←/→.
    private let imageCache = NSCache<NSString, NSImage>()

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
            return name
        }
        let position = "\(currentIndex + 1) / \(gallery.count)"
        if isSlideshow {
            return "\(name) — \(position) \(LanguageManager.shared.t(.slideshowSuffix))"
        }
        return "\(name) — \(position)"
    }

    func refreshWindowTitle() {
        objectWillChange.send()
        applyWindowTitle()
    }

    func applyWindowTitle() {
        NSApp.windows.first?.title = windowTitle
    }

    var canNavigate: Bool { gallery.count > 1 }

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
        folderAccess.retain(url)
        stopSlideshow()
        currentURL = url
        loadImage(at: url)
        discoverSiblings(for: url)
    }

    private func openFolder(_ directory: URL) {
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
        loadGeneration += 1
        let generation = loadGeneration
        errorMessage = nil
        cancelPrefetch()

        if let cached = cachedImage(for: url) {
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
}
