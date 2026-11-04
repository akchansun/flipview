#include "AppInfo.h"
#include "I18n.h"
#include "MainWindow.h"
#include "SelfTest.h"

#include <QCoreApplication>
#include <QApplication>
#include <QCommandLineParser>
#include <QFileInfo>
#include <QIcon>
#include <QSettings>
#include <cstdio>

int main(int argc, char* argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QCoreApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
#endif
    QApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral(FLIP_ORG_NAME));
    app.setOrganizationDomain(QStringLiteral(FLIP_ORG_DOMAIN));
    app.setApplicationName(QStringLiteral(FLIP_APP_NAME));
    app.setApplicationVersion(QStringLiteral(FLIP_VERSION));
    app.setWindowIcon(QIcon(QStringLiteral(":/icons/flip.svg")));
    QSettings::setDefaultFormat(QSettings::IniFormat);

    const QString pref = QSettings().value(QStringLiteral("language"), QStringLiteral("auto")).toString();
    if (pref == QLatin1String("zh_CN"))
        I18n::setLang(I18n::Lang::ZhCN);
    else if (pref == QLatin1String("en"))
        I18n::setLang(I18n::Lang::En);
    else
        I18n::setLang(I18n::Lang::Auto);
    app.setApplicationDisplayName(I18n::t("app.name"));

    QCommandLineParser parser;
    parser.setApplicationDescription(I18n::t("empty.sub"));
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addPositionalArgument(QStringLiteral("path"), I18n::t("dialog.openImage"),
                                 QStringLiteral("[path]"));
    QCommandLineOption selfTest(QStringLiteral("self-test"),
                                QStringLiteral("Run built-in smoke tests and exit"));
    parser.addOption(selfTest);
    parser.process(app);

    if (parser.isSet(selfTest))
        return runSelfTest();

    MainWindow window;
    const QStringList pos = parser.positionalArguments();
    if (!pos.isEmpty()) {
        const QFileInfo info(pos.first());
        window.openPath(info.exists() ? info.absoluteFilePath() : pos.first());
    }
    window.show();
    return app.exec();
}
