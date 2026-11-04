#include "ToolIcons.h"

#include <QPainter>
#include <QPainterPath>
#include <QPixmap>

namespace {

QPixmap canvas(QSize size, QColor fill = Qt::transparent)
{
    QPixmap pm(size * 2);
    pm.setDevicePixelRatio(2);
    pm.fill(fill);
    return pm;
}

void beginPaint(QPainter& p, QPixmap& pm)
{
    p.begin(&pm);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.scale(pm.devicePixelRatio(), pm.devicePixelRatio());
}

QIcon fromPainter(const QPixmap& pm)
{
    return QIcon(pm);
}

} // namespace

namespace ToolIcons {

QIcon icon(const char* name, QSize size)
{
    QPixmap pm = canvas(size);
    QPainter p;
    beginPaint(p, pm);
    QPen pen(QColor(40, 40, 40), 1.4);
    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::RoundJoin);
    p.setPen(pen);
    p.setBrush(Qt::NoBrush);
    const QRectF r(1.5, 1.5, size.width() - 3.0, size.height() - 3.0);
    const QString key = QString::fromLatin1(name);

    auto chevron = [&](bool right) {
        const qreal cx = size.width() / 2.0;
        const qreal cy = size.height() / 2.0;
        const qreal dx = right ? 3.2 : -3.2;
        p.drawLine(QPointF(cx - dx, cy - 5), QPointF(cx + dx * 0.2, cy));
        p.drawLine(QPointF(cx + dx * 0.2, cy), QPointF(cx - dx, cy + 5));
    };

    if (key == QLatin1String("prev"))
        chevron(false);
    else if (key == QLatin1String("next"))
        chevron(true);
    else if (key == QLatin1String("zoomOut")) {
        p.drawEllipse(QRectF(3, 3, 10, 10));
        p.drawLine(QPointF(6.5, 8), QPointF(9.5, 8));
        p.drawLine(QPointF(12.2, 12.2), QPointF(15.5, 15.5));
    } else if (key == QLatin1String("zoomIn")) {
        p.drawEllipse(QRectF(3, 3, 10, 10));
        p.drawLine(QPointF(6.5, 8), QPointF(9.5, 8));
        p.drawLine(QPointF(8, 6.5), QPointF(8, 9.5));
        p.drawLine(QPointF(12.2, 12.2), QPointF(15.5, 15.5));
    } else if (key == QLatin1String("fit")) {
        p.drawLine(QPointF(3, 6), QPointF(3, 3));
        p.drawLine(QPointF(3, 3), QPointF(6, 3));
        p.drawLine(QPointF(15, 3), QPointF(12, 3));
        p.drawLine(QPointF(15, 3), QPointF(15, 6));
        p.drawLine(QPointF(3, 12), QPointF(3, 15));
        p.drawLine(QPointF(3, 15), QPointF(6, 15));
        p.drawLine(QPointF(15, 12), QPointF(15, 15));
        p.drawLine(QPointF(15, 15), QPointF(12, 15));
    } else if (key == QLatin1String("actual")) {
        p.drawRect(QRectF(4, 4, 10, 10));
    } else if (key == QLatin1String("rotateLeft") || key == QLatin1String("rotateRight")) {
        const bool left = key == QLatin1String("rotateLeft");
        QPainterPath arc;
        const QRectF arcR(3.5, 3.5, 11, 11);
        arc.arcMoveTo(arcR, left ? 40 : 140);
        arc.arcTo(arcR, left ? 40 : 140, left ? 220 : -220);
        p.drawPath(arc);
        const QPointF tip = left ? QPointF(4.2, 5.2) : QPointF(13.8, 5.2);
        p.setBrush(QColor(40, 40, 40));
        QPolygonF head;
        head << tip << (left ? QPointF(7.5, 3.2) : QPointF(10.5, 3.2))
             << (left ? QPointF(7.2, 7.4) : QPointF(10.8, 7.4));
        p.drawPolygon(head);
    } else if (key == QLatin1String("flipH")) {
        p.drawLine(QPointF(9, 3), QPointF(9, 15));
        p.drawLine(QPointF(4, 9), QPointF(8, 6));
        p.drawLine(QPointF(4, 9), QPointF(8, 12));
        p.drawLine(QPointF(14, 9), QPointF(10, 6));
        p.drawLine(QPointF(14, 9), QPointF(10, 12));
    } else if (key == QLatin1String("flipV")) {
        p.drawLine(QPointF(3, 9), QPointF(15, 9));
        p.drawLine(QPointF(9, 4), QPointF(6, 8));
        p.drawLine(QPointF(9, 4), QPointF(12, 8));
        p.drawLine(QPointF(9, 14), QPointF(6, 10));
        p.drawLine(QPointF(9, 14), QPointF(12, 10));
    } else if (key == QLatin1String("markup")) {
        p.drawEllipse(QRectF(3, 3, 12, 12));
        p.drawLine(QPointF(7, 12), QPointF(12, 6));
    } else if (key == QLatin1String("crop")) {
        p.drawRect(QRectF(5, 5, 8, 8));
        p.drawLine(QPointF(5, 3), QPointF(5, 15));
        p.drawLine(QPointF(3, 5), QPointF(15, 5));
    } else if (key == QLatin1String("adjustColor")) {
        p.drawLine(QPointF(4, 6), QPointF(14, 6));
        p.drawLine(QPointF(4, 9), QPointF(14, 9));
        p.drawLine(QPointF(4, 12), QPointF(14, 12));
        p.setBrush(QColor(40, 40, 40));
        p.drawEllipse(QPointF(8, 6), 1.4, 1.4);
        p.drawEllipse(QPointF(11, 9), 1.4, 1.4);
        p.drawEllipse(QPointF(7, 12), 1.4, 1.4);
    } else if (key == QLatin1String("adjustSize")) {
        p.drawRect(QRectF(4, 6, 7, 7));
        p.drawLine(QPointF(13, 4), QPointF(13, 8));
        p.drawLine(QPointF(11, 6), QPointF(15, 6));
    } else if (key == QLatin1String("inspector")) {
        p.drawEllipse(QRectF(3.5, 3.5, 11, 11));
        p.drawLine(QPointF(9, 8), QPointF(9, 13));
        p.setBrush(QColor(40, 40, 40));
        p.drawEllipse(QPointF(9, 6.4), 0.8, 0.8);
    } else if (key == QLatin1String("removeBg")) {
        p.drawEllipse(QRectF(5, 4, 8, 8));
        p.drawRect(QRectF(6.5, 11, 5, 3));
        p.setPen(QPen(QColor(40, 40, 40), 1.1, Qt::DashLine));
        p.drawRect(r);
    } else if (key == QLatin1String("more")) {
        p.drawLine(QPointF(5, 6), QPointF(8, 9));
        p.drawLine(QPointF(8, 9), QPointF(5, 12));
        p.drawLine(QPointF(9, 6), QPointF(12, 9));
        p.drawLine(QPointF(12, 9), QPointF(9, 12));
    } else if (key == QLatin1String("pen")) {
        p.drawLine(QPointF(5, 13), QPointF(12, 5));
        p.drawLine(QPointF(5, 13), QPointF(4, 15));
    } else if (key == QLatin1String("line")) {
        p.drawLine(QPointF(4, 13), QPointF(14, 5));
    } else if (key == QLatin1String("arrow")) {
        p.drawLine(QPointF(4, 13), QPointF(13, 6));
        p.drawLine(QPointF(13, 6), QPointF(9, 6.5));
        p.drawLine(QPointF(13, 6), QPointF(12.2, 10));
    } else if (key == QLatin1String("rect")) {
        p.drawRect(QRectF(4, 5, 10, 8));
    } else if (key == QLatin1String("roundRect")) {
        p.drawRoundedRect(QRectF(4, 5, 10, 8), 2.5, 2.5);
    } else if (key == QLatin1String("oval")) {
        p.drawEllipse(QRectF(4, 5, 10, 8));
    } else if (key == QLatin1String("highlight")) {
        p.setPen(QPen(QColor(255, 204, 0), 3.2, Qt::SolidLine, Qt::RoundCap));
        p.drawLine(QPointF(4, 12), QPointF(14, 6));
    } else if (key == QLatin1String("text")) {
        QFont f;
        f.setBold(true);
        f.setPixelSize(13);
        p.setFont(f);
        p.drawText(QRectF(0, 0, size.width(), size.height()), Qt::AlignCenter, QStringLiteral("A"));
    } else if (key == QLatin1String("fill")) {
        p.setBrush(QColor(40, 40, 40, 180));
        p.drawRect(QRectF(4, 5, 10, 8));
    } else if (key == QLatin1String("stroke")) {
        p.drawRect(QRectF(4, 5, 10, 8));
    } else if (key == QLatin1String("undo")) {
        p.drawArc(QRectF(4, 4, 10, 10), 40 * 16, 200 * 16);
        p.drawLine(QPointF(4.5, 6), QPointF(7, 3.5));
        p.drawLine(QPointF(4.5, 6), QPointF(7.2, 8));
    } else if (key == QLatin1String("save")) {
        p.drawRoundedRect(QRectF(4, 3.5, 10, 11), 1.2, 1.2);
        p.drawRect(QRectF(6.5, 3.5, 5, 4));
    } else if (key == QLatin1String("saveAs")) {
        p.drawRoundedRect(QRectF(3.5, 3.5, 9, 10), 1.2, 1.2);
        p.drawLine(QPointF(13, 10), QPointF(13, 15));
        p.drawLine(QPointF(11.5, 13.5), QPointF(13, 15));
        p.drawLine(QPointF(14.5, 13.5), QPointF(13, 15));
    } else if (key == QLatin1String("print")) {
        p.drawRect(QRectF(4, 8, 10, 6));
        p.drawRect(QRectF(6, 4, 6, 4));
        p.drawRect(QRectF(6, 11, 6, 3));
    } else if (key == QLatin1String("trash")) {
        p.drawRect(QRectF(6, 6, 6, 8));
        p.drawLine(QPointF(5, 6), QPointF(13, 6));
        p.drawLine(QPointF(7.5, 4.5), QPointF(10.5, 4.5));
    } else {
        p.drawRect(r);
    }
    p.end();
    return fromPainter(pm);
}

QIcon colorDot(MarkupColor color, bool selected)
{
    QPixmap pm = canvas(QSize(12, 12));
    QPainter p;
    beginPaint(p, pm);
    p.setBrush(markupRgb(color));
    p.setPen(selected ? QPen(QColor(30, 30, 30), 2) : QPen(QColor(0, 0, 0, 64), 0.5));
    p.drawEllipse(QRectF(1, 1, 10, 10));
    p.end();
    return fromPainter(pm);
}

QIcon weightSample(MarkupWeight weight, int length)
{
    QPixmap pm = canvas(QSize(length, 10));
    QPainter p;
    beginPaint(p, pm);
    QPen pen(QColor(40, 40, 40), weightSampleThickness(weight), Qt::SolidLine, Qt::RoundCap);
    p.setPen(pen);
    p.drawLine(QPointF(1, 5), QPointF(length - 1, 5));
    p.end();
    return fromPainter(pm);
}

QIcon fontSample(MarkupFontSize size)
{
    QPixmap pm = canvas(QSize(18, 18));
    QPainter p;
    beginPaint(p, pm);
    QFont f;
    f.setBold(true);
    f.setPointSizeF(fontSamplePointSize(size) * 0.7);
    p.setFont(f);
    p.setPen(QColor(40, 40, 40));
    p.drawText(QRectF(0, 0, 18, 18), Qt::AlignCenter, QStringLiteral("A"));
    p.end();
    return fromPainter(pm);
}

QIcon textBackground(bool on)
{
    QPixmap pm = canvas(QSize(22, 16));
    QPainter p;
    beginPaint(p, pm);
    if (on) {
        p.setBrush(QColor(255, 59, 48));
        p.setPen(Qt::NoPen);
        p.drawRoundedRect(QRectF(1, 1, 20, 14), 4, 4);
        p.setPen(Qt::white);
    } else {
        p.setPen(QColor(40, 40, 40));
    }
    QFont f;
    f.setBold(true);
    f.setPointSize(10);
    p.setFont(f);
    p.drawText(QRectF(0, 0, 22, 16), Qt::AlignCenter, QStringLiteral("A"));
    p.end();
    return fromPainter(pm);
}

} // namespace ToolIcons
