#pragma once

#include <QSettings>
#include <QString>

// QSettings keys under org XixiangfengTech / Flip (see AppInfo.h).
namespace LaunchSettings {

inline QString tipsDontShowKey()
{
    return QStringLiteral("tips/dontShowAgain");
}

// Consume-once: skip tips on the relaunch right after an in-place update
// (tips were already shown in the pre-update combined dialog).
inline QString tipsSkipOnceKey()
{
    return QStringLiteral("tips/skipOnce");
}

inline void setSkipStartupTipsOnce(QSettings& settings, bool skip = true)
{
    settings.setValue(tipsSkipOnceKey(), skip);
}

inline bool shouldShowStartupTips(QSettings& settings)
{
    if (settings.value(tipsSkipOnceKey(), false).toBool()) {
        settings.setValue(tipsSkipOnceKey(), false);
        settings.sync();
        return false;
    }
    return !settings.value(tipsDontShowKey(), false).toBool();
}

inline void setStartupTipsDontShow(QSettings& settings, bool dontShow = true)
{
    settings.setValue(tipsDontShowKey(), dontShow);
}

} // namespace LaunchSettings
