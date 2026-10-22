## 0.4.6

- 访达双击打开后强制把主窗口提到最前（从访达接管激活，并用 `orderFrontRegardless`；0.4.5 的 `activate` 会被新系统忽略）

## 0.4.5

- 从访达双击 /「打开方式」打开图片后，把 Flip 窗口提到最前（不再留在访达下面）

## 0.4.4

- 图片类型 `LSHandlerRank` 改为 Default，便于系统把 Flip 当作首选看图软件
- 应用菜单新增「设为默认看图软件」：一次登记 JPEG / PNG / HEIC 等常见格式（访达「全部更改」每次只改一种）

## 0.4.3

- Help 菜单改为应用内使用提示（文案与启动 `tipsMessage` 相同），不再弹出系统「Help isn’t available for Flip」
- 帮助对话框与帮助菜单均可打开 https://www.ak129.cn/flip/

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
