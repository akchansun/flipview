#pragma once

#include "UpdateFeed.h"

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>

class QNetworkAccessManager;
class QNetworkReply;

// Asset URLs used for the Gitee vs GitHub TTFB race (empty entries omitted).
QStringList linuxAssetRaceUrls(const LinuxRelease& rel);

// HTTP 2xx/3xx (including 206 Partial Content) count as a live mirror.
bool probeHttpStatusOk(int status);

// Unique order: race winner, then the other direct asset (no pages / site).
QStringList rankedAssetUrlChain(const LinuxRelease& rel, const QString& winner);

// Unique order: race winner, other asset, release pages, product site.
QStringList updateOpenUrlChain(const LinuxRelease& rel, const QString& winner);

int downloadProbeTimeoutMs();

// Parallel HEAD (then ranged GET if HEAD is rejected) of giteeAsset vs githubAsset.
// Emits the first successful asset URL. If both fail or assets are missing, emits
// empty; the caller then opens the other asset, release pages, and the site.
class DownloadRacer final : public QObject
{
    Q_OBJECT

public:
    explicit DownloadRacer(QObject* parent = nullptr);
    ~DownloadRacer() override;
    void start(const LinuxRelease& rel);

signals:
    void finished(const QString& url);

private slots:
    void onMetaDataChanged();
    void onReplyFinished();

private:
    struct Probe {
        QString url;
        QNetworkReply* reply = nullptr;
        bool triedRangedGet = false;
    };

    void armWatchdog();
    void beginProbe(const QString& url, bool rangedGet);
    void retryWithRangedGet(Probe* probe);
    Probe* probeFor(QNetworkReply* reply);
    void settle(const QString& url);
    void abortAll();

    QNetworkAccessManager* m_nam = nullptr;
    QList<Probe> m_probes;
    bool m_settled = false;
};
