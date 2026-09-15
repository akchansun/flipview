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

/// One combined launch dialog for tips and/or updates (not two sequential NSAlerts).
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
            let offer = await fetch.value
            await presentCombinedIfNeeded(offer: offer)
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

    private struct PendingUpdate: Sendable {
        let release: VersionFeed.MacOSRelease
        let rankedAssets: Task<[URL], Never>
        let rankedOpenURLs: Task<[URL], Never>
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
            let rankedAssets = Task.detached(priority: .utility) {
                await DownloadMirror.rankedAssetURLs(links)
            }
            let rankedOpenURLs = Task.detached(priority: .utility) {
                await DownloadMirror.rankedOpenURLs(links)
            }
            return PendingUpdate(
                release: feed.macos,
                rankedAssets: rankedAssets,
                rankedOpenURLs: rankedOpenURLs
            )
        } catch {
            return nil
        }
    }

    @MainActor
    private static func presentCombinedIfNeeded(offer: PendingUpdate?) async {
        let defaults = UserDefaults.standard
        let showTips = !defaults.bool(forKey: PreferenceKey.launchTipsDontShowAgain)
        let showUpdate = offer != nil
            && !defaults.bool(forKey: PreferenceKey.updateCheckDontAskAgain)

        guard showTips || showUpdate else { return }

        let lang = LanguageManager.shared
        let alert = NSAlert()
        alert.alertStyle = .informational

        var bodyParts: [String] = []
        if showTips {
            bodyParts.append(lang.t(.tipsMessage))
        }
        if showUpdate, let offer {
            let notes: String
            switch lang.resolved {
            case .chineseSimplified:
                notes = offer.release.notes?.zh?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            case .english:
                notes = offer.release.notes?.en?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            var updateBody = lang.format(
                .updateAvailableMessage,
                offer.release.version,
                AppVersion.currentMarketing
            )
            if !notes.isEmpty {
                updateBody += "\n\n" + notes
            }
            bodyParts.append(updateBody)
        }

        if showTips && showUpdate {
            alert.messageText = lang.t(.launchCombinedTitle)
        } else if showUpdate {
            alert.messageText = lang.t(.updateAvailableTitle)
        } else {
            alert.messageText = lang.t(.tipsTitle)
        }
        alert.informativeText = bodyParts.joined(separator: "\n\n————\n\n")

        // 「不再提示」checkbox when tips are part of this dialog.
        var dontShowTipsButton: NSButton?
        if showTips {
            let check = NSButton(
                checkboxWithTitle: lang.t(.tipsDontShowAgain),
                target: nil,
                action: nil
            )
            check.state = .off
            alert.accessoryView = check
            dontShowTipsButton = check
        }

        if showUpdate {
            alert.addButton(withTitle: lang.t(.updateNow))
            alert.addButton(withTitle: lang.t(.updateLater))
            alert.addButton(withTitle: lang.t(.updateDontAsk))
        } else {
            alert.addButton(withTitle: lang.t(.tipsGotIt))
        }

        let response = await runAlert(alert)

        if let check = dontShowTipsButton, check.state == .on {
            defaults.set(true, forKey: PreferenceKey.launchTipsDontShowAgain)
        }

        guard showUpdate, let offer else { return }

        switch response {
        case .alertFirstButtonReturn:
            let assets = await offer.rankedAssets.value
            let openURLs = await offer.rankedOpenURLs.value
            if assets.isEmpty {
                openDownloadFallback(openURLs)
            } else {
                await InPlaceUpdater.updateReplacingRunningApp(
                    assetURLs: assets,
                    fallbackOpenURLs: openURLs
                )
            }
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
