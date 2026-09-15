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
- 启动时显示使用提示（可「不再提示」）；联网检查更新（可「不更新」）
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
- GitHub Release：<https://github.com/akchansun/flipview/releases/tag/v0.2.0>（域外推荐）
- Gitee Release：<https://gitee.com/akcg/flipview/releases/tag/v0.2.0>
- 源码：GitHub <https://github.com/akchansun/flipview> · Gitee <https://gitee.com/akcg/flipview>

### 启动提示与更新检查
每次启动，主窗口出现后会先显示简短使用提示。点「知道了」下次仍会显示；点「不再提示」后不再弹出。随后在后台请求官网 `https://www.ak129.cn/flip/version.json`（约 6 秒超时）。若远程 macOS 版本更新，会提示发行说明，并可：

- **前往更新**：并行探测 `giteeAsset` / `githubAsset`（HEAD，不行再 Range GET），打开更快的安装包；失败则另一侧安装包 → Gitee/GitHub 发布页 → 官网 `download.site`
- **稍后再说**：关闭对话框，下次启动再问
- **不更新**：记住选择，不再检查或提示

网络失败或 JSON 无效时静默跳过，不会打断看图。应用不会自动下载或替换 `.app`。

恢复提示与更新检查（终端，bundle id `app.flipview.viewer`）：

```bash
defaults delete app.flipview.viewer launchTipsDontShowAgain
defaults delete app.flipview.viewer updateCheckDontAskAgain
```

若无效，可删除容器内偏好：`~/Library/Containers/app.flipview.viewer/Data/Library/Preferences/app.flipview.viewer.plist`，或 `defaults delete app.flipview.viewer` 清空本应用全部偏好。

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
- Launch tips (optional “Don’t show again”) and an online update check (“Don’t Update” stops prompts)
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
- GitHub Release: <https://github.com/akchansun/flipview/releases/tag/v0.2.0> (recommended outside China)
- Gitee Release: <https://gitee.com/akcg/flipview/releases/tag/v0.2.0>
- Source: GitHub <https://github.com/akchansun/flipview> · Gitee <https://gitee.com/akcg/flipview>

### Launch tips and updates
After the main window appears, Flip shows short usage tips. **OK** keeps showing them next launch; **Don’t show again** persists via UserDefaults. It then fetches `https://www.ak129.cn/flip/version.json` (about 6s timeout). If the `macos.version` is newer, a dialog offers:

- **Update** — race `giteeAsset` / `githubAsset` in parallel (HEAD, then Range GET) and open the faster zip; if that open fails: the other zip → Gitee/GitHub release pages → site `download.site`
- **Later** — dismiss only; ask again next launch
- **Don’t Update** — persist and never prompt updates again

Network or JSON failures are silent. Flip does not auto-download or replace the `.app`.

Reset in Terminal (bundle id `app.flipview.viewer`):

```bash
defaults delete app.flipview.viewer launchTipsDontShowAgain
defaults delete app.flipview.viewer updateCheckDontAskAgain
```

If that does nothing, remove `~/Library/Containers/app.flipview.viewer/Data/Library/Preferences/app.flipview.viewer.plist`, or `defaults delete app.flipview.viewer` to clear all Flip preferences.

### Credits
Maintained by [Xixiangfeng Tech (安康喜相逢科技)](https://www.ak129.cn/) — lottery-shop digital tools, points systems, English education software, and local IT in Ankang, China.

### License
MIT — see [LICENSE](LICENSE).
