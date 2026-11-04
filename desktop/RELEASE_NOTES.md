# Flip（看图）1.3.0 更新说明

**日期：** 2026-11-04  
**平台：** Ubuntu、Windows，以及统信 UOS、银河麒麟、Deepin 等国产系统  
**许可：** MIT  
**产品页：** https://www.ak129.cn/flip/

这次把 macOS Flip 里已经能用的看图、标注和轻量编辑，用同一套界面接到 Linux / Windows / 国产系统。打开一张图，就可以在 Flip 里翻页、裁剪、画标注、改颜色改尺寸，不必再切到别的看图软件。

需要 Qt 6 运行库（多数发行版为 `libqt6widgets6` 一类，另建议安装 `qt6-image-formats-plugins` 以便打开 WebP、TIFF）。

---

## 新功能

- 顶部工具条与 macOS Flip /「预览」窄窗一致：主栏翻页、缩放、旋转、标注、裁剪；窗口变窄时用 `>>` 收起其余项；点标注才出现第二行画笔 / 直线 / 箭头 / 矩形 / 圆角矩形 / 椭圆 / 高亮 / 文字
- 工具图标悬停显示名称
- 线宽选择为横线由细到粗，点开勾选
- 文字可加微信式彩色圆角背景，字自动用对比色
- 裁剪可拖八个点、移动选区、Shift 正方形、显示像素尺寸；Ctrl+A 全选，回车或双击裁切
- 已有文字可再点编辑、改字号；标注可选中后拖动、改色改粗细改填充，形状可拉伸
- 从剪贴板新建（Ctrl+N）；检查器显示文件名、像素、大小、格式；有 DPI 时一并列出
- 向左 / 向右旋转 90°（Ctrl+L / Ctrl+R）、水平 / 垂直翻转
- 调整颜色（曝光、对比度、亮度、饱和度等）、调整大小（可按比例）
- 移除背景（按画面边角取样抠透明底，适合纯色底）
- 拷贝、存储 / 存储为（按原图分辨率写入）、打印（Ctrl+P）
- 撤销按操作回退；选中标注时 Delete 只删标注，不会误删整张图

## 沿用

- 打开一张图，即可在同一文件夹里前后翻页（方向键、工具栏、左右边缘点击、滚轮）
- 默认缩放：小图按 100% 显示，大图缩小以适应窗口，居中、默认不放大
- 简体中文 / English，可跟随系统，也可在「查看 → 语言」里切换
- 帮助菜单「使用提示」（F1）与启动说明相同；「关于」仍在帮助菜单；「访问 Flip 产品页」打开 https://www.ak129.cn/flip/
- Linux 上「前往更新」仍可就地替换当前目录里的 Flip；Windows 或安装目录不可写时改为打开下载页

## 说明

- 同一套 Qt 6 源码，Ubuntu / UOS / 麒麟 / Deepin / Windows 共用
- 不包含 PDF、签名、连续互通、iCloud
- 帮助提示原文未改

## 编译与运行

```bash
sudo apt install build-essential cmake ninja-build qt6-base-dev qt6-image-formats-plugins
cmake -S desktop -B desktop/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build desktop/build
./desktop/build/Flip 某张图.png
```

Windows 用同一 CMake 工程，再用 `windeployqt` 收集 Qt 运行库后打 zip。

源码：https://github.com/akchansun/flipview（`desktop/` 目录）

---

# Flip 1.3.0 Release Notes

**Date:** 4 Nov 2026  
**Platforms:** Ubuntu, Windows, and Chinese domestic desktops (UnionTech UOS, Kylin, Deepin)  
**License:** MIT  
**Site:** https://www.ak129.cn/flip/

This build brings the macOS Flip image workflow — paging, markup, crop, and light edits — to Linux, Windows, and domestic OS with the same toolbar layout. Open one picture and stay in Flip instead of bouncing to another viewer.

Needs a Qt 6 runtime. On Debian/Ubuntu also install `qt6-image-formats-plugins` for WebP and TIFF.

## What’s new

- Preview-style toolbar: main bar plus `>>` overflow on a narrow window; markup tools appear on a second row
- Hover labels on toolbar icons
- Line width picker uses horizontal strokes from thin to thick
- WeChat-style text background: colored rounded chip with contrasting ink
- Crop with eight handles, move the box, Shift for square, live pixel size; Ctrl+A, Return / double-click to crop
- Existing text can be edited again; markup can be selected, dragged, recolored, and resized
- New from Clipboard (Ctrl+N); inspector shows file name, pixels, size, and format
- Rotate left / right (Ctrl+L / Ctrl+R), flip horizontal / vertical
- Adjust Color, Adjust Size, Remove Background (corner-sample cutout)
- Copy, Save / Save As at full resolution, Print (Ctrl+P)
- Undo follows real actions; Delete removes selected markup instead of the file

## Unchanged

- Same-folder previous / next; small images stay at 100%, large images fit the window
- 简体中文 / English
- Help → Usage Tips (F1) uses the same text as the launch tips; About and Visit Flip on ak129.cn remain
- Linux in-place update still replaces `Flip` in the running directory; Windows opens the download page

## Notes

- One Qt 6 tree for Ubuntu, UOS, Kylin, Deepin, and Windows
- Not PDF, signatures, Continuity, or iCloud
- Launch / Help tips copy is unchanged
