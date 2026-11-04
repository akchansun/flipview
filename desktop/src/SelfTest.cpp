#include "SelfTest.h"

#include "AppInfo.h"
#include "DownloadRace.h"
#include "FitZoom.h"
#include "FolderPager.h"
#include "I18n.h"
#include "ImageOps.h"
#include "InPlaceUpdater.h"
#include "LaunchSettings.h"
#include "MainWindow.h"
#include "Markup.h"
#include "NaturalSort.h"
#include "ToolbarLayout.h"
#include "UpdateFeed.h"
#include "VersionCompare.h"

#include <QAction>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QKeySequence>
#include <QMenu>
#include <QMenuBar>
#include <QProcess>
#include <QSettings>
#include <QTemporaryDir>
#include <cmath>
#include <cstdio>

namespace {

int g_fails = 0;

void expect(bool cond, const char* msg)
{
    if (!cond) {
        std::fprintf(stderr, "FAIL: %s\n", msg);
        ++g_fails;
    } else {
        std::printf("ok  %s\n", msg);
    }
}

void expectNear(double actual, double expected, const char* msg)
{
    const bool ok = std::fabs(actual - expected) < 1e-9;
    if (!ok)
        std::fprintf(stderr, "FAIL: %s (got %f, expected %f)\n", msg, actual, expected);
    expect(ok, msg);
}

QImage solidImage(int w, int h, QRgb color)
{
    QImage img(w, h, QImage::Format_RGB32);
    img.fill(color);
    return img;
}

bool saveOrLog(const QImage& img, const QString& path)
{
    if (img.save(path))
        return true;
    std::fprintf(stderr, "note: could not write %s\n", qPrintable(path));
    return false;
}

} // namespace

int runSelfTest()
{
    std::printf("Flip self-test\n");

    expectNear(defaultFitScale(QSize(200, 150), QSize(800, 600)), 1.0, "small image stays 100%");
    expectNear(defaultFitScale(QSize(800, 600), QSize(800, 600)), 1.0, "exact fit stays 100%");
    expectNear(defaultFitScale(QSize(1920, 1080), QSize(800, 600)), 800.0 / 1920.0,
               "wide image scales down to width");
    expectNear(defaultFitScale(QSize(400, 1600), QSize(800, 600)), 600.0 / 1600.0,
               "tall image scales down to height");
    expect(defaultFitScale(QSize(4000, 3000), QSize(1000, 1000)) < 1.0, "large image never upscales");
    expectNear(defaultFitScale(QSize(10, 10), QSize(1000, 1000)), 1.0, "tiny image never upscales");

    expect(naturalLessThan(QStringLiteral("img2.png"), QStringLiteral("img10.png")),
           "natural sort 2 < 10");
    expect(naturalLessThan(QStringLiteral("img1.png"), QStringLiteral("img2.png")),
           "natural sort 1 < 2");
    expect(!naturalLessThan(QStringLiteral("img10.png"), QStringLiteral("img2.png")),
           "natural sort 10 not < 2");

    expect(QStringLiteral(FLIP_VERSION) == QStringLiteral("1.3.0"), "app version 1.3.0");
    qunsetenv("FLIP_UPDATE_FEED");
    expect(compareVersions(QStringLiteral("1.1.0"), QStringLiteral("1.0.0")) > 0, "1.1.0 > 1.0.0");
    expect(compareVersions(QStringLiteral("1.0.0"), QStringLiteral("1.1.0")) < 0, "1.0.0 < 1.1.0");
    expect(compareVersions(QStringLiteral("1.0"), QStringLiteral("1.0.0")) == 0, "1.0 == 1.0.0");
    expect(compareVersions(QStringLiteral("v1.2.0"), QStringLiteral("1.1.9")) > 0, "v1.2.0 > 1.1.9");
    expect(compareVersions(QStringLiteral("1.10.0"), QStringLiteral("1.9.0")) > 0, "1.10.0 > 1.9.0");
    expect(isNewerVersion(QStringLiteral("1.2.0"), QStringLiteral("1.1.0")), "remote 1.2.0 is newer");
    expect(!isNewerVersion(QStringLiteral("1.0.0"), QStringLiteral("1.1.0")), "older remote is not newer");
    expect(!isNewerVersion(QStringLiteral("1.1.0"), QStringLiteral("1.1.0")), "same version is not newer");
    expect(!isNewerVersion(QString(), QStringLiteral("1.1.0")), "empty remote is not newer");

    const QByteArray sampleJson = QByteArrayLiteral(
        "{\n"
        "  \"schema\": 1,\n"
        "  \"product\": \"Flip\",\n"
        "  \"linux\": {\n"
        "    \"version\": \"1.0.0\",\n"
        "    \"notes\": {\n"
        "      \"zh\": \"同目录翻页看图；方向键与边缘点击翻页。需 Qt 6 运行库。\",\n"
        "      \"en\": \"Same-folder image paging; arrow keys and edge click. Needs Qt 6 runtime.\"\n"
        "    },\n"
        "    \"download\": {\n"
        "      \"site\": \"https://www.ak129.cn/flip/#linux\",\n"
        "      \"gitee\": \"https://gitee.com/akcg/flip-linux/releases/tag/v1.0.0\",\n"
        "      \"github\": \"https://github.com/akchansun/flip-linux/releases/tag/v1.0.0\",\n"
        "      \"giteeAsset\": \"https://gitee.com/akcg/flip-linux/releases/download/v1.0.0/flip-linux-1.0.0-amd64.tar.gz\",\n"
        "      \"githubAsset\": \"https://github.com/akchansun/flip-linux/releases/download/v1.0.0/flip-linux-1.0.0-amd64.tar.gz\"\n"
        "    }\n"
        "  }\n"
        "}\n");
    LinuxRelease rel;
    expect(parseLinuxRelease(sampleJson, &rel), "parse linux version.json");
    expect(rel.version == QStringLiteral("1.0.0"), "parsed linux version");
    expect(rel.downloadGitee.contains(QStringLiteral("gitee.com")), "parsed gitee url");
    expect(rel.giteeAsset.contains(QStringLiteral("amd64.tar.gz")), "parsed gitee asset");
    expect(rel.githubAsset.contains(QStringLiteral("github.com")), "parsed github asset");
    expect(linuxAssetRaceUrls(rel).size() == 2, "race uses both asset URLs");
    expect(linuxAssetRaceUrls(rel).first() == rel.giteeAsset, "gitee asset raced first");
    expect(hasLinuxDownloadCandidate(rel), "sample json has download candidates");
    expect(probeHttpStatusOk(200) && probeHttpStatusOk(206) && probeHttpStatusOk(302),
           "2xx/3xx/206 probe ok");
    expect(!probeHttpStatusOk(404) && !probeHttpStatusOk(0), "404/0 probe not ok");
    {
        const QStringList chain = updateOpenUrlChain(rel, rel.giteeAsset);
        expect(!chain.isEmpty() && chain.first() == rel.giteeAsset, "winner asset first");
        expect(chain.contains(rel.githubAsset), "chain includes other asset");
        expect(chain.contains(rel.downloadGitee), "chain includes gitee release page");
        expect(chain.contains(rel.downloadGithub), "chain includes github release page");
        expect(chain.contains(rel.downloadSite), "chain includes site");
        expect(chain.size() == 5, "chain is winner, other asset, pages, site");
        const QStringList timeoutChain = updateOpenUrlChain(rel, QString());
        expect(timeoutChain.first() == rel.giteeAsset, "empty winner still tries assets before pages");
        expect(timeoutChain.size() == 5, "timeout chain has assets, pages, site");
        expect(timeoutChain.indexOf(rel.downloadGitee) > timeoutChain.indexOf(rel.githubAsset),
               "release pages come after assets");
        const QStringList rankedGithub = rankedAssetUrlChain(rel, rel.githubAsset);
        expect(rankedGithub.size() == 2 && rankedGithub.first() == rel.githubAsset
                   && rankedGithub.last() == rel.giteeAsset,
               "ranked assets are winner then other");
        expect(!rankedGithub.contains(rel.downloadSite) && !rankedGithub.contains(rel.downloadGitee),
               "ranked assets omit pages and site");
        const QStringList rankedEmpty = rankedAssetUrlChain(rel, QString());
        expect(rankedEmpty.size() == 2 && rankedEmpty.first() == rel.giteeAsset,
               "empty winner still ranks both assets");
    }
    LinuxRelease pagesOnly;
    const QByteArray noAssetJson = QByteArrayLiteral(
        "{\"linux\":{\"version\":\"1.0.0\",\"download\":{"
        "\"site\":\"https://www.ak129.cn/flip/#linux\","
        "\"gitee\":\"https://gitee.com/akcg/flip-linux/releases/tag/v1.0.0\","
        "\"github\":\"https://github.com/akchansun/flip-linux/releases/tag/v1.0.0\"}}}");
    expect(parseLinuxRelease(noAssetJson, &pagesOnly), "parse linux json without assets");
    expect(linuxAssetRaceUrls(pagesOnly).isEmpty(), "no assets means no race URLs");
    expect(rankedAssetUrlChain(pagesOnly, QString()).isEmpty(), "no assets means no ranked assets");
    expect(updateOpenUrlChain(pagesOnly, QString()).size() == 3,
           "without assets chain is pages then site");
    expect(hasLinuxDownloadCandidate(pagesOnly), "pages-only still has download candidates");
    expect(downloadProbeTimeoutMs() > 0 && downloadProbeTimeoutMs() < updateFeedTimeoutMs(),
           "probe timeout shorter than feed timeout");
    expect(!parseLinuxRelease(QByteArrayLiteral("{not json"), &rel), "reject invalid json");
    expect(!parseLinuxRelease(QByteArrayLiteral("{\"macos\":{}}"), &rel), "reject missing linux");
    expect(updateFeedUrl().toString().contains(QStringLiteral("/flip/version.json")),
           "default update feed url");

    {
        QTemporaryDir cfg;
        expect(cfg.isValid(), "settings temp dir");
        QSettings s(cfg.path() + QStringLiteral("/flip.ini"), QSettings::IniFormat);
        expect(LaunchSettings::shouldShowStartupTips(s), "tips shown by default");
        LaunchSettings::setStartupTipsDontShow(s, true);
        s.sync();
        QSettings s2(cfg.path() + QStringLiteral("/flip.ini"), QSettings::IniFormat);
        expect(!LaunchSettings::shouldShowStartupTips(s2), "tips dontShow persists");
        expect(s2.contains(LaunchSettings::tipsDontShowKey()), "tips settings key");
    }

    {
        QTemporaryDir cfg;
        expect(cfg.isValid(), "skipOnce settings temp dir");
        const QString ini = cfg.path() + QStringLiteral("/flip.ini");
        QSettings s(ini, QSettings::IniFormat);
        expect(!s.value(LaunchSettings::tipsSkipOnceKey(), false).toBool(),
               "skipOnce off by default");
        expect(!s.contains(LaunchSettings::tipsSkipOnceKey()), "skipOnce key absent by default");
        expect(LaunchSettings::shouldShowStartupTips(s), "tips shown when skipOnce unset");

        LaunchSettings::setSkipStartupTipsOnce(s, true);
        s.sync();
        QSettings s2(ini, QSettings::IniFormat);
        expect(s2.value(LaunchSettings::tipsSkipOnceKey(), false).toBool(), "skipOnce stored");
        expect(!LaunchSettings::shouldShowStartupTips(s2), "skipOnce hides tips once");
        expect(!s2.value(LaunchSettings::tipsSkipOnceKey(), false).toBool(),
               "skipOnce cleared after consume");
        s2.sync();
        QSettings s3(ini, QSettings::IniFormat);
        expect(LaunchSettings::shouldShowStartupTips(s3), "tips return after one-shot skip");

        LaunchSettings::setStartupTipsDontShow(s3, true);
        LaunchSettings::setSkipStartupTipsOnce(s3, true);
        s3.sync();
        expect(!LaunchSettings::shouldShowStartupTips(s3),
               "dontShow still hides tips with skipOnce");
        expect(!s3.value(LaunchSettings::tipsSkipOnceKey(), false).toBool(),
               "skipOnce cleared under dontShow");
        expect(!LaunchSettings::shouldShowStartupTips(s3), "dontShow persists after skipOnce");
    }

    I18n::setLang(I18n::Lang::ZhCN);
    expect(I18n::t("app.name") == QStringLiteral("看图"), "zh app name");
    expect(I18n::t("tips.dontShow") == QStringLiteral("不再提示"), "zh dont show tips");
    expect(I18n::t("update.dont") == QStringLiteral("不更新"), "zh dont update");
    expect(I18n::t("update.go") == QStringLiteral("前往更新"), "zh go update");
    expect(I18n::t("update.later") == QStringLiteral("稍后再说"), "zh later");
    expect(I18n::t("tips.ok") == QStringLiteral("知道了"), "zh tips ok");
    expect(I18n::t("help.tips") == QStringLiteral("使用提示(&T)"), "zh help tips");
    expect(I18n::t("help.visitWebsite").contains(QStringLiteral("产品页")), "zh visit website");
    expect(I18n::t("tips.body").contains(QStringLiteral("同一文件夹")), "zh tips body for help");
    expect(I18n::t("launch.combinedTitle").contains(QStringLiteral("Flip")), "zh combined title");
    expect(I18n::t("update.picking").contains(QStringLiteral("源")), "zh picking source");
    expect(I18n::t("update.openDownload") == QStringLiteral("打开下载"), "zh open download");
    expect(I18n::t("about.body").arg(QStringLiteral(FLIP_VERSION)).contains(QStringLiteral("1.3.0")),
           "zh about shows version");
    I18n::setLang(I18n::Lang::En);
    expect(I18n::t("app.name") == QStringLiteral("Flip"), "en app name");
    expect(I18n::t("help.tips") == QStringLiteral("&Usage Tips"), "en help tips");
    expect(I18n::t("help.visitWebsite").contains(QStringLiteral("ak129.cn")), "en visit website");
    expect(I18n::t("tips.dontShow") == QStringLiteral("Don't show again"), "en dont show tips");
    expect(I18n::t("update.later") == QStringLiteral("Later"), "en later");
    expect(I18n::t("update.go") == QStringLiteral("Go to update"), "en go update");
    expect(I18n::t("launch.combinedTitle") == QStringLiteral("Welcome"), "en combined title");
    expect(I18n::t("update.picking").contains(QStringLiteral("faster")), "en picking source");
    expect(I18n::t("update.openDownload").contains(QStringLiteral("download")), "en open download");

    {
        MainWindow window;
        expect(!window.menuBar()->actions().isEmpty(), "menu bar has menus");
        QMenu* helpMenu = window.menuBar()->actions().last()->menu();
        expect(helpMenu != nullptr, "last menu is help");
        QList<QAction*> items;
        for (QAction* action : helpMenu->actions()) {
            if (!action->isSeparator())
                items << action;
        }
        expect(items.size() == 3, "help has tips, website, about");
        if (items.size() == 3) {
            expect(items.at(0)->shortcut() == QKeySequence(QKeySequence::HelpContents),
                   "HelpContents/F1 bound to tips");
            expect(items.at(1)->shortcut().isEmpty(), "visit website has no HelpContents shortcut");
            expect(items.at(2)->shortcut().isEmpty(), "about has no HelpContents shortcut");
        }
        QStringList labels;
        for (QAction* action : items)
            labels << action->text().remove(QLatin1Char('&'));
        const bool hasTips = labels.contains(QStringLiteral("使用提示"))
            || labels.contains(QStringLiteral("Usage Tips"));
        const bool hasAbout = labels.contains(QStringLiteral("关于"))
            || labels.contains(QStringLiteral("About"));
        const bool hasVisit = labels.contains(QStringLiteral("访问 Flip 产品页"))
            || labels.contains(QStringLiteral("Visit Flip on ak129.cn"));
        expect(hasTips, "help menu labels include usage tips");
        expect(hasVisit, "help menu labels include visit website");
        expect(hasAbout, "help menu labels include about");
    }

    {
        QTemporaryDir pack;
        expect(pack.isValid(), "inplace pack temp dir");
        const QString pkg = pack.path() + QStringLiteral("/flip-linux-1.2.0-amd64");
        expect(QDir().mkpath(pkg + QStringLiteral("/icons")), "inplace pkg dirs");
        auto writeBytes = [](const QString& path, const QByteArray& data) {
            QFile f(path);
            if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
                return false;
            return f.write(data) == data.size();
        };
        expect(writeBytes(pkg + QStringLiteral("/Flip"), QByteArrayLiteral("new-flip-binary")),
               "write packaged Flip");
        expect(writeBytes(pkg + QStringLiteral("/README.md"), QByteArrayLiteral("readme")),
               "write packaged README");
        expect(writeBytes(pkg + QStringLiteral("/LICENSE"), QByteArrayLiteral("mit")),
               "write packaged LICENSE");
        expect(writeBytes(pkg + QStringLiteral("/flip.desktop"), QByteArrayLiteral("[Desktop Entry]\n")),
               "write packaged desktop");
        expect(writeBytes(pkg + QStringLiteral("/icons/flip.svg"), QByteArrayLiteral("<svg/>")),
               "write packaged icon");
        expect(QDir().mkpath(pkg + QStringLiteral("/examples")), "inplace examples dir");
        expect(writeBytes(pkg + QStringLiteral("/examples/skip-me"), QByteArrayLiteral("no")),
               "write packaged example decoy");

        expect(InPlaceUpdater::findFlipBinary(pack.path())
                   == QFileInfo(pkg + QStringLiteral("/Flip")).absoluteFilePath(),
               "find Flip in extract tree");

        QTemporaryDir dest;
        expect(dest.isValid(), "inplace dest temp dir");
        const QString destExe = dest.path() + QStringLiteral("/Flip");
        expect(writeBytes(destExe, QByteArrayLiteral("old-flip-binary")), "write old Flip");
        expect(InPlaceUpdater::isInstallWritable(destExe), "temp install is writable");
        expect(!InPlaceUpdater::isAppImageInstall(), "self-test is not AppImage");

        QString err;
        expect(InPlaceUpdater::stageNewBinary(pkg + QStringLiteral("/Flip"), destExe, &err),
               "stage new binary beside running exe");
        const QString staged = InPlaceUpdater::stagedBinaryPath(destExe);
        expect(QFile::exists(staged), "staged Flip.flip-new exists");
        {
            QFile oldF(destExe);
            expect(oldF.open(QIODevice::ReadOnly) && oldF.readAll() == QByteArrayLiteral("old-flip-binary"),
                   "original Flip unchanged after staging");
            QFile newF(staged);
            expect(newF.open(QIODevice::ReadOnly) && newF.readAll() == QByteArrayLiteral("new-flip-binary"),
                   "staged file is complete new binary");
        }

        const QStringList copied = InPlaceUpdater::copyPackageSidecars(pkg, dest.path());
        expect(QFile::exists(dest.path() + QStringLiteral("/README.md")), "copied README");
        expect(QFile::exists(dest.path() + QStringLiteral("/flip.desktop")), "copied desktop");
        expect(QFile::exists(dest.path() + QStringLiteral("/icons/flip.svg")), "copied icon");
        expect(!QFile::exists(dest.path() + QStringLiteral("/examples/skip-me")),
               "did not copy examples");
        expect(copied.size() >= 4, "copied readme license desktop icon");

        const QString helper = InPlaceUpdater::helperScriptContents(4242, destExe, staged);
        expect(helper.contains(QStringLiteral("mv \"$EXE\" \"$OLD\"")), "helper moves old binary");
        expect(helper.contains(QStringLiteral("mv \"$NEW\" \"$EXE\"")), "helper installs staged binary");
        expect(helper.contains(InPlaceUpdater::shellSingleQuote(destExe)), "helper quotes dest exe");
        expect(helper.contains(QStringLiteral("4242")), "helper waits for pid");

        {
            const QString scriptPath = dest.path() + QStringLiteral("/helper.sh");
            QFile script(scriptPath);
            expect(script.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text),
                   "write helper script");
            const QByteArray body =
                InPlaceUpdater::helperScriptContents(999999999, destExe, staged).toUtf8();
            expect(script.write(body) == body.size(), "helper script bytes");
            script.close();
            QFile::setPermissions(scriptPath, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
#ifndef Q_OS_WIN
            // In-place swap is a bash helper used on Linux / UOS / Kylin only.
            QProcess helperProc;
            helperProc.start(QStringLiteral("/bin/bash"), {scriptPath});
            expect(helperProc.waitForFinished(15000) && helperProc.exitCode() == 0,
                   "helper swap succeeds");
            QFile swapped(destExe);
            expect(swapped.open(QIODevice::ReadOnly)
                       && swapped.readAll() == QByteArrayLiteral("new-flip-binary"),
                   "helper replaced Flip with staged binary");
            expect(!QFile::exists(staged), "helper removed staged Flip.flip-new");
#endif
        }

        const QString archive = pack.path() + QStringLiteral("/pkg.tar.gz");
        QProcess tar;
        tar.start(QStringLiteral("tar"),
                  {QStringLiteral("-czf"), archive, QStringLiteral("-C"), pack.path(),
                   QStringLiteral("flip-linux-1.2.0-amd64")});
        expect(tar.waitForFinished(15000) && tar.exitCode() == 0, "create sample tarball");
        expect(InPlaceUpdater::fileLooksLikeGzip(archive), "tarball is gzip");
        QTemporaryDir extracted;
        expect(extracted.isValid(), "extract dest");
        expect(InPlaceUpdater::extractTarball(archive, extracted.path(), &err), "extract tarball");
        expect(InPlaceUpdater::findFlipBinary(extracted.path()).endsWith(QStringLiteral("/Flip")),
               "extracted tarball contains Flip");

        qputenv("APPIMAGE", "/tmp/Flip.AppImage");
        expect(InPlaceUpdater::isAppImageInstall(), "APPIMAGE env detected");
        expect(!InPlaceUpdater::isInstallWritable(destExe), "AppImage install not writable");
        qunsetenv("APPIMAGE");
        expect(InPlaceUpdater::isInstallWritable(destExe), "writable again after unset APPIMAGE");
    }

    QTemporaryDir tmp;
    expect(tmp.isValid(), "temp dir");
    const QString dir = tmp.path();

    const QImage red = solidImage(200, 150, qRgb(200, 40, 40));
    const QImage blue = solidImage(1920, 400, qRgb(40, 80, 180));
    const QImage green = solidImage(64, 64, qRgb(40, 160, 70));

    expect(saveOrLog(red, dir + QStringLiteral("/img2.png")), "write img2.png");
    expect(saveOrLog(blue, dir + QStringLiteral("/img10.png")), "write img10.png");
    expect(saveOrLog(green, dir + QStringLiteral("/img1.png")), "write img1.png");
    saveOrLog(red, dir + QStringLiteral("/photo.jpg"));
    saveOrLog(green, dir + QStringLiteral("/icon.bmp"));
    saveOrLog(red, dir + QStringLiteral("/scan.tif"));
    saveOrLog(green, dir + QStringLiteral("/sticker.webp"));

    FolderPager pager;
    expect(pager.open(dir + QStringLiteral("/img2.png")), "open img2.png");
    expect(pager.count() >= 3, "folder has at least 3 pngs");
    expect(pager.currentFileName() == QStringLiteral("img2.png"), "current is img2");

    // Natural order among img1 / img2 / img10 regardless of other extra formats.
    QStringList names;
    pager.first();
    for (int i = 0; i < pager.count(); ++i) {
        pager.jumpTo(i);
        names << pager.currentFileName();
    }
    const int i1 = names.indexOf(QStringLiteral("img1.png"));
    const int i2 = names.indexOf(QStringLiteral("img2.png"));
    const int i10 = names.indexOf(QStringLiteral("img10.png"));
    expect(i1 >= 0 && i2 >= 0 && i10 >= 0 && i1 < i2 && i2 < i10, "img1 < img2 < img10 in folder");

    pager.open(dir + QStringLiteral("/img1.png"));
    const QString first = pager.currentFileName();
    pager.previous(); // wrap to last
    expect(!pager.currentFileName().isEmpty() && pager.currentFileName() != first,
           "previous wraps from first");
    pager.next();
    expect(pager.currentFileName() == first, "next wraps back to first");

    QImage loaded(dir + QStringLiteral("/img10.png"));
    expect(!loaded.isNull() && loaded.width() == 1920 && loaded.height() == 400, "load wide png");
    expectNear(defaultFitScale(loaded.size(), QSize(800, 600)), 800.0 / 1920.0,
               "loaded wide png fit-zoom");

    std::printf("Qt image read formats:");
    for (const QByteArray& fmt : QImageReader::supportedImageFormats())
        std::printf(" %s", fmt.constData());
    std::printf("\nQt image write formats:");
    for (const QByteArray& fmt : QImageWriter::supportedImageFormats())
        std::printf(" %s", fmt.constData());
    std::printf("\n");

    if (QFile::exists(dir + QStringLiteral("/photo.jpg"))) {
        QImage jpg(dir + QStringLiteral("/photo.jpg"));
        expect(!jpg.isNull(), "read jpeg");
    }
    if (QFile::exists(dir + QStringLiteral("/sticker.webp"))) {
        QImage webp(dir + QStringLiteral("/sticker.webp"));
        expect(!webp.isNull(), "read webp");
    }
    if (QFile::exists(dir + QStringLiteral("/scan.tif"))) {
        QImage tif(dir + QStringLiteral("/scan.tif"));
        expect(!tif.isNull(), "read tiff");
    }

    expect(ToolbarLayout::showsRotateRight(620) && !ToolbarLayout::showsRotateRight(619),
           "rotate-right breakpoint 620");
    expect(ToolbarLayout::showsFlip(740) && !ToolbarLayout::showsFlip(739), "flip breakpoint 740");
    expect(ToolbarLayout::showsAdjustExtras(900), "adjust extras at 900");
    expect(ToolbarLayout::showsInspectorExtras(1040) && ToolbarLayout::hasOverflow(1039),
           "inspector at 1040; overflow below");
    expect(!ToolbarLayout::hasOverflow(1040), "full bar has no overflow");
    expect(std::abs(weightScale(MarkupWeight::Thin) - 0.16) < 1e-9, "thin weight scale");
    expect(std::abs(weightSampleThickness(MarkupWeight::Heavy) - 6.0) < 1e-9, "heavy sample thickness");
    expect(strokeWidthForImage(QSize(1000, 1000), MarkupWeight::Thin) >= 0.5, "hairline floor 0.5");
    {
        const QPointF snapped = constrainAxis(QPointF(0.2, 0.2), QPointF(0.5, 0.21));
        expect(std::abs(snapped.y() - 0.2) < 0.02, "shift snaps line toward axis");
        const QPointF sq = constrainSquare(QPointF(0.2, 0.2), QPointF(0.5, 0.3));
        expect(std::abs(std::abs(sq.x() - 0.2) - std::abs(sq.y() - 0.2)) < 1e-9, "shift square equal sides");
    }
    {
        MarkupItem item;
        item.id = newMarkupId();
        item.kind = MarkupKind::Line;
        item.start = QPointF(0.25, 0.25);
        item.end = QPointF(0.75, 0.25);
        QVector<MarkupItem> items{item};
        transformMarkup(items, ImageOp::rotateLeft());
        expect(std::abs(items.first().start.x() - (1 - 0.25)) < 1e-9, "rotate left x = 1-y");
        expect(std::abs(items.first().start.y() - 0.25) < 1e-9, "rotate left y = x");
    }
    {
        QImage src(40, 20, QImage::Format_RGB32);
        src.fill(qRgb(200, 10, 10));
        const QImage rot = applyOp(src, ImageOp::rotateLeft());
        expect(rot.width() == 20 && rot.height() == 40, "rotate left swaps size");
        ColorAdjust identity;
        expect(identity.isIdentity(), "default color adjust is identity");
        identity.exposure = 0.5;
        expect(!identity.isIdentity(), "exposure makes color non-identity");
        const QImage cropped = applyOp(src, ImageOp::cropFrac(QRectF(0.25, 0.25, 0.5, 0.5)));
        expect(cropped.width() > 0 && cropped.height() > 0, "crop produces pixels");
    }
    I18n::setLang(I18n::Lang::ZhCN);
    expect(I18n::t("toolbar.more") == QStringLiteral("更多"), "zh more");
    expect(I18n::t("markup.textBg") == QStringLiteral("文字背景"), "zh text background");
    I18n::setLang(I18n::Lang::En);
    expect(I18n::t("toolbar.markup") == QStringLiteral("Markup"), "en markup");
    expect(I18n::t("weight.thin") == QStringLiteral("Thin"), "en thin");

    expect(FolderPager::isImageFile(QStringLiteral("/tmp/a.png")), "png suffix recognized");
    expect(FolderPager::isImageFile(QStringLiteral("/tmp/a.JPEG")), "jpeg suffix recognized");
    expect(!FolderPager::isImageFile(QStringLiteral("/tmp/notes.txt")), "txt is not an image");

    if (g_fails == 0)
        std::printf("self-test passed\n");
    else
        std::fprintf(stderr, "self-test failed: %d check(s)\n", g_fails);
    return g_fails == 0 ? 0 : 1;
}
