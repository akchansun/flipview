#include "ImageView.h"

#include "FitZoom.h"
#include "I18n.h"

#include <QDragEnterEvent>
#include <QDropEvent>
#include <QKeyEvent>
#include <QMimeData>
#include <QMouseEvent>
#include <QPainter>
#include <QPainterPath>
#include <QUrl>
#include <QWheelEvent>
#include <QtMath>
#include <algorithm>
#include <optional>

namespace {
constexpr double kMinScale = 0.05;
constexpr double kMaxScale = 64.0;
constexpr double kZoomStep = 1.25;
} // namespace

ImageView::ImageView(QWidget* parent)
    : QWidget(parent)
{
    setMouseTracking(true);
    setAcceptDrops(true);
    setMinimumSize(320, 240);
    setFocusPolicy(Qt::StrongFocus);
    setAutoFillBackground(false);
}

void ImageView::setSession(ImageSession* session)
{
    if (m_session == session)
        return;
    if (m_session)
        disconnect(m_session, nullptr, this, nullptr);
    m_session = session;
    if (m_session)
        connect(m_session, &ImageSession::changed, this, &ImageView::syncFromSession);
    syncFromSession();
}

void ImageView::syncFromSession()
{
    if (!m_session || !m_session->hasImage()) {
        clearImage();
        return;
    }
    m_image = m_session->displayed();
    m_pixmap = QPixmap::fromImage(m_image);
    if (m_fitMode)
        applyScale(fitScale(), true);
    update();
}

void ImageView::setImage(const QImage& image)
{
    m_image = image;
    m_pixmap = QPixmap::fromImage(m_image);
    m_pan = QPointF();
    zoomFitDefault();
    update();
}

void ImageView::clearImage()
{
    m_image = QImage();
    m_pixmap = QPixmap();
    m_scale = 1.0;
    m_fitMode = true;
    m_pan = QPointF();
    update();
    emit scaleChanged(m_scale);
}

bool ImageView::hasImage() const
{
    return !m_image.isNull();
}

void ImageView::zoomIn()
{
    applyScale(m_scale * kZoomStep, false);
}

void ImageView::zoomOut()
{
    applyScale(m_scale / kZoomStep, false);
}

void ImageView::zoomActual()
{
    applyScale(1.0, false);
}

void ImageView::zoomFitDefault()
{
    applyScale(fitScale(), true);
}

double ImageView::scale() const
{
    return m_scale;
}

QSize ImageView::imagePixelSize() const
{
    return m_image.size();
}

double ImageView::fitScale() const
{
    return defaultFitScale(m_image.size(), size());
}

QRectF ImageView::drawnRect() const
{
    if (m_image.isNull())
        return {};
    const QSizeF drawn(m_image.width() * m_scale, m_image.height() * m_scale);
    QPointF topLeft((width() - drawn.width()) / 2.0, (height() - drawn.height()) / 2.0);
    topLeft += m_pan;
    return QRectF(topLeft, drawn);
}

void ImageView::applyScale(double scale, bool fitMode)
{
    m_fitMode = fitMode;
    m_scale = std::clamp(scale, kMinScale, kMaxScale);
    if (m_fitMode)
        m_pan = QPointF();
    update();
    emit scaleChanged(m_scale);
}

int ImageView::edgeZoneWidth() const
{
    return std::max(48, int(width() * 0.16));
}

ImageView::HoverEdge ImageView::edgeAt(const QPoint& pos) const
{
    if (!hasImage() || (m_session && m_session->tool() != MarkupTool::Browse))
        return HoverEdge::None;
    const int zone = edgeZoneWidth();
    if (pos.x() <= zone)
        return HoverEdge::Left;
    if (pos.x() >= width() - zone)
        return HoverEdge::Right;
    return HoverEdge::None;
}

void ImageView::updateHover(const QPoint& pos)
{
    const HoverEdge edge = edgeAt(pos);
    if (edge != m_hover) {
        m_hover = edge;
        update();
    }
    updateCursor(pos);
}

void ImageView::updateCursor(const QPoint& /*pos*/)
{
    if (!m_session || !hasImage()) {
        unsetCursor();
        return;
    }
    const MarkupTool tool = m_session->tool();
    if (tool == MarkupTool::Text) {
        setCursor(Qt::IBeamCursor);
        return;
    }
    if (isMarkupInk(tool) || tool == MarkupTool::Crop) {
        setCursor(Qt::CrossCursor);
        return;
    }
    if (m_hover != HoverEdge::None) {
        setCursor(Qt::PointingHandCursor);
        return;
    }
    unsetCursor();
}

QStringList ImageView::droppedPaths(const QMimeData* mime) const
{
    QStringList paths;
    if (!mime || !mime->hasUrls())
        return paths;
    for (const QUrl& url : mime->urls()) {
        if (url.isLocalFile())
            paths << url.toLocalFile();
    }
    return paths;
}

void ImageView::beginTextEdit(const MarkupItem& item)
{
    if (!m_textEdit) {
        m_textEdit = new QLineEdit(this);
        m_textEdit->setFrame(false);
        connect(m_textEdit, &QLineEdit::editingFinished, this, &ImageView::commitTextEdit);
        connect(m_textEdit, &QLineEdit::returnPressed, this, &ImageView::commitTextEdit);
    }
    const QRectF box = textViewBounds(item, drawnRect(), m_image.size());
    m_textEdit->setGeometry(box.toRect().adjusted(-2, -2, 8, 4));
    QFont font = m_textEdit->font();
    font.setPointSizeF(textPointSizeForImage(m_image.size(), item.fontSize));
    m_textEdit->setFont(font);
    m_textEdit->setText(item.text);
    m_textEdit->setPlaceholderText(I18n::t("markup.placeholder"));
    m_textEdit->show();
    m_textEdit->setFocus();
    m_textEdit->selectAll();
}

void ImageView::commitTextEdit()
{
    if (!m_textEdit || !m_textEdit->isVisible() || !m_session)
        return;
    if (MarkupItem* item = m_session->mutableSelected()) {
        item->text = m_textEdit->text();
    }
    m_textEdit->hide();
    m_session->commitDraft();
}

void ImageView::cancelTextEdit()
{
    if (m_textEdit)
        m_textEdit->hide();
    if (m_session)
        m_session->cancelDraft();
}

void ImageView::paintEvent(QPaintEvent*)
{
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.fillRect(rect(), QColor(24, 24, 24));

    if (m_image.isNull()) {
        p.setPen(QColor(210, 210, 210));
        QFont title = font();
        title.setPointSize(title.pointSize() + 4);
        title.setBold(true);
        p.setFont(title);
        const QRect hintRect = rect().adjusted(24, 0, -24, -12);
        p.drawText(hintRect, Qt::AlignCenter, I18n::t("empty.hint"));
        QFont sub = font();
        p.setFont(sub);
        p.setPen(QColor(150, 150, 150));
        p.drawText(rect().adjusted(24, 28, -24, 0), Qt::AlignHCenter | Qt::AlignVCenter,
                   I18n::t("empty.sub"));
        return;
    }

    const QRectF dest = drawnRect();
    p.setRenderHint(QPainter::SmoothPixmapTransform, m_scale < 0.999 || m_scale > 1.001);
    p.drawPixmap(dest.toRect(), m_pixmap);

    if (m_session) {
        p.setClipRect(dest);
        for (const MarkupItem& item : m_session->items())
            drawMarkupItem(p, item, dest, m_image.size(), item.id == m_session->selectedId());
        if (m_session->tool() == MarkupTool::Crop && m_session->cropSelection())
            drawCropOverlay(p, *m_session->cropSelection(), dest, m_image.size());
        p.setClipping(false);
    }

    if (m_hover != HoverEdge::None) {
        const int zone = edgeZoneWidth();
        QRect band = m_hover == HoverEdge::Left ? QRect(0, 0, zone, height())
                                                : QRect(width() - zone, 0, zone, height());
        p.fillRect(band, QColor(255, 255, 255, 22));
        p.setPen(Qt::NoPen);
        p.setBrush(QColor(255, 255, 255, 200));
        const qreal cx = m_hover == HoverEdge::Left ? zone * 0.45 : width() - zone * 0.45;
        const qreal cy = height() / 2.0;
        QPainterPath chevron;
        if (m_hover == HoverEdge::Left) {
            chevron.moveTo(cx + 8, cy - 18);
            chevron.lineTo(cx - 10, cy);
            chevron.lineTo(cx + 8, cy + 18);
            chevron.lineTo(cx + 14, cy + 10);
            chevron.lineTo(cx + 2, cy);
            chevron.lineTo(cx + 14, cy - 10);
        } else {
            chevron.moveTo(cx - 8, cy - 18);
            chevron.lineTo(cx + 10, cy);
            chevron.lineTo(cx - 8, cy + 18);
            chevron.lineTo(cx - 14, cy + 10);
            chevron.lineTo(cx - 2, cy);
            chevron.lineTo(cx - 14, cy - 10);
        }
        chevron.closeSubpath();
        p.drawPath(chevron);
    }
}

void ImageView::resizeEvent(QResizeEvent*)
{
    if (m_fitMode && hasImage())
        applyScale(fitScale(), true);
}

void ImageView::mousePressEvent(QMouseEvent* event)
{
    if (event->button() != Qt::LeftButton)
        return;
    m_pressPos = event->pos();
    m_pressPan = m_pan;
    m_moved = false;
    m_drag = DragMode::None;
    m_handle = MarkupHandle::None;
    if (!hasImage() || !m_session) {
        return;
    }

    const QRectF dest = drawnRect();
    const QPointF norm = viewToNorm(event->position(), dest);
    m_pressNorm = norm;
    const MarkupTool tool = m_session->tool();

    if (tool == MarkupTool::Crop) {
        if (m_session->cropSelection()) {
            m_handle = hitCropHandle(*m_session->cropSelection(), event->position(), dest);
            if (m_handle == MarkupHandle::Body) {
                m_drag = DragMode::CropMove;
                m_cropStart = *m_session->cropSelection();
                return;
            }
            if (m_handle != MarkupHandle::None) {
                m_drag = DragMode::CropResize;
                m_cropStart = *m_session->cropSelection();
                return;
            }
        }
        m_drag = DragMode::CropNew;
        m_session->setCropSelection(QRectF(norm, QSizeF(0, 0)));
        return;
    }

    if (isMarkupInk(tool)) {
        if (tool != MarkupTool::Text) {
            const QString hit = hitTestMarkup(m_session->items(), event->position(), dest, m_image.size());
            if (!hit.isEmpty() && tool != MarkupTool::Pen) {
                m_session->select(hit);
                if (m_session->mutableSelected()) {
                    m_handle = hitMarkupHandle(*m_session->mutableSelected(), event->position(), dest,
                                               m_image.size());
                    m_drag = m_handle == MarkupHandle::None ? DragMode::Move : DragMode::Resize;
                }
            }
        }
        if (m_drag == DragMode::None) {
            MarkupItem item;
            item.id = newMarkupId();
            item.color = m_session->color();
            item.weight = m_session->weight();
            item.fontSize = m_session->fontSize();
            item.filled = m_session->filled();
            item.start = norm;
            item.end = norm;
            item.origin = norm;
            switch (tool) {
            case MarkupTool::Pen:
                item.kind = MarkupKind::Stroke;
                item.points << norm;
                break;
            case MarkupTool::Line:
                item.kind = MarkupKind::Line;
                break;
            case MarkupTool::Arrow:
                item.kind = MarkupKind::Arrow;
                break;
            case MarkupTool::Rect:
                item.kind = MarkupKind::Rect;
                break;
            case MarkupTool::RoundRect:
                item.kind = MarkupKind::RoundRect;
                break;
            case MarkupTool::Oval:
                item.kind = MarkupKind::Oval;
                break;
            case MarkupTool::Highlight:
                item.kind = MarkupKind::Highlight;
                break;
            case MarkupTool::Text:
                item.kind = MarkupKind::Text;
                item.text.clear();
                m_session->addDraft(item);
                beginTextEdit(item);
                m_drag = DragMode::Text;
                return;
            default:
                break;
            }
            if (tool != MarkupTool::Text) {
                m_draft = item;
                m_session->addDraft(item);
                m_drag = DragMode::Draw;
            }
        }
        return;
    }

    const QString hit = hitTestMarkup(m_session->items(), event->position(), dest, m_image.size());
    if (!hit.isEmpty()) {
        m_session->select(hit);
        if (MarkupItem* item = m_session->mutableSelected()) {
            if (item->kind == MarkupKind::Text) {
                beginTextEdit(*item);
                m_drag = DragMode::Text;
                return;
            }
            m_handle = hitMarkupHandle(*item, event->position(), dest, m_image.size());
            m_drag = m_handle == MarkupHandle::None ? DragMode::Move : DragMode::Resize;
            return;
        }
    } else {
        m_session->select({});
    }
}

void ImageView::mouseMoveEvent(QMouseEvent* event)
{
    updateHover(event->pos());
    if (!(event->buttons() & Qt::LeftButton) || !m_session)
        return;
    const QPoint delta = event->pos() - m_pressPos;
    if (delta.manhattanLength() >= 4)
        m_moved = true;
    const QRectF dest = drawnRect();
    const QPointF norm = viewToNorm(event->position(), dest);
    const bool shift = event->modifiers() & Qt::ShiftModifier;

    if (m_drag == DragMode::Draw) {
        if (MarkupItem* item = m_session->mutableSelected()) {
            if (item->kind == MarkupKind::Stroke) {
                item->points << norm;
            } else if (item->kind == MarkupKind::Line || item->kind == MarkupKind::Arrow) {
                item->end = shift ? constrainAxis(item->start, norm) : norm;
            } else {
                item->end = shift ? constrainSquare(item->start, norm) : norm;
            }
            m_session->updateDraft(*item);
        }
        return;
    }
    if (m_drag == DragMode::Move) {
        if (MarkupItem* item = m_session->mutableSelected()) {
            translateMarkup(item, norm - m_pressNorm);
            m_pressNorm = norm;
            m_session->updateDraft(*item);
        }
        return;
    }
    if (m_drag == DragMode::Resize) {
        if (MarkupItem* item = m_session->mutableSelected()) {
            resizeMarkup(item, m_handle, norm, shift);
            m_session->updateDraft(*item);
        }
        return;
    }
    if (m_drag == DragMode::CropNew) {
        QPointF end = shift ? constrainSquare(m_pressNorm, norm) : norm;
        m_session->setCropSelection(QRectF(m_pressNorm, end).normalized());
        return;
    }
    if (m_drag == DragMode::CropMove && m_session->cropSelection()) {
        m_session->setCropSelection(translatedCrop(m_cropStart, norm - m_pressNorm));
        return;
    }
    if (m_drag == DragMode::CropResize && m_session->cropSelection()) {
        m_session->setCropSelection(resizedCrop(m_cropStart, m_handle, norm, shift));
        return;
    }
    if (m_drag == DragMode::None && !m_fitMode && hasImage()
        && (!m_session || m_session->tool() == MarkupTool::Browse)) {
        m_pan = m_pressPan + delta;
        setCursor(Qt::ClosedHandCursor);
        update();
    }
}

void ImageView::mouseReleaseEvent(QMouseEvent* event)
{
    if (event->button() != Qt::LeftButton)
        return;
    updateHover(event->pos());
    if (m_session && (m_drag == DragMode::Draw || m_drag == DragMode::Move || m_drag == DragMode::Resize))
        m_session->commitDraft();
    if (m_session && m_drag == DragMode::CropNew && m_session->cropSelection()) {
        const QRectF box = m_session->cropSelection()->normalized();
        if (box.width() < 0.01 || box.height() < 0.01)
            m_session->setCropSelection(std::nullopt);
    }
    const DragMode finished = m_drag;
    m_drag = DragMode::None;
    if (m_moved || finished != DragMode::None)
        return;
    const HoverEdge edge = edgeAt(event->pos());
    if (edge == HoverEdge::Left)
        emit previousRequested();
    else if (edge == HoverEdge::Right)
        emit nextRequested();
}

void ImageView::mouseDoubleClickEvent(QMouseEvent* event)
{
    if (!hasImage())
        return;
    if (m_session && m_session->tool() == MarkupTool::Crop && m_session->cropSelection()) {
        const QRectF box = fracToView(*m_session->cropSelection(), drawnRect());
        if (box.contains(event->position())) {
            m_session->applyCrop();
            return;
        }
    }
    if (m_fitMode && qAbs(m_scale - 1.0) > 0.001)
        zoomActual();
    else
        zoomFitDefault();
}

void ImageView::wheelEvent(QWheelEvent* event)
{
    if (event->modifiers() & Qt::ControlModifier) {
        if (!hasImage())
            return;
        if (event->angleDelta().y() > 0)
            zoomIn();
        else if (event->angleDelta().y() < 0)
            zoomOut();
        return;
    }
    if (event->angleDelta().y() > 0)
        emit previousRequested();
    else if (event->angleDelta().y() < 0)
        emit nextRequested();
}

void ImageView::dragEnterEvent(QDragEnterEvent* event)
{
    if (!droppedPaths(event->mimeData()).isEmpty())
        event->acceptProposedAction();
}

void ImageView::dropEvent(QDropEvent* event)
{
    const QStringList paths = droppedPaths(event->mimeData());
    if (!paths.isEmpty()) {
        event->acceptProposedAction();
        emit filesDropped(paths);
    }
}

void ImageView::leaveEvent(QEvent*)
{
    if (m_hover != HoverEdge::None) {
        m_hover = HoverEdge::None;
        unsetCursor();
        update();
    }
}

void ImageView::keyPressEvent(QKeyEvent* event)
{
    if (!m_session) {
        QWidget::keyPressEvent(event);
        return;
    }
    if (event->key() == Qt::Key_Return || event->key() == Qt::Key_Enter) {
        if (m_session->tool() == MarkupTool::Crop)
            m_session->applyCrop();
        else if (m_textEdit && m_textEdit->isVisible())
            commitTextEdit();
        return;
    }
    if (event->key() == Qt::Key_Escape) {
        if (m_textEdit && m_textEdit->isVisible()) {
            cancelTextEdit();
            return;
        }
        if (m_session->tool() != MarkupTool::Browse) {
            m_session->setTool(MarkupTool::Browse);
            return;
        }
    }
    if (event->key() == Qt::Key_Delete || event->key() == Qt::Key_Backspace) {
        if (!m_session->selectedId().isEmpty()) {
            m_session->removeSelected();
            return;
        }
    }
    QWidget::keyPressEvent(event);
}
