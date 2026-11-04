#pragma once

#include "FolderPager.h"
#include "ImageSession.h"

#include <QMainWindow>

class ColorAdjustDialog;
class HoverTip;
class ImageView;
class InspectorDialog;
class SizeAdjustDialog;
class ViewerToolbar;
class QAction;
class QLabel;
class QMenu;
class QDragEnterEvent;
class QDropEvent;
class QShowEvent;

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget* parent = nullptr);
    bool openPath(const QString& path);

protected:
    void showEvent(QShowEvent* event) override;
    void keyPressEvent(QKeyEvent* event) override;
    void closeEvent(QCloseEvent* event) override;
    void dragEnterEvent(QDragEnterEvent* event) override;
    void dropEvent(QDropEvent* event) override;
    void changeEvent(QEvent* event) override;
    void resizeEvent(QResizeEvent* event) override;

private:
    void setupUi();
    void retranslateUi();
    void applyLanguagePreference();
    void openImageDialog();
    void openFolderDialog();
    void newFromClipboard();
    bool confirmDiscard();
    void goPrevious();
    void goNext();
    void goFirst();
    void goLast();
    void showTips();
    void visitWebsite();
    void showAbout();
    void loadCurrent();
    void updateChrome();
    void handleDropped(const QStringList& paths);
    void restoreGeometryFromSettings();
    void saveImage();
    void saveImageAs();
    void printImage();
    void trashImage();
    void copyImage();
    void copyPath();
    void showColorAdjust();
    void showSizeAdjust();
    void showInspector();

    ImageSession m_session;
    ImageView* m_view = nullptr;
    ViewerToolbar* m_toolbar = nullptr;
    HoverTip* m_tip = nullptr;
    QLabel* m_statusLabel = nullptr;
    FolderPager m_pager;
    QString m_error;
    ColorAdjustDialog* m_colorDialog = nullptr;
    SizeAdjustDialog* m_sizeDialog = nullptr;
    InspectorDialog* m_inspectorDialog = nullptr;

    QAction* m_openImageAction = nullptr;
    QAction* m_openFolderAction = nullptr;
    QAction* m_newClipboardAction = nullptr;
    QAction* m_saveAction = nullptr;
    QAction* m_saveAsAction = nullptr;
    QAction* m_printAction = nullptr;
    QAction* m_trashAction = nullptr;
    QAction* m_quitAction = nullptr;
    QAction* m_undoAction = nullptr;
    QAction* m_copyImageAction = nullptr;
    QAction* m_copyPathAction = nullptr;
    QAction* m_prevAction = nullptr;
    QAction* m_nextAction = nullptr;
    QAction* m_zoomInAction = nullptr;
    QAction* m_zoomOutAction = nullptr;
    QAction* m_actualAction = nullptr;
    QAction* m_fitAction = nullptr;
    QAction* m_fullScreenAction = nullptr;
    QAction* m_rotateLeftAction = nullptr;
    QAction* m_rotateRightAction = nullptr;
    QAction* m_flipHAction = nullptr;
    QAction* m_flipVAction = nullptr;
    QAction* m_cropAction = nullptr;
    QAction* m_selectAllAction = nullptr;
    QAction* m_colorAction = nullptr;
    QAction* m_sizeAction = nullptr;
    QAction* m_inspectorAction = nullptr;
    QAction* m_removeBgAction = nullptr;
    QAction* m_langAutoAction = nullptr;
    QAction* m_langZhAction = nullptr;
    QAction* m_langEnAction = nullptr;
    QAction* m_tipsAction = nullptr;
    QAction* m_visitWebsiteAction = nullptr;
    QAction* m_aboutAction = nullptr;

    QMenu* m_fileMenu = nullptr;
    QMenu* m_editMenu = nullptr;
    QMenu* m_viewMenu = nullptr;
    QMenu* m_imageMenu = nullptr;
    QMenu* m_langMenu = nullptr;
    QMenu* m_helpMenu = nullptr;

    bool m_didLaunchPrompts = false;
};
