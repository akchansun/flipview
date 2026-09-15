import AppKit
import Foundation

/// UserDefaults keys for launch tips and the online update prompt.
///
/// Reset in Terminal (sandboxed apps may store this under the container):
/// `defaults delete app.flipview.viewer launchTipsDontShowAgain`
/// `defaults delete app.flipview.viewer updateCheckDontAskAgain`
enum PreferenceKey {
    /// When `true`, skip the startup tips dialog.
    static let launchTipsDontShowAgain = "launchTipsDontShowAgain"
    /// When `true`, never prompt about updates again (「不更新」).
    static let updateCheckDontAskAgain = "updateCheckDontAskAgain"
}

/// Startup tips (every launch unless dismissed with 「不再提示」) then an online update check.
enum LaunchPrompts {
    static let feedURL = URL(string: "https://www.ak129.cn/flip/version.json")!

    @MainActor
    private static var didStart = false

    @MainActor
    static func start() {
        guard !didStart else { return }
        didStart = true

        let fetch = Task.detached(priority: .utility) {
            await LaunchPrompts.fetchNewerMacRelease()
        }

        Task { @MainActor in
            await waitForMainWindow()
            await presentTipsIfNeeded()
            if let release = await fetch.value {
                await presentUpdateIfNeeded(release)
            }
        }
    }

    @MainActor
    private static func waitForMainWindow() async {
        for _ in 0..<60 {
            if visibleMainWindow() != nil {
                try? await Task.sleep(nanoseconds: 350_000_000)
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @MainActor
    private static func visibleMainWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.isVisible && window.attachedSheet == nil && !window.isSheet
        }
    }

    @MainActor
    private static func presentTipsIfNeeded() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: PreferenceKey.launchTipsDontShowAgain) else { return }

        let lang = LanguageManager.shared
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = lang.t(.tipsTitle)
        alert.informativeText = lang.t(.tipsMessage)
        alert.addButton(withTitle: lang.t(.tipsGotIt))
        alert.addButton(withTitle: lang.t(.tipsDontShowAgain))

        let response = await runAlert(alert)
        if response == .alertSecondButtonReturn {
            defaults.set(true, forKey: PreferenceKey.launchTipsDontShowAgain)
        }
    }

    private static func fetchNewerMacRelease() async -> VersionFeed.MacOSRelease? {
        if UserDefaults.standard.bool(forKey: PreferenceKey.updateCheckDontAskAgain) {
            return nil
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        var request = URLRequest(url: feedURL, timeoutInterval: 6)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Flip/\(AppVersion.currentMarketing) (macOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession(configuration: config).data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            let feed = try JSONDecoder().decode(VersionFeed.self, from: data)
            let remote = feed.macos.version.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !remote.isEmpty, AppVersion.isNewer(remote, than: AppVersion.currentMarketing) else {
                return nil
            }
            guard preferredDownloadURL(feed.macos.download) != nil else {
                return nil
            }
            return feed.macos
        } catch {
            return nil
        }
    }

    @MainActor
    private static func presentUpdateIfNeeded(_ release: VersionFeed.MacOSRelease) async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: PreferenceKey.updateCheckDontAskAgain) else { return }
        guard let url = preferredDownloadURL(release.download) else { return }

        let lang = LanguageManager.shared
        let notes: String
        switch lang.resolved {
        case .chineseSimplified:
            notes = release.notes?.zh?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case .english:
            notes = release.notes?.en?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        var body = lang.format(
            .updateAvailableMessage,
            release.version,
            AppVersion.currentMarketing
        )
        if !notes.isEmpty {
            body += "\n\n" + notes
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = lang.t(.updateAvailableTitle)
        alert.informativeText = body
        alert.addButton(withTitle: lang.t(.updateNow))
        alert.addButton(withTitle: lang.t(.updateLater))
        alert.addButton(withTitle: lang.t(.updateDontAsk))

        let response = await runAlert(alert)
        switch response {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(url)
        case .alertThirdButtonReturn:
            defaults.set(true, forKey: PreferenceKey.updateCheckDontAskAgain)
        default:
            break
        }
    }

    static func preferredDownloadURL(_ links: VersionFeed.MacOSRelease.Download?) -> URL? {
        guard let links else { return nil }
        for candidate in [links.site, links.gitee, links.github] {
            guard let raw = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
                  let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http"
            else { continue }
            return url
        }
        return nil
    }

    @MainActor
    private static func runAlert(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        if let window = visibleMainWindow() {
            return await alert.beginSheetModal(for: window)
        }
        return alert.runModal()
    }
}
