#pragma once

#include <QChar>
#include <QString>

inline bool naturalLessThan(const QString& left, const QString& right)
{
    const QString a = left.toCaseFolded();
    const QString b = right.toCaseFolded();
    int i = 0;
    int j = 0;
    while (i < a.size() && j < b.size()) {
        if (a.at(i).isDigit() && b.at(j).isDigit()) {
            int ia = i;
            while (ia < a.size() && a.at(ia).isDigit())
                ++ia;
            int jb = j;
            while (jb < b.size() && b.at(jb).isDigit())
                ++jb;
            const QString na = a.mid(i, ia - i);
            const QString nb = b.mid(j, jb - j);
            const qlonglong va = na.toLongLong();
            const qlonglong vb = nb.toLongLong();
            if (va != vb)
                return va < vb;
            if (na.size() != nb.size())
                return na.size() < nb.size();
            i = ia;
            j = jb;
            continue;
        }
        if (a.at(i) != b.at(j))
            return a.at(i) < b.at(j);
        ++i;
        ++j;
    }
    return a.size() < b.size();
}
