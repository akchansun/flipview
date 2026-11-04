#include "LaunchPrompts.h"

#include "AppInfo.h"
#include "DownloadRace.h"
#include "I18n.h"
#include "InPlaceUpdater.h"
#include "LaunchSettings.h"
#include "UpdateFeed.h"
#include "VersionCompare.h"

#include <QApplication>
#include <QCheckBox>
#include <QDesktopServices>
#include <QDialog>
#include <QDialogButtonBox>
#include <QFrame>
#include <QLabel>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>
#include <QPushButton>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QVBoxLayout>
#include <QWidget>

namespace {

enum class CombinedChoice { None, GotIt, UpdateNow, Later, DontUpdate };

void openDownloadFallback(const QStringList& urls)
{
    for (const QString& url : urls) {
        if (url.isEmpty())
            continue;
        if (QDesktopServices::openUrl(QUrl(url)))
            return;
    }
}

void beginInPlaceUpdate(QWidget* parent, const LinuxRelease& rel, const QString& winner)
{
    const QStringList assets = rankedAssetUrlChain(rel, winner);
    const QStringList opens = updateOpenUrlChain(rel, winner);
    if (assets.isEmpty()) {
        openDownloadFallback(opens);
        return;
    }
    // Tips already shown in this dialog; don't show again after relaunch.
    QSettings settings;
    LaunchSettings::setSkipStartupTipsOnce(settings, true);
    settings.sync();
    InPlaceUpdater::start(parent, assets, opens);
}

} // namespace

class UpdateChecker final : public QObject
{
    Q_OBJECT

public:
    explicit UpdateChecker(QWidget* parentWindow)
        : QObject(parentWindow)
        , m_window(parentWindow)
    {
    }

    void start()
    {
        const QUrl url = updateFeedUrl();
        if (!url.isValid()) {
            deliver(LinuxRelease{}, false);
            return;
        }

        auto* nam = new QNetworkAccessManager(this);
        QNetworkRequest req(url);
        req.setHeader(QNetworkRequest::UserAgentHeader,
                      QStringLiteral("Flip/%1 (Linux)").arg(QStringLiteral(FLIP_VERSION)));
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
        req.setTransferTimeout(updateFeedTimeoutMs());
#endif

        m_reply = nam->get(req);
        connect(m_reply, &QNetworkReply::finished, this, &UpdateChecker::onFinished);

        auto* watchdog = new QTimer(this);
        watchdog->setSingleShot(true);
        connect(watchdog, &QTimer::timeout, this, [this] {
            if (m_reply)
                m_reply->abort();
        });
        watchdog->start(updateFeedTimeoutMs());
    }

    void deliver(const LinuxRelease& rel, bool hasNewer)
    {
        QWidget* window = m_window;
        if (window) {
            QTimer::singleShot(0, window, [window, rel, hasNewer] {
                presentCombinedLaunchDialog(window, rel, hasNewer);
            });
        }
        deleteLater();
    }

private slots:
    void onFinished()
    {
        QNetworkReply* reply = m_reply;
        m_reply = nullptr;
        if (!reply) {
            deliver(LinuxRelease{}, false);
            return;
        }

        const QNetworkReply::NetworkError error = reply->error();
        const QByteArray payload = (error == QNetworkReply::NoError) ? reply->readAll() : QByteArray();
        reply->deleteLater();

        LinuxRelease rel;
        const bool ok = error == QNetworkReply::NoError && parseLinuxRelease(payload, &rel)
            && isNewerVersion(rel.version, QStringLiteral(FLIP_VERSION))
            && hasLinuxDownloadCandidate(rel);
        deliver(ok ? rel : LinuxRelease{}, ok);
    }

private:
    QPointer<QWidget> m_window;
    QNetworkReply* m_reply = nullptr;
};

void presentCombinedLaunchDialog(QWidget* parent, const LinuxRelease& rel, bool showUpdate)
{
    QSettings settings;
    const bool showTips = LaunchSettings::shouldShowStartupTips(settings);
    showUpdate = showUpdate && !rel.version.isEmpty();
    if (!showTips && !showUpdate)
        return;

    QDialog dialog(parent);
    if (showTips && showUpdate)
        dialog.setWindowTitle(I18n::t("launch.combinedTitle"));
    else if (showUpdate)
        dialog.setWindowTitle(I18n::t("update.title"));
    else
        dialog.setWindowTitle(I18n::t("tips.title"));
    dialog.setModal(true);
    dialog.setMinimumWidth(500);

    auto* layout = new QVBoxLayout(&dialog);
    layout->setContentsMargins(20, 16, 20, 12);
    layout->setSpacing(12);

    if (showTips) {
        auto* tips = new QLabel(I18n::t("tips.body"), &dialog);
        tips->setTextFormat(Qt::RichText);
        tips->setWordWrap(true);
        tips->setTextInteractionFlags(Qt::TextSelectableByMouse);
        tips->setMinimumWidth(460);
        layout->addWidget(tips);
    }

    if (showTips && showUpdate) {
        auto* line = new QFrame(&dialog);
        line->setFrameShape(QFrame::HLine);
        line->setFrameShadow(QFrame::Sunken);
        layout->addWidget(line);
    }

    if (showUpdate) {
        const QString notes =
            releaseNotes(rel).toHtmlEscaped().replace(QLatin1Char('\n'), QStringLiteral("<br>"));
        auto* update = new QLabel(
            I18n::t("update.body").arg(QStringLiteral(FLIP_VERSION), rel.version, notes), &dialog);
        update->setTextFormat(Qt::RichText);
        update->setWordWrap(true);
        update->setTextInteractionFlags(Qt::TextSelectableByMouse);
        update->setMinimumWidth(460);
        layout->addWidget(update);
    }

    QCheckBox* dontShowTips = nullptr;
    if (showTips) {
        dontShowTips = new QCheckBox(I18n::t("tips.dontShow"), &dialog);
        layout->addWidget(dontShowTips);
    }

    auto* buttons = new QDialogButtonBox(&dialog);
    QPushButton* goBtn = nullptr;
    QPushButton* laterBtn = nullptr;
    QPushButton* dontBtn = nullptr;
    QPushButton* okBtn = nullptr;
    if (showUpdate) {
        dontBtn = buttons->addButton(I18n::t("update.dont"), QDialogButtonBox::ResetRole);
        laterBtn = buttons->addButton(I18n::t("update.later"), QDialogButtonBox::RejectRole);
        goBtn = buttons->addButton(I18n::t("update.go"), QDialogButtonBox::AcceptRole);
        goBtn->setDefault(true);
        goBtn->setFocus();
    } else {
        okBtn = buttons->addButton(I18n::t("tips.ok"), QDialogButtonBox::AcceptRole);
        okBtn->setDefault(true);
        okBtn->setFocus();
    }
    layout->addWidget(buttons);

    CombinedChoice choice = CombinedChoice::None;
    QString winner;
    bool raceDone = true;
    DownloadRacer* racer = nullptr;
    if (showUpdate && !linuxAssetRaceUrls(rel).isEmpty()) {
        raceDone = false;
        racer = new DownloadRacer(&dialog);
        QObject::connect(racer, &DownloadRacer::finished, &dialog, [&](const QString& url) {
            winner = url;
            raceDone = true;
        });
        racer->start(rel);
    }

    QObject::connect(&dialog, &QDialog::finished, &dialog, [] {
        QApplication::restoreOverrideCursor();
    });

    if (okBtn) {
        QObject::connect(okBtn, &QPushButton::clicked, &dialog, [&] {
            choice = CombinedChoice::GotIt;
            dialog.accept();
        });
    }
    if (laterBtn) {
        QObject::connect(laterBtn, &QPushButton::clicked, &dialog, [&] {
            choice = CombinedChoice::Later;
            dialog.reject();
        });
    }
    if (dontBtn) {
        QObject::connect(dontBtn, &QPushButton::clicked, &dialog, [&] {
            choice = CombinedChoice::DontUpdate;
            dialog.reject();
        });
    }
    if (goBtn) {
        QObject::connect(goBtn, &QPushButton::clicked, &dialog, [&] {
            auto finishGo = [&] {
                choice = CombinedChoice::UpdateNow;
                dialog.accept();
            };
            if (raceDone) {
                finishGo();
                return;
            }
            goBtn->setEnabled(false);
            if (laterBtn)
                laterBtn->setEnabled(false);
            if (dontBtn)
                dontBtn->setEnabled(false);
            goBtn->setText(I18n::t("update.picking"));
            QApplication::setOverrideCursor(Qt::WaitCursor);
            if (!racer)
                return;
            QObject::connect(racer, &DownloadRacer::finished, &dialog, [&, finishGo](const QString& url) {
                winner = url;
                raceDone = true;
                QApplication::restoreOverrideCursor();
                finishGo();
            });
        });
    }

    dialog.adjustSize();
    dialog.exec();

    if (dontShowTips && dontShowTips->isChecked()) {
        LaunchSettings::setStartupTipsDontShow(settings, true);
        settings.sync();
    }
    // Later / DontUpdate only dismiss this launch; next launch still checks.
    if (choice == CombinedChoice::UpdateNow)
        beginInPlaceUpdate(parent, rel, winner);
}

void startOnlineUpdateCheck(QWidget* parent)
{
    if (!parent)
        return;

    auto* checker = new UpdateChecker(parent);
    checker->start();
}

void runLaunchPrompts(QWidget* parent)
{
    if (!parent)
        return;
    startOnlineUpdateCheck(parent);
}

#include "LaunchPrompts.moc"
