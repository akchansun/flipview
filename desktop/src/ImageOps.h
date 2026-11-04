#pragma once

#include "Markup.h"

#include <QImage>
#include <QRectF>
#include <QVector>

enum class ImageOpKind {
    RotateLeft,
    RotateRight,
    FlipHorizontal,
    FlipVertical,
    Crop,
    Resize,
    Color,
    RemoveBackground
};

struct ColorAdjust {
    double exposure = 0;
    double contrast = 1;
    double brightness = 0;
    double saturation = 1;
    double highlights = 1;
    double shadows = 0;
    double temperature = 0;
    double tint = 0;
    double sepia = 0;
    double sharpness = 0;
    bool autoLevels = false;

    bool isIdentity() const;
};

struct ImageOp {
    ImageOpKind kind = ImageOpKind::RotateLeft;
    QRectF crop; // bottom-left normalized
    int resizeW = 0;
    int resizeH = 0;
    ColorAdjust color;

    static ImageOp rotateLeft();
    static ImageOp rotateRight();
    static ImageOp flipHorizontal();
    static ImageOp flipVertical();
    static ImageOp cropFrac(const QRectF& frac);
    static ImageOp resizeTo(int w, int h);
    static ImageOp colorAdjust(const ColorAdjust& c);
    static ImageOp removeBackground();
};

QImage applyOp(const QImage& src, const ImageOp& op);
QImage applyOps(const QImage& src, const QVector<ImageOp>& ops);
QImage bakeMarkup(const QImage& src, const QVector<MarkupItem>& items);
void transformMarkup(QVector<MarkupItem>& items, const ImageOp& op);

QImage loadDisplayImage(const QString& path, int maxLongEdge = 0);
QImage loadFullImage(const QString& path);
