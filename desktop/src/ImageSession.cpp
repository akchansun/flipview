#include "ImageSession.h"

#include <QDateTime>
#include <QFileInfo>
#include <QImageReader>
#include <QImageWriter>
namespace {
constexpr int kDisplayLongEdge = 4096;
}

ImageSession::ImageSession(QObject* parent)
    : QObject(parent)
{
}

bool ImageSession::openPath(const QString& path)
{
    const QImage img = loadDisplayImage(path, kDisplayLongEdge);
    if (img.isNull())
        return false;
    m_path = path;
    m_source = img;
    m_ops.clear();
    m_items.clear();
    m_undo.clear();
    m_selected.clear();
    m_crop.reset();
    m_tool = MarkupTool::Browse;
    m_liveColor = {};
    m_colorPushed = false;
    fillInfo();
    rebuildDisplayed();
    emit changed();
    return true;
}

bool ImageSession::openImage(const QImage& image, const QString& suggestedName)
{
    if (image.isNull())
        return false;
    m_path.clear();
    m_source = image.convertToFormat(QImage::Format_ARGB32);
    m_ops.clear();
    m_items.clear();
    m_undo.clear();
    m_selected.clear();
    m_crop.reset();
    m_tool = MarkupTool::Browse;
    m_liveColor = {};
    m_colorPushed = false;
    m_info = {};
    m_info.fileName = suggestedName;
    m_info.pixels = m_source.size();
    m_info.format = QStringLiteral("PNG");
    m_info.colorSpace = QStringLiteral("sRGB");
    rebuildDisplayed();
    emit changed();
    return true;
}

void ImageSession::clear()
{
    m_path.clear();
    m_source = {};
    m_displayed = {};
    m_ops.clear();
    m_items.clear();
    m_undo.clear();
    m_selected.clear();
    m_crop.reset();
    m_tool = MarkupTool::Browse;
    m_info = {};
    emit changed();
}

bool ImageSession::isDirty() const
{
    return !m_ops.isEmpty() || !m_items.isEmpty();
}

QString ImageSession::fileName() const
{
    if (!m_info.fileName.isEmpty())
        return m_info.fileName;
    return QFileInfo(m_path).fileName();
}

void ImageSession::rebuildDisplayed()
{
    m_displayed = applyOps(m_source, m_ops);
}

void ImageSession::pushUndo()
{
    m_undo.push_back({m_ops, m_items});
    if (m_undo.size() > 40)
        m_undo.removeFirst();
}

void ImageSession::apply(const ImageOp& op)
{
    if (!hasImage())
        return;
    pushUndo();
    m_ops.push_back(op);
    transformMarkup(m_items, op);
    m_crop.reset();
    if (op.kind != ImageOpKind::Color)
        m_liveColor = {};
    rebuildDisplayed();
    emit changed();
}

void ImageSession::beginColorAdjust()
{
    if (!hasImage())
        return;
    showAdjustColor = true;
    m_colorPushed = false;
    emit changed();
}

void ImageSession::setLiveColor(const ColorAdjust& color)
{
    if (!hasImage())
        return;
    if (!m_colorPushed) {
        pushUndo();
        m_colorPushed = true;
    }
    m_liveColor = color;
    if (!m_ops.isEmpty() && m_ops.last().kind == ImageOpKind::Color)
        m_ops.removeLast();
    if (!color.isIdentity())
        m_ops.push_back(ImageOp::colorAdjust(color));
    rebuildDisplayed();
    emit changed();
}

void ImageSession::commitColor()
{
    showAdjustColor = false;
    m_colorPushed = false;
    emit changed();
}

void ImageSession::applyResize(int w, int h)
{
    apply(ImageOp::resizeTo(std::max(1, w), std::max(1, h)));
    showAdjustSize = false;
}

void ImageSession::applyCrop()
{
    if (!m_crop)
        return;
    const QRectF box = m_crop->normalized();
    if (box.width() <= 0.01 || box.height() <= 0.01)
        return;
    apply(ImageOp::cropFrac(box));
    m_tool = MarkupTool::Browse;
    emit requestZoomFit();
}

void ImageSession::selectAllCrop()
{
    if (!hasImage())
        return;
    m_tool = MarkupTool::Crop;
    m_crop = QRectF(0, 0, 1, 1);
    emit changed();
}

void ImageSession::removeBackground()
{
    apply(ImageOp::removeBackground());
}

void ImageSession::undo()
{
    if (m_undo.isEmpty())
        return;
    const UndoFrame frame = m_undo.takeLast();
    m_ops = frame.ops;
    m_items = frame.items;
    m_selected.clear();
    rebuildDisplayed();
    emit changed();
}

void ImageSession::revert()
{
    if (!isDirty())
        return;
    pushUndo();
    m_ops.clear();
    m_items.clear();
    m_selected.clear();
    m_crop.reset();
    m_liveColor = {};
    rebuildDisplayed();
    emit changed();
}

QImage ImageSession::fullComposite() const
{
    QImage full = m_path.isEmpty() ? m_source : loadFullImage(m_path);
    if (full.isNull())
        full = m_source;
    full = applyOps(full, m_ops);
    return bakeMarkup(full, m_items);
}

QImage ImageSession::composite() const
{
    return bakeMarkup(m_displayed, m_items);
}

bool ImageSession::save()
{
    if (m_path.isEmpty())
        return false;
    return saveAs(m_path);
}

bool ImageSession::saveAs(const QString& path)
{
    QImage out = fullComposite();
    if (out.isNull())
        return false;
    QImageWriter writer(path);
    const QString suffix = QFileInfo(path).suffix().toLower();
    if (suffix == QLatin1String("jpg") || suffix == QLatin1String("jpeg"))
        writer.setQuality(92);
    if (!writer.write(out))
        return false;
    m_path = path;
    m_source = loadDisplayImage(path, kDisplayLongEdge);
    if (m_source.isNull())
        m_source = out;
    m_ops.clear();
    m_items.clear();
    m_undo.clear();
    m_selected.clear();
    m_crop.reset();
    fillInfo();
    rebuildDisplayed();
    emit changed();
    return true;
}

void ImageSession::setTool(MarkupTool tool)
{
    if (m_tool == tool)
        return;
    if (m_tool == MarkupTool::Crop && tool != MarkupTool::Crop)
        m_crop.reset();
    m_tool = tool;
    if (!isMarkupInk(tool) && tool != MarkupTool::Crop)
        m_selected.clear();
    emit changed();
}

void ImageSession::setColor(MarkupColor c)
{
    m_color = c;
    restyleSelected();
    emit changed();
}

void ImageSession::setWeight(MarkupWeight w)
{
    m_weight = w;
    restyleSelected();
    emit changed();
}

void ImageSession::setFontSize(MarkupFontSize s)
{
    m_fontSize = s;
    restyleSelected();
    emit changed();
}

void ImageSession::setFilled(bool on)
{
    m_filled = on;
    if (MarkupItem* item = mutableSelected()) {
        if (kindCanFill(item->kind)) {
            pushUndo();
            item->filled = on;
        }
    }
    emit changed();
}

void ImageSession::setTextBackground(bool on)
{
    m_filled = on;
    if (MarkupItem* item = mutableSelected()) {
        if (item->kind == MarkupKind::Text) {
            pushUndo();
            item->filled = on;
        }
    }
    emit changed();
}

void ImageSession::select(const QString& id)
{
    m_selected = id;
    syncToolbarFromSelection();
    emit changed();
}

void ImageSession::addDraft(const MarkupItem& item)
{
    pushUndo();
    m_items.push_back(item);
    m_selected = item.id;
    emit changed();
}

void ImageSession::updateDraft(const MarkupItem& item)
{
    if (MarkupItem* existing = mutableItem(item.id))
        *existing = item;
    emit changed();
}

void ImageSession::commitDraft()
{
    if (m_items.isEmpty())
        return;
    if (!isMeaningfulShape(m_items.last())) {
        m_items.removeLast();
        if (!m_undo.isEmpty())
            m_undo.removeLast();
        m_selected.clear();
    } else {
        m_selected = m_items.last().id;
        syncToolbarFromSelection();
    }
    if (m_tool == MarkupTool::Text)
        m_tool = MarkupTool::Browse;
    emit changed();
}

void ImageSession::cancelDraft()
{
    if (!m_items.isEmpty() && !isMeaningfulShape(m_items.last())) {
        m_items.removeLast();
        if (!m_undo.isEmpty())
            m_undo.removeLast();
    }
    if (m_tool == MarkupTool::Text)
        m_tool = MarkupTool::Browse;
    emit changed();
}

void ImageSession::restyleSelected()
{
    MarkupItem* item = mutableSelected();
    if (!item)
        return;
    pushUndo();
    item->color = m_color;
    item->weight = m_weight;
    item->fontSize = m_fontSize;
}

void ImageSession::removeSelected()
{
    if (m_selected.isEmpty())
        return;
    pushUndo();
    for (int i = 0; i < m_items.size(); ++i) {
        if (m_items.at(i).id == m_selected) {
            m_items.removeAt(i);
            break;
        }
    }
    m_selected.clear();
    emit changed();
}

MarkupItem* ImageSession::mutableSelected()
{
    return mutableItem(m_selected);
}

MarkupItem* ImageSession::mutableItem(const QString& id)
{
    if (id.isEmpty())
        return nullptr;
    for (MarkupItem& item : m_items) {
        if (item.id == id)
            return &item;
    }
    return nullptr;
}

void ImageSession::setCropSelection(const std::optional<QRectF>& frac)
{
    m_crop = frac;
    emit changed();
}

void ImageSession::syncToolbarFromSelection()
{
    if (const MarkupItem* item = mutableSelected()) {
        m_color = item->color;
        m_weight = item->weight;
        m_fontSize = item->fontSize;
        m_filled = item->filled;
    }
}

void ImageSession::fillInfo()
{
    m_info = {};
    const QFileInfo fi(m_path);
    m_info.fileName = fi.fileName();
    m_info.path = m_path;
    m_info.bytes = fi.size();
    m_info.format = fi.suffix().toUpper();
    m_info.pixels = m_source.size();
    m_info.colorSpace = m_source.hasAlphaChannel() ? QStringLiteral("sRGB + Alpha")
                                                   : QStringLiteral("sRGB");
    if (m_source.dotsPerMeterX() > 0) {
        const double dpi = m_source.dotsPerMeterX() * 0.0254;
        m_info.dpi = QString::number(dpi, 'f', 0);
    }
    QImageReader reader(m_path);
    reader.setAutoTransform(true);
    const QSize actual = reader.size();
    if (actual.isValid())
        m_info.pixels = actual;
    const QString desc = reader.text(QStringLiteral("Description"));
    if (!desc.isEmpty())
        m_info.profile = desc;
}
