#include "ImageOps.h"

#include <QImageReader>
#include <QPainter>
#include <QtMath>
#include <algorithm>
#include <cmath>
#include <vector>

namespace {

QImage toArgb(const QImage& src)
{
    return src.convertToFormat(QImage::Format_ARGB32);
}

void autoLevelPixels(QImage& img)
{
    const int n = img.width() * img.height();
    if (n <= 0)
        return;
    std::vector<int> hr(256, 0), hg(256, 0), hb(256, 0);
    for (int y = 0; y < img.height(); ++y) {
        const QRgb* line = reinterpret_cast<const QRgb*>(img.constScanLine(y));
        for (int x = 0; x < img.width(); ++x) {
            const QRgb p = line[x];
            hr[qRed(p)]++;
            hg[qGreen(p)]++;
            hb[qBlue(p)]++;
        }
    }
    auto stretch = [n](const std::vector<int>& h, int* lo, int* hi) {
        const int cut = std::max(1, n / 100);
        int acc = 0;
        *lo = 0;
        for (int i = 0; i < 256; ++i) {
            acc += h[i];
            if (acc >= cut) {
                *lo = i;
                break;
            }
        }
        acc = 0;
        *hi = 255;
        for (int i = 255; i >= 0; --i) {
            acc += h[i];
            if (acc >= cut) {
                *hi = i;
                break;
            }
        }
        if (*hi <= *lo)
            *hi = *lo + 1;
    };
    int r0, r1, g0, g1, b0, b1;
    stretch(hr, &r0, &r1);
    stretch(hg, &g0, &g1);
    stretch(hb, &b0, &b1);
    auto map = [](int v, int lo, int hi) {
        return std::clamp(int(std::lround((v - lo) * 255.0 / (hi - lo))), 0, 255);
    };
    for (int y = 0; y < img.height(); ++y) {
        QRgb* line = reinterpret_cast<QRgb*>(img.scanLine(y));
        for (int x = 0; x < img.width(); ++x) {
            const QRgb p = line[x];
            line[x] = qRgba(map(qRed(p), r0, r1), map(qGreen(p), g0, g1), map(qBlue(p), b0, b1), qAlpha(p));
        }
    }
}

QImage applyColor(const QImage& src, const ColorAdjust& c)
{
    if (c.isIdentity())
        return src;
    QImage img = toArgb(src);
    if (c.autoLevels)
        autoLevelPixels(img);

    const double expMul = std::pow(2.0, c.exposure);
    const double temp = c.temperature;
    const double tint = c.tint;
    for (int y = 0; y < img.height(); ++y) {
        QRgb* line = reinterpret_cast<QRgb*>(img.scanLine(y));
        for (int x = 0; x < img.width(); ++x) {
            const QRgb p = line[x];
            double r = qRed(p) / 255.0;
            double g = qGreen(p) / 255.0;
            double b = qBlue(p) / 255.0;
            r *= expMul;
            g *= expMul;
            b *= expMul;
            r = (r - 0.5) * c.contrast + 0.5 + c.brightness;
            g = (g - 0.5) * c.contrast + 0.5 + c.brightness;
            b = (b - 0.5) * c.contrast + 0.5 + c.brightness;
            const double gray = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            r = gray + (r - gray) * c.saturation;
            g = gray + (g - gray) * c.saturation;
            b = gray + (b - gray) * c.saturation;
            const double lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            if (lum > 0.5) {
                r = lum + (r - lum) * c.highlights;
                g = lum + (g - lum) * c.highlights;
                b = lum + (b - lum) * c.highlights;
            } else {
                const double sh = 1.0 + c.shadows;
                r = lum + (r - lum) * sh;
                g = lum + (g - lum) * sh;
                b = lum + (b - lum) * sh;
            }
            r += temp * 0.08;
            b -= temp * 0.08;
            g += tint * 0.06;
            if (c.sepia > 0) {
                const double sr = (r * 0.393 + g * 0.769 + b * 0.189);
                const double sg = (r * 0.349 + g * 0.686 + b * 0.168);
                const double sb = (r * 0.272 + g * 0.534 + b * 0.131);
                r = r + (sr - r) * c.sepia;
                g = g + (sg - g) * c.sepia;
                b = b + (sb - b) * c.sepia;
            }
            auto sat = [](double v) { return std::clamp(int(std::lround(v * 255.0)), 0, 255); };
            line[x] = qRgba(sat(r), sat(g), sat(b), qAlpha(p));
        }
    }

    if (c.sharpness > 0.001) {
        QImage blur = img.scaled(std::max(1, img.width() / 2), std::max(1, img.height() / 2),
                                 Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                          .scaled(img.size(), Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
        const double amt = std::clamp(c.sharpness, 0.0, 2.0);
        for (int y = 0; y < img.height(); ++y) {
            QRgb* line = reinterpret_cast<QRgb*>(img.scanLine(y));
            const QRgb* bLine = reinterpret_cast<const QRgb*>(blur.constScanLine(y));
            for (int x = 0; x < img.width(); ++x) {
                const QRgb p = line[x];
                const QRgb q = bLine[x];
                auto ch = [&](int a, int b) {
                    return std::clamp(int(std::lround(a + (a - b) * amt)), 0, 255);
                };
                line[x] = qRgba(ch(qRed(p), qRed(q)), ch(qGreen(p), qGreen(q)), ch(qBlue(p), qBlue(q)),
                                qAlpha(p));
            }
        }
    }
    return img;
}

QImage cropImage(const QImage& src, const QRectF& frac)
{
    const QRectF box = frac.normalized();
    const int w = src.width();
    const int h = src.height();
    const int x = std::clamp(int(std::floor(box.x() * w)), 0, w - 1);
    // BL frac → top-left bitmap: pixelY = (1 - maxY) * height
    const double maxY = box.y() + box.height();
    const int y = std::clamp(int(std::floor((1.0 - maxY) * h)), 0, h - 1);
    const int cw = std::clamp(int(std::ceil(box.width() * w)), 1, w - x);
    const int ch = std::clamp(int(std::ceil(box.height() * h)), 1, h - y);
    return src.copy(x, y, cw, ch);
}

QImage removeBg(const QImage& src)
{
    QImage img = toArgb(src);
    if (img.width() < 2 || img.height() < 2)
        return img;
    const QRgb c0 = img.pixel(0, 0);
    const QRgb c1 = img.pixel(img.width() - 1, 0);
    const QRgb c2 = img.pixel(0, img.height() - 1);
    const QRgb c3 = img.pixel(img.width() - 1, img.height() - 1);
    const int sr = (qRed(c0) + qRed(c1) + qRed(c2) + qRed(c3)) / 4;
    const int sg = (qGreen(c0) + qGreen(c1) + qGreen(c2) + qGreen(c3)) / 4;
    const int sb = (qBlue(c0) + qBlue(c1) + qBlue(c2) + qBlue(c3)) / 4;
    for (int y = 0; y < img.height(); ++y) {
        QRgb* line = reinterpret_cast<QRgb*>(img.scanLine(y));
        for (int x = 0; x < img.width(); ++x) {
            const QRgb p = line[x];
            const int d = std::abs(qRed(p) - sr) + std::abs(qGreen(p) - sg) + std::abs(qBlue(p) - sb);
            if (d < 48)
                line[x] = qRgba(qRed(p), qGreen(p), qBlue(p), 0);
        }
    }
    return img;
}

QImage readScaled(const QString& path, int maxLongEdge)
{
    QImageReader reader(path);
    reader.setAutoTransform(true);
    const QSize sz = reader.size();
    if (maxLongEdge > 0 && sz.isValid()) {
        const int longEdge = std::max(sz.width(), sz.height());
        if (longEdge > maxLongEdge) {
            const double s = double(maxLongEdge) / double(longEdge);
            reader.setScaledSize(QSize(std::max(1, int(sz.width() * s)), std::max(1, int(sz.height() * s))));
        }
    }
    return reader.read();
}

} // namespace

bool ColorAdjust::isIdentity() const
{
    return std::abs(exposure) < 1e-6 && std::abs(contrast - 1) < 1e-6 && std::abs(brightness) < 1e-6
        && std::abs(saturation - 1) < 1e-6 && std::abs(highlights - 1) < 1e-6 && std::abs(shadows) < 1e-6
        && std::abs(temperature) < 1e-6 && std::abs(tint) < 1e-6 && std::abs(sepia) < 1e-6
        && std::abs(sharpness) < 1e-6 && !autoLevels;
}

ImageOp ImageOp::rotateLeft()
{
    ImageOp o;
    o.kind = ImageOpKind::RotateLeft;
    return o;
}
ImageOp ImageOp::rotateRight()
{
    ImageOp o;
    o.kind = ImageOpKind::RotateRight;
    return o;
}
ImageOp ImageOp::flipHorizontal()
{
    ImageOp o;
    o.kind = ImageOpKind::FlipHorizontal;
    return o;
}
ImageOp ImageOp::flipVertical()
{
    ImageOp o;
    o.kind = ImageOpKind::FlipVertical;
    return o;
}
ImageOp ImageOp::cropFrac(const QRectF& frac)
{
    ImageOp o;
    o.kind = ImageOpKind::Crop;
    o.crop = frac;
    return o;
}
ImageOp ImageOp::resizeTo(int w, int h)
{
    ImageOp o;
    o.kind = ImageOpKind::Resize;
    o.resizeW = w;
    o.resizeH = h;
    return o;
}
ImageOp ImageOp::colorAdjust(const ColorAdjust& c)
{
    ImageOp o;
    o.kind = ImageOpKind::Color;
    o.color = c;
    return o;
}
ImageOp ImageOp::removeBackground()
{
    ImageOp o;
    o.kind = ImageOpKind::RemoveBackground;
    return o;
}

QImage applyOp(const QImage& src, const ImageOp& op)
{
    switch (op.kind) {
    case ImageOpKind::RotateLeft:
        return src.transformed(QTransform().rotate(-90));
    case ImageOpKind::RotateRight:
        return src.transformed(QTransform().rotate(90));
    case ImageOpKind::FlipHorizontal:
        return src.mirrored(true, false);
    case ImageOpKind::FlipVertical:
        return src.mirrored(false, true);
    case ImageOpKind::Crop:
        return cropImage(src, op.crop);
    case ImageOpKind::Resize:
        return src.scaled(std::max(1, op.resizeW), std::max(1, op.resizeH), Qt::IgnoreAspectRatio,
                          Qt::SmoothTransformation);
    case ImageOpKind::Color:
        return applyColor(src, op.color);
    case ImageOpKind::RemoveBackground:
        return removeBg(src);
    }
    return src;
}

QImage applyOps(const QImage& src, const QVector<ImageOp>& ops)
{
    QImage out = src;
    for (const ImageOp& op : ops)
        out = applyOp(out, op);
    return out;
}

QImage bakeMarkup(const QImage& src, const QVector<MarkupItem>& items)
{
    QImage out = toArgb(src);
    QPainter p(&out);
    p.setRenderHint(QPainter::Antialiasing, true);
    const QRectF rect(0, 0, out.width(), out.height());
    for (const MarkupItem& item : items)
        drawMarkupItem(p, item, rect, out.size(), false);
    return out;
}

void transformMarkup(QVector<MarkupItem>& items, const ImageOp& op)
{
    auto map = [&](QPointF p) -> QPointF {
        switch (op.kind) {
        case ImageOpKind::RotateRight:
            return {p.y(), 1 - p.x()};
        case ImageOpKind::RotateLeft:
            return {1 - p.y(), p.x()};
        case ImageOpKind::FlipHorizontal:
            return {1 - p.x(), p.y()};
        case ImageOpKind::FlipVertical:
            return {p.x(), 1 - p.y()};
        case ImageOpKind::Crop: {
            const QRectF box = op.crop.normalized();
            const double w = std::max(box.width(), 0.0001);
            const double h = std::max(box.height(), 0.0001);
            return {(p.x() - box.x()) / w, (p.y() - box.y()) / h};
        }
        default:
            return p;
        }
    };
    for (MarkupItem& item : items)
        item.mapPoints(map);
}

QImage loadDisplayImage(const QString& path, int maxLongEdge)
{
    if (maxLongEdge <= 0)
        maxLongEdge = 4096;
    return readScaled(path, maxLongEdge);
}

QImage loadFullImage(const QString& path)
{
    return readScaled(path, 0);
}
