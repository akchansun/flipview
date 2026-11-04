#include "UpdateFeed.h"

#include "AppInfo.h"
#include "I18n.h"

#include <QByteArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtGlobal>
#include <QUrl>

namespace {
constexpr int kTimeoutMs = 6000;
} // namespace

bool parseLinuxRelease(const QByteArray& json, LinuxRelease* out)
{
    if (!out)
        return false;

    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(json, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject())
        return false;

    const QJsonObject linuxObj = doc.object().value(QStringLiteral("linux")).toObject();
    if (linuxObj.isEmpty())
        return false;

    LinuxRelease rel;
    rel.version = linuxObj.value(QStringLiteral("version")).toString().trimmed();
    if (rel.version.isEmpty())
        return false;

    const QJsonObject notes = linuxObj.value(QStringLiteral("notes")).toObject();
    rel.notesZh = notes.value(QStringLiteral("zh")).toString();
    rel.notesEn = notes.value(QStringLiteral("en")).toString();

    const QJsonObject download = linuxObj.value(QStringLiteral("download")).toObject();
    rel.downloadSite = download.value(QStringLiteral("site")).toString().trimmed();
    rel.downloadGitee = download.value(QStringLiteral("gitee")).toString().trimmed();
    rel.downloadGithub = download.value(QStringLiteral("github")).toString().trimmed();
    rel.giteeAsset = download.value(QStringLiteral("giteeAsset")).toString().trimmed();
    rel.githubAsset = download.value(QStringLiteral("githubAsset")).toString().trimmed();

    *out = rel;
    return true;
}

bool hasLinuxDownloadCandidate(const LinuxRelease& rel)
{
    return !rel.giteeAsset.trimmed().isEmpty()
        || !rel.githubAsset.trimmed().isEmpty()
        || !rel.downloadGitee.trimmed().isEmpty()
        || !rel.downloadGithub.trimmed().isEmpty()
        || !rel.downloadSite.trimmed().isEmpty();
}

QString releaseNotes(const LinuxRelease& rel)
{
    if (I18n::resolved() == I18n::Lang::ZhCN) {
        if (!rel.notesZh.isEmpty())
            return rel.notesZh;
        return rel.notesEn;
    }
    if (!rel.notesEn.isEmpty())
        return rel.notesEn;
    return rel.notesZh;
}

QUrl updateFeedUrl()
{
    const QByteArray env = qgetenv("FLIP_UPDATE_FEED");
    if (!env.isEmpty())
        return QUrl::fromUserInput(QString::fromUtf8(env));
    return QUrl(QStringLiteral(FLIP_UPDATE_FEED_URL));
}

int updateFeedTimeoutMs()
{
    return kTimeoutMs;
}
