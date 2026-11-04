#pragma once

#include <QString>
#include <QStringList>

class QWidget;

// Download a Flip tarball, extract, and replace the running install in place.
namespace InPlaceUpdater {

bool isAppImageInstall();
QString runningExecutablePath();
QString installDirectory(const QString& exePath);
bool isInstallWritable(const QString& exePath);

bool fileLooksLikeGzip(const QString& path);
bool extractTarball(const QString& archivePath, const QString& destDir, QString* error);
QString findFlipBinary(const QString& extractRoot);

bool copyOverwrite(const QString& src, const QString& dest);
QStringList copyPackageSidecars(const QString& packageDir, const QString& destDir);

QString stagedBinaryPath(const QString& destExe);
bool stageNewBinary(const QString& srcFlip, const QString& destExe, QString* error);

QString shellSingleQuote(const QString& path);
QString helperScriptContents(qint64 pid, const QString& destExe, const QString& stagedExe);

// Race-ordered asset URLs. On success the process quits after spawning a helper
// that swaps the binary and relaunches. If the install is not writable or the
// package cannot be applied, a dialog offers opening the download instead.
void start(QWidget* parent, const QStringList& assetUrls, const QStringList& fallbackOpenUrls);

} // namespace InPlaceUpdater
