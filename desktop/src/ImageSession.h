#pragma once

#include "ImageOps.h"
#include "Markup.h"

#include <QImage>
#include <QObject>
#include <QString>
#include <QVector>
#include <optional>

struct FileInfo {
    QString fileName;
    QString path;
    qint64 bytes = 0;
    QString format;
    QSize pixels;
    QString colorSpace;
    QString dpi;
    QString profile;
    QString camera;
    QString lens;
    QString exposure;
    QString captured;
};

class ImageSession : public QObject
{
    Q_OBJECT

public:
    explicit ImageSession(QObject* parent = nullptr);

    bool openPath(const QString& path);
    bool openImage(const QImage& image, const QString& suggestedName);
    void clear();

    bool hasImage() const { return !m_source.isNull(); }
    bool isDirty() const;
    QString path() const { return m_path; }
    QString fileName() const;
    QImage displayed() const { return m_displayed; }
    QSize pixelSize() const { return m_displayed.size(); }
    FileInfo inspector() const { return m_info; }

    void apply(const ImageOp& op);
    void beginColorAdjust();
    void setLiveColor(const ColorAdjust& color);
    void commitColor();
    ColorAdjust liveColor() const { return m_liveColor; }
    void applyResize(int w, int h);
    void applyCrop();
    void selectAllCrop();
    void removeBackground();
    void undo();
    void revert();
    bool canUndo() const { return !m_undo.isEmpty(); }

    bool save();
    bool saveAs(const QString& path);
    QImage composite() const;

    MarkupTool tool() const { return m_tool; }
    void setTool(MarkupTool tool);
    MarkupColor color() const { return m_color; }
    MarkupWeight weight() const { return m_weight; }
    MarkupFontSize fontSize() const { return m_fontSize; }
    bool filled() const { return m_filled; }
    void setColor(MarkupColor c);
    void setWeight(MarkupWeight w);
    void setFontSize(MarkupFontSize s);
    void setFilled(bool on);
    void setTextBackground(bool on);

    QVector<MarkupItem> items() const { return m_items; }
    QString selectedId() const { return m_selected; }
    void select(const QString& id);
    void addDraft(const MarkupItem& item);
    void updateDraft(const MarkupItem& item);
    void commitDraft();
    void cancelDraft();
    void restyleSelected();
    void removeSelected();
    MarkupItem* mutableSelected();
    MarkupItem* mutableItem(const QString& id);

    std::optional<QRectF> cropSelection() const { return m_crop; }
    void setCropSelection(const std::optional<QRectF>& frac);

    bool showAdjustColor = false;
    bool showAdjustSize = false;
    bool showInspector = false;

signals:
    void changed();
    void requestZoomFit();

private:
    struct UndoFrame {
        QVector<ImageOp> ops;
        QVector<MarkupItem> items;
    };

    void rebuildDisplayed();
    void pushUndo();
    void fillInfo();
    void syncToolbarFromSelection();
    QImage fullComposite() const;

    QString m_path;
    QImage m_source;
    QImage m_displayed;
    QVector<ImageOp> m_ops;
    QVector<MarkupItem> m_items;
    QVector<UndoFrame> m_undo;
    MarkupTool m_tool = MarkupTool::Browse;
    MarkupColor m_color = MarkupColor::Red;
    MarkupWeight m_weight = MarkupWeight::Regular;
    MarkupFontSize m_fontSize = MarkupFontSize::Regular;
    bool m_filled = false;
    QString m_selected;
    std::optional<QRectF> m_crop;
    ColorAdjust m_liveColor;
    bool m_colorPushed = false;
    FileInfo m_info;
};
