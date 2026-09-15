## 0.4.2

- 「不更新」只关闭本次启动的更新对话框，下次启动仍会检查更新（不再永久跳过）
- 不再写入或读取 `updateCheckDontAskAgain`；以前点过「不更新」的用户也会重新收到提示

## 0.4.1

- 就地更新重启后不再重复弹出「使用提示」（合并窗口里已看过）

# Changelog

## 0.4.0 — 2026-09-15

- Combine launch tips + update into **one** dialog (tips-only / update-only / both)
- 「前往更新」downloads the faster of `giteeAsset` / `githubAsset` and **in-place updates** the existing Flip.app (stage Contents → helper swap → clear quarantine → relaunch)
- If the bundle is not writable, fall back to opening the download URL with a clear alert
- Release builds: App Sandbox **off** (network client kept) so ad-hoc signed Flip.app can rewrite itself; Debug keeps Sandbox
- Preference keys unchanged: `launchTipsDontShowAgain`, `updateCheckDontAskAgain`

## 0.3.0 — 2026-09-15

- Launch tips dialog (OK / Don’t show again); shown every launch until dismissed
- Online update check against `https://www.ak129.cn/flip/version.json` (timeout ~6s, fail silent)
- Update prompt: race `giteeAsset` vs `githubAsset`; fallback other zip → release pages → site
- App Sandbox outgoing network client entitlement for the version feed

## 0.2.0 — 2026-09-15

- Product renamed to **Flip** (repo: `flipview`)
- MIT license; bilingual README; About credits link to www.ak129.cn
- Performance: screen-sized decode, memory cache, delayed serial ±2 prefetch
- ExFAT-friendly folder listing (extension-only, async open)
- Context menu: open folder / Reveal in Finder / Open With
- Trackpad one-flip-per-gesture; side click + arrow cursors

## 0.1.0

- Initial SwiftUI/AppKit viewer (same-folder paging)
