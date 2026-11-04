#pragma once

#include <QString>
#include <QStringList>

class FolderPager
{
public:
    bool open(const QString& fileOrDir);
    bool next();
    bool previous();
    bool first();
    bool last();
    bool jumpTo(int index);

    bool isEmpty() const;
    QString currentPath() const;
    QString currentFileName() const;
    QString directory() const;
    int index() const;
    int count() const;

    static QStringList supportedSuffixes();
    static QString fileDialogFilter();
    static bool isImageFile(const QString& path);

private:
    void scan(const QString& dir, const QString& preferredFile);
    QStringList m_files;
    int m_index = -1;
    QString m_directory;
};
