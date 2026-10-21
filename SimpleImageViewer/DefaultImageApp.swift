import AppKit
import UniformTypeIdentifiers

/// Register Flip as the default viewer for still-image UTIs via Launch Services.
///
/// Finder 「显示简介 → 全部更改」only sticks for **one** type at a time, and
/// `LSHandlerRank = Alternate` made Flip a last-resort handler so Preview won.
enum DefaultImageApp {
    static var claimedTypes: [UTType] {
        var seen = Set<String>()
        return SupportedFormats.contentTypes.filter { seen.insert($0.identifier).inserted }
    }

    @MainActor
    static func confirmAndApply() async {
        let lang = LanguageManager.shared
        let confirm = NSAlert()
        confirm.alertStyle = .informational
        confirm.messageText = lang.t(.setDefaultTitle)
        confirm.informativeText = lang.t(.setDefaultMessage)
        confirm.addButton(withTitle: lang.t(.setDefaultConfirm))
        confirm.addButton(withTitle: lang.t(.cancel))
        NSApp.activate(ignoringOtherApps: true)
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        let result = await apply()

        let done = NSAlert()
        if result.failed.isEmpty {
            done.alertStyle = .informational
            done.messageText = lang.t(.setDefaultSuccessTitle)
            done.informativeText = lang.t(.setDefaultSuccessMessage)
        } else if result.succeeded == 0 {
            done.alertStyle = .warning
            done.messageText = lang.t(.setDefaultFailedTitle)
            done.informativeText = lang.t(.setDefaultFailedMessage)
        } else {
            done.alertStyle = .warning
            done.messageText = lang.t(.setDefaultPartialTitle)
            done.informativeText = lang.format(
                .setDefaultPartialMessage,
                result.succeeded,
                result.failed.count
            )
        }
        done.addButton(withTitle: lang.t(.ok))
        _ = done.runModal()
    }

    private static func apply() async -> (succeeded: Int, failed: [String]) {
        let appURL = Bundle.main.bundleURL
        var succeeded = 0
        var failed: [String] = []
        for type in claimedTypes {
            let error: Error? = await withCheckedContinuation { continuation in
                NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type) { error in
                    continuation.resume(returning: error)
                }
            }
            if let error {
                failed.append(type.identifier)
                if isUserCancelled(error) {
                    break
                }
            } else {
                succeeded += 1
            }
        }
        return (succeeded, failed)
    }

    private static func isUserCancelled(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError
    }
}
