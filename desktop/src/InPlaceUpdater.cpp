#include "InPlaceUpdater.h"

#include "AppInfo.h"
#include "I18n.h"

#include <QApplication>
#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QMessageBox>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>
#include <QProcess>
#include <QProgressDialog>
#include <QTemporaryDir>
#include <QTimer>
#include <QUrl>
#include <QUuid>
#include <QWidget>
#include <utility>

namespace InPlaceUpdater {

constexpr int kDownloadTimeoutMs = 300000;

QString userAgent()
{
    return QStringLiteral("Flip/%1 (Linux)").arg(QStringLiteral(FLIP_VERSION));
}

void openDownloadFallback(const QStringList& urls)
{
    for (const QString& url : urls) {
        if (url.isEmpty())
            continue;
        if (QDesktopServices::openUrl(QUrl(url)))
            return;
    }
}

void presentFallback(QWidget* parent, const QString& title, const QString& message,
                     const QStringList& urls)
{
    QMessageBox box(parent);
    box.setIcon(QMessageBox::Warning);
    box.setWindowTitle(title);
    box.setText(message);
    box.setStandardButtons(QMessageBox::Ok | QMessageBox::Cancel);
    box.setDefaultButton(QMessageBox::Ok);
    box.setButtonText(QMessageBox::Ok, I18n::t("update.openDownload"));
    box.setButtonText(QMessageBox::Cancel, I18n::t("dialog.cancel"));
    if (box.exec() == QMessageBox::Ok)
        openDownloadFallback(urls);
}

class InPlaceUpdateJob final : public QObject
{
    Q_OBJECT

public:
    InPlaceUpdateJob(QWidget* parent, QStringList assetUrls, QStringList fallbackUrls)
        : QObject(parent)
        , m_parent(parent)
        , m_assets(std::move(assetUrls))
        , m_fallback(std::move(fallbackUrls))
    {
        m_temp = new QTemporaryDir();
        m_nam = new QNetworkAccessManager(this);
    }

    ~InPlaceUpdateJob() override
    {
        abortReply();
        delete m_temp;
        m_temp = nullptr;
    }

    void start()
    {
        if (!m_temp || !m_temp->isValid()) {
            fail(true);
            return;
        }

        m_progress = new QProgressDialog(I18n::t("update.downloadingBody"), QString(), 0, 0,
                                         m_parent);
        m_progress->setWindowTitle(I18n::t("update.downloadingTitle"));
        m_progress->setCancelButton(nullptr);
        m_progress->setMinimumDuration(0);
        m_progress->setWindowModality(Qt::WindowModal);
        m_progress->show();

        tryNextAsset();
    }

private:
    void abortReply()
    {
        if (!m_reply)
            return;
        m_reply->disconnect(this);
        if (m_reply->isRunning())
            m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }

    void closeProgress()
    {
        if (!m_progress)
            return;
        m_progress->close();
        m_progress->deleteLater();
        m_progress = nullptr;
    }

    void fail(bool notWritable)
    {
        closeProgress();
        presentFallback(m_parent,
                        I18n::t(notWritable ? "update.notWritableTitle" : "update.failedTitle"),
                        I18n::t(notWritable ? "update.notWritableBody" : "update.failedBody"),
                        m_fallback);
        deleteLater();
    }

    void tryNextAsset()
    {
        abortReply();
        if (m_file) {
            m_file->close();
            m_file->remove();
            m_file->deleteLater();
            m_file = nullptr;
        }
        if (m_index >= m_assets.size()) {
            fail(false);
            return;
        }

        const QUrl url(m_assets.at(m_index++));
        if (!url.isValid() || url.scheme().isEmpty()) {
            tryNextAsset();
            return;
        }

        m_tarPath = m_temp->filePath(QStringLiteral("Flip-update-%1.tar.gz")
                                         .arg(QUuid::createUuid().toString(QUuid::WithoutBraces)));
        m_file = new QFile(m_tarPath, this);
        if (!m_file->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            tryNextAsset();
            return;
        }

        QNetworkRequest req(url);
        req.setHeader(QNetworkRequest::UserAgentHeader, userAgent());
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
        req.setTransferTimeout(kDownloadTimeoutMs);
#endif
        m_reply = m_nam->get(req);
        connect(m_reply, &QNetworkReply::readyRead, this, &InPlaceUpdateJob::onReadyRead);
        connect(m_reply, &QNetworkReply::finished, this, &InPlaceUpdateJob::onDownloadFinished);
    }

    void onReadyRead()
    {
        if (!m_reply || !m_file)
            return;
        m_file->write(m_reply->readAll());
    }

    void onDownloadFinished()
    {
        QNetworkReply* reply = m_reply;
        m_reply = nullptr;
        if (!reply) {
            tryNextAsset();
            return;
        }

        if (m_file) {
            if (reply->bytesAvailable() > 0)
                m_file->write(reply->readAll());
            m_file->flush();
            m_file->close();
        }

        const bool ok = reply->error() == QNetworkReply::NoError;
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        reply->deleteLater();

        if (!ok || (status != 0 && (status < 200 || status >= 300)) || !m_file
            || !fileLooksLikeGzip(m_tarPath)) {
            tryNextAsset();
            return;
        }

        applyPackage();
    }

    void applyPackage()
    {
        const QString extractDir =
            m_temp->filePath(QStringLiteral("extract-%1")
                                 .arg(QUuid::createUuid().toString(QUuid::WithoutBraces)));
        QString err;
        if (!extractTarball(m_tarPath, extractDir, &err)) {
            tryNextAsset();
            return;
        }

        const QString srcFlip = findFlipBinary(extractDir);
        if (srcFlip.isEmpty()) {
            tryNextAsset();
            return;
        }

        const QString destExe = runningExecutablePath();
        if (destExe.isEmpty() || !isInstallWritable(destExe)) {
            fail(true);
            return;
        }

        if (!stageNewBinary(srcFlip, destExe, &err)) {
            fail(false);
            return;
        }

        copyPackageSidecars(QFileInfo(srcFlip).absolutePath(), installDirectory(destExe));

        if (!spawnHelper(destExe)) {
            QFile::remove(stagedBinaryPath(destExe));
            fail(false);
            return;
        }

        closeProgress();
        QTimer::singleShot(150, qApp, [] {
            QCoreApplication::quit();
        });
        deleteLater();
    }

    bool spawnHelper(const QString& destExe)
    {
        const QString scriptPath =
            QDir::temp().filePath(QStringLiteral("flip-inplace-update-%1.sh")
                                      .arg(QUuid::createUuid().toString(QUuid::WithoutBraces)));
        QFile script(scriptPath);
        if (!script.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
            return false;
        const QByteArray body =
            helperScriptContents(QCoreApplication::applicationPid(), destExe, stagedBinaryPath(destExe))
                .toUtf8();
        if (script.write(body) != body.size())
            return false;
        script.close();
        QFile::setPermissions(scriptPath, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        return QProcess::startDetached(QStringLiteral("/bin/bash"), {scriptPath});
    }

    QPointer<QWidget> m_parent;
    QStringList m_assets;
    QStringList m_fallback;
    int m_index = 0;
    QTemporaryDir* m_temp = nullptr;
    QNetworkAccessManager* m_nam = nullptr;
    QNetworkReply* m_reply = nullptr;
    QFile* m_file = nullptr;
    QString m_tarPath;
    QPointer<QProgressDialog> m_progress;
};

bool isAppImageInstall()
{
    return !qEnvironmentVariable("APPIMAGE").trimmed().isEmpty();
}

QString runningExecutablePath()
{
    const QFileInfo fi(QCoreApplication::applicationFilePath());
    const QString canon = fi.canonicalFilePath();
    return canon.isEmpty() ? fi.absoluteFilePath() : canon;
}

QString installDirectory(const QString& exePath)
{
    return QFileInfo(exePath).absolutePath();
}

bool isInstallWritable(const QString& exePath)
{
    if (isAppImageInstall())
        return false;
    const QString dir = installDirectory(exePath);
    if (dir.isEmpty())
        return false;
    const QFileInfo di(dir);
    if (!di.exists() || !di.isDir())
        return false;

    const QString probe =
        dir + QStringLiteral("/.flip-write-probe-") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    QFile f(probe);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    f.close();
    f.remove();
    return true;
}

bool fileLooksLikeGzip(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const QByteArray mag = f.read(2);
    return mag.size() == 2 && static_cast<unsigned char>(mag.at(0)) == 0x1f
        && static_cast<unsigned char>(mag.at(1)) == 0x8b;
}

bool extractTarball(const QString& archivePath, const QString& destDir, QString* error)
{
    if (!QDir().mkpath(destDir)) {
        if (error)
            *error = QStringLiteral("mkdir");
        return false;
    }

    auto run = [&](const QStringList& extra) {
        QProcess proc;
        QStringList args = {QStringLiteral("-xzf"), archivePath, QStringLiteral("-C"), destDir};
        args.append(extra);
        proc.start(QStringLiteral("tar"), args);
        if (!proc.waitForStarted(5000))
            return false;
        if (!proc.waitForFinished(120000)) {
            proc.kill();
            proc.waitForFinished(2000);
            return false;
        }
        if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
            if (error)
                *error = QString::fromUtf8(proc.readAllStandardError());
            return false;
        }
        return true;
    };

    if (run({QStringLiteral("--no-same-owner")}))
        return true;
    return run({});
}

QString findFlipBinary(const QString& extractRoot)
{
    QString best;
    int bestDepth = 100000;
    QDirIterator it(extractRoot, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QFileInfo fi(it.next());
        if (fi.fileName() != QLatin1String("Flip"))
            continue;
        const QString rel = QDir(extractRoot).relativeFilePath(fi.absoluteFilePath());
        if (rel.startsWith(QLatin1String("..")) || rel.contains(QStringLiteral("/../")))
            continue;
        const int depth = rel.count(QLatin1Char('/'));
        if (depth < bestDepth) {
            bestDepth = depth;
            best = fi.absoluteFilePath();
        }
    }
    return best;
}

bool copyOverwrite(const QString& src, const QString& dest)
{
    if (src.isEmpty() || dest.isEmpty() || !QFile::exists(src))
        return false;
    if (QFile::exists(dest) && !QFile::remove(dest))
        return false;
    return QFile::copy(src, dest);
}

QStringList copyPackageSidecars(const QString& packageDir, const QString& destDir)
{
    QStringList copied;
    if (packageDir.isEmpty() || destDir.isEmpty())
        return copied;
    if (!QDir().mkpath(destDir))
        return copied;

    const QStringList files = {QStringLiteral("README.md"), QStringLiteral("README"),
                               QStringLiteral("LICENSE"), QStringLiteral("LICENSE.txt"),
                               QStringLiteral("flip.desktop")};
    for (const QString& name : files) {
        const QString src = packageDir + QLatin1Char('/') + name;
        if (!QFile::exists(src))
            continue;
        const QString dest = destDir + QLatin1Char('/') + name;
        if (copyOverwrite(src, dest))
            copied << dest;
    }

    const QDir icons(packageDir + QStringLiteral("/icons"));
    if (icons.exists()) {
        const QString destIcons = destDir + QStringLiteral("/icons");
        QDir().mkpath(destIcons);
        const QFileInfoList entries =
            icons.entryInfoList(QDir::Files | QDir::NoDotAndDotDot | QDir::NoSymLinks);
        for (const QFileInfo& fi : entries) {
            const QString dest = destIcons + QLatin1Char('/') + fi.fileName();
            if (copyOverwrite(fi.absoluteFilePath(), dest))
                copied << dest;
        }
    }
    return copied;
}

QString stagedBinaryPath(const QString& destExe)
{
    return destExe + QStringLiteral(".flip-new");
}

bool stageNewBinary(const QString& srcFlip, const QString& destExe, QString* error)
{
    if (srcFlip.isEmpty() || destExe.isEmpty() || !QFile::exists(srcFlip)) {
        if (error)
            *error = QStringLiteral("missing source");
        return false;
    }
    const QString staged = stagedBinaryPath(destExe);
    if (!copyOverwrite(srcFlip, staged)) {
        if (error)
            *error = QStringLiteral("copy staged binary");
        return false;
    }
    QFile::setPermissions(staged, QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                      | QFileDevice::ExeOwner | QFileDevice::ReadGroup
                                      | QFileDevice::ExeGroup | QFileDevice::ReadOther
                                      | QFileDevice::ExeOther);
    QFile stagedFile(staged);
    if (!stagedFile.open(QIODevice::ReadOnly)) {
        QFile::remove(staged);
        if (error)
            *error = QStringLiteral("reopen staged");
        return false;
    }
    stagedFile.close();
    return true;
}

QString shellSingleQuote(const QString& path)
{
    QString s = path;
    s.replace(QLatin1Char('\''), QStringLiteral("'\\''"));
    return QLatin1Char('\'') + s + QLatin1Char('\'');
}

QString helperScriptContents(qint64 pid, const QString& destExe, const QString& stagedExe)
{
    const QString exe = shellSingleQuote(destExe);
    const QString neu = shellSingleQuote(stagedExe);
    return QStringLiteral(
               "#!/bin/bash\n"
               "set -euo pipefail\n"
               "EXE=%1\n"
               "NEW=%2\n"
               "PID=%3\n"
               "OLD=\"$EXE.flip-old-$$\"\n"
               "\n"
               "for i in $(seq 1 100); do\n"
               "  if ! kill -0 \"$PID\" 2>/dev/null; then\n"
               "    break\n"
               "  fi\n"
               "  sleep 0.1\n"
               "done\n"
               "sleep 0.3\n"
               "\n"
               "if [ ! -f \"$NEW\" ]; then\n"
               "  exit 1\n"
               "fi\n"
               "\n"
               "rm -f \"$OLD\"\n"
               "if [ -e \"$EXE\" ]; then\n"
               "  mv \"$EXE\" \"$OLD\"\n"
               "fi\n"
               "if ! mv \"$NEW\" \"$EXE\"; then\n"
               "  if [ -e \"$OLD\" ]; then\n"
               "    mv \"$OLD\" \"$EXE\" || true\n"
               "  fi\n"
               "  exit 1\n"
               "fi\n"
               "chmod +x \"$EXE\" || true\n"
               "rm -f \"$OLD\"\n"
               "\n"
               "if command -v setsid >/dev/null 2>&1; then\n"
               "  setsid \"$EXE\" >/dev/null 2>&1 &\n"
               "else\n"
               "  nohup \"$EXE\" >/dev/null 2>&1 &\n"
               "fi\n"
               "rm -f -- \"$0\"\n")
        .arg(exe, neu, QString::number(pid));
}

void start(QWidget* parent, const QStringList& assetUrls, const QStringList& fallbackOpenUrls)
{
    if (assetUrls.isEmpty()) {
        openDownloadFallback(fallbackOpenUrls);
        return;
    }

    const QString exe = runningExecutablePath();
    if (exe.isEmpty() || !isInstallWritable(exe)) {
        presentFallback(parent, I18n::t("update.notWritableTitle"), I18n::t("update.notWritableBody"),
                        fallbackOpenUrls);
        return;
    }

    auto* job = new InPlaceUpdateJob(parent, assetUrls, fallbackOpenUrls);
    job->start();
}

} // namespace InPlaceUpdater

#include "InPlaceUpdater.moc"
