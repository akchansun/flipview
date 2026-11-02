## 0.6.5

- 最细一档是发丝线（约 0.5pt），不再像马克笔
- 点选和选中虚线贴着笔画外边，矩形只点边框，不再用一大圈包围盒

## 0.6.4

- 已有标注可改：点选后改颜色 / 线宽；箭头和矩形可拖端点拉伸；画完自动选中便于接着改
- 文字：点一次选中，再点或双击改内容；工具条单独调节字号（小 / 中 / 大 / 特大）
- 改文字不再因为误提交而丢内容；颜色点也加大了点击区域

## 0.6.3

- 最细那档线宽按钮点得中；画上去的细线也更容易点选

## 0.6.2

- 标注线条可调细 / 中 / 粗 / 特粗；文字大小跟着走
- 选中标注后再点颜色或粗细，改的是当前这项
- 撤销按真实操作回退（移动、改色、改字），不再误删另一笔
- 选中标注时 Delete 只删标注，不会把整张图丢进废纸篓
- 画笔点一下可以打点

## 0.6.1

- 标注画在图片文档里，不再盖住顶部工具条
- 已有文字可再点编辑；标注可选中后拖动，Delete 删除选中项

## 0.6.0

- 窗口顶部工具条：翻页、缩放、旋转翻转、画笔 / 箭头 / 矩形 / 文字标注、颜色、存储、打印
- 标注画在图上，存储时按原图分辨率写入；Esc 退出标注回到浏览

## 0.5.0

- 向左 / 向右旋转 90°（⌘L / ⌘R）、水平 / 垂直翻转
- 拷贝图片、存储 / 存储为（按原图分辨率重放旋转翻转，不会把屏幕预览图写回文件）
- 打印（⌘P）；未保存更改时翻页、打开或退出会询问
- 图像菜单与右键菜单可做上述操作；⌘Z 撤销上一步

## 0.4.9

- 放大以指针/手势位置为焦点，不再锚在画布左下角（适配时左右留白消失会看起来往左跳）

## 0.4.8

- 打开变慢、关掉后又自己打开：去掉每次打开都 `openApplication` 自己（会绕 Launch Services，关闭后延迟回调还会把 Flip 拉起来）
- 单窗口改为 `Window`，避免 WindowGroup 关了再新建一个

## 0.4.7

- 根因：`handlesExternalEvents(matching: [])` 让窗口场景拒绝访达打开事件，系统不把 Flip 切到前台；后台再 `activate` 会被忽略
- 改为现有窗口认领 `*` 外部事件，并用 Launch Services 激活自己；多余窗口会关掉

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
