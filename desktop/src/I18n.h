#pragma once

#include <QString>

namespace I18n {

enum class Lang { Auto, ZhCN, En };

void setLang(Lang lang);
Lang lang();
Lang resolved();
QString t(const char* key);

} // namespace I18n
