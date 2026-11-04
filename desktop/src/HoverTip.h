#pragma once

#include <QLabel>
#include <QPoint>
#include <QString>
#include <QTimer>

class HoverTip : public QLabel
{
    Q_OBJECT

public:
    explicit HoverTip(QWidget* host);

    void schedule(const QString& text, QPoint globalAnchor);
    void hideSoon();
    void cancel();

private:
    void showNow();

    QWidget* m_host = nullptr;
    QTimer m_show;
    QTimer m_hide;
    QString m_text;
    QPoint m_anchor;
    bool m_visibleTip = false;
};
