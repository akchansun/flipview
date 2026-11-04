#include "FolderPager.h"
#include "I18n.h"
#include "NaturalSort.h"

#include <QDir>
#include <QFileInfo>
#include <QImageReader>
#include <QSet>
#include <algorithm>

namespace {

QStringList uniqueSortedSuffixes()
{
    QSet<QString> set;
    const auto formats = QImageReader::supportedImageFormats();
    for (const QByteArray& fmt : formats)
        set.insert(QString::fromLatin1(fmt).toLower());
    // Common aliases even if a plugin reports only one spelling.
    if (set.contains(QStringLiteral("jpg")))
        set.insert(QStringLiteral("jpeg"));
    if (set.contains(QStringLiteral("jpeg")))
        set.insert(QStringLiteral("jpg"));
    if (set.contains(QStringLiteral("tif")))
        set.insert(QStringLiteral("tiff"));
    if (set.contains(QStringLiteral("tiff")))
        set.insert(QStringLiteral("tif"));
    QStringList list(set.begin(), set.end());
    list.sort();
    return list;
}

} // namespace

QStringList FolderPager::supportedSuffixes()
{
    return uniqueSortedSuffixes();
}

QString FolderPager::fileDialogFilter()
{
    QStringList wildcards;
    for (const QString& suffix : supportedSuffixes())
        wildcards << QStringLiteral("*.") + suffix;
    const QString images = QStringLiteral("%1 (%2)")
                               .arg(I18n::t("dialog.images"), wildcards.join(QLatin1Char(' ')));
    return images + QStringLiteral(";;%1 (*)").arg(I18n::t("dialog.allFiles"));
}

bool FolderPager::isImageFile(const QString& path)
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    return !suffix.isEmpty() && supportedSuffixes().contains(suffix);
}

bool FolderPager::open(const QString& fileOrDir)
{
    const QFileInfo info(fileOrDir);
    if (!info.exists()) {
        m_files.clear();
        m_index = -1;
        m_directory.clear();
        return false;
    }
    if (info.isDir()) {
        scan(info.absoluteFilePath(), QString());
        return !m_files.isEmpty();
    }
    if (!isImageFile(info.absoluteFilePath())) {
        m_files.clear();
        m_index = -1;
        m_directory.clear();
        return false;
    }
    scan(info.absolutePath(), info.absoluteFilePath());
    return m_index >= 0;
}

void FolderPager::scan(const QString& dir, const QString& preferredFile)
{
    m_directory = QDir(dir).absolutePath();
    m_files.clear();
    m_index = -1;

    QDir folder(m_directory);
    folder.setFilter(QDir::Files | QDir::Readable | QDir::Hidden);
    const QFileInfoList entries = folder.entryInfoList(QDir::Files | QDir::Readable, QDir::NoSort);
    for (const QFileInfo& entry : entries) {
        if (entry.fileName().startsWith(QLatin1Char('.'))) {
            const bool openedHidden = !preferredFile.isEmpty()
                && QFileInfo(preferredFile).absoluteFilePath() == entry.absoluteFilePath();
            if (!openedHidden)
                continue;
        }
        if (isImageFile(entry.absoluteFilePath()))
            m_files << entry.absoluteFilePath();
    }

    std::sort(m_files.begin(), m_files.end(), [](const QString& a, const QString& b) {
        return naturalLessThan(QFileInfo(a).fileName(), QFileInfo(b).fileName());
    });

    if (m_files.isEmpty())
        return;

    if (!preferredFile.isEmpty()) {
        const QString abs = QFileInfo(preferredFile).absoluteFilePath();
        m_index = m_files.indexOf(abs);
        if (m_index < 0 && isImageFile(abs)) {
            m_files << abs;
            std::sort(m_files.begin(), m_files.end(), [](const QString& a, const QString& b) {
                return naturalLessThan(QFileInfo(a).fileName(), QFileInfo(b).fileName());
            });
            m_index = m_files.indexOf(abs);
        }
    }
    if (m_index < 0)
        m_index = 0;
}

bool FolderPager::next()
{
    if (m_files.isEmpty())
        return false;
    m_index = (m_index + 1) % m_files.size();
    return true;
}

bool FolderPager::previous()
{
    if (m_files.isEmpty())
        return false;
    m_index = (m_index - 1 + m_files.size()) % m_files.size();
    return true;
}

bool FolderPager::first()
{
    if (m_files.isEmpty())
        return false;
    m_index = 0;
    return true;
}

bool FolderPager::last()
{
    if (m_files.isEmpty())
        return false;
    m_index = m_files.size() - 1;
    return true;
}

bool FolderPager::jumpTo(int index)
{
    if (index < 0 || index >= m_files.size())
        return false;
    m_index = index;
    return true;
}

bool FolderPager::isEmpty() const
{
    return m_files.isEmpty();
}

QString FolderPager::currentPath() const
{
    if (m_index < 0 || m_index >= m_files.size())
        return {};
    return m_files.at(m_index);
}

QString FolderPager::currentFileName() const
{
    return QFileInfo(currentPath()).fileName();
}

QString FolderPager::directory() const
{
    return m_directory;
}

int FolderPager::index() const
{
    return m_index;
}

int FolderPager::count() const
{
    return m_files.size();
}
