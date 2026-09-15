import AppKit
import Foundation

/// Downloads a Flip.zip, extracts Flip.app, and replaces `Contents` of the running
/// bundle via a short-lived helper script (cannot overwrite a running Mach-O in place).
enum InPlaceUpdater {
    enum Failure: Error {
        case notWritable
        case downloadFailed
        case extractFailed
        case invalidPackage
        case helperFailed
    }

    /// Race-ordered asset zip URLs. On success the current process exits after spawning the helper.
    @MainActor
    static func updateReplacingRunningApp(
        assetURLs: [URL],
        fallbackOpenURLs: [URL]
    ) async {
        let lang = LanguageManager.shared
        let bundleURL = Bundle.main.bundleURL

        guard isBundleWritable(bundleURL) else {
            presentFallback(
                title: lang.t(.updateNotWritableTitle),
                message: lang.t(.updateNotWritableMessage),
                urls: fallbackOpenURLs
            )
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        // Non-modal floating panel while download / extract runs.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 88),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = lang.t(.appName)
        panel.isFloatingPanel = true
        panel.level = .floating
        let label = NSTextField(wrappingLabelWithString: "\(lang.t(.updateDownloadingTitle))\n\(lang.t(.updateDownloadingMessage))")
        label.frame = NSRect(x: 16, y: 16, width: 328, height: 56)
        panel.contentView?.addSubview(label)
        panel.center()
        panel.makeKeyAndOrderFront(nil)

        do {
            let zipFile = try await downloadFirstZip(assetURLs)
            let newApp = try extractFlipApp(fromZip: zipFile)
            panel.orderOut(nil)
            try launchHelperAndExit(newApp: newApp, targetApp: bundleURL)
        } catch {
            panel.orderOut(nil)
            presentFallback(
                title: lang.t(.updateFailedTitle),
                message: lang.t(.updateFailedMessage),
                urls: fallbackOpenURLs
            )
        }
    }

    static func isBundleWritable(_ bundleURL: URL) -> Bool {
        let fm = FileManager.default
        let contents = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        if fm.isWritableFile(atPath: contents.path) { return true }
        if fm.isWritableFile(atPath: bundleURL.path) { return true }
        let probe = contents.appendingPathComponent(".flip-write-probe-\(UUID().uuidString)")
        do {
            try Data().write(to: probe)
            try fm.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    private static func downloadFirstZip(_ urls: [URL]) async throws -> URL {
        var lastError: Error = Failure.downloadFailed
        for url in urls {
            do {
                return try await downloadZip(url)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func downloadZip(_ url: URL) async throws -> URL {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        var request = URLRequest(url: url)
        request.setValue("Flip/\(AppVersion.currentMarketing) (macOS)", forHTTPHeaderField: "User-Agent")

        let (tempURL, response) = try await URLSession(configuration: config).download(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw Failure.downloadFailed
        }

        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent("Flip-update-\(UUID().uuidString).zip")
        if fm.fileExists(atPath: dest.path) {
            try fm.removeItem(at: dest)
        }
        try fm.moveItem(at: tempURL, to: dest)
        return dest
    }

    private static func extractFlipApp(fromZip zipURL: URL) throws -> URL {
        let fm = FileManager.default
        let extractDir = fm.temporaryDirectory.appendingPathComponent(
            "Flip-extract-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-x", "-k", zipURL.path, extractDir.path]
        proc.standardError = Pipe()
        proc.standardOutput = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            throw Failure.extractFailed
        }
        guard proc.terminationStatus == 0 else { throw Failure.extractFailed }

        if let app = findAppBundle(under: extractDir) {
            return app
        }
        throw Failure.invalidPackage
    }

    private static func findAppBundle(under root: URL) -> URL? {
        let fm = FileManager.default
        if root.pathExtension == "app" { return root }
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var fallback: URL?
        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else { continue }
            if url.deletingPathExtension().lastPathComponent == "Flip" {
                return url
            }
            if fallback == nil { fallback = url }
            enumerator.skipDescendants()
        }
        return fallback
    }

    /// Stage new Contents, write helper, spawn it, then terminate this process.
    private static func launchHelperAndExit(newApp: URL, targetApp: URL) throws {
        let fm = FileManager.default
        let stagingParent = fm.temporaryDirectory.appendingPathComponent(
            "Flip-stage-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: stagingParent, withIntermediateDirectories: true)
        let stagedContents = stagingParent.appendingPathComponent("Contents", isDirectory: true)
        let sourceContents = newApp.appendingPathComponent("Contents", isDirectory: true)
        guard fm.fileExists(atPath: sourceContents.path) else { throw Failure.invalidPackage }
        try fm.copyItem(at: sourceContents, to: stagedContents)

        let scriptURL = fm.temporaryDirectory.appendingPathComponent(
            "flip-inplace-update-\(UUID().uuidString).sh"
        )
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/bash
        set -euo pipefail
        APP=\(shellEscape(targetApp.path))
        NEW_CONTENTS=\(shellEscape(stagedContents.path))
        OLD_CONTENTS="$APP/Contents.flip-old-$$"
        PID=\(pid)

        for i in $(seq 1 100); do
          if ! kill -0 "$PID" 2>/dev/null; then
            break
          fi
          sleep 0.1
        done
        sleep 0.3

        if [ ! -d "$NEW_CONTENTS" ]; then
          exit 1
        fi

        rm -rf "$OLD_CONTENTS" 2>/dev/null || true
        if [ -d "$APP/Contents" ]; then
          mv "$APP/Contents" "$OLD_CONTENTS"
        fi
        mv "$NEW_CONTENTS" "$APP/Contents"

        # Clear quarantine on the existing bundle path (avoids a fresh Gatekeeper grant).
        /usr/bin/xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
        /usr/bin/xattr -cr "$APP" 2>/dev/null || true

        rm -rf "$OLD_CONTENTS" 2>/dev/null || true
        /usr/bin/open "$APP" || true
        rm -f -- "$0" 2>/dev/null || true
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/bash")
        helper.arguments = [scriptURL.path]
        helper.standardOutput = FileHandle.nullDevice
        helper.standardError = FileHandle.nullDevice
        do {
            try helper.run()
        } catch {
            throw Failure.helperFailed
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.terminate(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                exit(0)
            }
        }
    }

    private static func shellEscape(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    @MainActor
    private static func presentFallback(title: String, message: String, urls: [URL]) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        let lang = LanguageManager.shared
        alert.addButton(withTitle: lang.t(.updateOpenDownload))
        alert.addButton(withTitle: lang.t(.cancel))
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            for url in urls {
                if NSWorkspace.shared.open(url) { return }
            }
        }
    }
}
