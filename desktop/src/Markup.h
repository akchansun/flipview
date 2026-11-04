#pragma once

#include <QColor>
#include <QPointF>
#include <QRectF>
#include <QSize>
#include <QString>
#include <QVector>
#include <functional>
#include <optional>

class QPainter;

enum class MarkupTool {
    Browse,
    Pen,
    Line,
    Arrow,
    Rect,
    RoundRect,
    Oval,
    Highlight,
    Text,
    Crop
};

enum class MarkupColor { Red, Orange, Yellow, Green, Blue, White, Black };
enum class MarkupWeight { Thin, Regular, Thick, Heavy };
enum class MarkupFontSize { Small, Regular, Large, Extra };
enum class MarkupKind { Stroke, Line, Arrow, Rect, RoundRect, Oval, Highlight, Text };

enum class MarkupHandle {
    None,
    Body,
    Start,
    End,
    N,
    NE,
    E,
    SE,
    S,
    SW,
    W,
    NW
};

bool isMarkupInk(MarkupTool tool);
bool toolCanFill(MarkupTool tool);
bool kindCanFill(MarkupKind kind);

QColor markupRgb(MarkupColor color);
QColor contrastingInk(MarkupColor color);
double weightScale(MarkupWeight weight);
double weightSampleThickness(MarkupWeight weight);
double fontScale(MarkupFontSize size);
double fontSamplePointSize(MarkupFontSize size);

double strokeWidthForImage(QSize imagePx, MarkupWeight weight);
double textPointSizeForImage(QSize imagePx, MarkupFontSize size);

struct MarkupItem {
    QString id;
    MarkupColor color = MarkupColor::Red;
    MarkupWeight weight = MarkupWeight::Regular;
    MarkupFontSize fontSize = MarkupFontSize::Regular;
    bool filled = false;
    MarkupKind kind = MarkupKind::Stroke;
    QVector<QPointF> points;
    QPointF start;
    QPointF end;
    QPointF origin;
    QString text;

    QRectF bounds() const;
    void mapPoints(const std::function<QPointF(QPointF)>& fn);
};

QPointF clamp01(QPointF p);
QRectF clampNormalized(QRectF r);
QPointF constrainAxis(QPointF start, QPointF end);
QPointF constrainSquare(QPointF start, QPointF end);

// Bottom-left normalized (0–1) ↔ Qt view (Y down) inside the drawn image rect.
QPointF normToView(QPointF n, const QRectF& imageRect);
QPointF viewToNorm(QPointF v, const QRectF& imageRect);
QRectF fracToView(QRectF frac, const QRectF& imageRect);

void drawMarkupItem(QPainter& p, const MarkupItem& item, const QRectF& imageRect, QSize imagePx,
                    bool selected);
void drawCropOverlay(QPainter& p, const QRectF& frac, const QRectF& imageRect, QSize imagePx);

QString hitTestMarkup(const QVector<MarkupItem>& items, QPointF viewPt, const QRectF& imageRect,
                      QSize imagePx);
MarkupHandle hitMarkupHandle(const MarkupItem& item, QPointF viewPt, const QRectF& imageRect,
                             QSize imagePx);
MarkupHandle hitCropHandle(const QRectF& frac, QPointF viewPt, const QRectF& imageRect);

QRectF resizedCrop(QRectF frac, MarkupHandle handle, QPointF normPt, bool square);
QRectF translatedCrop(QRectF frac, QPointF delta);

void resizeMarkup(MarkupItem* item, MarkupHandle handle, QPointF normPt, bool shift);
void translateMarkup(MarkupItem* item, QPointF delta);

QRectF textViewBounds(const MarkupItem& item, const QRectF& imageRect, QSize imagePx);

bool isMeaningfulShape(const MarkupItem& item);
QString newMarkupId();
