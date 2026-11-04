#include "DownloadRace.h"

#include "AppInfo.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>

namespace {
constexpr int kProbeTimeoutMs = 2500;

QNetworkRequest probeRequest(const QString& url, bool rangedGet)
{
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader,
                  QStringLiteral("Flip/%1").arg(QStringLiteral(FLIP_VERSION)));
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
    req.setTransferTimeout(kProbeTimeoutMs);
#endif
    if (rangedGet)
        req.setRawHeader("Range", "bytes=0-0");
    return req;
}

int httpStatus(QNetworkReply* reply)
{
    return reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
}

bool headWasRejected(QNetworkReply* reply)
{
    if (reply->operation() != QNetworkAccessManager::HeadOperation)
        return false;
    const int status = httpStatus(reply);
    return status == 405 || status == 501
        || reply->error() == QNetworkReply::ContentOperationNotPermittedError;
}
} // namespace

QStringList linuxAssetRaceUrls(const LinuxRelease& rel)
{
    QStringList urls;
    const QString gitee = rel.giteeAsset.trimmed();
    const QString github = rel.githubAsset.trimmed();
    if (!gitee.isEmpty())
        urls << gitee;
    if (!github.isEmpty() && github != gitee)
        urls << github;
    return urls;
}

bool probeHttpStatusOk(int status)
{
    return status >= 200 && status < 400;
}

QStringList rankedAssetUrlChain(const LinuxRelease& rel, const QString& winner)
{
    QStringList out;
    const auto add = [&out](const QString& url) {
        if (url.isEmpty() || out.contains(url))
            return;
        out << url;
    };
    add(winner.trimmed());
    add(rel.giteeAsset.trimmed());
    add(rel.githubAsset.trimmed());
    return out;
}

QStringList updateOpenUrlChain(const LinuxRelease& rel, const QString& winner)
{
    QStringList out;
    const auto add = [&out](const QString& url) {
        if (url.isEmpty() || out.contains(url))
            return;
        out << url;
    };
    add(winner.trimmed());
    add(rel.giteeAsset.trimmed());
    add(rel.githubAsset.trimmed());
    add(rel.downloadGitee.trimmed());
    add(rel.downloadGithub.trimmed());
    add(rel.downloadSite.trimmed());
    return out;
}

int downloadProbeTimeoutMs()
{
    return kProbeTimeoutMs;
}

DownloadRacer::DownloadRacer(QObject* parent)
    : QObject(parent)
{
}

DownloadRacer::~DownloadRacer()
{
    m_settled = true;
    abortAll();
}

void DownloadRacer::start(const LinuxRelease& rel)
{
    const QStringList assets = linuxAssetRaceUrls(rel);
    if (assets.isEmpty()) {
        settle(QString());
        return;
    }

    m_nam = new QNetworkAccessManager(this);
    for (const QString& url : assets)
        beginProbe(url, false);
    armWatchdog();
}

void DownloadRacer::beginProbe(const QString& url, bool rangedGet)
{
    Probe* probe = nullptr;
    for (Probe& p : m_probes) {
        if (p.url == url) {
            probe = &p;
            break;
        }
    }
    if (!probe) {
        m_probes.push_back(Probe{url, nullptr, rangedGet});
        probe = &m_probes.last();
    }
    probe->triedRangedGet = rangedGet;

    const QNetworkRequest req = probeRequest(url, rangedGet);
    QNetworkReply* reply = rangedGet ? m_nam->get(req) : m_nam->head(req);
    probe->reply = reply;
    connect(reply, &QNetworkReply::metaDataChanged, this, &DownloadRacer::onMetaDataChanged);
    connect(reply, &QNetworkReply::finished, this, &DownloadRacer::onReplyFinished);
}

void DownloadRacer::retryWithRangedGet(Probe* probe)
{
    if (!probe || probe->triedRangedGet)
        return;
    if (probe->reply) {
        probe->reply->disconnect(this);
        probe->reply->deleteLater();
        probe->reply = nullptr;
    }
    beginProbe(probe->url, true);
}

void DownloadRacer::armWatchdog()
{
    auto* watchdog = new QTimer(this);
    watchdog->setSingleShot(true);
    connect(watchdog, &QTimer::timeout, this, [this] {
        if (m_settled)
            return;
        abortAll();
        settle(QString());
    });
    watchdog->start(kProbeTimeoutMs);
}

DownloadRacer::Probe* DownloadRacer::probeFor(QNetworkReply* reply)
{
    for (Probe& p : m_probes) {
        if (p.reply == reply)
            return &p;
    }
    return nullptr;
}

void DownloadRacer::onMetaDataChanged()
{
    if (m_settled)
        return;
    auto* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply)
        return;
    const int status = httpStatus(reply);
    if (headWasRejected(reply))
        return;
    if (!probeHttpStatusOk(status))
        return;
    Probe* probe = probeFor(reply);
    settle(probe ? probe->url : reply->url().toString());
}

void DownloadRacer::onReplyFinished()
{
    if (m_settled)
        return;
    auto* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply)
        return;

    Probe* probe = probeFor(reply);
    if (headWasRejected(reply) && probe && !probe->triedRangedGet) {
        retryWithRangedGet(probe);
        return;
    }

    const int status = httpStatus(reply);
    if (reply->error() == QNetworkReply::NoError && probeHttpStatusOk(status)) {
        settle(probe ? probe->url : reply->url().toString());
        return;
    }

    int pending = 0;
    for (const Probe& p : m_probes) {
        if (p.reply && p.reply->isRunning())
            ++pending;
    }
    if (pending == 0)
        settle(QString());
}

void DownloadRacer::settle(const QString& url)
{
    if (m_settled)
        return;
    m_settled = true;
    abortAll();
    emit finished(url);
    deleteLater();
}

void DownloadRacer::abortAll()
{
    for (Probe& p : m_probes) {
        if (!p.reply)
            continue;
        p.reply->disconnect(this);
        if (p.reply->isRunning())
            p.reply->abort();
        p.reply->deleteLater();
        p.reply = nullptr;
    }
}
