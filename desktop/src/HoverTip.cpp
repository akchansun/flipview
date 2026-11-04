#include "HoverTip.h"

#include <QGuiApplication>
#include <QScreen>
#include <algorithm>

HoverTip::HoverTip(QWidget* host)
    : QLabel(host)
    , m_host(host)
{
    setAttribute(Qt::WA_TransparentForMouseEvents);
    setStyleSheet(QStringLiteral(
        "QLabel { background: rgba(246,246,246,235); color: #222; border: 1px solid rgba(0,0,0,30);"
        " border-radius: 6px; padding: 4px 8px; font-size: 11px; }"));
    hide();
    m_show.setSingleShot(true);
    m_hide.setSingleShot(true);
    connect(&m_show, &QTimer::timeout, this, &HoverTip::showNow);
    connect(&m_hide, &QTimer::timeout, this, [this] {
        m_visibleTip = false;
        hide();
    });
}

void HoverTip::schedule(const QString& text, QPoint globalAnchor)
{
    m_hide.stop();
    m_text = text;
    m_anchor = globalAnchor;
    if (m_visibleTip) {
        showNow();
        return;
    }
    m_show.start(240);
}

void HoverTip::hideSoon()
{
    m_show.stop();
    if (m_visibleTip)
        m_hide.start(60);
}

void HoverTip::cancel()
{
    m_show.stop();
    m_hide.stop();
    m_visibleTip = false;
    hide();
}

void HoverTip::showNow()
{
    if (m_text.isEmpty() || !m_host)
        return;
    setText(m_text);
    adjustSize();
    QPoint local = m_host->mapFromGlobal(QPoint(m_anchor.x() - width() / 2, m_anchor.y()));
    const int minX = 36;
    const int maxX = m_host->width() - width() - 36;
    local.setX(std::clamp(local.x(), minX, std::max(minX, maxX)));
    local.setY(std::clamp(local.y(), 8, std::max(8, m_host->height() - height() - 8)));
    move(local);
    m_visibleTip = true;
    show();
    raise();
}
