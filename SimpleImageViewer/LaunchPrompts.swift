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
            if let offer = await fetch.value {
                await presentUpdateIfNeeded(offer)
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

    private struct PendingUpdate: Sendable {
        let release: VersionFeed.MacOSRelease
        let rankedURLs: Task<[URL], Never>
    }

    private static func fetchNewerMacRelease() async -> PendingUpdate? {
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
            guard DownloadMirror.hasAnyCandidate(feed.macos.download) else {
                return nil
            }
            let links = feed.macos.download
            let rankedURLs = Task.detached(priority: .utility) {
                await DownloadMirror.rankedOpenURLs(links)
            }
            return PendingUpdate(release: feed.macos, rankedURLs: rankedURLs)
        } catch {
            return nil
        }
    }

    @MainActor
    private static func presentUpdateIfNeeded(_ offer: PendingUpdate) async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: PreferenceKey.updateCheckDontAskAgain) else { return }

        let release = offer.release
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
            let urls = await offer.rankedURLs.value
            openDownloadFallback(urls)
        case .alertThirdButtonReturn:
            defaults.set(true, forKey: PreferenceKey.updateCheckDontAskAgain)
        default:
            break
        }
    }

    /// Winner zip, other zip, then pages, then site. `NSWorkspace.open` false → next URL.
    @MainActor
    private static func openDownloadFallback(_ urls: [URL]) {
        for url in urls {
            if NSWorkspace.shared.open(url) {
                return
            }
        }
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
