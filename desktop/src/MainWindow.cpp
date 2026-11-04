#include "MainWindow.h"

#include "AppInfo.h"
#include "EditDialogs.h"
#include "HoverTip.h"
#include "I18n.h"
#include "ImageView.h"
#include "LaunchPrompts.h"
#include "ViewerToolbar.h"

#include <QActionGroup>
#include <QApplication>
#include <QClipboard>
#include <QCloseEvent>
#include <QDateTime>
#include <QDesktopServices>
#include <QDialog>
#include <QDialogButtonBox>
#include <QDir>
#include <QDragEnterEvent>
#include <QDropEvent>
#include <QFileDialog>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QImageReader>
#include <QKeyEvent>
#include <QLabel>
#include <QMenuBar>
#include <QMessageBox>
#include <QMimeData>
#include <QPageLayout>
#include <QPainter>
#include <QPrintDialog>
#include <QPrinter>
#include <QPushButton>
#include <QResizeEvent>
#include <QSettings>
#include <QShowEvent>
#include <QStatusBar>
#include <QStyle>
#include <QTimer>
#include <QUrl>
#include <QVBoxLayout>

#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
#include <QFile>
#endif

namespace {
constexpr int kDefaultWidth = 1100;
constexpr int kDefaultHeight = 740;

QKeySequence modKey(int key)
{
#ifdef Q_OS_MAC
    return QKeySequence(Qt::CTRL | key);
#else
    return QKeySequence(Qt::CTRL | key);
#endif
}
} // namespace

MainWindow::MainWindow(QWidget* parent)
    : QMainWindow(parent)
{
    setAcceptDrops(true);
    setWindowIcon(QIcon(QStringLiteral(":/icons/flip.svg")));
    resize(kDefaultWidth, kDefaultHeight);
    setMinimumSize(480, 320);
    setupUi();
    applyLanguagePreference();
    retranslateUi();
    restoreGeometryFromSettings();
}

void MainWindow::setupUi()
{
    auto* central = new QWidget(this);
    auto* layout = new QVBoxLayout(central);
    layout->setContentsMargins(0, 0, 0, 0);
    layout->setSpacing(0);
    m_tip = new HoverTip(this);
    m_toolbar = new ViewerToolbar(&m_session, m_tip, central);
    m_view = new ImageView(central);
    m_view->setSession(&m_session);
    layout->addWidget(m_toolbar);
    layout->addWidget(m_view, 1);
    setCentralWidget(central);

    m_openImageAction = new QAction(this);
    m_openImageAction->setShortcut(QKeySequence::Open);
    m_openImageAction->setIcon(style()->standardIcon(QStyle::SP_DialogOpenButton));
    connect(m_openImageAction, &QAction::triggered, this, &MainWindow::openImageDialog);

    m_openFolderAction = new QAction(this);
    m_openFolderAction->setShortcut(QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_O));
    m_openFolderAction->setIcon(style()->standardIcon(QStyle::SP_DirOpenIcon));
    connect(m_openFolderAction, &QAction::triggered, this, &MainWindow::openFolderDialog);

    m_newClipboardAction = new QAction(this);
    m_newClipboardAction->setShortcut(modKey(Qt::Key_N));
    connect(m_newClipboardAction, &QAction::triggered, this, &MainWindow::newFromClipboard);

    m_saveAction = new QAction(this);
    m_saveAction->setShortcut(QKeySequence::Save);
    connect(m_saveAction, &QAction::triggered, this, &MainWindow::saveImage);

    m_saveAsAction = new QAction(this);
    m_saveAsAction->setShortcut(QKeySequence::SaveAs);
    connect(m_saveAsAction, &QAction::triggered, this, &MainWindow::saveImageAs);

    m_printAction = new QAction(this);
    m_printAction->setShortcut(QKeySequence::Print);
    connect(m_printAction, &QAction::triggered, this, &MainWindow::printImage);

    m_trashAction = new QAction(this);
    connect(m_trashAction, &QAction::triggered, this, &MainWindow::trashImage);

    m_quitAction = new QAction(this);
    m_quitAction->setShortcut(QKeySequence::Quit);
    connect(m_quitAction, &QAction::triggered, this, &QWidget::close);

    m_undoAction = new QAction(this);
    m_undoAction->setShortcut(QKeySequence::Undo);
    connect(m_undoAction, &QAction::triggered, &m_session, &ImageSession::undo);

    m_copyImageAction = new QAction(this);
    m_copyImageAction->setShortcut(QKeySequence::Copy);
    connect(m_copyImageAction, &QAction::triggered, this, &MainWindow::copyImage);

    m_copyPathAction = new QAction(this);
    connect(m_copyPathAction, &QAction::triggered, this, &MainWindow::copyPath);

    m_prevAction = new QAction(this);
    m_prevAction->setShortcut(QKeySequence(Qt::Key_Left));
    connect(m_prevAction, &QAction::triggered, this, &MainWindow::goPrevious);

    m_nextAction = new QAction(this);
    m_nextAction->setShortcut(QKeySequence(Qt::Key_Right));
    connect(m_nextAction, &QAction::triggered, this, &MainWindow::goNext);

    m_zoomInAction = new QAction(this);
    m_zoomInAction->setShortcuts({QKeySequence::ZoomIn, QKeySequence(Qt::Key_Plus), QKeySequence(Qt::Key_Equal)});
    connect(m_zoomInAction, &QAction::triggered, m_view, &ImageView::zoomIn);

    m_zoomOutAction = new QAction(this);
    m_zoomOutAction->setShortcuts({QKeySequence::ZoomOut, QKeySequence(Qt::Key_Minus)});
    connect(m_zoomOutAction, &QAction::triggered, m_view, &ImageView::zoomOut);

    m_actualAction = new QAction(this);
    m_actualAction->setShortcut(QKeySequence(Qt::Key_1));
    connect(m_actualAction, &QAction::triggered, m_view, &ImageView::zoomActual);

    m_fitAction = new QAction(this);
    m_fitAction->setShortcuts({QKeySequence(Qt::Key_0), QKeySequence(Qt::Key_F)});
    connect(m_fitAction, &QAction::triggered, m_view, &ImageView::zoomFitDefault);

    m_fullScreenAction = new QAction(this);
    m_fullScreenAction->setShortcut(QKeySequence(Qt::Key_F11));
    m_fullScreenAction->setCheckable(true);
    connect(m_fullScreenAction, &QAction::triggered, this, [this](bool on) {
        if (on)
            showFullScreen();
        else
            showNormal();
    });

    m_rotateLeftAction = new QAction(this);
    m_rotateLeftAction->setShortcut(modKey(Qt::Key_L));
    connect(m_rotateLeftAction, &QAction::triggered, this, [this] { m_session.apply(ImageOp::rotateLeft()); });

    m_rotateRightAction = new QAction(this);
    m_rotateRightAction->setShortcut(modKey(Qt::Key_R));
    connect(m_rotateRightAction, &QAction::triggered, this, [this] { m_session.apply(ImageOp::rotateRight()); });

    m_flipHAction = new QAction(this);
    connect(m_flipHAction, &QAction::triggered, this, [this] { m_session.apply(ImageOp::flipHorizontal()); });

    m_flipVAction = new QAction(this);
    connect(m_flipVAction, &QAction::triggered, this, [this] { m_session.apply(ImageOp::flipVertical()); });

    m_cropAction = new QAction(this);
    m_cropAction->setShortcut(modKey(Qt::Key_K));
    connect(m_cropAction, &QAction::triggered, this, [this] {
        if (m_session.tool() == MarkupTool::Crop && m_session.cropSelection())
            m_session.applyCrop();
        else
            m_session.setTool(MarkupTool::Crop);
    });

    m_selectAllAction = new QAction(this);
    m_selectAllAction->setShortcut(QKeySequence::SelectAll);
    connect(m_selectAllAction, &QAction::triggered, &m_session, &ImageSession::selectAllCrop);

    m_colorAction = new QAction(this);
    connect(m_colorAction, &QAction::triggered, this, &MainWindow::showColorAdjust);

    m_sizeAction = new QAction(this);
    connect(m_sizeAction, &QAction::triggered, this, &MainWindow::showSizeAdjust);

    m_inspectorAction = new QAction(this);
    connect(m_inspectorAction, &QAction::triggered, this, &MainWindow::showInspector);

    m_removeBgAction = new QAction(this);
    connect(m_removeBgAction, &QAction::triggered, &m_session, &ImageSession::removeBackground);

    m_langAutoAction = new QAction(this);
    m_langAutoAction->setCheckable(true);
    m_langZhAction = new QAction(this);
    m_langZhAction->setCheckable(true);
    m_langEnAction = new QAction(this);
    m_langEnAction->setCheckable(true);
    auto* langGroup = new QActionGroup(this);
    langGroup->setExclusive(true);
    langGroup->addAction(m_langAutoAction);
    langGroup->addAction(m_langZhAction);
    langGroup->addAction(m_langEnAction);
    connect(m_langAutoAction, &QAction::triggered, this, [this] {
        QSettings().setValue(QStringLiteral("language"), QStringLiteral("auto"));
        applyLanguagePreference();
        retranslateUi();
    });
    connect(m_langZhAction, &QAction::triggered, this, [this] {
        QSettings().setValue(QStringLiteral("language"), QStringLiteral("zh_CN"));
        applyLanguagePreference();
        retranslateUi();
    });
    connect(m_langEnAction, &QAction::triggered, this, [this] {
        QSettings().setValue(QStringLiteral("language"), QStringLiteral("en"));
        applyLanguagePreference();
        retranslateUi();
    });

    m_tipsAction = new QAction(this);
    m_tipsAction->setShortcut(QKeySequence::HelpContents);
    connect(m_tipsAction, &QAction::triggered, this, &MainWindow::showTips);

    m_visitWebsiteAction = new QAction(this);
    connect(m_visitWebsiteAction, &QAction::triggered, this, &MainWindow::visitWebsite);

    m_aboutAction = new QAction(this);
    connect(m_aboutAction, &QAction::triggered, this, &MainWindow::showAbout);

    m_fileMenu = menuBar()->addMenu(QString());
    m_fileMenu->addAction(m_openImageAction);
    m_fileMenu->addAction(m_openFolderAction);
    m_fileMenu->addAction(m_newClipboardAction);
    m_fileMenu->addSeparator();
    m_fileMenu->addAction(m_saveAction);
    m_fileMenu->addAction(m_saveAsAction);
    m_fileMenu->addAction(m_printAction);
    m_fileMenu->addSeparator();
    m_fileMenu->addAction(m_trashAction);
    m_fileMenu->addSeparator();
    m_fileMenu->addAction(m_quitAction);

    m_editMenu = menuBar()->addMenu(QString());
    m_editMenu->addAction(m_undoAction);
    m_editMenu->addAction(m_copyImageAction);
    m_editMenu->addAction(m_copyPathAction);
    m_editMenu->addAction(m_selectAllAction);

    m_viewMenu = menuBar()->addMenu(QString());
    m_viewMenu->addAction(m_prevAction);
    m_viewMenu->addAction(m_nextAction);
    m_viewMenu->addSeparator();
    m_viewMenu->addAction(m_zoomInAction);
    m_viewMenu->addAction(m_zoomOutAction);
    m_viewMenu->addAction(m_actualAction);
    m_viewMenu->addAction(m_fitAction);
    m_viewMenu->addSeparator();
    m_viewMenu->addAction(m_fullScreenAction);
    m_langMenu = m_viewMenu->addMenu(QString());
    m_langMenu->addAction(m_langAutoAction);
    m_langMenu->addAction(m_langZhAction);
    m_langMenu->addAction(m_langEnAction);

    m_imageMenu = menuBar()->addMenu(QString());
    m_imageMenu->addAction(m_rotateLeftAction);
    m_imageMenu->addAction(m_rotateRightAction);
    m_imageMenu->addAction(m_flipHAction);
    m_imageMenu->addAction(m_flipVAction);
    m_imageMenu->addSeparator();
    m_imageMenu->addAction(m_cropAction);
    m_imageMenu->addAction(m_colorAction);
    m_imageMenu->addAction(m_sizeAction);
    m_imageMenu->addAction(m_inspectorAction);
    m_imageMenu->addAction(m_removeBgAction);

    m_helpMenu = menuBar()->addMenu(QString());
    m_helpMenu->addAction(m_tipsAction);
    m_helpMenu->addAction(m_visitWebsiteAction);
    m_helpMenu->addSeparator();
    m_helpMenu->addAction(m_aboutAction);

    m_statusLabel = new QLabel(this);
    statusBar()->addWidget(m_statusLabel, 1);

    connect(m_view, &ImageView::previousRequested, this, &MainWindow::goPrevious);
    connect(m_view, &ImageView::nextRequested, this, &MainWindow::goNext);
    connect(m_view, &ImageView::filesDropped, this, &MainWindow::handleDropped);
    connect(m_view, &ImageView::scaleChanged, this, [this](double) { updateChrome(); });
    connect(&m_session, &ImageSession::changed, this, [this] {
        m_toolbar->refresh();
        updateChrome();
    });
    connect(&m_session, &ImageSession::requestZoomFit, m_view, &ImageView::zoomFitDefault);
    connect(m_toolbar, &ViewerToolbar::previousRequested, this, &MainWindow::goPrevious);
    connect(m_toolbar, &ViewerToolbar::nextRequested, this, &MainWindow::goNext);
    connect(m_toolbar, &ViewerToolbar::zoomInRequested, m_view, &ImageView::zoomIn);
    connect(m_toolbar, &ViewerToolbar::zoomOutRequested, m_view, &ImageView::zoomOut);
    connect(m_toolbar, &ViewerToolbar::zoomFitRequested, m_view, &ImageView::zoomFitDefault);
    connect(m_toolbar, &ViewerToolbar::zoomActualRequested, m_view, &ImageView::zoomActual);
    connect(m_toolbar, &ViewerToolbar::saveRequested, this, &MainWindow::saveImage);
    connect(m_toolbar, &ViewerToolbar::saveAsRequested, this, &MainWindow::saveImageAs);
    connect(m_toolbar, &ViewerToolbar::printRequested, this, &MainWindow::printImage);
    connect(m_toolbar, &ViewerToolbar::trashRequested, this, &MainWindow::trashImage);
    connect(m_toolbar, &ViewerToolbar::undoRequested, &m_session, &ImageSession::undo);
    connect(m_toolbar, &ViewerToolbar::adjustColorRequested, this, &MainWindow::showColorAdjust);
    connect(m_toolbar, &ViewerToolbar::adjustSizeRequested, this, &MainWindow::showSizeAdjust);
    connect(m_toolbar, &ViewerToolbar::inspectorRequested, this, &MainWindow::showInspector);
}

void MainWindow::applyLanguagePreference()
{
    const QString pref = QSettings().value(QStringLiteral("language"), QStringLiteral("auto")).toString();
    if (pref == QLatin1String("zh_CN"))
        I18n::setLang(I18n::Lang::ZhCN);
    else if (pref == QLatin1String("en"))
        I18n::setLang(I18n::Lang::En);
    else
        I18n::setLang(I18n::Lang::Auto);

    m_langAutoAction->setChecked(pref == QLatin1String("auto") || pref.isEmpty());
    m_langZhAction->setChecked(pref == QLatin1String("zh_CN"));
    m_langEnAction->setChecked(pref == QLatin1String("en"));
}

void MainWindow::retranslateUi()
{
    m_fileMenu->setTitle(I18n::t("menu.file"));
    m_editMenu->setTitle(I18n::t("menu.edit"));
    m_viewMenu->setTitle(I18n::t("menu.view"));
    m_imageMenu->setTitle(I18n::t("menu.image"));
    m_helpMenu->setTitle(I18n::t("menu.help"));
    m_langMenu->setTitle(I18n::t("menu.language"));

    m_openImageAction->setText(I18n::t("file.openImage"));
    m_openFolderAction->setText(I18n::t("file.openFolder"));
    m_newClipboardAction->setText(I18n::t("file.newClipboard"));
    m_saveAction->setText(I18n::t("file.save"));
    m_saveAsAction->setText(I18n::t("file.saveAs"));
    m_printAction->setText(I18n::t("file.print"));
    m_trashAction->setText(I18n::t("file.trash"));
    m_quitAction->setText(I18n::t("file.quit"));
    m_undoAction->setText(I18n::t("edit.undo"));
    m_copyImageAction->setText(I18n::t("edit.copyImage"));
    m_copyPathAction->setText(I18n::t("edit.copyPath"));
    m_prevAction->setText(I18n::t("view.previous"));
    m_nextAction->setText(I18n::t("view.next"));
    m_zoomInAction->setText(I18n::t("view.zoomIn"));
    m_zoomOutAction->setText(I18n::t("view.zoomOut"));
    m_actualAction->setText(I18n::t("view.actualSize"));
    m_fitAction->setText(I18n::t("view.fitDefault"));
    m_fullScreenAction->setText(I18n::t("view.fullscreen"));
    m_rotateLeftAction->setText(I18n::t("image.rotateLeft"));
    m_rotateRightAction->setText(I18n::t("image.rotateRight"));
    m_flipHAction->setText(I18n::t("image.flipH"));
    m_flipVAction->setText(I18n::t("image.flipV"));
    m_cropAction->setText(I18n::t("image.crop"));
    m_selectAllAction->setText(I18n::t("image.selectAll"));
    m_colorAction->setText(I18n::t("adjust.color"));
    m_sizeAction->setText(I18n::t("adjust.size"));
    m_inspectorAction->setText(I18n::t("inspector"));
    m_removeBgAction->setText(I18n::t("image.removeBg"));
    m_langAutoAction->setText(I18n::t("view.langAuto"));
    m_langZhAction->setText(I18n::t("view.langZh"));
    m_langEnAction->setText(I18n::t("view.langEn"));
    m_tipsAction->setText(I18n::t("help.tips"));
    m_visitWebsiteAction->setText(I18n::t("help.visitWebsite"));
    m_aboutAction->setText(I18n::t("help.about"));
    QApplication::setApplicationDisplayName(I18n::t("app.name"));
    m_toolbar->retranslate();
    if (m_colorDialog)
        m_colorDialog->retranslate();
    if (m_sizeDialog)
        m_sizeDialog->retranslate();
    if (m_inspectorDialog)
        m_inspectorDialog->retranslate();
    m_view->update();
    updateChrome();
}

bool MainWindow::confirmDiscard()
{
    if (!m_session.isDirty())
        return true;
    const QString name = m_session.fileName();
    const QMessageBox::StandardButton ret = QMessageBox::question(
        this, I18n::t("unsaved.title"),
        name.isEmpty() ? I18n::t("unsaved.body") : I18n::t("unsaved.bodyNamed").arg(name),
        QMessageBox::Save | QMessageBox::Discard | QMessageBox::Cancel, QMessageBox::Save);
    if (ret == QMessageBox::Cancel)
        return false;
    if (ret == QMessageBox::Save) {
        if (m_session.path().isEmpty()) {
            saveImageAs();
            return !m_session.isDirty();
        }
        return m_session.save();
    }
    return true;
}

bool MainWindow::openPath(const QString& path)
{
    if (!confirmDiscard())
        return false;
    m_error.clear();
    if (!m_pager.open(path)) {
        m_error = I18n::t("error.cannotOpen");
        m_session.clear();
        updateChrome();
        return false;
    }
    loadCurrent();
    return m_session.hasImage();
}

void MainWindow::openImageDialog()
{
    const QString start = m_pager.currentPath().isEmpty() ? QDir::homePath()
                                                          : QFileInfo(m_pager.currentPath()).absolutePath();
    const QString path = QFileDialog::getOpenFileName(this, I18n::t("dialog.openImage"), start,
                                                      FolderPager::fileDialogFilter());
    if (!path.isEmpty())
        openPath(path);
}

void MainWindow::openFolderDialog()
{
    const QString start = m_pager.directory().isEmpty() ? QDir::homePath() : m_pager.directory();
    const QString path = QFileDialog::getExistingDirectory(this, I18n::t("dialog.openFolder"), start);
    if (!path.isEmpty())
        openPath(path);
}

void MainWindow::newFromClipboard()
{
    const QImage img = QGuiApplication::clipboard()->image();
    if (img.isNull()) {
        QMessageBox::information(this, I18n::t("app.name"), I18n::t("error.clipboardEmpty"));
        return;
    }
    if (!confirmDiscard())
        return;
    const QString name = I18n::t("file.untitled") + QStringLiteral("-")
        + QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss"))
        + QStringLiteral(".png");
    m_pager = FolderPager();
    m_session.openImage(img, name);
    updateChrome();
}

void MainWindow::goPrevious()
{
    if (!confirmDiscard())
        return;
    if (m_pager.previous())
        loadCurrent();
}

void MainWindow::goNext()
{
    if (!confirmDiscard())
        return;
    if (m_pager.next())
        loadCurrent();
}

void MainWindow::goFirst()
{
    if (!confirmDiscard())
        return;
    if (m_pager.first())
        loadCurrent();
}

void MainWindow::goLast()
{
    if (!confirmDiscard())
        return;
    if (m_pager.last())
        loadCurrent();
}

void MainWindow::loadCurrent()
{
    m_error.clear();
    const QString path = m_pager.currentPath();
    if (path.isEmpty()) {
        m_session.clear();
        updateChrome();
        return;
    }
    if (!m_session.openPath(path)) {
        m_error = I18n::t("error.cannotOpen");
        m_session.clear();
    }
    updateChrome();
}

void MainWindow::updateChrome()
{
    QString title = I18n::t("app.name");
    if (!m_pager.isEmpty() || m_session.hasImage()) {
        QString name = m_session.fileName();
        if (name.isEmpty())
            name = m_pager.currentFileName();
        title = name + QStringLiteral(" — ") + I18n::t("app.name");
        if (m_session.isDirty())
            title += QStringLiteral(" ") + I18n::t("status.edited");
    }
    setWindowTitle(title);

    if (m_pager.isEmpty() && !m_session.hasImage()) {
        m_statusLabel->setText(m_error.isEmpty() ? I18n::t("status.ready") : m_error);
        return;
    }
    QStringList parts;
    if (!m_pager.isEmpty())
        parts << I18n::t("status.position").arg(m_pager.index() + 1).arg(m_pager.count());
    if (!m_error.isEmpty()) {
        parts << m_error;
    } else if (m_session.hasImage()) {
        const QSize sz = m_session.pixelSize();
        parts << QStringLiteral("%1 × %2").arg(sz.width()).arg(sz.height());
        parts << QStringLiteral("%1%").arg(qRound(m_view->scale() * 100.0));
    }
    m_statusLabel->setText(parts.join(QStringLiteral("  ·  ")));
}

void MainWindow::handleDropped(const QStringList& paths)
{
    if (paths.isEmpty())
        return;
    openPath(paths.first());
}

void MainWindow::saveImage()
{
    if (!m_session.hasImage())
        return;
    if (m_session.path().isEmpty()) {
        saveImageAs();
        return;
    }
    if (!m_session.save())
        QMessageBox::warning(this, I18n::t("app.name"),
                             I18n::t("error.couldNotSave").arg(m_session.fileName()));
}

void MainWindow::saveImageAs()
{
    if (!m_session.hasImage())
        return;
    const QString start = m_session.path().isEmpty() ? QDir::home().filePath(m_session.fileName())
                                                     : m_session.path();
    const QString path = QFileDialog::getSaveFileName(this, I18n::t("file.saveAs"), start,
                                                      FolderPager::fileDialogFilter());
    if (path.isEmpty())
        return;
    if (!m_session.saveAs(path))
        QMessageBox::warning(this, I18n::t("app.name"), I18n::t("error.couldNotSave").arg(path));
}

void MainWindow::printImage()
{
    if (!m_session.hasImage())
        return;
    const QImage img = m_session.composite();
    QPrinter printer(QPrinter::HighResolution);
    printer.setPageOrientation(img.width() >= img.height() ? QPageLayout::Landscape : QPageLayout::Portrait);
    QPageLayout layout = printer.pageLayout();
    layout.setUnits(QPageLayout::Point);
    layout.setMargins(QMarginsF(36, 36, 36, 36));
    printer.setPageLayout(layout);
    QPrintDialog dialog(&printer, this);
    dialog.setWindowTitle(I18n::t("file.print"));
    if (dialog.exec() != QDialog::Accepted)
        return;
    QPainter painter(&printer);
    const QRectF page = printer.pageRect(QPrinter::DevicePixel);
    QImage scaled = img.scaled(page.size().toSize(), Qt::KeepAspectRatio, Qt::SmoothTransformation);
    const QPointF origin(page.x() + (page.width() - scaled.width()) / 2.0,
                         page.y() + (page.height() - scaled.height()) / 2.0);
    painter.drawImage(origin, scaled);
}

void MainWindow::trashImage()
{
    const QString path = m_pager.currentPath();
    if (path.isEmpty())
        return;
    const QString name = QFileInfo(path).fileName();
    if (QMessageBox::question(this, I18n::t("file.trashAsk"),
                              I18n::t("file.trashNamed").arg(name),
                              QMessageBox::Yes | QMessageBox::No, QMessageBox::No)
        != QMessageBox::Yes)
        return;
#if QT_VERSION >= QT_VERSION_CHECK(5, 15, 0)
    if (!QFile::moveToTrash(path)) {
        QFile::remove(path);
    }
#else
    QFile::remove(path);
#endif
    const QString dir = m_pager.directory();
    m_session.clear();
    if (!m_pager.open(dir) || m_pager.isEmpty()) {
        updateChrome();
        return;
    }
    loadCurrent();
}

void MainWindow::copyImage()
{
    if (!m_session.hasImage())
        return;
    QGuiApplication::clipboard()->setImage(m_session.composite());
}

void MainWindow::copyPath()
{
    if (m_session.path().isEmpty())
        return;
    QGuiApplication::clipboard()->setText(m_session.path());
}

void MainWindow::showColorAdjust()
{
    if (!m_colorDialog)
        m_colorDialog = new ColorAdjustDialog(&m_session, this);
    m_session.beginColorAdjust();
    m_colorDialog->retranslate();
    m_colorDialog->show();
    m_colorDialog->raise();
}

void MainWindow::showSizeAdjust()
{
    delete m_sizeDialog;
    m_sizeDialog = new SizeAdjustDialog(&m_session, this);
    m_sizeDialog->retranslate();
    m_sizeDialog->show();
}

void MainWindow::showInspector()
{
    if (!m_inspectorDialog)
        m_inspectorDialog = new InspectorDialog(&m_session, this);
    m_inspectorDialog->refresh();
    m_inspectorDialog->show();
    m_inspectorDialog->raise();
}

void MainWindow::showTips()
{
    QDialog dialog(this);
    dialog.setWindowTitle(I18n::t("tips.title"));
    dialog.setModal(true);
    dialog.setMinimumWidth(500);
    auto* layout = new QVBoxLayout(&dialog);
    layout->setContentsMargins(20, 16, 20, 12);
    layout->setSpacing(12);
    auto* label = new QLabel(I18n::t("tips.body"), &dialog);
    label->setTextFormat(Qt::RichText);
    label->setWordWrap(true);
    label->setTextInteractionFlags(Qt::TextSelectableByMouse);
    label->setMinimumWidth(460);
    layout->addWidget(label);
    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Ok, &dialog);
    if (QPushButton* ok = buttons->button(QDialogButtonBox::Ok)) {
        ok->setText(I18n::t("tips.ok"));
        ok->setDefault(true);
    }
    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    layout->addWidget(buttons);
    dialog.adjustSize();
    dialog.exec();
}

void MainWindow::visitWebsite()
{
    QDesktopServices::openUrl(QUrl(QStringLiteral(FLIP_WEBSITE_URL)));
}

void MainWindow::showAbout()
{
    QDialog dialog(this);
    dialog.setWindowTitle(I18n::t("about.title"));
    dialog.setModal(true);
    auto* layout = new QVBoxLayout(&dialog);
    auto* label = new QLabel(I18n::t("about.body").arg(QStringLiteral(FLIP_VERSION)), &dialog);
    label->setTextFormat(Qt::RichText);
    label->setOpenExternalLinks(true);
    label->setWordWrap(true);
    label->setTextInteractionFlags(Qt::TextBrowserInteraction);
    layout->addWidget(label);
    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Ok, &dialog);
    connect(buttons, &QDialogButtonBox::accepted, &dialog, &QDialog::accept);
    layout->addWidget(buttons);
    dialog.resize(560, 320);
    dialog.exec();
}

void MainWindow::restoreGeometryFromSettings()
{
    QSettings settings;
    const QByteArray geo = settings.value(QStringLiteral("geometry")).toByteArray();
    if (!geo.isEmpty())
        restoreGeometry(geo);
}

void MainWindow::showEvent(QShowEvent* event)
{
    QMainWindow::showEvent(event);
    if (m_didLaunchPrompts)
        return;
    m_didLaunchPrompts = true;
    QTimer::singleShot(0, this, [this] { runLaunchPrompts(this); });
}

void MainWindow::closeEvent(QCloseEvent* event)
{
    if (!confirmDiscard()) {
        event->ignore();
        return;
    }
    QSettings().setValue(QStringLiteral("geometry"), saveGeometry());
    QMainWindow::closeEvent(event);
}

void MainWindow::keyPressEvent(QKeyEvent* event)
{
    switch (event->key()) {
    case Qt::Key_Left:
    case Qt::Key_Up:
    case Qt::Key_PageUp:
        goPrevious();
        return;
    case Qt::Key_Right:
    case Qt::Key_Down:
    case Qt::Key_PageDown:
    case Qt::Key_Space:
        goNext();
        return;
    case Qt::Key_Home:
        goFirst();
        return;
    case Qt::Key_End:
        goLast();
        return;
    case Qt::Key_Escape:
        if (isFullScreen()) {
            m_fullScreenAction->setChecked(false);
            showNormal();
            return;
        }
        break;
    default:
        break;
    }
    QMainWindow::keyPressEvent(event);
}

void MainWindow::dragEnterEvent(QDragEnterEvent* event)
{
    if (event->mimeData()->hasUrls())
        event->acceptProposedAction();
}

void MainWindow::dropEvent(QDropEvent* event)
{
    QStringList paths;
    for (const QUrl& url : event->mimeData()->urls()) {
        if (url.isLocalFile())
            paths << url.toLocalFile();
    }
    handleDropped(paths);
}

void MainWindow::changeEvent(QEvent* event)
{
    if (event->type() == QEvent::LanguageChange)
        retranslateUi();
    QMainWindow::changeEvent(event);
}

void MainWindow::resizeEvent(QResizeEvent* event)
{
    QMainWindow::resizeEvent(event);
}
