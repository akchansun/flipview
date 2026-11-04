#pragma once

#include "ImageSession.h"

#include <QDialog>
#include <QWidget>

class QCheckBox;
class QDoubleSpinBox;
class QLabel;
class QSlider;
class QSpinBox;

class ColorAdjustDialog : public QDialog
{
    Q_OBJECT
public:
    explicit ColorAdjustDialog(ImageSession* session, QWidget* parent = nullptr);
    void retranslate();

private:
    void syncFromSession();
    void emitLive();
    QSlider* addSlider(const char* key, double min, double max, double* field, int decimals = 2);

    ImageSession* m_session = nullptr;
    ColorAdjust m_draft;
    QCheckBox* m_autoLevels = nullptr;
};

class SizeAdjustDialog : public QDialog
{
    Q_OBJECT
public:
    explicit SizeAdjustDialog(ImageSession* session, QWidget* parent = nullptr);
    void retranslate();

private:
    void seed();
    void onWidth(int w);
    void onHeight(int h);
    void onPercent(int p);

    ImageSession* m_session = nullptr;
    QSpinBox* m_width = nullptr;
    QSpinBox* m_height = nullptr;
    QSpinBox* m_percent = nullptr;
    QCheckBox* m_keep = nullptr;
    QSize m_original;
    double m_aspect = 1;
};

class InspectorDialog : public QDialog
{
    Q_OBJECT
public:
    explicit InspectorDialog(ImageSession* session, QWidget* parent = nullptr);
    void refresh();
    void retranslate();

private:
    ImageSession* m_session = nullptr;
    QLabel* m_body = nullptr;
};
