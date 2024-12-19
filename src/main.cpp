#include <clocale>
#include <QtWebEngineQuick>
#include <QQuickWebEngineProfile>


#define APP_TITLE "Stremio - Freedom to Stream"
#define DESKTOP true

#ifdef DESKTOP
#include <QtWidgets/QApplication>
typedef QApplication Application;
#include <QQuickStyle>

#include "tray/systemtray.h"
#include "saver/screensaver.h"
#include "server/stremioprocess.h"
#include "player/mpv.h"
#include "mainapplication.h"

#else
#include <QGuiApplication>
#endif

#define APP_TITLE "Stremio - Freedom to Stream"

void InitializeParameters(QQmlApplicationEngine *engine, MainApp& app) {
    QQmlContext *ctx = engine->rootContext();
    SystemTray * systemTray = new SystemTray();
    Qt::ColorScheme systemColorScheme = QGuiApplication::styleHints()->colorScheme();

    ctx->setContextProperty("applicationDirPath", QGuiApplication::applicationDirPath());
    ctx->setContextProperty("appTitle", QString(APP_TITLE));
    ctx->setContextProperty("autoUpdater", app.autoupdater);
    ctx->setContextProperty("systemColorScheme", QVariant::fromValue(systemColorScheme));

    // Set access to an object of class properties in QML context
    ctx->setContextProperty("systemTray", systemTray);

#ifdef QT_DEBUG
    ctx->setContextProperty("debug", true);
#else
    ctx->setContextProperty("debug", false);
#endif
}

int main(int argc, char **argv)
{
    qputenv("QTWEBENGINE_CHROMIUM_FLAGS", "--autoplay-policy=no-user-gesture-required --enable-gpu-rasterization --enable-oop-rasterization");
    qputenv("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark");

    // TODO CHECK LINUX
    Application::setAttribute(Qt::AA_EnableHighDpiScaling);
    Application::setApplicationName("Stremio");
    Application::setApplicationVersion(STREMIO_SHELL_VERSION);
    Application::setOrganizationName("Smart Code ltd");
    Application::setOrganizationDomain("stremio.com");

    // Qt sets the locale in the QGuiApplication constructor, but libmpv
    // requires the LC_NUMERIC category to be set to "C", so change it back.
    std::setlocale(LC_NUMERIC, "C");

    // Ensure OpenGL
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    // **Instantiate your application object here**
    MainApp app(argc, argv, true);

    // Persistent Session
    QQuickWebEngineProfile* webEngineProfile = QQuickWebEngineProfile::defaultProfile();
    webEngineProfile->setPersistentCookiesPolicy(QQuickWebEngineProfile::ForcePersistentCookies);
    webEngineProfile->setOffTheRecord(false);
    webEngineProfile->setStorageName(QStringLiteral("Default"));
    webEngineProfile->setCachePath(webEngineProfile->persistentStoragePath() + QStringLiteral("/Cache"));

#ifndef Q_OS_MACOS
    if( app.isSecondary() ) {
        if( app.arguments().count() > 1)
            app.sendMessage( app.arguments().at(1).toUtf8() );
        else
            app.sendMessage( "SHOW" );
        //app.sendMessage( app.arguments().join(' ').toUtf8() );
        return 0;
    }
#endif

    MainApp::setWindowIcon(QIcon(":/images/stremio_window.png"));
    QQuickStyle::setStyle("Material");

    static QQmlApplicationEngine* engine = new QQmlApplicationEngine();

    qmlRegisterType<Process>("com.stremio.process", 1, 0, "Process");
    qmlRegisterType<MpvObject>("com.stremio.libmpv", 1, 0, "MpvObject");
    qmlRegisterType<ScreenSaver>("com.stremio.screensaver", 1, 0, "ScreenSaver");

    InitializeParameters(engine, app);

    engine->load(QUrl(QStringLiteral("qrc:/main.qml")));

#ifndef Q_OS_MACOS
    QObject::connect( &app, &SingleApplication::receivedMessage, &app, &MainApp::processMessage );
#endif
    QObject::connect( &app, SIGNAL(receivedMessage(QVariant, QVariant)), engine->rootObjects().value(0),
                      SLOT(onAppMessageReceived(QVariant, QVariant)) );
    int ret = app.exec();
    delete engine;
    engine = nullptr;
    return ret;
}