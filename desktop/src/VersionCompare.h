#pragma once

#include <QChar>
#include <QList>
#include <QString>
#include <QStringList>
#include <algorithm>

// Numeric dotted versions: "1.1.0", "v1.0", "1.0.0-beta" (suffix ignored after the
// last fully numeric component). Missing trailing parts compare as 0, so 1.0 == 1.0.0.
inline QList<int> versionParts(const QString& version)
{
    QString s = version.trimmed();
    if (s.startsWith(QLatin1Char('v')) || s.startsWith(QLatin1Char('V')))
        s = s.mid(1);

    QList<int> parts;
    const QStringList bits = s.split(QLatin1Char('.'));
    for (const QString& bit : bits) {
        int i = 0;
        while (i < bit.size() && bit.at(i).isDigit())
            ++i;
        if (i == 0)
            break;
        parts.append(bit.left(i).toInt());
        if (i < bit.size())
            break;
    }
    return parts;
}

// <0 if a < b, 0 if equal, >0 if a > b.
inline int compareVersions(const QString& a, const QString& b)
{
    const QList<int> pa = versionParts(a);
    const QList<int> pb = versionParts(b);
    const int n = std::max(pa.size(), pb.size());
    for (int i = 0; i < n; ++i) {
        const int va = i < pa.size() ? pa.at(i) : 0;
        const int vb = i < pb.size() ? pb.at(i) : 0;
        if (va != vb)
            return va < vb ? -1 : 1;
    }
    return 0;
}

inline bool isNewerVersion(const QString& remote, const QString& local)
{
    if (remote.trimmed().isEmpty() || local.trimmed().isEmpty())
        return false;
    return compareVersions(remote, local) > 0;
}
