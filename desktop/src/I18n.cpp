#include "I18n.h"

#include <QHash>
#include <QLocale>
#include <QString>

namespace I18n {
namespace {

Lang g_pref = Lang::Auto;

QHash<QString, QString> zhTable()
{
    return {
        {"app.name", QStringLiteral("看图")},
        {"menu.file", QStringLiteral("文件(&F)")},
        {"menu.view", QStringLiteral("查看(&V)")},
        {"menu.help", QStringLiteral("帮助(&H)")},
        {"menu.language", QStringLiteral("语言(&L)")},
        {"file.openImage", QStringLiteral("打开图片(&O)…")},
        {"file.openFolder", QStringLiteral("打开文件夹(&D)…")},
        {"file.newClipboard", QStringLiteral("从剪贴板新建")},
        {"file.save", QStringLiteral("存储")},
        {"file.saveAs", QStringLiteral("存储为…")},
        {"file.print", QStringLiteral("打印…")},
        {"file.trash", QStringLiteral("移到废纸篓…")},
        {"file.trashAsk", QStringLiteral("移到废纸篓？")},
        {"file.trashNamed", QStringLiteral("“%1” 将移到废纸篓。")},
        {"file.untitled", QStringLiteral("未命名")},
        {"file.quit", QStringLiteral("退出(&Q)")},
        {"menu.edit", QStringLiteral("编辑(&E)")},
        {"menu.image", QStringLiteral("图像(&I)")},
        {"edit.undo", QStringLiteral("撤销")},
        {"edit.copyImage", QStringLiteral("拷贝图片")},
        {"edit.copyPath", QStringLiteral("拷贝路径")},
        {"toolbar.markup", QStringLiteral("标注")},
        {"toolbar.more", QStringLiteral("更多")},
        {"tool.pen", QStringLiteral("画笔")},
        {"tool.line", QStringLiteral("直线")},
        {"tool.arrow", QStringLiteral("箭头")},
        {"tool.rect", QStringLiteral("矩形")},
        {"tool.roundRect", QStringLiteral("圆角矩形")},
        {"tool.oval", QStringLiteral("椭圆")},
        {"tool.highlight", QStringLiteral("高亮")},
        {"tool.text", QStringLiteral("文字")},
        {"tool.crop", QStringLiteral("框选裁剪")},
        {"markup.fill", QStringLiteral("填充")},
        {"markup.stroke", QStringLiteral("描边")},
        {"markup.color", QStringLiteral("标注颜色")},
        {"markup.weight", QStringLiteral("线条粗细")},
        {"markup.font", QStringLiteral("文字大小")},
        {"markup.textBg", QStringLiteral("文字背景")},
        {"markup.placeholder", QStringLiteral("输入文字 · 再点一次或双击可改")},
        {"color.red", QStringLiteral("红色")},
        {"color.orange", QStringLiteral("橙色")},
        {"color.yellow", QStringLiteral("黄色")},
        {"color.green", QStringLiteral("绿色")},
        {"color.blue", QStringLiteral("蓝色")},
        {"color.white", QStringLiteral("白色")},
        {"color.black", QStringLiteral("黑色")},
        {"weight.thin", QStringLiteral("细")},
        {"weight.regular", QStringLiteral("中")},
        {"weight.thick", QStringLiteral("粗")},
        {"weight.heavy", QStringLiteral("特粗")},
        {"font.small", QStringLiteral("小字")},
        {"font.regular", QStringLiteral("中字")},
        {"font.large", QStringLiteral("大字")},
        {"font.extra", QStringLiteral("特大字")},
        {"image.rotateLeft", QStringLiteral("向左旋转")},
        {"image.rotateRight", QStringLiteral("向右旋转")},
        {"image.flipH", QStringLiteral("水平翻转")},
        {"image.flipV", QStringLiteral("垂直翻转")},
        {"image.crop", QStringLiteral("裁剪")},
        {"image.selectAll", QStringLiteral("全选")},
        {"image.removeBg", QStringLiteral("移除背景")},
        {"adjust.color", QStringLiteral("调整颜色")},
        {"adjust.size", QStringLiteral("调整大小")},
        {"adjust.width", QStringLiteral("宽度")},
        {"adjust.height", QStringLiteral("高度")},
        {"adjust.percent", QStringLiteral("百分比")},
        {"adjust.keepAspect", QStringLiteral("按比例缩放")},
        {"adjust.exposure", QStringLiteral("曝光")},
        {"adjust.contrast", QStringLiteral("对比度")},
        {"adjust.brightness", QStringLiteral("亮度")},
        {"adjust.saturation", QStringLiteral("饱和度")},
        {"adjust.highlights", QStringLiteral("高光")},
        {"adjust.shadows", QStringLiteral("阴影")},
        {"adjust.temperature", QStringLiteral("色温")},
        {"adjust.tint", QStringLiteral("色调")},
        {"adjust.sepia", QStringLiteral("褐色")},
        {"adjust.sharpness", QStringLiteral("锐度")},
        {"adjust.autoLevels", QStringLiteral("自动色阶")},
        {"adjust.reset", QStringLiteral("全部还原")},
        {"inspector", QStringLiteral("显示检查器")},
        {"inspector.file", QStringLiteral("文件")},
        {"inspector.pixels", QStringLiteral("像素")},
        {"inspector.bytes", QStringLiteral("大小")},
        {"inspector.format", QStringLiteral("格式")},
        {"inspector.color", QStringLiteral("颜色")},
        {"inspector.dpi", QStringLiteral("分辨率")},
        {"inspector.profile", QStringLiteral("描述文件")},
        {"inspector.camera", QStringLiteral("相机")},
        {"inspector.lens", QStringLiteral("镜头")},
        {"inspector.exposure", QStringLiteral("曝光")},
        {"inspector.captured", QStringLiteral("拍摄时间")},
        {"unsaved.title", QStringLiteral("存储对此图片的更改？")},
        {"unsaved.body", QStringLiteral("这张图片有未存储的更改。")},
        {"unsaved.bodyNamed", QStringLiteral("“%1” 有未存储的更改。")},
        {"status.edited", QStringLiteral("（已编辑）")},
        {"error.clipboardEmpty", QStringLiteral("剪贴板里没有图片。")},
        {"error.couldNotSave", QStringLiteral("无法存储“%1”。")},
        {"view.previous", QStringLiteral("上一张")},
        {"view.next", QStringLiteral("下一张")},
        {"view.first", QStringLiteral("第一张")},
        {"view.last", QStringLiteral("最后一张")},
        {"view.zoomIn", QStringLiteral("放大")},
        {"view.zoomOut", QStringLiteral("缩小")},
        {"view.actualSize", QStringLiteral("实际大小")},
        {"view.fitDefault", QStringLiteral("适应窗口")},
        {"view.fullscreen", QStringLiteral("全屏")},
        {"view.langAuto", QStringLiteral("跟随系统")},
        {"view.langZh", QStringLiteral("简体中文")},
        {"view.langEn", QStringLiteral("English")},
        {"help.tips", QStringLiteral("使用提示(&T)")},
        {"help.visitWebsite", QStringLiteral("访问 Flip 产品页(&W)")},
        {"help.about", QStringLiteral("关于(&A)")},
        {"empty.hint", QStringLiteral("打开图片，或把文件拖到这里")},
        {"empty.sub", QStringLiteral("方向键在同一文件夹里前后翻页")},
        {"error.cannotOpen", QStringLiteral("无法打开该图片")},
        {"dialog.openImage", QStringLiteral("打开图片")},
        {"dialog.openFolder", QStringLiteral("打开文件夹")},
        {"dialog.images", QStringLiteral("图片")},
        {"dialog.allFiles", QStringLiteral("所有文件")},
        {"about.title", QStringLiteral("关于 看图")},
        {"about.body",
         QStringLiteral(
             "<p><b>看图</b>（Flip）版本 %1</p>"
             "<p>面向办公场景的轻量看图软件：打开一张图片，即可用方向键在"
             "<b>同一文件夹</b>里前后翻页，类似经典的 Windows 照片查看器。</p>"
             "<p>默认缩放：小于窗口的图片按 100% 显示；大于窗口的图片缩小以适应窗口，居中、默认不放大。</p>"
             "<p>许可证：MIT<br>开发：喜相逢科技 / Xixiangfeng Tech<br>"
             "网站：<a href=\"https://www.ak129.cn/flip/\">https://www.ak129.cn/flip/</a></p>")},
        {"tips.title", QStringLiteral("使用提示")},
        {"tips.body",
         QStringLiteral(
             "<p>打开一张图片后，即可在<b>同一文件夹</b>里前后翻页。</p>"
             "<ul>"
             "<li>方向键、空格、PageUp / PageDown：上一张 / 下一张</li>"
             "<li>点击画面左 / 右边缘：上一张 / 下一张</li>"
             "<li>鼠标滚轮翻页；按住 Ctrl 再滚轮可缩放</li>"
             "<li>默认缩放：小于窗口的图片按 100% 显示，大于窗口的缩小以适应窗口</li>"
             "</ul>")},
        {"tips.ok", QStringLiteral("知道了")},
        {"tips.dontShow", QStringLiteral("不再提示")},
        {"launch.combinedTitle", QStringLiteral("欢迎使用 Flip")},
        {"update.title", QStringLiteral("发现新版本")},
        {"update.body",
         QStringLiteral("<p>当前版本 %1，新版本 <b>%2</b>。</p><p>%3</p>")},
        {"update.go", QStringLiteral("前往更新")},
        {"update.picking", QStringLiteral("正在选择较快的源…")},
        {"update.dont", QStringLiteral("不更新")},
        {"update.later", QStringLiteral("稍后再说")},
        {"update.downloadingTitle", QStringLiteral("正在更新 Flip…")},
        {"update.downloadingBody",
         QStringLiteral("正在下载并安装更新，完成后将自动重新打开。")},
        {"update.failedTitle", QStringLiteral("更新失败")},
        {"update.failedBody",
         QStringLiteral("无法在原位置更新 Flip。可改为打开下载链接，手动替换程序。")},
        {"update.notWritableTitle", QStringLiteral("无法就地更新")},
        {"update.notWritableBody",
         QStringLiteral("当前 Flip 安装目录不可写（例如位于只读位置或 AppImage）。请打开下载链接并手动替换文件。")},
        {"update.openDownload", QStringLiteral("打开下载")},
        {"dialog.cancel", QStringLiteral("取消")},
        {"status.ready", QStringLiteral("打开一张图片开始浏览")},
        {"status.position", QStringLiteral("%1 / %2")},
        {"usage",
         QStringLiteral("用法: Flip [图片文件或文件夹]\n"
                        "      Flip --self-test\n"
                        "      Flip --help")},
    };
}

QHash<QString, QString> enTable()
{
    return {
        {"app.name", QStringLiteral("Flip")},
        {"menu.file", QStringLiteral("&File")},
        {"menu.view", QStringLiteral("&View")},
        {"menu.help", QStringLiteral("&Help")},
        {"menu.language", QStringLiteral("&Language")},
        {"file.openImage", QStringLiteral("&Open Image…")},
        {"file.openFolder", QStringLiteral("Open &Folder…")},
        {"file.newClipboard", QStringLiteral("New from Clipboard")},
        {"file.save", QStringLiteral("Save")},
        {"file.saveAs", QStringLiteral("Save As…")},
        {"file.print", QStringLiteral("Print…")},
        {"file.trash", QStringLiteral("Move to Trash…")},
        {"file.trashAsk", QStringLiteral("Move to Trash?")},
        {"file.trashNamed", QStringLiteral("“%1” will be moved to the Trash.")},
        {"file.untitled", QStringLiteral("Untitled")},
        {"file.quit", QStringLiteral("&Quit")},
        {"menu.edit", QStringLiteral("&Edit")},
        {"menu.image", QStringLiteral("&Image")},
        {"edit.undo", QStringLiteral("Undo")},
        {"edit.copyImage", QStringLiteral("Copy Image")},
        {"edit.copyPath", QStringLiteral("Copy Path")},
        {"toolbar.markup", QStringLiteral("Markup")},
        {"toolbar.more", QStringLiteral("More")},
        {"tool.pen", QStringLiteral("Draw")},
        {"tool.line", QStringLiteral("Line")},
        {"tool.arrow", QStringLiteral("Arrow")},
        {"tool.rect", QStringLiteral("Rectangle")},
        {"tool.roundRect", QStringLiteral("Rounded Rectangle")},
        {"tool.oval", QStringLiteral("Ellipse")},
        {"tool.highlight", QStringLiteral("Highlight")},
        {"tool.text", QStringLiteral("Text")},
        {"tool.crop", QStringLiteral("Crop selection")},
        {"markup.fill", QStringLiteral("Fill")},
        {"markup.stroke", QStringLiteral("Stroke")},
        {"markup.color", QStringLiteral("Markup color")},
        {"markup.weight", QStringLiteral("Line width")},
        {"markup.font", QStringLiteral("Font size")},
        {"markup.textBg", QStringLiteral("Text background")},
        {"markup.placeholder", QStringLiteral("Type here · double-click to edit")},
        {"color.red", QStringLiteral("Red")},
        {"color.orange", QStringLiteral("Orange")},
        {"color.yellow", QStringLiteral("Yellow")},
        {"color.green", QStringLiteral("Green")},
        {"color.blue", QStringLiteral("Blue")},
        {"color.white", QStringLiteral("White")},
        {"color.black", QStringLiteral("Black")},
        {"weight.thin", QStringLiteral("Thin")},
        {"weight.regular", QStringLiteral("Medium")},
        {"weight.thick", QStringLiteral("Thick")},
        {"weight.heavy", QStringLiteral("Extra thick")},
        {"font.small", QStringLiteral("Small text")},
        {"font.regular", QStringLiteral("Medium text")},
        {"font.large", QStringLiteral("Large text")},
        {"font.extra", QStringLiteral("Extra large text")},
        {"image.rotateLeft", QStringLiteral("Rotate Left")},
        {"image.rotateRight", QStringLiteral("Rotate Right")},
        {"image.flipH", QStringLiteral("Flip Horizontal")},
        {"image.flipV", QStringLiteral("Flip Vertical")},
        {"image.crop", QStringLiteral("Crop")},
        {"image.selectAll", QStringLiteral("Select All")},
        {"image.removeBg", QStringLiteral("Remove Background")},
        {"adjust.color", QStringLiteral("Adjust Color")},
        {"adjust.size", QStringLiteral("Adjust Size")},
        {"adjust.width", QStringLiteral("Width")},
        {"adjust.height", QStringLiteral("Height")},
        {"adjust.percent", QStringLiteral("Percent")},
        {"adjust.keepAspect", QStringLiteral("Scale proportionally")},
        {"adjust.exposure", QStringLiteral("Exposure")},
        {"adjust.contrast", QStringLiteral("Contrast")},
        {"adjust.brightness", QStringLiteral("Brightness")},
        {"adjust.saturation", QStringLiteral("Saturation")},
        {"adjust.highlights", QStringLiteral("Highlights")},
        {"adjust.shadows", QStringLiteral("Shadows")},
        {"adjust.temperature", QStringLiteral("Temperature")},
        {"adjust.tint", QStringLiteral("Tint")},
        {"adjust.sepia", QStringLiteral("Sepia")},
        {"adjust.sharpness", QStringLiteral("Sharpness")},
        {"adjust.autoLevels", QStringLiteral("Auto Levels")},
        {"adjust.reset", QStringLiteral("Reset All")},
        {"inspector", QStringLiteral("Show Inspector")},
        {"inspector.file", QStringLiteral("File")},
        {"inspector.pixels", QStringLiteral("Pixels")},
        {"inspector.bytes", QStringLiteral("Size")},
        {"inspector.format", QStringLiteral("Format")},
        {"inspector.color", QStringLiteral("Color")},
        {"inspector.dpi", QStringLiteral("DPI")},
        {"inspector.profile", QStringLiteral("Profile")},
        {"inspector.camera", QStringLiteral("Camera")},
        {"inspector.lens", QStringLiteral("Lens")},
        {"inspector.exposure", QStringLiteral("Exposure")},
        {"inspector.captured", QStringLiteral("Captured")},
        {"unsaved.title", QStringLiteral("Save changes to this image?")},
        {"unsaved.body", QStringLiteral("This image has unsaved edits.")},
        {"unsaved.bodyNamed", QStringLiteral("“%1” has unsaved edits.")},
        {"status.edited", QStringLiteral("(Edited)")},
        {"error.clipboardEmpty", QStringLiteral("Clipboard has no image.")},
        {"error.couldNotSave", QStringLiteral("Could not save “%1”.")},
        {"view.previous", QStringLiteral("Previous")},
        {"view.next", QStringLiteral("Next")},
        {"view.first", QStringLiteral("First")},
        {"view.last", QStringLiteral("Last")},
        {"view.zoomIn", QStringLiteral("Zoom In")},
        {"view.zoomOut", QStringLiteral("Zoom Out")},
        {"view.actualSize", QStringLiteral("Actual Size")},
        {"view.fitDefault", QStringLiteral("Fit Window")},
        {"view.fullscreen", QStringLiteral("Full Screen")},
        {"view.langAuto", QStringLiteral("System default")},
        {"view.langZh", QStringLiteral("简体中文")},
        {"view.langEn", QStringLiteral("English")},
        {"help.tips", QStringLiteral("&Usage Tips")},
        {"help.visitWebsite", QStringLiteral("&Visit Flip on ak129.cn")},
        {"help.about", QStringLiteral("&About")},
        {"empty.hint", QStringLiteral("Open an image, or drop a file here")},
        {"empty.sub", QStringLiteral("Arrow keys page through the same folder")},
        {"error.cannotOpen", QStringLiteral("Could not open this image")},
        {"dialog.openImage", QStringLiteral("Open Image")},
        {"dialog.openFolder", QStringLiteral("Open Folder")},
        {"dialog.images", QStringLiteral("Images")},
        {"dialog.allFiles", QStringLiteral("All files")},
        {"about.title", QStringLiteral("About Flip")},
        {"about.body",
         QStringLiteral(
             "<p><b>Flip</b> (看图) version %1</p>"
             "<p>A lightweight office image viewer: open one picture, then "
             "page through the <b>same folder</b> with the arrow keys, like classic Windows Photo Viewer.</p>"
             "<p>Default zoom: images smaller than the window stay at 100%; larger images scale down to fit, "
             "centered, with no upscaling by default.</p>"
             "<p>License: MIT<br>Developer: 喜相逢科技 / Xixiangfeng Tech<br>"
             "Website: <a href=\"https://www.ak129.cn/flip/\">https://www.ak129.cn/flip/</a></p>")},
        {"tips.title", QStringLiteral("Tips")},
        {"tips.body",
         QStringLiteral(
             "<p>Open an image, then page through the <b>same folder</b>.</p>"
             "<ul>"
             "<li>Arrow keys, Space, PageUp / PageDown: previous / next</li>"
             "<li>Click the left or right edge: previous / next</li>"
             "<li>Mouse wheel pages; Ctrl+wheel zooms</li>"
             "<li>Default zoom: images smaller than the window stay at 100%; larger images scale down to fit</li>"
             "</ul>")},
        {"tips.ok", QStringLiteral("OK")},
        {"tips.dontShow", QStringLiteral("Don't show again")},
        {"launch.combinedTitle", QStringLiteral("Welcome")},
        {"update.title", QStringLiteral("Update available")},
        {"update.body",
         QStringLiteral("<p>Current version %1, new version <b>%2</b>.</p><p>%3</p>")},
        {"update.go", QStringLiteral("Go to update")},
        {"update.picking", QStringLiteral("Picking the faster source…")},
        {"update.dont", QStringLiteral("Don't update")},
        {"update.later", QStringLiteral("Later")},
        {"update.downloadingTitle", QStringLiteral("Updating Flip…")},
        {"update.downloadingBody",
         QStringLiteral("Downloading and installing the update. Flip will relaunch when finished.")},
        {"update.failedTitle", QStringLiteral("Update failed")},
        {"update.failedBody",
         QStringLiteral("Flip could not update itself in place. You can open the download page instead.")},
        {"update.notWritableTitle", QStringLiteral("Cannot update here")},
        {"update.notWritableBody",
         QStringLiteral("This Flip install is not writable (for example, a read-only location or AppImage). Open the download instead and replace the files manually.")},
        {"update.openDownload", QStringLiteral("Open download")},
        {"dialog.cancel", QStringLiteral("Cancel")},
        {"status.ready", QStringLiteral("Open an image to start browsing")},
        {"status.position", QStringLiteral("%1 / %2")},
        {"usage",
         QStringLiteral("Usage: Flip [image-file-or-folder]\n"
                        "       Flip --self-test\n"
                        "       Flip --help")},
    };
}

const QHash<QString, QString>& tableFor(Lang lang)
{
    static const QHash<QString, QString> zh = zhTable();
    static const QHash<QString, QString> en = enTable();
    return lang == Lang::ZhCN ? zh : en;
}

} // namespace

void setLang(Lang lang)
{
    g_pref = lang;
}

Lang lang()
{
    return g_pref;
}

Lang resolved()
{
    if (g_pref != Lang::Auto)
        return g_pref;
    const QLocale loc = QLocale::system();
    if (loc.language() == QLocale::Chinese)
        return Lang::ZhCN;
    return Lang::En;
}

QString t(const char* key)
{
    const auto& table = tableFor(resolved());
    const QString k = QString::fromLatin1(key);
    const auto it = table.constFind(k);
    if (it != table.cend())
        return it.value();
    return k;
}

} // namespace I18n
