# Flip

[中文](#中文) · [English](#english)

Lightweight **macOS** image viewer: open one picture, flip through the same folder. Free and open source (MIT).

**Gitee：** <https://gitee.com/akcg/flipview>（国内访问更稳；GitHub 可作镜像）  
**开发者 / Developer:** [喜相逢科技 · www.ak129.cn](https://www.ak129.cn)

> 主仓库建议放在 **Gitee**（`flipview`），GitHub 访问不便时可只维护 Gitee。

---

## 中文

### 这是什么
Flip 是一款免费开源的 macOS 看图工具，用法接近经典 Windows 照片查看器：打开一张图，用键盘 / 触控板 / 点击左右侧在**同一文件夹**里翻页。

### 功能
- 同目录上一张 / 下一张（←→、双指滑动、点击左右约 1/3 区域）
- 小图 100%、大图等比缩小适应窗口并居中
- 右键：打开文件夹、访达中显示、用其他 App 打开
- 界面中英可切换
- 常见格式（JPEG / PNG / HEIC / WebP / TIFF…，走系统 ImageIO）

### 系统要求
- macOS 14+
- 建议在内置 SSD 上浏览大量照片；外置 ExFAT 受盘速限制

### 编译

发布用 **Release 通用包**（`x86_64` + `arm64`），Intel 与 Apple Silicon（M 系列）均可原生运行。
```bash
xcodebuild -project SimpleImageViewer.xcodeproj -scheme SimpleImageViewer -configuration Release
```
或用 Xcode 打开 `SimpleImageViewer.xcodeproj`，Scheme 选 **SimpleImageViewer**，运行后产物为 **Flip.app**。

> 工程目录暂名 `SimpleImageViewer`（历史原因），产品名与品牌为 **Flip**。发布到 Gitee 仓库 `flipview`；若需要再镜像到 GitHub。

### 关于喜相逢科技
Flip 由[安康喜相逢科技](https://www.ak129.cn)维护。我们做福彩数字化、彩店积分、英语教培与本地 IT 服务。软件服务，非购彩渠道，不承诺中奖。

- 网站：<https://www.ak129.cn>
- 电话：177 7296 8885

### 许可证
MIT，见 [LICENSE](LICENSE)。

---

## 发布到 Gitee

1. 在 [gitee.com](https://gitee.com) 新建仓库，名称建议 `flipview`，公开，不要勾选「使用 Readme 初始化」（本地已有文件）。
2. 本机执行：
```bash
cd "/Volumes/MacBook/项目/Viewer"
git remote add origin git@gitee.com:akcg/flipview.git
git push -u origin main
```

---

## English

### What it is
Flip is a free, open-source macOS image viewer. Open one image, then flip through others in the **same folder**—similar to the classic Windows Photo Viewer.

### Features
- Same-folder previous / next (arrows, trackpad swipe, click left/right thirds)
- Scale-down-only fit, centered
- Context menu: open folder, Reveal in Finder, Open With
- English / 简体中文 UI
- Common formats via macOS ImageIO

### Requirements
- macOS 14+
- Internal SSD recommended for large libraries; external ExFAT is I/O-bound

### Build

Ship a **Release universal** binary (`x86_64` + `arm64`) so Intel and Apple Silicon Macs both run natively.

```bash
xcodebuild -project SimpleImageViewer.xcodeproj -scheme SimpleImageViewer -configuration Release
```
Open `SimpleImageViewer.xcodeproj` in Xcode; the app product is **Flip.app**.

### Credits
Maintained by [Xixiangfeng Tech (安康喜相逢科技)](https://www.ak129.cn) — lottery-shop digital tools, points systems, English education software, and local IT in Ankang, China.

### License
MIT — see [LICENSE](LICENSE).
