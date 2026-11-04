#include "EditDialogs.h"

#include "I18n.h"

#include <QCheckBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QLocale>
#include <QPushButton>
#include <QSlider>
#include <QSpinBox>
#include <QVariant>
#include <QVBoxLayout>
#include <algorithm>
#include <cmath>

namespace {
QString fmtBytes(qint64 n)
{
    if (n < 1024)
        return QStringLiteral("%1 B").arg(n);
    if (n < 1024 * 1024)
        return QStringLiteral("%1 KB").arg(n / 1024.0, 0, 'f', 1);
    return QStringLiteral("%1 MB").arg(n / (1024.0 * 1024.0), 0, 'f', 1);
}
} // namespace

ColorAdjustDialog::ColorAdjustDialog(ImageSession* session, QWidget* parent)
    : QDialog(parent)
    , m_session(session)
{
    setWindowFlag(Qt::Tool, true);
    resize(280, 0);
    auto* layout = new QFormLayout(this);
    layout->setContentsMargins(14, 14, 14, 14);
    addSlider("adjust.exposure", -2, 2, &m_draft.exposure);
    addSlider("adjust.contrast", 0.5, 2, &m_draft.contrast);
    addSlider("adjust.brightness", -0.5, 0.5, &m_draft.brightness);
    addSlider("adjust.saturation", 0, 2, &m_draft.saturation);
    addSlider("adjust.highlights", 0, 1, &m_draft.highlights);
    addSlider("adjust.shadows", -1, 1, &m_draft.shadows);
    addSlider("adjust.temperature", -1, 1, &m_draft.temperature);
    addSlider("adjust.tint", -1, 1, &m_draft.tint);
    addSlider("adjust.sepia", 0, 1, &m_draft.sepia);
    addSlider("adjust.sharpness", 0, 2, &m_draft.sharpness);
    m_autoLevels = new QCheckBox(this);
    connect(m_autoLevels, &QCheckBox::toggled, this, [this](bool on) {
        m_draft.autoLevels = on;
        emitLive();
    });
    layout->addRow(m_autoLevels);
    auto* reset = new QPushButton(this);
    connect(reset, &QPushButton::clicked, this, [this] {
        m_draft = {};
        m_autoLevels->setChecked(false);
        emitLive();
        retranslate();
    });
    layout->addRow(reset);
    reset->setObjectName(QStringLiteral("reset"));
    retranslate();
}

QSlider* ColorAdjustDialog::addSlider(const char* key, double min, double max, double* field, int)
{
    auto* slider = new QSlider(Qt::Horizontal, this);
    slider->setRange(0, 200);
    slider->setProperty("key", QByteArray(key));
    slider->setProperty("min", min);
    slider->setProperty("max", max);
    auto* label = new QLabel(this);
    label->setObjectName(QString::fromLatin1(key));
    auto* row = new QHBoxLayout;
    row->addWidget(slider, 1);
    qobject_cast<QFormLayout*>(layout())->addRow(label, slider);
    connect(slider, &QSlider::valueChanged, this, [this, slider, field, min, max](int v) {
        *field = min + (max - min) * (v / 200.0);
        emitLive();
    });
    slider->setProperty("fieldPtr", QVariant::fromValue(static_cast<void*>(field)));
    Q_UNUSED(row);
    return slider;
}

void ColorAdjustDialog::emitLive()
{
    if (m_session)
        m_session->setLiveColor(m_draft);
}

void ColorAdjustDialog::syncFromSession()
{
    if (!m_session)
        return;
    m_draft = m_session->liveColor();
    m_autoLevels->setChecked(m_draft.autoLevels);
    const auto sliders = findChildren<QSlider*>();
    for (QSlider* slider : sliders) {
        const double min = slider->property("min").toDouble();
        const double max = slider->property("max").toDouble();
        auto* field = static_cast<double*>(slider->property("fieldPtr").value<void*>());
        if (!field || max <= min)
            continue;
        slider->blockSignals(true);
        slider->setValue(int(std::lround((*field - min) / (max - min) * 200.0)));
        slider->blockSignals(false);
    }
}

void ColorAdjustDialog::retranslate()
{
    setWindowTitle(I18n::t("adjust.color"));
    auto setLabel = [this](const char* key) {
        if (auto* lab = findChild<QLabel*>(QString::fromLatin1(key)))
            lab->setText(I18n::t(key));
    };
    setLabel("adjust.exposure");
    setLabel("adjust.contrast");
    setLabel("adjust.brightness");
    setLabel("adjust.saturation");
    setLabel("adjust.highlights");
    setLabel("adjust.shadows");
    setLabel("adjust.temperature");
    setLabel("adjust.tint");
    setLabel("adjust.sepia");
    setLabel("adjust.sharpness");
    if (m_autoLevels)
        m_autoLevels->setText(I18n::t("adjust.autoLevels"));
    if (auto* reset = findChild<QPushButton*>(QStringLiteral("reset")))
        reset->setText(I18n::t("adjust.reset"));
    syncFromSession();
}

SizeAdjustDialog::SizeAdjustDialog(ImageSession* session, QWidget* parent)
    : QDialog(parent)
    , m_session(session)
{
    setWindowFlag(Qt::Tool, true);
    auto* form = new QFormLayout(this);
    form->setContentsMargins(20, 20, 20, 20);
    m_width = new QSpinBox(this);
    m_height = new QSpinBox(this);
    m_percent = new QSpinBox(this);
    m_width->setRange(1, 20000);
    m_height->setRange(1, 20000);
    m_percent->setRange(1, 400);
    m_keep = new QCheckBox(this);
    m_keep->setChecked(true);
    form->addRow(I18n::t("adjust.width"), m_width);
    form->addRow(I18n::t("adjust.height"), m_height);
    form->addRow(I18n::t("adjust.percent"), m_percent);
    form->addRow(m_keep);
    auto* presets = new QHBoxLayout;
    auto addPreset = [&](const QString& label, auto fn) {
        auto* b = new QPushButton(label, this);
        connect(b, &QPushButton::clicked, this, fn);
        presets->addWidget(b);
    };
    addPreset(QStringLiteral("640"), [this] {
        const int longEdge = std::max(m_width->value(), m_height->value());
        const double s = 640.0 / std::max(1, longEdge);
        onWidth(std::max(1, int(m_original.width() * (640.0 / std::max(1, std::max(m_original.width(), m_original.height()))))));
        Q_UNUSED(s);
    });
    addPreset(QStringLiteral("1024"), [this] { onPercent(int(1024.0 / std::max(1, std::max(m_original.width(), m_original.height())) * 100)); });
    addPreset(QStringLiteral("1920"), [this] { onPercent(int(1920.0 / std::max(1, std::max(m_original.width(), m_original.height())) * 100)); });
    addPreset(QStringLiteral("50%"), [this] { onPercent(50); });
    addPreset(QStringLiteral("100%"), [this] { onPercent(100); });
    form->addRow(presets);
    auto* buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel, this);
    connect(buttons, &QDialogButtonBox::accepted, this, [this] {
        if (m_session)
            m_session->applyResize(m_width->value(), m_height->value());
        accept();
    });
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
    form->addRow(buttons);
    connect(m_width, qOverload<int>(&QSpinBox::valueChanged), this, &SizeAdjustDialog::onWidth);
    connect(m_height, qOverload<int>(&QSpinBox::valueChanged), this, &SizeAdjustDialog::onHeight);
    connect(m_percent, qOverload<int>(&QSpinBox::valueChanged), this, &SizeAdjustDialog::onPercent);
    seed();
    retranslate();
}

void SizeAdjustDialog::seed()
{
    if (!m_session)
        return;
    m_original = m_session->pixelSize();
    m_aspect = m_original.height() > 0 ? double(m_original.width()) / double(m_original.height()) : 1;
    m_width->blockSignals(true);
    m_height->blockSignals(true);
    m_percent->blockSignals(true);
    m_width->setValue(std::max(1, m_original.width()));
    m_height->setValue(std::max(1, m_original.height()));
    m_percent->setValue(100);
    m_width->blockSignals(false);
    m_height->blockSignals(false);
    m_percent->blockSignals(false);
}

void SizeAdjustDialog::onWidth(int w)
{
    if (m_keep->isChecked() && m_aspect > 0)
        m_height->blockSignals(true), m_height->setValue(std::max(1, int(std::lround(w / m_aspect)))),
            m_height->blockSignals(false);
    if (m_original.width() > 0) {
        m_percent->blockSignals(true);
        m_percent->setValue(std::max(1, int(std::lround(w * 100.0 / m_original.width()))));
        m_percent->blockSignals(false);
    }
}

void SizeAdjustDialog::onHeight(int h)
{
    if (m_keep->isChecked() && m_aspect > 0)
        m_width->blockSignals(true), m_width->setValue(std::max(1, int(std::lround(h * m_aspect)))),
            m_width->blockSignals(false);
}

void SizeAdjustDialog::onPercent(int p)
{
    m_width->blockSignals(true);
    m_height->blockSignals(true);
    m_width->setValue(std::max(1, int(std::lround(m_original.width() * p / 100.0))));
    m_height->setValue(std::max(1, int(std::lround(m_original.height() * p / 100.0))));
    m_width->blockSignals(false);
    m_height->blockSignals(false);
}

void SizeAdjustDialog::retranslate()
{
    setWindowTitle(I18n::t("adjust.size"));
    if (auto* form = qobject_cast<QFormLayout*>(layout())) {
        if (auto* lab = qobject_cast<QLabel*>(form->labelForField(m_width)))
            lab->setText(I18n::t("adjust.width"));
        if (auto* lab = qobject_cast<QLabel*>(form->labelForField(m_height)))
            lab->setText(I18n::t("adjust.height"));
        if (auto* lab = qobject_cast<QLabel*>(form->labelForField(m_percent)))
            lab->setText(I18n::t("adjust.percent"));
    }
    m_keep->setText(I18n::t("adjust.keepAspect"));
}

InspectorDialog::InspectorDialog(ImageSession* session, QWidget* parent)
    : QDialog(parent)
    , m_session(session)
{
    setWindowFlag(Qt::Tool, true);
    setMinimumWidth(280);
    auto* layout = new QVBoxLayout(this);
    layout->setContentsMargins(14, 14, 14, 14);
    m_body = new QLabel(this);
    m_body->setTextInteractionFlags(Qt::TextSelectableByMouse);
    m_body->setWordWrap(true);
    layout->addWidget(m_body);
    retranslate();
}

void InspectorDialog::refresh()
{
    if (!m_session)
        return;
    const FileInfo info = m_session->inspector();
    auto row = [](const char* key, const QString& value) {
        if (value.isEmpty())
            return QString();
        return QStringLiteral("<tr><td align='right' width='84'><b>%1</b></td><td>%2</td></tr>")
            .arg(I18n::t(key).toHtmlEscaped(), value.toHtmlEscaped());
    };
    QString html = QStringLiteral("<table cellspacing='4'>");
    html += row("inspector.file", info.fileName);
    html += row("inspector.bytes", info.bytes > 0 ? fmtBytes(info.bytes) : QString());
    html += row("inspector.format", info.format);
    if (info.pixels.isValid())
        html += row("inspector.pixels", QStringLiteral("%1 × %2").arg(info.pixels.width()).arg(info.pixels.height()));
    html += row("inspector.color", info.colorSpace);
    html += row("inspector.dpi", info.dpi);
    html += row("inspector.profile", info.profile);
    html += row("inspector.camera", info.camera);
    html += row("inspector.lens", info.lens);
    html += row("inspector.exposure", info.exposure);
    html += row("inspector.captured", info.captured);
    html += QStringLiteral("</table>");
    m_body->setText(html);
}

void InspectorDialog::retranslate()
{
    setWindowTitle(I18n::t("inspector"));
    refresh();
}
