import AppKit
import SwiftUI

@main
struct SimpleImageViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var language = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.session)
                .environmentObject(language)
                .id(language.preference)
        }
        .defaultSize(width: 1100, height: 740)
        // Keep a single window: Finder "Open With" is handled in AppDelegate, not a new scene.
        .handlesExternalEvents(matching: [])
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(language.t(.aboutApp)) {
                    showAboutPanel()
                }
                Button(language.t(.visitWebsite)) {
                    openProductWebsite()
                }
                Divider()
                Button(language.t(.setDefaultMenu)) {
                    Task { await DefaultImageApp.confirmAndApply() }
                }
            }

            CommandGroup(replacing: .newItem) {
                Button(language.t(.openImage)) {
                    appDelegate.session.openPanelForImage()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(language.t(.openFolder)) {
                    appDelegate.session.openPanelForFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(after: .newItem) {
                Button(language.t(.moveToTrashEllipsis)) {
                    appDelegate.session.requestDelete()
                }
                .keyboardShortcut(.delete, modifiers: [])
            }

            CommandGroup(replacing: .help) {
                Button(language.t(.flipHelp)) {
                    showHelpPanel()
                }
                .keyboardShortcut("?", modifiers: .command)

                Button(language.t(.visitWebsite)) {
                    openProductWebsite()
                }
            }

            CommandMenu(language.t(.viewMenu)) {
                Button(language.t(.previousImage)) {
                    appDelegate.session.navigate(.previous)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button(language.t(.nextImage)) {
                    appDelegate.session.navigate(.next)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Divider()

                Button(language.t(.zoomIn)) {
                    appDelegate.session.requestZoom(.in)
                }
                .keyboardShortcut("=", modifiers: .command)

                Button(language.t(.zoomOut)) {
                    appDelegate.session.requestZoom(.out)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button(language.t(.fitToWindow)) {
                    appDelegate.session.requestZoom(.fit)
                }
                .keyboardShortcut("0", modifiers: .command)

                Button(language.t(.actualSize)) {
                    appDelegate.session.requestZoom(.actual)
                }
                .keyboardShortcut("1", modifiers: .command)

                Divider()

                Button(appDelegate.session.isSlideshow ? language.t(.stopSlideshow) : language.t(.startSlideshow)) {
                    appDelegate.session.toggleSlideshow()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu(language.t(.languageMenu)) {
                ForEach(LanguagePreference.allCases) { pref in
                    Button((language.preference == pref ? "✓ " : "    ") + pref.menuTitle) {
                        language.preference = pref
                        appDelegate.session.refreshWindowTitle()
                    }
                }
            }
        }
    }
}


@MainActor
private func showAboutPanel() {
    let lang = LanguageManager.shared
    let credits = NSMutableAttributedString(string: lang.t(.aboutCredits) + "\n")
    let linkText = "https://www.ak129.cn/flip/"
    let link = NSMutableAttributedString(string: linkText)
    let fullRange = NSRange(location: 0, length: link.length)
    link.addAttribute(.link, value: "https://www.ak129.cn/flip/", range: fullRange)
    link.addAttribute(.foregroundColor, value: NSColor.linkColor, range: fullRange)
    credits.append(link)

    NSApp.orderFrontStandardAboutPanel(options: [
        .applicationName: "Flip",
        .credits: credits,
        .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? AppVersion.currentMarketing
    ])
}

@MainActor
private func openProductWebsite() {
    if let url = URL(string: "https://www.ak129.cn/flip/") {
        NSWorkspace.shared.open(url)
    }
}

/// In-app Help: same `tipsMessage` as the launch dialog (no Help Book / `.help` bundle).
@MainActor
private func showHelpPanel() {
    let lang = LanguageManager.shared
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = lang.t(.tipsTitle)
    alert.informativeText = lang.t(.tipsMessage)
    alert.addButton(withTitle: lang.t(.tipsGotIt))
    alert.addButton(withTitle: lang.t(.visitWebsite))

    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertSecondButtonReturn {
        openProductWebsite()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let session = ImageSession()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        ViewerWindow.requestFront()
        LaunchPrompts.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ViewerWindow.requestFront()
        return true
    }

    /// Finder "Open With", double-click, and files dropped on the Dock icon / app.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        session.open(url)
        ViewerWindow.requestFront()
    }
}

/// Finder stays frontmost after Open With / double-click. `activate(ignoringOtherApps:)`
/// is ignored on recent macOS; activate *from* Finder and force the window up.
@MainActor
enum ViewerWindow {
    private static var pendingFront = false

    static func requestFront() {
        pendingFront = true
        raiseNow()
        DispatchQueue.main.async { raiseNow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { raiseNow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            raiseNow()
            pendingFront = false
        }
    }

    /// Called when the SwiftUI window is known (title / frame attach).
    static func fulfillPendingIfNeeded() {
        guard pendingFront else { return }
        raiseNow()
    }

    static func raiseNow() {
        guard pendingFront else { return }
        activateFromFrontmost()
        NSApp.unhide(nil)
        guard let window = mainWindow() else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if window.frameAutosaveName == "Flip.Main" {
            pendingFront = false
        }
    }

    private static func activateFromFrontmost() {
        let current = NSRunningApplication.current
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != current.bundleIdentifier {
            current.activate(from: front)
        } else {
            NSApp.activate()
        }
    }

    static func mainWindow() -> NSWindow? {
        let candidates = NSApp.windows.filter { !$0.isSheet && $0.canBecomeKey && $0.frame.width > 100 }
        if let named = candidates.first(where: { $0.frameAutosaveName == "Flip.Main" }) {
            return named
        }
        return candidates.first(where: \.isVisible) ?? candidates.first
    }
}
