import AppKit
import Foundation

/// Holds security-scoped access so a sandboxed app can list a folder after the user
/// opens a single file (Open panel, drag-and-drop, or Finder "Open With").
@MainActor
final class FolderAccess {
    private var retainedURLs: [URL] = []

    func retain(_ url: URL) {
        if url.startAccessingSecurityScopedResource() {
            retainedURLs.append(url)
        }
    }

    func releaseAll() {
        for url in retainedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        retainedURLs.removeAll()
    }

    func saveBookmark(for directory: URL) {
        do {
            let data = try directory.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key(for: directory))
        } catch {
            NSLog("Flip: could not save folder bookmark: \(error.localizedDescription)")
        }
    }

    /// Returns a live security-scoped directory URL if we have a bookmark for this path.
    func restoreBookmark(for directory: URL) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key(for: directory)) else { return nil }

        do {
            var stale = false
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            retain(resolved)
            if stale {
                saveBookmark(for: resolved)
            }
            return resolved
        } catch {
            return nil
        }
    }

    func canListContents(of directory: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) != nil
    }

    /// Modal powerbox: user grants read access to the folder that contains the current image.
    func promptForDirectory(preferred: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = preferred
        panel.prompt = LanguageManager.shared.t(.allow)
        panel.message = LanguageManager.shared.t(.allowFolderPanelMessage)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        retain(url)
        saveBookmark(for: url)
        return url
    }

    private func key(for directory: URL) -> String {
        "Flip.bookmark:" + normalizedPath(directory)
    }

    private func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
