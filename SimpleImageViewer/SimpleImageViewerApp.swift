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
        LaunchPrompts.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    /// Finder "Open With", double-click, and files dropped on the Dock icon / app.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        session.open(url)
    }
}
