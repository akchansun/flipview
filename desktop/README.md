# Flip（看图）

面向办公场景的轻量 Linux 图片查看器：打开一张图，即可在**同一文件夹**里前后翻页，类似经典 Windows 照片查看器。

- 品牌名：**Flip**（中文名：**看图**）
- 许可：**MIT**
- 开发：[喜相逢科技 / Xixiangfeng Tech](https://www.ak129.cn/flip/)
- 目标系统：Ubuntu、Windows，以及统信 UOS、银河麒麟、深度等国产系统（同一套 Qt 源码）
- 版本：**1.3.0**（与 macOS Flip 0.6.x 对齐的工具条、标注、裁剪与轻量编辑）

## 功能

- 打开图片或文件夹（菜单 / 文件对话框 / 拖放 / 命令行参数）
- 同一目录上一张 / 下一张（方向键、工具栏、左右边缘点击、滚轮）
- 默认缩放：小于窗口的图片按 **100%** 显示；大于窗口的缩小以适应窗口；居中；默认不放大
- 常见格式（由 Qt 图像插件提供）：JPEG、PNG、BMP、GIF、WebP、TIFF 等
- 窗口标题显示文件名
- 界面语言：简体中文 / English（可跟随系统，也可在「查看 → 语言」里切换）
- 帮助菜单：「使用提示」（F1）随时再看与启动提示相同的操作说明；「关于」仍在帮助菜单。「访问 Flip 产品页」打开 https://www.ak129.cn/flip/
- 启动时使用提示与更新检查合并为**同一个对话框**（仅提示 / 仅更新 / 两者同时，不再连续弹两个窗）。提示可勾选「不再提示」；仅提示时按钮为「知道了」。点击「前往更新」并执行原地替换后，下一次启动会跳过一次使用提示（合并对话框里已经看过）；未勾选「不再提示」时，之后启动仍会显示。「稍后再说 / 不更新」不会设置这次一次性跳过
- 每次启动在线检查更新（读取官网 `version.json` 的 `linux` 字段）。有新版本时同一窗口提供「前往更新 / 稍后再说 / 不更新」。「前往更新」会并行短超时探测 **`giteeAsset` / `githubAsset`**（HEAD，不行再用 Range GET），下载更快的 tar.gz，解压后在**当前可执行文件所在目录**原地替换 `Flip` 以及同目录的 README / desktop / 图标，然后重新打开。目录不可写（只读位置、系统目录、AppImage 等）时改为打开下载链接。「稍后再说」和「不更新」都只关闭本次对话框，下次启动仍会检查
- 关于对话框含版本号、MIT 说明与 https://www.ak129.cn/flip/
- 顶部工具条与 macOS Flip /「预览」窄窗一致：主栏翻页、缩放、旋转、标注、裁剪；窄窗用 `>>` 溢出；点标注才出现第二行画笔 / 直线 / 箭头 / 矩形 / 圆角矩形 / 椭圆 / 高亮 / 文字、填充、微信式文字背景、颜色、线宽（横线由细到粗）、字号
- 图标悬停显示名称（约 240ms）
- 裁剪：八个控点、拖移选区、Shift 正方形、像素 HUD；Ctrl+A 全选；回车或双击裁切
- 旋转 / 翻转、调整颜色、调整大小、检查器、移除背景（按边角取样抠透明底）
- 从剪贴板新建、存储 / 存储为、打印、撤销
- 标注可选中后拖动、改色改粗细改填充；文字可再编辑；输入结束回到浏览光标

## 依赖

编译需要：

- CMake ≥ 3.16
- C++17 编译器（GCC / Clang）
- **Qt 6** Widgets + Gui（推荐；本仓库在 Ubuntu 24.04 上用 Qt 6.4 验证）
- 若系统只有 **Qt 5.15**，CMake 会自动回退

运行时建议安装图像格式插件，以便打开 WebP、TIFF 等：

```bash
# Debian / Ubuntu / 多数衍生版
sudo apt install qt6-image-formats-plugins
```

统信 UOS、银河麒麟请使用各自的包管理器（`apt` / `yum` / 应用商店），包名可能是 `qt6-base-dev`、`libqt6-dev` 或 `qt5-default` 一类，以发行版仓库为准。

## 在 Linux amd64 上编译

```bash
sudo apt install build-essential cmake ninja-build qt6-base-dev qt6-base-dev-tools qt6-image-formats-plugins
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

可执行文件：`build/Flip`

无显示器（例如服务器冒烟）时：

```bash
QT_QPA_PLATFORM=offscreen ./build/Flip --self-test
```

有桌面时：

```bash
./build/Flip examples/img1.png
```

### 统信 UOS / 银河麒麟

1. 安装「开发者工具」或对应的 `gcc`、`cmake`、Qt 开发包（优先 Qt 6，没有再用 Qt 5.15）。
2. 用上面同一套 `cmake -S . -B build` 命令即可；不要依赖本仓库以外的私有服务器。
3. 国产系统桌面（DDE / UKUI）一般能直接运行 Qt Widgets 程序。若图标未出现在启动器，把 `packaging/flip.desktop` 复制到 `~/.local/share/applications/`，并把 `resources/icons/flip.svg` 安装为 `flip` 图标。
4. 中文界面依赖系统中文字体（如文泉驿、Noto CJK）。UOS / 麒麟默认已包含。

## 打包

### 源码旁的二进制 tarball（最简单）

目标机器需已安装 Qt 6 运行库（Ubuntu 上为 `libqt6widgets6t64` 等，名称因发行版而异）以及 `qt6-image-formats-plugins`。

```bash
./scripts/make-tarball.sh
```

产物在 `dist/flip-linux-<version>-amd64.tar.gz`。

已发布的 1.3.0 安装包（GitHub Release `desktop-1.3.0`，flip-linux 仓库没有写入权限）：

- Linux amd64：https://github.com/akchansun/flipview/releases/download/desktop-1.3.0/flip-linux-1.3.0-amd64.tar.gz
- Windows x64（含 Qt 运行库）：https://github.com/akchansun/flipview/releases/download/desktop-1.3.0/Flip-1.3.0-windows-x64.zip

Linux 包在 Ubuntu 22.04 上编译，需要 glibc 2.35 或更高，以及本机的 Qt 6 运行库。Windows 压缩包解压后直接运行 `Flip.exe`。

### AppImage（可选）

可用 [linuxdeploy](https://github.com/linuxdeploy/linuxdeploy) 与 `linuxdeploy-plugin-qt` 把 `build/Flip` 打成 AppImage，便于拷到没有开发包的电脑。本仓库不绑定特定打包主机。在 amd64 Linux 上大致步骤：

```bash
# 下载 linuxdeploy 与 linuxdeploy-plugin-qt 到 PATH 后：
export QMAKE=$(command -v qmake6 || command -v qmake)
linuxdeploy --appdir AppDir -e build/Flip -d packaging/flip.desktop -i resources/icons/flip.svg --plugin qt --output appimage
```

无 FUSE 的环境可用 `APPIMAGE_EXTRACT_AND_RUN=1` 运行 linuxdeploy 的 AppImage 发行包。

## 键盘

| 按键 | 作用 |
| --- | --- |
| ← → ↑ ↓、空格、PageUp/PageDown | 上一张 / 下一张（目录内循环） |
| Home / End | 第一张 / 最后一张 |
| Ctrl+滚轮、+ / − | 放大 / 缩小 |
| 0 或 F | 恢复默认适应窗口 |
| 1 | 实际大小 100% |
| 双击图片 | 在适应窗口与 100% 之间切换 |
| F11 | 全屏 |
| Ctrl+O / Ctrl+Shift+O | 打开图片 / 打开文件夹 |
| Ctrl+N | 从剪贴板新建 |
| Ctrl+S / Ctrl+Shift+S | 存储 / 存储为 |
| Ctrl+P | 打印 |
| Ctrl+Z | 撤销 |
| Ctrl+L / Ctrl+R | 向左 / 向右旋转 |
| Ctrl+K | 裁剪（有选区时应用） |
| Ctrl+A | 裁剪全选 |
| Delete | 删除选中标注 |
| F1 | 使用提示（帮助菜单） |

## Windows

同一套 Qt 6 源码。在安装了 Qt 6 与 CMake 的 Windows（MSVC 或 MinGW）上：

```bat
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

发布可用 `windeployqt build\Flip.exe` 收集 Qt 运行库，再打 zip。更新检查仍读官网 `version.json` 的 `linux` 字段；Windows 安装目录不可用 Linux tar 就地替换时，会改为打开下载页。

国产系统（统信 UOS、银河麒麟、Deepin）按上面 Linux 步骤编译即可，桌面为 DDE / UKUI。

---

# Flip (看图) — English

A small, free image viewer for Linux: open one file, then page through the **same folder**, like classic Windows Photo Viewer.

- License: MIT
- Developer: [喜相逢科技 / Xixiangfeng Tech](https://www.ak129.cn/flip/)
- Targets: Ubuntu, Windows, and Chinese domestic desktops (UnionTech UOS, Kylin, Deepin)
- 1.3.0 matches macOS Flip 0.6.x: Preview-style toolbar (`>>` overflow, markup second row), crop, markup, color/size/inspector, print, clipboard new
- Help menu: **Usage Tips** (F1) shows the same text as the launch tips dialog; **About** remains. **Visit Flip on ak129.cn** opens https://www.ak129.cn/flip/
- Each launch uses **one combined dialog** for usage tips and/or updates (tips-only, update-only, or both). Check **Don't show again** to skip tips; tips-only uses **OK**. After **Go to update** runs an in-place replace, the next launch skips tips once (they were already in the combined dialog); if **Don't show again** was not checked, later launches still show tips. **Later** / **Don't update** do not set this one-shot skip
- Each launch checks [version.json](https://www.ak129.cn/flip/version.json) (`linux`). A newer build offers **Go to update / Later / Don't update** in that same window. **Go to update** races **`linux.download.giteeAsset` vs `githubAsset`** (HEAD, then a 1-byte ranged GET if HEAD is rejected), downloads the faster tarball, and **replaces `Flip` plus README / desktop / icons in the running executable’s directory**, then relaunches. If that directory is not writable (read-only path, system install, AppImage), it opens the download instead. **Later** and **Don't update** only close this launch; the next launch still checks

Build:

```bash
sudo apt install build-essential cmake ninja-build qt6-base-dev qt6-base-dev-tools qt6-image-formats-plugins
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/Flip examples/img1.png
```

CMake prefers Qt 6 and falls back to Qt 5.15 if Qt 6 development packages are missing. Install `qt6-image-formats-plugins` (or your distro’s equivalent) for WebP and TIFF.

UOS / Kylin: install GCC, CMake, and Qt 6 (or 5.15) from the distro repositories, then use the same CMake commands. Widgets UI is intended to stay compatible with DDE and UKUI.

Published 1.3.0 packages are on the flipview release `desktop-1.3.0`:

- Linux amd64: https://github.com/akchansun/flipview/releases/download/desktop-1.3.0/flip-linux-1.3.0-amd64.tar.gz (built on Ubuntu 22.04, needs glibc 2.35+ and a Qt 6 runtime)
- Windows x64: https://github.com/akchansun/flipview/releases/download/desktop-1.3.0/Flip-1.3.0-windows-x64.zip (`Flip.exe` plus the Qt runtime from `windeployqt`)

See the Chinese section above for build steps, AppImage notes, and keyboard shortcuts.
