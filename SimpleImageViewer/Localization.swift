import Foundation
import SwiftUI

enum LanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english
    case chineseSimplified

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .system: return "System / 跟随系统"
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        }
    }
}

enum ResolvedLanguage {
    case english
    case chineseSimplified
}

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private static let defaultsKey = "appLanguagePreference"

    @Published var preference: LanguagePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.defaultsKey)
            objectWillChange.send()
        }
    }

    var resolved: ResolvedLanguage {
        switch preference {
        case .english:
            return .english
        case .chineseSimplified:
            return .chineseSimplified
        case .system:
            let code = Locale.preferredLanguages.first ?? "en"
            if code.hasPrefix("zh") {
                return .chineseSimplified
            }
            return .english
        }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let pref = LanguagePreference(rawValue: raw) {
            preference = pref
        } else {
            preference = .system
        }
    }

    func t(_ key: L10n.Key) -> String {
        L10n.string(key, language: resolved)
    }

    func format(_ key: L10n.Key, _ args: CVarArg...) -> String {
        String(format: t(key), locale: resolved == .chineseSimplified ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US"), arguments: args)
    }
}

enum L10n {
    enum Key: String {
        case appName
        case openImage
        case openFolder
        case moveToTrashEllipsis
        case moveToTrash
        case moveToTrashQuestion
        case moveToTrashMessageNamed
        case moveToTrashMessage
        case cancel
        case ok
        case viewMenu
        case previousImage
        case nextImage
        case zoomIn
        case zoomOut
        case fitToWindow
        case actualSize
        case startSlideshow
        case stopSlideshow
        case languageMenu
        case allowFolderTitle
        case allowFolderBody
        case allow
        case openImageToStart
        case openImageHint
        case shortcutsHint
        case chooseImageMessage
        case chooseFolderMessage
        case open
        case noSupportedImages
        case couldNotOpenImage
        case couldNotLoadNamed
        case slideshowSuffix
        case allowFolderPanelMessage
        case slideshowHint
        case revealInFinder
        case openWith
        case copyPath
        case noAppsToOpenWith
        case aboutApp
        case aboutCredits
        case visitWebsite
        case tipsTitle
        case tipsMessage
        case tipsGotIt
        case tipsDontShowAgain
        case updateAvailableTitle
        case updateAvailableMessage
        case updateNow
        case updateLater
        case updateDontAsk
        case launchCombinedTitle
        case updateDownloadingTitle
        case updateDownloadingMessage
        case updateFailedTitle
        case updateFailedMessage
        case updateNotWritableTitle
        case updateNotWritableMessage
        case updateOpenDownload
    }

    static func string(_ key: Key, language: ResolvedLanguage) -> String {
        switch language {
        case .english:
            return en[key] ?? key.rawValue
        case .chineseSimplified:
            return zh[key] ?? en[key] ?? key.rawValue
        }
    }

    private static let en: [Key: String] = [
        .appName: "Flip",
        .openImage: "Open Image…",
        .openFolder: "Open Folder…",
        .moveToTrashEllipsis: "Move to Trash…",
        .moveToTrash: "Move to Trash",
        .moveToTrashQuestion: "Move to Trash?",
        .moveToTrashMessageNamed: "“%@” will be moved to the Trash.",
        .moveToTrashMessage: "This image will be moved to the Trash.",
        .cancel: "Cancel",
        .ok: "OK",
        .viewMenu: "View",
        .previousImage: "Previous Image",
        .nextImage: "Next Image",
        .zoomIn: "Zoom In",
        .zoomOut: "Zoom Out",
        .fitToWindow: "Fit (No Upscale)",
        .actualSize: "Actual Size",
        .startSlideshow: "Start Slideshow",
        .stopSlideshow: "Stop Slideshow",
        .languageMenu: "Language",
        .allowFolderTitle: "To browse other images in this folder, allow folder access.",
        .allowFolderBody: "Allow…",
        .allow: "Allow",
        .openImageToStart: "Open an image to start",
        .openImageHint: "File → Open Image…, drop a file on this window, or use Finder’s Open With.",
        .shortcutsHint: "← → / swipe / click sides    ·    ⌘O  open",
        .chooseImageMessage: "Choose an image to view",
        .chooseFolderMessage: "Choose a folder of images",
        .open: "Open",
        .noSupportedImages: "No supported images in this folder.",
        .couldNotOpenImage: "Could not open image",
        .couldNotLoadNamed: "Could not load “%@”.",
        .slideshowSuffix: "(Slideshow)",
        .allowFolderPanelMessage: "Allow Flip to look at other images in this folder.",
        .slideshowHint: "Slideshow · Esc or ⌘⇧S to stop",
        .revealInFinder: "Reveal in Finder",
        .openWith: "Open With",
        .copyPath: "Copy Path",
        .noAppsToOpenWith: "No Applications",
        .aboutApp: "About Flip",
        .aboutCredits: "Free & open source (MIT)\nMade by Xixiangfeng Tech · Ankang\nwww.ak129.cn",
        .visitWebsite: "Visit Flip on ak129.cn",
        .tipsTitle: "Tips",
        .tipsMessage: """
        After you open an image, browse others in the same folder:

        • Trackpad swipe
        • Click the left or right window edge
        • Left / right arrow keys

        Default zoom: 100% for small images; large images fit the window.
        """,
        .tipsGotIt: "OK",
        .tipsDontShowAgain: "Don't show again",
        .updateAvailableTitle: "Update Available",
        .updateAvailableMessage: "Flip %@ is available. You have %@.",
        .updateNow: "Update",
        .updateLater: "Later",
        .updateDontAsk: "Don't Update",
        .launchCombinedTitle: "Welcome",
        .updateDownloadingTitle: "Updating Flip…",
        .updateDownloadingMessage: "Downloading and installing the update. Flip will relaunch when finished.",
        .updateFailedTitle: "Update Failed",
        .updateFailedMessage: "Flip could not update itself in place. You can open the download page instead.",
        .updateNotWritableTitle: "Cannot Update Here",
        .updateNotWritableMessage: "This Flip.app is not writable (for example, it may be in a read-only location). Open the download instead and replace the app manually.",
        .updateOpenDownload: "Open Download"
    ]

    private static let zh: [Key: String] = [
        .appName: "Flip",
        .openImage: "打开图片…",
        .openFolder: "打开文件夹…",
        .moveToTrashEllipsis: "移到废纸篓…",
        .moveToTrash: "移到废纸篓",
        .moveToTrashQuestion: "移到废纸篓？",
        .moveToTrashMessageNamed: "“%@” 将移到废纸篓。",
        .moveToTrashMessage: "这张图片将移到废纸篓。",
        .cancel: "取消",
        .ok: "好",
        .viewMenu: "显示",
        .previousImage: "上一张",
        .nextImage: "下一张",
        .zoomIn: "放大",
        .zoomOut: "缩小",
        .fitToWindow: "适应窗口（不放大）",
        .actualSize: "实际大小",
        .startSlideshow: "开始幻灯片",
        .stopSlideshow: "停止幻灯片",
        .languageMenu: "语言",
        .allowFolderTitle: "要浏览此文件夹中的其他图片，请允许访问文件夹。",
        .allowFolderBody: "允许…",
        .allow: "允许",
        .openImageToStart: "打开一张图片开始浏览",
        .openImageHint: "菜单「文件 → 打开图片…」、把文件拖进窗口，或用访达「打开方式」。",
        .shortcutsHint: "← → / 滑动 / 点左右两侧    ·    ⌘O  打开",
        .chooseImageMessage: "选择要查看的图片",
        .chooseFolderMessage: "选择包含图片的文件夹",
        .open: "打开",
        .noSupportedImages: "此文件夹中没有支持的图片。",
        .couldNotOpenImage: "无法打开图片",
        .couldNotLoadNamed: "无法加载“%@”。",
        .slideshowSuffix: "（幻灯片）",
        .allowFolderPanelMessage: "允许 Flip 查看此文件夹中的其他图片。",
        .slideshowHint: "幻灯片播放中 · 按 Esc 或 ⌘⇧S 停止",
        .revealInFinder: "在访达中显示",
        .openWith: "打开方式",
        .copyPath: "拷贝路径",
        .noAppsToOpenWith: "没有可用的应用程序",
        .aboutApp: "关于 Flip",
        .aboutCredits: "免费开源（MIT）\n安康喜相逢科技制作\nwww.ak129.cn",
        .visitWebsite: "访问 Flip 产品页",
        .tipsTitle: "使用提示",
        .tipsMessage: """
        打开一张图片后，可浏览同一文件夹中的其他图片：

        • 触控板左右滑动
        • 点击窗口左、右边缘
        • 键盘 ← → 方向键

        默认缩放：小图按 100% 显示，大图缩小以适应窗口。
        """,
        .tipsGotIt: "知道了",
        .tipsDontShowAgain: "不再提示",
        .updateAvailableTitle: "发现新版本",
        .updateAvailableMessage: "Flip %@ 已发布（当前 %@）。",
        .updateNow: "前往更新",
        .updateLater: "稍后再说",
        .updateDontAsk: "不更新",
        .launchCombinedTitle: "欢迎使用 Flip",
        .updateDownloadingTitle: "正在更新 Flip…",
        .updateDownloadingMessage: "正在下载并安装更新，完成后将自动重新打开。",
        .updateFailedTitle: "更新失败",
        .updateFailedMessage: "无法在原位置更新 Flip.app。可改为打开下载链接，手动替换应用。",
        .updateNotWritableTitle: "无法就地更新",
        .updateNotWritableMessage: "当前 Flip.app 不可写（例如位于只读位置）。请打开下载链接并手动替换应用。",
        .updateOpenDownload: "打开下载"
    ]
}
