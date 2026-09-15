# Flip

[中文](#中文) · [English](#english)

Lightweight **macOS** image viewer: open one picture, flip through the same folder. Free and open source (MIT).

**GitHub:** <https://github.com/akchansun/flipview>  
**Gitee:** <https://gitee.com/akcg/flipview>  
**Product page:** <https://www.ak129.cn/flip/>  
**Developer:** [喜相逢科技](https://www.ak129.cn/)

---

## 中文

### 这是什么
Flip 是一款免费开源的 macOS 看图工具，用法接近经典 Windows 照片查看器：打开一张图，用键盘 / 触控板 / 点击左右侧在**同一文件夹**里翻页。

### 功能
- 同目录上一张 / 下一张（←→、双指滑动、点击左右约 1/3 区域）
- 小图 100%、大图等比缩小适应窗口并居中
- 右键：打开文件夹、访达中显示、用其他 App 打开
- 界面中英可切换
- 启动时合并显示使用提示与更新（可「不再提示」/「不更新」）；「前往更新」就地替换当前 Flip.app
- 常见格式（JPEG / PNG / HEIC / WebP / TIFF…，走系统 ImageIO）

### 系统要求
- macOS 14+
- 建议在内置 SSD 上浏览大量照片；外置 ExFAT 受盘速限制

### 编译

发布用 **Release 通用包**（`x86_64` + `arm64`），Intel 与 Apple Silicon（M 系列）均可原生运行。

```bash
xcodebuild -project SimpleImageViewer.xcodeproj -scheme SimpleImageViewer \
  -configuration Release -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO
```

或用 Xcode 打开 `SimpleImageViewer.xcodeproj`，Scheme 选 **SimpleImageViewer**，产物为 **Flip.app**。

> 工程目录暂名 `SimpleImageViewer`（历史原因），产品名与品牌为 **Flip**。

### 下载
- 官网：<https://www.ak129.cn/flip/>
- GitHub Release：<https://github.com/akchansun/flipview/releases/tag/v0.4.0>（域外推荐）
- Gitee Release：<https://gitee.com/akcg/flipview/releases/tag/v0.4.0>
- 源码：GitHub <https://github.com/akchansun/flipview> · Gitee <https://gitee.com/akcg/flipview>

### 启动提示与更新检查
主窗口出现后弹出**一个**对话框（提示与更新合并，不再连续两个弹窗）：

- 仅提示：文案 + 「知道了」；勾选「不再提示」后不再显示提示
- 仅更新 / 提示+更新：发行说明 + 「前往更新」/「稍后再说」/「不更新」；提示出现时可用勾选「不再提示」

联网请求 `https://www.ak129.cn/flip/version.json`（约 6 秒超时）。**前往更新**会并行探测 `giteeAsset` / `githubAsset`，下载更快的 zip，解压后**就地替换**当前 Flip.app 的 `Contents`（辅助脚本在退出后交换目录、清除 `com.apple.quarantine` 并重新打开），避免再开一份新下载的 `.app` 触发 Gatekeeper。若应用目录不可写，则改为打开下载链接并说明原因。

- **稍后再说**：关闭对话框，下次启动再问更新
- **不更新**：记住选择，不再检查或提示更新

网络失败或 JSON 无效时静默跳过。Release 发行包关闭 App Sandbox（保留网络客户端）以便就地更新；Debug 仍可启用沙盒。

恢复提示与更新检查（终端，bundle id `app.flipview.viewer`）：

```bash
defaults delete app.flipview.viewer launchTipsDontShowAgain
defaults delete app.flipview.viewer updateCheckDontAskAgain
```

若无效：沙盒 Debug 构建可删容器内偏好 `~/Library/Containers/app.flipview.viewer/Data/Library/Preferences/app.flipview.viewer.plist`；Release（无沙盒）用 `defaults delete app.flipview.viewer` 即可。

### 关于
Flip 由[安康喜相逢科技](https://www.ak129.cn/)维护。我们做福彩数字化、彩店积分、英语教培与本地 IT 服务。软件服务，非购彩渠道，不承诺中奖。

### 许可证
MIT，见 [LICENSE](LICENSE)。

---

## English

### What it is
Flip is a free, open-source macOS image viewer. Open one image, then flip through others in the **same folder**—similar to the classic Windows Photo Viewer.

### Features
- Same-folder previous / next (arrows, trackpad swipe, click left/right thirds)
- Scale-down-only fit, centered
- Context menu: open folder, Reveal in Finder, Open With
- English / 简体中文 UI
- Combined launch tips + update dialog; in-place self-update (“Don’t Update” stops prompts)
- Common formats via macOS ImageIO

### Requirements
- macOS 14+
- Internal SSD recommended for large libraries; external ExFAT is I/O-bound

### Build

Ship a **Release universal** binary (`x86_64` + `arm64`) so Intel and Apple Silicon Macs both run natively.

```bash
xcodebuild -project SimpleImageViewer.xcodeproj -scheme SimpleImageViewer \
  -configuration Release -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO
```

Open `SimpleImageViewer.xcodeproj` in Xcode; the app product is **Flip.app**.

### Download
- Website: <https://www.ak129.cn/flip/>
- GitHub Release: <https://github.com/akchansun/flipview/releases/tag/v0.4.0> (recommended outside China)
- Gitee Release: <https://gitee.com/akcg/flipview/releases/tag/v0.4.0>
- Source: GitHub <https://github.com/akchansun/flipview> · Gitee <https://gitee.com/akcg/flipview>

### Launch tips and updates
After the main window appears, Flip shows **one** dialog (tips and/or update — never two alerts in a row):

- Tips only: message + **OK**; check **Don’t show again** to suppress tips
- Update only / tips+update: release notes + **Update** / **Later** / **Don’t Update**; tips include the same checkbox when shown

Fetches `https://www.ak129.cn/flip/version.json` (~6s timeout). **Update** races `giteeAsset` / `githubAsset`, downloads the faster zip, and **in-place replaces** `Contents` inside the running Flip.app (helper script swaps after exit, clears `com.apple.quarantine`, relaunches) so you are not forced through Gatekeeper on a freshly downloaded `.app`. If the bundle is not writable, Flip opens the download URL with a clear alert instead.

- **Later** — dismiss; ask about updates again next launch
- **Don’t Update** — persist and never prompt updates again

Network/JSON failures are silent. Release builds disable App Sandbox (network client kept) so in-place update can rewrite the bundle; Debug may keep Sandbox.

Reset in Terminal (bundle id `app.flipview.viewer`):

```bash
defaults delete app.flipview.viewer launchTipsDontShowAgain
defaults delete app.flipview.viewer updateCheckDontAskAgain
```

If that does nothing: sandboxed Debug builds may use `~/Library/Containers/app.flipview.viewer/Data/Library/Preferences/app.flipview.viewer.plist`; Release (no sandbox) only needs `defaults delete app.flipview.viewer`.

### Credits
Maintained by [Xixiangfeng Tech (安康喜相逢科技)](https://www.ak129.cn/) — lottery-shop digital tools, points systems, English education software, and local IT in Ankang, China.

### License
MIT — see [LICENSE](LICENSE).
