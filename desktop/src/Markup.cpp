#include "Markup.h"

#include <QFont>
#include <QUuid>
#include <QFontMetricsF>
#include <QPainter>
#include <QPainterPath>
#include <QtMath>
#include <algorithm>
#include <cmath>

namespace {

constexpr double kPi = 3.14159265358979323846;

QRectF boxFromCorners(QPointF a, QPointF b)
{
    return QRectF(QPointF(std::min(a.x(), b.x()), std::min(a.y(), b.y())),
                  QPointF(std::max(a.x(), b.x()), std::max(a.y(), b.y())));
}

double distToSegment(QPointF p, QPointF a, QPointF b)
{
    const QPointF ab = b - a;
    const double len2 = QPointF::dotProduct(ab, ab);
    if (len2 < 1e-12)
        return QLineF(p, a).length();
    double t = QPointF::dotProduct(p - a, ab) / len2;
    t = std::clamp(t, 0.0, 1.0);
    const QPointF proj = a + ab * t;
    return QLineF(p, proj).length();
}

QPainterPath strokePath(const QVector<QPointF>& viewPts)
{
    QPainterPath path;
    if (viewPts.isEmpty())
        return path;
    if (viewPts.size() == 1) {
        path.addEllipse(viewPts.first(), 0.5, 0.5);
        return path;
    }
    path.moveTo(viewPts.first());
    for (int i = 1; i < viewPts.size() - 1; ++i) {
        const QPointF mid = (viewPts.at(i) + viewPts.at(i + 1)) / 2.0;
        path.quadTo(viewPts.at(i), mid);
    }
    path.lineTo(viewPts.last());
    return path;
}

void paintSelection(QPainter& p, const QPainterPath& path, double width)
{
    QPen white(QColor(255, 255, 255, 235), std::min(width + 1.0, 1.6));
    white.setStyle(Qt::CustomDashLine);
    white.setDashPattern({2.5, 2.0});
    QPen black(QColor(0, 0, 0, 107), std::min(width + 1.0, 1.6));
    black.setStyle(Qt::CustomDashLine);
    black.setDashPattern({2.5, 2.0});
    black.setDashOffset(2.25);
    p.setBrush(Qt::NoBrush);
    p.setPen(white);
    p.drawPath(path);
    p.setPen(black);
    p.drawPath(path);
}

void paintKnob(QPainter& p, QPointF c, double radius)
{
    p.setPen(QPen(QColor(0, 120, 255), 1.1));
    p.setBrush(Qt::white);
    p.drawEllipse(c, radius, radius);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(0, 0, 0, 51));
    p.drawEllipse(c, radius - 0.55, radius - 0.55);
}

QRectF viewBox(QPointF a, QPointF b)
{
    return QRectF(QPointF(std::min(a.x(), b.x()), std::min(a.y(), b.y())),
                  QPointF(std::max(a.x(), b.x()), std::max(a.y(), b.y()))).normalized();
}

} // namespace

bool isMarkupInk(MarkupTool tool)
{
    switch (tool) {
    case MarkupTool::Pen:
    case MarkupTool::Line:
    case MarkupTool::Arrow:
    case MarkupTool::Rect:
    case MarkupTool::RoundRect:
    case MarkupTool::Oval:
    case MarkupTool::Highlight:
    case MarkupTool::Text:
        return true;
    default:
        return false;
    }
}

bool toolCanFill(MarkupTool tool)
{
    return tool == MarkupTool::Rect || tool == MarkupTool::RoundRect || tool == MarkupTool::Oval;
}

bool kindCanFill(MarkupKind kind)
{
    return kind == MarkupKind::Rect || kind == MarkupKind::RoundRect || kind == MarkupKind::Oval;
}

QColor markupRgb(MarkupColor color)
{
    switch (color) {
    case MarkupColor::Red:
        return QColor::fromRgbF(1, 0.231, 0.188);
    case MarkupColor::Orange:
        return QColor::fromRgbF(1, 0.584, 0);
    case MarkupColor::Yellow:
        return QColor::fromRgbF(1, 0.8, 0);
    case MarkupColor::Green:
        return QColor::fromRgbF(0.204, 0.78, 0.349);
    case MarkupColor::Blue:
        return QColor::fromRgbF(0, 0.478, 1);
    case MarkupColor::White:
        return QColor::fromRgbF(1, 1, 1);
    case MarkupColor::Black:
        return QColor::fromRgbF(0, 0, 0);
    }
    return QColor(255, 59, 48);
}

QColor contrastingInk(MarkupColor color)
{
    if (color == MarkupColor::Yellow || color == MarkupColor::White)
        return QColor::fromRgbF(0.12, 0.12, 0.12);
    return Qt::white;
}

double weightScale(MarkupWeight weight)
{
    switch (weight) {
    case MarkupWeight::Thin:
        return 0.16;
    case MarkupWeight::Regular:
        return 1.0;
    case MarkupWeight::Thick:
        return 2.3;
    case MarkupWeight::Heavy:
        return 4.0;
    }
    return 1.0;
}

double weightSampleThickness(MarkupWeight weight)
{
    switch (weight) {
    case MarkupWeight::Thin:
        return 1.0;
    case MarkupWeight::Regular:
        return 2.0;
    case MarkupWeight::Thick:
        return 3.5;
    case MarkupWeight::Heavy:
        return 6.0;
    }
    return 2.0;
}

double fontScale(MarkupFontSize size)
{
    switch (size) {
    case MarkupFontSize::Small:
        return 0.7;
    case MarkupFontSize::Regular:
        return 1.0;
    case MarkupFontSize::Large:
        return 1.5;
    case MarkupFontSize::Extra:
        return 2.15;
    }
    return 1.0;
}

double fontSamplePointSize(MarkupFontSize size)
{
    switch (size) {
    case MarkupFontSize::Small:
        return 9;
    case MarkupFontSize::Regular:
        return 12;
    case MarkupFontSize::Large:
        return 16;
    case MarkupFontSize::Extra:
        return 20;
    }
    return 12;
}

double strokeWidthForImage(QSize imagePx, MarkupWeight weight)
{
    const double shortSide = std::min(imagePx.width(), imagePx.height());
    return std::max(0.5, shortSide * 0.0026 * weightScale(weight));
}

double textPointSizeForImage(QSize imagePx, MarkupFontSize size)
{
    const double shortSide = std::min(imagePx.width(), imagePx.height());
    return std::max(12.0, shortSide * 0.02 * fontScale(size));
}

QRectF MarkupItem::bounds() const
{
    if (kind == MarkupKind::Stroke) {
        if (points.isEmpty())
            return {};
        QRectF r(points.first(), QSizeF(0, 0));
        for (const QPointF& p : points)
            r = r.united(QRectF(p, QSizeF(0, 0)));
        return r;
    }
    if (kind == MarkupKind::Text)
        return QRectF(origin, QSizeF(0, 0));
    return boxFromCorners(start, end);
}

void MarkupItem::mapPoints(const std::function<QPointF(QPointF)>& fn)
{
    for (QPointF& p : points)
        p = fn(p);
    start = fn(start);
    end = fn(end);
    origin = fn(origin);
}

QPointF clamp01(QPointF p)
{
    return {std::clamp(p.x(), 0.0, 1.0), std::clamp(p.y(), 0.0, 1.0)};
}

QRectF clampNormalized(QRectF r)
{
    r = r.normalized();
    const double x = std::clamp(r.x(), 0.0, 1.0);
    const double y = std::clamp(r.y(), 0.0, 1.0);
    const double rgt = std::clamp(r.x() + r.width(), 0.0, 1.0);
    const double top = std::clamp(r.y() + r.height(), 0.0, 1.0);
    return QRectF(QPointF(x, y), QPointF(std::max(x, rgt), std::max(y, top)));
}

QPointF constrainAxis(QPointF start, QPointF end)
{
    const double dx = end.x() - start.x();
    const double dy = end.y() - start.y();
    const double length = std::hypot(dx, dy);
    if (length < 1e-5)
        return start;
    const double snapped = std::round(std::atan2(dy, dx) / (kPi / 4.0)) * (kPi / 4.0);
    return clamp01(QPointF(start.x() + std::cos(snapped) * length, start.y() + std::sin(snapped) * length));
}

QPointF constrainSquare(QPointF start, QPointF end)
{
    const double dx = end.x() - start.x();
    const double dy = end.y() - start.y();
    const double side = std::max(std::abs(dx), std::abs(dy));
    return clamp01(QPointF(start.x() + side * (dx < 0 ? -1 : 1), start.y() + side * (dy < 0 ? -1 : 1)));
}

QPointF normToView(QPointF n, const QRectF& imageRect)
{
    return {imageRect.x() + n.x() * imageRect.width(),
            imageRect.y() + (1.0 - n.y()) * imageRect.height()};
}

QPointF viewToNorm(QPointF v, const QRectF& imageRect)
{
    if (imageRect.width() < 1e-6 || imageRect.height() < 1e-6)
        return {};
    return clamp01({(v.x() - imageRect.x()) / imageRect.width(),
                    1.0 - (v.y() - imageRect.y()) / imageRect.height()});
}

QRectF fracToView(QRectF frac, const QRectF& imageRect)
{
    const QRectF box = frac.normalized();
    const double left = imageRect.x() + box.x() * imageRect.width();
    const double top = imageRect.y() + (1.0 - box.y() - box.height()) * imageRect.height();
    return QRectF(left, top, box.width() * imageRect.width(), box.height() * imageRect.height());
}

QRectF textViewBounds(const MarkupItem& item, const QRectF& imageRect, QSize imagePx)
{
    const double pt = textPointSizeForImage(imagePx, item.fontSize);
    QFont font;
    font.setPointSizeF(pt);
    font.setWeight(item.filled ? QFont::Medium : QFont::Normal);
    const QFontMetricsF fm(font);
    const QString shown = item.text.isEmpty() ? QStringLiteral(" ") : item.text;
    QRectF box = fm.boundingRect(shown);
    const QPointF origin = normToView(item.origin, imageRect);
    box.moveLeft(origin.x());
    box.moveBottom(origin.y());
    if (item.filled) {
        const double padX = std::max(6.0, fm.height() * 0.4);
        const double padY = std::max(3.0, fm.height() * 0.22);
        box.adjust(-padX, -padY, padX, padY);
    }
    return box;
}

static void drawArrow(QPainter& p, QPointF from, QPointF to, double line)
{
    const QLineF shaft(from, to);
    const double len = shaft.length();
    if (len < 0.5)
        return;
    const double head = std::max(line * 5.1, 7.0);
    const double angle = std::atan2(to.y() - from.y(), to.x() - from.x());
    const double wing = kPi * 0.17;
    const QPointF back(to.x() - std::cos(angle) * head * 0.68, to.y() - std::sin(angle) * head * 0.68);
    p.drawLine(from, back);
    QPainterPath headPath;
    headPath.moveTo(to);
    headPath.lineTo(QPointF(to.x() - std::cos(angle - wing) * head, to.y() - std::sin(angle - wing) * head));
    headPath.lineTo(QPointF(to.x() - std::cos(angle + wing) * head, to.y() - std::sin(angle + wing) * head));
    headPath.closeSubpath();
    p.fillPath(headPath, p.pen().color());
}

void drawMarkupItem(QPainter& p, const MarkupItem& item, const QRectF& imageRect, QSize imagePx,
                    bool selected)
{
    const double line = strokeWidthForImage(imagePx, item.weight);
    const QColor color = markupRgb(item.color);
    QPen pen(color, line);
    if (item.kind == MarkupKind::Rect || item.kind == MarkupKind::RoundRect) {
        pen.setCapStyle(Qt::FlatCap);
        pen.setJoinStyle(Qt::MiterJoin);
    } else {
        pen.setCapStyle(Qt::RoundCap);
        pen.setJoinStyle(Qt::RoundJoin);
    }
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);

    QPainterPath selectPath;

    switch (item.kind) {
    case MarkupKind::Stroke: {
        QVector<QPointF> pts;
        pts.reserve(item.points.size());
        for (const QPointF& n : item.points)
            pts << normToView(n, imageRect);
        if (pts.size() == 1) {
            p.setBrush(color);
            p.setPen(Qt::NoPen);
            p.drawEllipse(pts.first(), line / 2.0, line / 2.0);
            selectPath.addEllipse(pts.first(), line / 2.0, line / 2.0);
        } else {
            const QPainterPath path = strokePath(pts);
            p.drawPath(path);
            selectPath = path;
        }
        break;
    }
    case MarkupKind::Line: {
        const QPointF a = normToView(item.start, imageRect);
        const QPointF b = normToView(item.end, imageRect);
        p.drawLine(a, b);
        selectPath.moveTo(a);
        selectPath.lineTo(b);
        break;
    }
    case MarkupKind::Arrow: {
        const QPointF a = normToView(item.start, imageRect);
        const QPointF b = normToView(item.end, imageRect);
        drawArrow(p, a, b, line);
        selectPath.moveTo(a);
        selectPath.lineTo(b);
        break;
    }
    case MarkupKind::Rect:
    case MarkupKind::RoundRect:
    case MarkupKind::Oval:
    case MarkupKind::Highlight: {
        const QRectF box = viewBox(normToView(item.start, imageRect), normToView(item.end, imageRect));
        if (item.kind == MarkupKind::Highlight) {
            p.save();
            p.setCompositionMode(QPainter::CompositionMode_Multiply);
            QColor hi = color;
            hi.setAlphaF(0.4);
            p.setBrush(hi);
            p.setPen(Qt::NoPen);
            const double r = std::min(3.5, std::min(box.width(), box.height()) / 2.0);
            p.drawRoundedRect(box, r, r);
            p.restore();
            selectPath.addRoundedRect(box, r, r);
            break;
        }
        const double rr = std::min(std::max(std::min(box.width(), box.height()) * 0.12, 3.0), 14.0);
        QColor fill = color;
        fill.setAlphaF(0.9);
        if (item.kind == MarkupKind::Oval) {
            if (item.filled)
                p.setBrush(fill);
            p.drawEllipse(box);
            selectPath.addEllipse(box);
        } else if (item.kind == MarkupKind::RoundRect) {
            if (item.filled)
                p.setBrush(fill);
            p.drawRoundedRect(box, rr, rr);
            selectPath.addRoundedRect(box, rr, rr);
        } else {
            if (item.filled)
                p.setBrush(fill);
            p.drawRect(box);
            selectPath.addRect(box);
        }
        break;
    }
    case MarkupKind::Text: {
        const QRectF box = textViewBounds(item, imageRect, imagePx);
        const double pt = textPointSizeForImage(imagePx, item.fontSize);
        QFont font;
        font.setPointSizeF(pt);
        font.setWeight(item.filled ? QFont::Medium : QFont::Normal);
        p.setFont(font);
        if (item.filled) {
            const double rad = std::min(std::max(box.height(), 1.0) / 2.0, 18.0);
            p.setPen(Qt::NoPen);
            p.setBrush(color);
            p.drawRoundedRect(box, rad, rad);
            p.setPen(contrastingInk(item.color));
            p.drawText(box, Qt::AlignCenter, item.text);
        } else {
            p.setPen(QColor(0, 0, 0, 71));
            p.drawText(box.translated(0, 0.6), Qt::AlignLeft | Qt::AlignVCenter, item.text);
            p.setPen(color);
            p.drawText(box, Qt::AlignLeft | Qt::AlignVCenter, item.text);
        }
        selectPath.addRoundedRect(box.adjusted(-4, -4, 4, 4), 4, 4);
        break;
    }
    }

    if (selected) {
        paintSelection(p, selectPath, line);
        if (item.kind == MarkupKind::Line || item.kind == MarkupKind::Arrow) {
            paintKnob(p, normToView(item.start, imageRect), 3.4);
            paintKnob(p, normToView(item.end, imageRect), 3.4);
        } else if (item.kind == MarkupKind::Rect || item.kind == MarkupKind::RoundRect
                   || item.kind == MarkupKind::Oval || item.kind == MarkupKind::Highlight) {
            const QRectF box = viewBox(normToView(item.start, imageRect), normToView(item.end, imageRect));
            const QPointF knobs[] = {box.topLeft(), box.topRight(), box.bottomLeft(), box.bottomRight(),
                                     QPointF(box.center().x(), box.top()), QPointF(box.center().x(), box.bottom()),
                                     QPointF(box.left(), box.center().y()), QPointF(box.right(), box.center().y())};
            for (const QPointF& k : knobs)
                paintKnob(p, k, 3.4);
        } else if (item.kind == MarkupKind::Text) {
            paintKnob(p, textViewBounds(item, imageRect, imagePx).center(), 3.4);
        }
    }
}

void drawCropOverlay(QPainter& p, const QRectF& frac, const QRectF& imageRect, QSize imagePx)
{
    const QRectF box = fracToView(frac, imageRect);
    QPainterPath dim;
    dim.setFillRule(Qt::OddEvenFill);
    dim.addRect(imageRect);
    dim.addRect(box);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(0, 0, 0, 107));
    p.drawPath(dim);
    p.setBrush(Qt::NoBrush);
    p.setPen(QPen(QColor(255, 255, 255, 245), 1.15));
    p.drawRect(box);
    const QPointF knobs[] = {box.topLeft(), box.topRight(), box.bottomLeft(), box.bottomRight(),
                             QPointF(box.center().x(), box.top()), QPointF(box.center().x(), box.bottom()),
                             QPointF(box.left(), box.center().y()), QPointF(box.right(), box.center().y())};
    for (const QPointF& k : knobs)
        paintKnob(p, k, 3.6);

    const int pxW = std::max(1, int(std::lround(frac.normalized().width() * imagePx.width())));
    const int pxH = std::max(1, int(std::lround(frac.normalized().height() * imagePx.height())));
    const QString hud = QStringLiteral("%1 × %2").arg(pxW).arg(pxH);
    QFont font;
    font.setPointSize(10);
    font.setBold(true);
    p.setFont(font);
    const QFontMetricsF fm(font);
    QRectF pill = fm.boundingRect(hud).adjusted(-8, -3, 8, 3);
    pill.moveCenter(QPointF(box.center().x(), box.top() - 8 - pill.height() / 2.0));
    if (pill.top() < imageRect.top() + 2)
        pill.moveTop(box.top() + 6);
    pill.moveLeft(std::clamp(pill.x(), imageRect.left() + 2.0, imageRect.right() - pill.width() - 2.0));
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(0, 0, 0, 199));
    p.drawRoundedRect(pill, 5, 5);
    p.setPen(Qt::white);
    p.drawText(pill, Qt::AlignCenter, hud);
}

QString hitTestMarkup(const QVector<MarkupItem>& items, QPointF viewPt, const QRectF& imageRect,
                      QSize imagePx)
{
    for (int i = items.size() - 1; i >= 0; --i) {
        const MarkupItem& item = items.at(i);
        const double line = strokeWidthForImage(imagePx, item.weight);
        const double tol = line / 2.0;
        if (item.kind == MarkupKind::Text) {
            if (textViewBounds(item, imageRect, imagePx).adjusted(-4, -4, 4, 4).contains(viewPt))
                return item.id;
            continue;
        }
        if (item.kind == MarkupKind::Stroke) {
            QVector<QPointF> pts;
            for (const QPointF& n : item.points)
                pts << normToView(n, imageRect);
            if (pts.size() == 1 && QLineF(viewPt, pts.first()).length() <= std::max(tol, 3.0))
                return item.id;
            for (int k = 1; k < pts.size(); ++k) {
                if (distToSegment(viewPt, pts.at(k - 1), pts.at(k)) <= tol + 1.0)
                    return item.id;
            }
            continue;
        }
        if (item.kind == MarkupKind::Line || item.kind == MarkupKind::Arrow) {
            const QPointF a = normToView(item.start, imageRect);
            const QPointF b = normToView(item.end, imageRect);
            if (distToSegment(viewPt, a, b) <= tol + 2.0)
                return item.id;
            continue;
        }
        const QRectF box = viewBox(normToView(item.start, imageRect), normToView(item.end, imageRect));
        if (item.filled || item.kind == MarkupKind::Highlight) {
            if (box.adjusted(-tol, -tol, tol, tol).contains(viewPt))
                return item.id;
        } else {
            const QRectF outer = box.adjusted(-tol, -tol, tol, tol);
            const QRectF inner = box.adjusted(tol, tol, -tol, -tol);
            if (outer.contains(viewPt) && (inner.width() < 1 || inner.height() < 1 || !inner.contains(viewPt)))
                return item.id;
        }
    }
    return {};
}

MarkupHandle hitMarkupHandle(const MarkupItem& item, QPointF viewPt, const QRectF& imageRect,
                             QSize imagePx)
{
    auto near = [&](QPointF c) { return QLineF(viewPt, c).length() <= 10.0; };
    if (item.kind == MarkupKind::Line || item.kind == MarkupKind::Arrow) {
        if (near(normToView(item.start, imageRect)))
            return MarkupHandle::Start;
        if (near(normToView(item.end, imageRect)))
            return MarkupHandle::End;
        return MarkupHandle::None;
    }
    if (item.kind == MarkupKind::Rect || item.kind == MarkupKind::RoundRect || item.kind == MarkupKind::Oval
        || item.kind == MarkupKind::Highlight) {
        const QRectF box = viewBox(normToView(item.start, imageRect), normToView(item.end, imageRect));
        if (near(box.topLeft()))
            return MarkupHandle::NW;
        if (near(box.topRight()))
            return MarkupHandle::NE;
        if (near(box.bottomLeft()))
            return MarkupHandle::SW;
        if (near(box.bottomRight()))
            return MarkupHandle::SE;
        if (near(QPointF(box.center().x(), box.top())))
            return MarkupHandle::N;
        if (near(QPointF(box.center().x(), box.bottom())))
            return MarkupHandle::S;
        if (near(QPointF(box.left(), box.center().y())))
            return MarkupHandle::W;
        if (near(QPointF(box.right(), box.center().y())))
            return MarkupHandle::E;
    }
    Q_UNUSED(imagePx);
    return MarkupHandle::None;
}

MarkupHandle hitCropHandle(const QRectF& frac, QPointF viewPt, const QRectF& imageRect)
{
    const QRectF box = fracToView(frac, imageRect);
    auto near = [&](QPointF c) { return QLineF(viewPt, c).length() <= 11.0; };
    if (near(box.topLeft()))
        return MarkupHandle::NW;
    if (near(QPointF(box.center().x(), box.top())))
        return MarkupHandle::N;
    if (near(box.topRight()))
        return MarkupHandle::NE;
    if (near(QPointF(box.right(), box.center().y())))
        return MarkupHandle::E;
    if (near(box.bottomRight()))
        return MarkupHandle::SE;
    if (near(QPointF(box.center().x(), box.bottom())))
        return MarkupHandle::S;
    if (near(box.bottomLeft()))
        return MarkupHandle::SW;
    if (near(QPointF(box.left(), box.center().y())))
        return MarkupHandle::W;
    if (box.adjusted(-3, -3, 3, 3).contains(viewPt))
        return MarkupHandle::Body;
    return MarkupHandle::None;
}

QRectF resizedCrop(QRectF frac, MarkupHandle handle, QPointF normPt, bool square)
{
    QRectF box = frac.normalized();
    double minX = box.left(), maxX = box.right(), minY = box.top(), maxY = box.bottom();
    if (square && (handle == MarkupHandle::NE || handle == MarkupHandle::NW || handle == MarkupHandle::SE
                   || handle == MarkupHandle::SW)) {
        QPointF opp;
        if (handle == MarkupHandle::NE)
            opp = {minX, minY};
        else if (handle == MarkupHandle::NW)
            opp = {maxX, minY};
        else if (handle == MarkupHandle::SE)
            opp = {minX, maxY};
        else
            opp = {maxX, maxY};
        const QPointF end = constrainSquare(opp, normPt);
        return clampNormalized(QRectF(opp, end));
    }
    switch (handle) {
    case MarkupHandle::N:
    case MarkupHandle::NE:
    case MarkupHandle::NW:
        maxY = normPt.y();
        break;
    case MarkupHandle::S:
    case MarkupHandle::SE:
    case MarkupHandle::SW:
        minY = normPt.y();
        break;
    default:
        break;
    }
    switch (handle) {
    case MarkupHandle::E:
    case MarkupHandle::NE:
    case MarkupHandle::SE:
        maxX = normPt.x();
        break;
    case MarkupHandle::W:
    case MarkupHandle::NW:
    case MarkupHandle::SW:
        minX = normPt.x();
        break;
    default:
        break;
    }
    return clampNormalized(QRectF(QPointF(minX, minY), QPointF(maxX, maxY)));
}

QRectF translatedCrop(QRectF frac, QPointF delta)
{
    QRectF box = frac.normalized();
    double dx = delta.x();
    double dy = delta.y();
    if (box.left() + dx < 0)
        dx = -box.left();
    if (box.right() + dx > 1)
        dx = 1 - box.right();
    if (box.top() + dy < 0)
        dy = -box.top();
    if (box.bottom() + dy > 1)
        dy = 1 - box.bottom();
    return QRectF(box.topLeft() + QPointF(dx, dy), box.size());
}

void resizeMarkup(MarkupItem* item, MarkupHandle handle, QPointF normPt, bool shift)
{
    if (!item)
        return;
    if (item->kind == MarkupKind::Line || item->kind == MarkupKind::Arrow) {
        if (handle == MarkupHandle::Start)
            item->start = shift ? constrainAxis(item->end, normPt) : clamp01(normPt);
        else
            item->end = shift ? constrainAxis(item->start, normPt) : clamp01(normPt);
        return;
    }
    if (handle == MarkupHandle::Start)
        item->start = shift ? constrainSquare(item->end, normPt) : clamp01(normPt);
    else if (handle == MarkupHandle::End)
        item->end = shift ? constrainSquare(item->start, normPt) : clamp01(normPt);
    else {
        QRectF box = boxFromCorners(item->start, item->end);
        box = resizedCrop(box, handle, normPt, shift);
        item->start = box.topLeft();
        item->end = box.bottomRight();
    }
}

void translateMarkup(MarkupItem* item, QPointF delta)
{
    if (!item)
        return;
    QRectF b = item->bounds();
    if (item->kind == MarkupKind::Text)
        b = QRectF(item->origin, QSizeF(0.02, 0.02));
    double dx = delta.x();
    double dy = delta.y();
    if (b.left() + dx < 0)
        dx = -b.left();
    if (b.right() + dx > 1)
        dx = 1 - b.right();
    if (b.top() + dy < 0)
        dy = -b.top();
    if (b.bottom() + dy > 1)
        dy = 1 - b.bottom();
    const QPointF d(dx, dy);
    item->mapPoints([&](QPointF p) { return clamp01(p + d); });
}

QString newMarkupId()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

bool isMeaningfulShape(const MarkupItem& item)
{
    if (item.kind == MarkupKind::Stroke)
        return item.points.size() >= 2;
    if (item.kind == MarkupKind::Text)
        return !item.text.trimmed().isEmpty();
    const QPointF d = item.end - item.start;
    return QPointF::dotProduct(d, d) > 0.0002;
}
