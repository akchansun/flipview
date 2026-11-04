#pragma once

#include "HoverTip.h"
#include "ImageSession.h"

#include <QWidget>

class QToolButton;
class QHBoxLayout;
class QVBoxLayout;
class QMenu;

class ViewerToolbar : public QWidget
{
    Q_OBJECT

public:
    ViewerToolbar(ImageSession* session, HoverTip* tip, QWidget* parent = nullptr);
    void retranslate();
    void refresh();

signals:
    void previousRequested();
    void nextRequested();
    void zoomInRequested();
    void zoomOutRequested();
    void zoomFitRequested();
    void zoomActualRequested();
    void saveRequested();
    void saveAsRequested();
    void printRequested();
    void trashRequested();
    void undoRequested();
    void adjustColorRequested();
    void adjustSizeRequested();
    void inspectorRequested();

protected:
    void resizeEvent(QResizeEvent* event) override;
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    QToolButton* makeButton(const char* iconName, const char* tipKey);
    void rebuild();
    void attachTip(QToolButton* button, const char* key);
    void addHairline(QHBoxLayout* row);

    ImageSession* m_session = nullptr;
    HoverTip* m_tip = nullptr;
    QVBoxLayout* m_root = nullptr;
    QWidget* m_mainRow = nullptr;
    QWidget* m_markupRow = nullptr;
    int m_barWidth = 0;
};
