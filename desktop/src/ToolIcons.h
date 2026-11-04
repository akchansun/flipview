#pragma once

#include "Markup.h"

#include <QIcon>
#include <QSize>

namespace ToolIcons {
QIcon icon(const char* name, QSize size = QSize(18, 18));
QIcon colorDot(MarkupColor color, bool selected);
QIcon weightSample(MarkupWeight weight, int length = 18);
QIcon fontSample(MarkupFontSize size);
QIcon textBackground(bool on);
}
