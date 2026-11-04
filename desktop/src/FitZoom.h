#pragma once

#include <QSize>
#include <algorithm>

// Default zoom: images smaller than the viewport stay at 100%;
// larger images scale down to fit. Never upscale by default.
inline double defaultFitScale(QSize image, QSize viewport)
{
    if (image.width() <= 0 || image.height() <= 0)
        return 1.0;
    if (viewport.width() <= 0 || viewport.height() <= 0)
        return 1.0;
    if (image.width() <= viewport.width() && image.height() <= viewport.height())
        return 1.0;
    const double sx = double(viewport.width()) / double(image.width());
    const double sy = double(viewport.height()) / double(image.height());
    return std::min(sx, sy);
}
