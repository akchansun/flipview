# Changelog

## 0.3.0 — 2026-09-15

- Launch tips dialog (OK / Don’t show again); shown every launch until dismissed
- Online update check against `https://www.ak129.cn/flip/version.json` (timeout ~6s, fail silent)
- Update prompt: race Gitee vs GitHub (asset URL probe), open the faster source; fallback to the other forge, then site
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
