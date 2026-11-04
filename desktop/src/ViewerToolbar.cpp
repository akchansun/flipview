#include "ViewerToolbar.h"

#include "I18n.h"
#include "ToolIcons.h"
#include "ToolbarLayout.h"

#include <QButtonGroup>
#include <QFrame>
#include <QHBoxLayout>
#include <QMenu>
#include <QResizeEvent>
#include <QToolButton>
#include <QVBoxLayout>

namespace {
QToolButton* styledButton(QWidget* parent)
{
    auto* b = new QToolButton(parent);
    b->setAutoRaise(true);
    b->setIconSize(QSize(16, 16));
    b->setFixedSize(28, 24);
    b->setFocusPolicy(Qt::NoFocus);
    return b;
}
} // namespace

ViewerToolbar::ViewerToolbar(ImageSession* session, HoverTip* tip, QWidget* parent)
    : QWidget(parent)
    , m_session(session)
    , m_tip(tip)
{
    setSizePolicy(QSizePolicy::Ignored, QSizePolicy::Fixed);
    setMinimumWidth(200);
    m_root = new QVBoxLayout(this);
    m_root->setContentsMargins(0, 0, 0, 0);
    m_root->setSpacing(0);
    m_mainRow = new QWidget(this);
    m_markupRow = new QWidget(this);
    m_root->addWidget(m_mainRow);
    auto* line = new QFrame(this);
    line->setFrameShape(QFrame::HLine);
    line->setFixedHeight(1);
    m_root->addWidget(line);
    m_root->addWidget(m_markupRow);
    rebuild();
}

QToolButton* ViewerToolbar::makeButton(const char* iconName, const char* tipKey)
{
    QToolButton* b = styledButton(this);
    b->setIcon(ToolIcons::icon(iconName));
    attachTip(b, tipKey);
    return b;
}

void ViewerToolbar::attachTip(QToolButton* button, const char* key)
{
    button->setProperty("tipKey", QByteArray(key));
    button->setToolTip(QString());
    button->installEventFilter(this);
}

void ViewerToolbar::addHairline(QHBoxLayout* row)
{
    auto* line = new QFrame(this);
    line->setFixedSize(1, 16);
    line->setStyleSheet(QStringLiteral("background: rgba(0,0,0,40);"));
    row->addSpacing(5);
    row->addWidget(line);
    row->addSpacing(5);
}

bool ViewerToolbar::eventFilter(QObject* watched, QEvent* event)
{
    auto* button = qobject_cast<QToolButton*>(watched);
    if (button && m_tip) {
        if (event->type() == QEvent::Enter) {
            const QByteArray key = button->property("tipKey").toByteArray();
            const QPoint g(button->mapToGlobal(QPoint(button->width() / 2, button->height() + 12)));
            m_tip->schedule(I18n::t(key.constData()), g);
        } else if (event->type() == QEvent::Leave) {
            m_tip->hideSoon();
        }
    }
    return QWidget::eventFilter(watched, event);
}

void ViewerToolbar::resizeEvent(QResizeEvent* event)
{
    QWidget::resizeEvent(event);
    if (event->size().width() != m_barWidth) {
        m_barWidth = event->size().width();
        rebuild();
    }
}

void ViewerToolbar::retranslate()
{
    rebuild();
}

void ViewerToolbar::refresh()
{
    if (width() > 0)
        m_barWidth = width();
    rebuild();
}

void ViewerToolbar::rebuild()
{
    if (width() > 0)
        m_barWidth = width();
    else if (m_barWidth <= 0)
        m_barWidth = 1100;

    qDeleteAll(m_mainRow->findChildren<QWidget*>(QString(), Qt::FindDirectChildrenOnly));
    qDeleteAll(m_markupRow->findChildren<QWidget*>(QString(), Qt::FindDirectChildrenOnly));
    delete m_mainRow->layout();
    delete m_markupRow->layout();

    auto* main = new QHBoxLayout(m_mainRow);
    main->setContentsMargins(8, 5, 8, 5);
    main->setSpacing(3);
    main->setSizeConstraint(QLayout::SetNoConstraint);
    m_mainRow->setFixedHeight(38);
    m_mainRow->setSizePolicy(QSizePolicy::Ignored, QSizePolicy::Fixed);

    const bool hasImage = m_session && m_session->hasImage();
    const bool canNav = hasImage; // pager gating is done by MainWindow enabling signals
    auto enable = [&](QToolButton* b, bool on) {
        b->setEnabled(on);
        b->setStyleSheet(on ? QString() : QStringLiteral("QToolButton { color: rgba(0,0,0,90); }"));
    };

    auto add = [&](QHBoxLayout* row, const char* icon, const char* key, auto handler, bool on = true) {
        QToolButton* b = makeButton(icon, key);
        enable(b, on && hasImage);
        connect(b, &QToolButton::clicked, this, handler);
        row->addWidget(b);
        return b;
    };

    Q_UNUSED(canNav);
    add(main, "prev", "view.previous", [this] { emit previousRequested(); }, true);
    add(main, "next", "view.next", [this] { emit nextRequested(); }, true);
    addHairline(main);
    add(main, "zoomOut", "view.zoomOut", [this] { emit zoomOutRequested(); });
    add(main, "fit", "view.fitDefault", [this] { emit zoomFitRequested(); });
    add(main, "zoomIn", "view.zoomIn", [this] { emit zoomInRequested(); });
    add(main, "actual", "view.actualSize", [this] { emit zoomActualRequested(); });
    addHairline(main);
    add(main, "rotateLeft", "image.rotateLeft", [this] {
        if (m_session)
            m_session->apply(ImageOp::rotateLeft());
    });

    QMenu* overflow = nullptr;
    auto overflowOrAdd = [&](bool visible, const char* icon, const char* key, auto handler) {
        if (visible) {
            add(main, icon, key, handler);
        } else {
            if (!overflow)
                overflow = new QMenu(this);
            overflow->addAction(ToolIcons::icon(icon), I18n::t(key), this, handler);
        }
    };

    overflowOrAdd(ToolbarLayout::showsRotateRight(m_barWidth), "rotateRight", "image.rotateRight", [this] {
        if (m_session)
            m_session->apply(ImageOp::rotateRight());
    });
    overflowOrAdd(ToolbarLayout::showsFlip(m_barWidth), "flipH", "image.flipH", [this] {
        if (m_session)
            m_session->apply(ImageOp::flipHorizontal());
    });
    overflowOrAdd(ToolbarLayout::showsFlip(m_barWidth), "flipV", "image.flipV", [this] {
        if (m_session)
            m_session->apply(ImageOp::flipVertical());
    });

    QToolButton* markup = add(main, "markup", "toolbar.markup", [this] {
        if (!m_session || !m_session->hasImage())
            return;
        if (isMarkupInk(m_session->tool()))
            m_session->setTool(MarkupTool::Browse);
        else
            m_session->setTool(MarkupTool::Pen);
    }, true);
    markup->setCheckable(true);
    markup->setChecked(m_session && isMarkupInk(m_session->tool()));
    enable(markup, hasImage);

    QToolButton* crop = add(main, "crop",
                            (m_session && m_session->cropSelection()) ? "tool.crop" : "image.crop", [this] {
                                if (!m_session || !m_session->hasImage())
                                    return;
                                if (m_session->tool() == MarkupTool::Crop && m_session->cropSelection())
                                    m_session->applyCrop();
                                else
                                    m_session->setTool(MarkupTool::Crop);
                            });
    crop->setCheckable(true);
    crop->setChecked(m_session && m_session->tool() == MarkupTool::Crop);

    overflowOrAdd(ToolbarLayout::showsAdjustExtras(m_barWidth), "adjustColor", "adjust.color",
                  [this] { emit adjustColorRequested(); });
    overflowOrAdd(ToolbarLayout::showsAdjustExtras(m_barWidth), "adjustSize", "adjust.size",
                  [this] { emit adjustSizeRequested(); });
    overflowOrAdd(ToolbarLayout::showsInspectorExtras(m_barWidth), "inspector", "inspector",
                  [this] { emit inspectorRequested(); });
    overflowOrAdd(ToolbarLayout::showsInspectorExtras(m_barWidth), "removeBg", "image.removeBg", [this] {
        if (m_session)
            m_session->removeBackground();
    });

    if (ToolbarLayout::hasOverflow(m_barWidth) && overflow) {
        QToolButton* more = makeButton("more", "toolbar.more");
        more->setMenu(overflow);
        more->setPopupMode(QToolButton::InstantPopup);
        enable(more, hasImage);
        main->addWidget(more);
    } else {
        delete overflow;
    }

    main->addSpacing(8);
    main->addStretch(1);
    add(main, "undo", "edit.undo", [this] { emit undoRequested(); }, m_session && m_session->canUndo());
    add(main, "save", "file.save", [this] { emit saveRequested(); });
    add(main, "saveAs", "file.saveAs", [this] { emit saveAsRequested(); });
    add(main, "print", "file.print", [this] { emit printRequested(); });
    add(main, "trash", "file.trash", [this] { emit trashRequested(); });

    const bool markupOn = m_session && isMarkupInk(m_session->tool());
    m_markupRow->setVisible(markupOn);
    if (m_root->itemAt(1))
        m_root->itemAt(1)->widget()->setVisible(markupOn);
    if (!markupOn)
        return;

    auto* ink = new QHBoxLayout(m_markupRow);
    ink->setContentsMargins(8, 5, 8, 5);
    ink->setSpacing(3);
    ink->setSizeConstraint(QLayout::SetNoConstraint);
    m_markupRow->setFixedHeight(38);
    m_markupRow->setSizePolicy(QSizePolicy::Ignored, QSizePolicy::Fixed);

    auto inkBtn = [&](MarkupTool tool, const char* icon, const char* key) {
        QToolButton* b = makeButton(icon, key);
        b->setCheckable(true);
        b->setChecked(m_session && m_session->tool() == tool);
        enable(b, hasImage);
        connect(b, &QToolButton::clicked, this, [this, tool] {
            if (m_session)
                m_session->setTool(tool);
        });
        ink->addWidget(b);
    };
    inkBtn(MarkupTool::Pen, "pen", "tool.pen");
    inkBtn(MarkupTool::Line, "line", "tool.line");
    inkBtn(MarkupTool::Arrow, "arrow", "tool.arrow");
    inkBtn(MarkupTool::Rect, "rect", "tool.rect");
    inkBtn(MarkupTool::RoundRect, "roundRect", "tool.roundRect");
    inkBtn(MarkupTool::Oval, "oval", "tool.oval");
    inkBtn(MarkupTool::Highlight, "highlight", "tool.highlight");
    inkBtn(MarkupTool::Text, "text", "tool.text");
    addHairline(ink);

    const bool expanded = ToolbarLayout::showsMarkupStylesExpanded(m_barWidth);

    auto colorMenu = [this](QToolButton* host) {
        auto* menu = new QMenu(host);
        const MarkupColor colors[] = {MarkupColor::Red, MarkupColor::Orange, MarkupColor::Yellow,
                                      MarkupColor::Green, MarkupColor::Blue, MarkupColor::White,
                                      MarkupColor::Black};
        const char* keys[] = {"color.red", "color.orange", "color.yellow", "color.green",
                              "color.blue", "color.white", "color.black"};
        for (int i = 0; i < 7; ++i) {
            menu->addAction(ToolIcons::colorDot(colors[i], m_session && m_session->color() == colors[i]),
                            I18n::t(keys[i]), this, [this, colors, i] {
                                if (m_session)
                                    m_session->setColor(colors[i]);
                            });
        }
        return menu;
    };

    if (expanded) {
        QToolButton* fill = makeButton(m_session && m_session->filled() ? "fill" : "stroke",
                                       m_session && m_session->filled() ? "markup.fill" : "markup.stroke");
        fill->setCheckable(true);
        fill->setChecked(m_session && m_session->filled());
        connect(fill, &QToolButton::clicked, this, [this] {
            if (m_session)
                m_session->setFilled(!m_session->filled());
        });
        ink->addWidget(fill);

        QToolButton* textBg = styledButton(this);
        textBg->setIcon(ToolIcons::textBackground(m_session && m_session->filled()));
        attachTip(textBg, "markup.textBg");
        connect(textBg, &QToolButton::clicked, this, [this] {
            if (m_session)
                m_session->setTextBackground(!(m_session->filled()));
        });
        ink->addWidget(textBg);

        const MarkupColor colors[] = {MarkupColor::Red, MarkupColor::Orange, MarkupColor::Yellow,
                                      MarkupColor::Green, MarkupColor::Blue, MarkupColor::White,
                                      MarkupColor::Black};
        for (MarkupColor c : colors) {
            QToolButton* dot = styledButton(this);
            dot->setIcon(ToolIcons::colorDot(c, m_session && m_session->color() == c));
            attachTip(dot, "markup.color");
            connect(dot, &QToolButton::clicked, this, [this, c] {
                if (m_session)
                    m_session->setColor(c);
            });
            ink->addWidget(dot);
        }
    } else {
        QToolButton* well = styledButton(this);
        well->setIcon(ToolIcons::colorDot(m_session ? m_session->color() : MarkupColor::Red, true));
        attachTip(well, "markup.color");
        well->setMenu(colorMenu(well));
        well->setPopupMode(QToolButton::InstantPopup);
        ink->addWidget(well);
    }

    QToolButton* weight = styledButton(this);
    weight->setIcon(ToolIcons::weightSample(m_session ? m_session->weight() : MarkupWeight::Regular, 18));
    attachTip(weight, "markup.weight");
    auto* wMenu = new QMenu(weight);
    const MarkupWeight weights[] = {MarkupWeight::Thin, MarkupWeight::Regular, MarkupWeight::Thick,
                                    MarkupWeight::Heavy};
    const char* wKeys[] = {"weight.thin", "weight.regular", "weight.thick", "weight.heavy"};
    for (int i = 0; i < 4; ++i) {
        wMenu->addAction(ToolIcons::weightSample(weights[i], 88), I18n::t(wKeys[i]), this, [this, weights, i] {
            if (m_session)
                m_session->setWeight(weights[i]);
        });
    }
    weight->setMenu(wMenu);
    weight->setPopupMode(QToolButton::InstantPopup);
    ink->addWidget(weight);

    if (expanded) {
        const MarkupFontSize fonts[] = {MarkupFontSize::Small, MarkupFontSize::Regular, MarkupFontSize::Large,
                                        MarkupFontSize::Extra};
        const char* fKeys[] = {"font.small", "font.regular", "font.large", "font.extra"};
        for (int i = 0; i < 4; ++i) {
            QToolButton* f = styledButton(this);
            f->setIcon(ToolIcons::fontSample(fonts[i]));
            attachTip(f, fKeys[i]);
            f->setCheckable(true);
            f->setChecked(m_session && m_session->fontSize() == fonts[i]);
            connect(f, &QToolButton::clicked, this, [this, fonts, i] {
                if (m_session)
                    m_session->setFontSize(fonts[i]);
            });
            ink->addWidget(f);
        }
    } else {
        QToolButton* font = makeButton("text", "markup.font");
        auto* fMenu = new QMenu(font);
        const MarkupFontSize fonts[] = {MarkupFontSize::Small, MarkupFontSize::Regular, MarkupFontSize::Large,
                                        MarkupFontSize::Extra};
        const char* fKeys[] = {"font.small", "font.regular", "font.large", "font.extra"};
        for (int i = 0; i < 4; ++i) {
            fMenu->addAction(I18n::t(fKeys[i]), this, [this, fonts, i] {
                if (m_session)
                    m_session->setFontSize(fonts[i]);
            });
        }
        font->setMenu(fMenu);
        font->setPopupMode(QToolButton::InstantPopup);
        ink->addWidget(font);
        QToolButton* fill = makeButton(m_session && m_session->filled() ? "fill" : "stroke", "markup.fill");
        connect(fill, &QToolButton::clicked, this, [this] {
            if (m_session)
                m_session->setFilled(!m_session->filled());
        });
        ink->addWidget(fill);
        QToolButton* textBg = styledButton(this);
        textBg->setIcon(ToolIcons::textBackground(m_session && m_session->filled()));
        attachTip(textBg, "markup.textBg");
        connect(textBg, &QToolButton::clicked, this, [this] {
            if (m_session)
                m_session->setTextBackground(!(m_session->filled()));
        });
        ink->addWidget(textBg);
    }
    ink->addStretch(1);
}
