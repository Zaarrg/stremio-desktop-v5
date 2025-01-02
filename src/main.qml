import QtQuick
import QtWebEngine
import QtWebChannel
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import com.stremio.process
import com.stremio.screensaver
import com.stremio.libmpv

import QtQml

import "autoupdater.js" as Autoupdater

ApplicationWindow {
    id: root
    visible: true

    minimumWidth: 1000
    minimumHeight: 650

    readonly property int initialWidth: Math.max(root.minimumWidth, Math.min(1600, Screen.desktopAvailableWidth * 0.8))
    readonly property int initialHeight: Math.max(root.minimumHeight, Math.min(1000, Screen.desktopAvailableHeight * 0.8))

    width: root.initialWidth
    height: root.initialHeight

    property bool quitting: false

    color: "#0c0b11";
    title: appTitle

    property var previousVisibility: Window.Windowed
    property var previousX
    property var previousY
    property var previousWidth
    property var previousHeight
    property bool wasFullScreen: false

    //
    // Player
    //
    MpvObject {
        id: mpv
        anchors.fill: parent
        onMpvEvent: function(ev, args) { transport.event(ev, args) }
    }

    //
    // Main UI (via WebEngineView)
    //

    WebEngineView {
        id: webView;

        focus: true

        readonly property string mainUrl: getWebUrl()

        url: webView.mainUrl;
        anchors.fill: parent
        backgroundColor: "transparent";
        property int tries: 0

        readonly property int maxTries: 20

        settings.javascriptCanAccessClipboard: true
        settings.javascriptCanPaste: true

        Component.onCompleted: function() {
            console.log("Loading web UI from URL: "+webView.mainUrl)

            webView.profile.httpUserAgent = webView.profile.httpUserAgent+' StremioShell/'+Qt.application.version

            // for more info, see
            // https://github.com/adobe/chromium/blob/master/net/disk_cache/backend_impl.cc - AdjustMaxCacheSize,
            // https://github.com/adobe/chromium/blob/master/net/disk_cache/backend_impl.cc#L2094
            webView.profile.httpCacheMaximumSize = 209715200 // 200 MB
        }

        onLoadingChanged: function(loadRequest) {
            // hack for webEngineView changing it's background color on crashes
            webView.backgroundColor = "transparent"

            var successfullyLoaded = loadRequest.status == WebEngineView.LoadSucceededStatus
            if (successfullyLoaded || webView.tries > 0) {
                // show the webview if the loading is failing
                // can fail because of many reasons, including captive portals
                splashScreen.visible = false
                pulseOpacity.running = false
            }

            if (successfullyLoaded) {
                injectJS()
            }

            var shouldRetry = loadRequest.status == WebEngineView.LoadFailedStatus ||
                loadRequest.status == WebEngineView.LoadStoppedStatus
            if ( shouldRetry && webView.tries < webView.maxTries) {
                retryTimer.restart()
            }
        }

        onRenderProcessTerminated: function(terminationStatus, exitCode) {
            console.log("render process terminated with code "+exitCode+" and status: "+terminationStatus)

            // hack for webEngineView changing it's background color on crashes
            webView.backgroundColor = "black"

            retryTimer.restart()

            // send an event for the crash, but since the web UI is not working, reset the queue and queue it
            transport.queued = []
            transport.queueEvent("render-process-terminated", { exitCode: exitCode, terminationStatus: terminationStatus, url: webView.url })

        }

        // WARNING: does not work..for some reason: "Scripts may close only the windows that were opened by it."
        // onWindowCloseRequested: function() {
        //     root.visible = false;
        //     Qt.quit()
        // }

        // In the app, we use open-external IPC signal, but make sure this works anyway
        property string hoveredLink: ""
        onLinkHovered: function(url) { hoveredLink = url }
        onNewWindowRequested: function(req) { if (req.userInitiated) Qt.openUrlExternally(hoveredLink) }

        // FIXME: When is this called?
        onFullScreenRequested: function(req) {
            setFullScreen(req.toggleOn);
            req.accept();
        }

        // Prevent navigation
        onNavigationRequested: function(req) {
            // WARNING: @TODO: perhaps we need a better way to parse URLs here
            var allowedHost = webView.mainUrl.split('/')[2]
            var targetHost = req.url.toString().split('/')[2]
            if (allowedHost != targetHost && (req.isMainFrame || targetHost !== 'www.youtube.com')) {
                console.log("onNavigationRequested: disallowed URL "+req.url.toString());
                req.action = WebEngineView.IgnoreRequest;
            }
        }

        Menu {
            id: ctxMenu
            MenuItem {
                text: "Undo"
                //shortcut: StandardKey.Undo
                onTriggered: webView.triggerWebAction(WebEngineView.Undo)
            }
            MenuItem {
                text: "Redo"
                //shortcut: StandardKey.Redo
                onTriggered: webView.triggerWebAction(WebEngineView.Redo)
            }
            MenuSeparator { }
            MenuItem {
                text: "Cut"
                //shortcut: StandardKey.Cut
                onTriggered: webView.triggerWebAction(WebEngineView.Cut)
            }
            MenuItem {
                text: "Copy"
                //shortcut: StandardKey.Copy
                onTriggered: webView.triggerWebAction(WebEngineView.Copy)
            }
            MenuItem {
                text: "Paste"
                //shortcut: StandardKey.Paste
                onTriggered: webView.triggerWebAction(WebEngineView.Paste)
            }
            MenuSeparator { }
            MenuItem {
                text: "Select All"
                //shortcut: StandardKey.SelectAll
                onTriggered: webView.triggerWebAction(WebEngineView.SelectAll)
            }
        }

        // Prevent ctx menu
        onContextMenuRequested: function(request) {
            request.accepted = true;
            // Allow menu inside editalbe objects
            if (request.isContentEditable) {
                ctxMenu.popup();
            }
        }

        Action {
            shortcut: StandardKey.Paste
            onTriggered: webView.triggerWebAction(WebEngineView.Paste)
        }

        DropArea {
            anchors.fill: parent
            onDropped: function(dropargs){
                var args = JSON.parse(JSON.stringify(dropargs))
                transport.event("dragdrop", args.urls)
            }
        }
        webChannel: wChannel
    }

    WebChannel {
        id: wChannel
    }

    // Transport
    QtObject {
        id: transport
        readonly property string shellVersion: Qt.application.version
        property string serverAddress: "http://127.0.0.1:11470" // will be set to something else if server inits on another port


        signal event(var ev, var args)
        function onEvent(ev, args) {
            if (ev === "quit") quitApp()
            if (ev === "app-ready") transport.flushQueue()
            if (ev === "mpv-command" && args && args[0] !== "run") mpv.command(args)
            if (ev === "mpv-set-prop") {
                mpv.setProperty(args[0], args[1]);
                if (args[0] === "pause") {
                    shouldDisableScreensaver(!args[1]);
                }
            }
            if (ev === "mpv-observe-prop") mpv.observeProperty(args)
            if (ev === "control-event") wakeupEvent()
            if (ev === "wakeup") wakeupEvent()
            if (ev === "set-window-mode") onWindowMode(args)
            if (ev === "open-external") Qt.openUrlExternally(args)
            if (ev === "win-focus" && !root.visible) {
                showWindow();
            }
            if (ev === "win-set-visibility") {
                if (args.hasOwnProperty('fullscreen')) {
                    setFullScreen(args.fullscreen);
                }
            }
            if (ev === "autoupdater-notif-clicked" && autoUpdater.onNotifClicked) {
                autoUpdater.onNotifClicked(); //Event not used. We use qt updateScreen notification instead
            }
            if (ev === "screensaver-toggle") shouldDisableScreensaver(args.disabled)
            if (ev === "file-close") fileDialog.close()
            if (ev === "file-open") {
                if (typeof args !== "undefined") {
                    var fileDialogDefaults = {
                        title: "Please choose",
                        selectExisting: true,
                        selectFolder: false,
                        selectMultiple: false,
                        nameFilters: [],
                        selectedNameFilter: "",
                        data: null
                    }
                    Object.keys(fileDialogDefaults).forEach(function(key) {
                        fileDialog[key] = args.hasOwnProperty(key) ? args[key] : fileDialogDefaults[key]
                    })
                }
                fileDialog.open()
            }
        }

        // events that we want to wait for the app to initialize
        property variant queued: []
        function queueEvent() {
            if (transport.queued) transport.queued.push(arguments)
            else transport.event.apply(transport, arguments)
        }
        function flushQueue() {
            if (transport.queued) transport.queued.forEach(function(args) { transport.event.apply(transport, args) })
            transport.queued = null;
        }
    }


    /* With help Connections object
 * set connections with System tray class
 * */
    Connections {
        target: systemTray

        function onSignalIconMenuAboutToShow() {
            systemTray.updateIsOnTop((root.flags & Qt.WindowStaysOnTopHint) === Qt.WindowStaysOnTopHint);
            systemTray.updateVisibleAction(root.visible);
        }

        function onSignalShow() {
            if(root.visible) {
                root.hide();
            } else {
                showWindow();
            }
        }

        function onSignalAlwaysOnTop() {
            root.raise()
            if (root.flags & Qt.WindowStaysOnTopHint) {
                root.flags &= ~Qt.WindowStaysOnTopHint;
            } else {
                root.flags |= Qt.WindowStaysOnTopHint;
            }
        }

        function onSignalBorderlessWindow() {
            root.raise()
            if (root.flags & Qt.FramelessWindowHint) {
                root.flags &= ~Qt.FramelessWindowHint;
            } else {
                root.flags |= Qt.FramelessWindowHint;
            }
        }

        // The signal - close the application by ignoring the check-box
        function onSignalQuit() {
            quitApp();
        }

        // Minimize / maximize the window by clicking on the default system tray
        function onSignalIconActivated() {
            showWindow();
        }
    }

    //
    // Streaming server
    //
    Process {
        id: streamingServer
        property string errMessage:
            "Error while starting streaming server. Please try to restart stremio. If it happens again please contact the Stremio support team for assistance"
        property int errors: 0
        property bool fastReload: false

        onStarted: function() { stayAliveStreamingServer.stop() }
        onFinished: function(code, status) {
            // status -> QProcess::CrashExit is 1
            if (!streamingServer.fastReload && errors < 5 && (code !== 0 || status !== 0) && !root.quitting) {
                transport.queueEvent("server-crash", {"code": code, "log": streamingServer.getErrBuff()});

                errors++
                showStreamingServerErr(code)
            }

            if (streamingServer.fastReload) {
                console.log("Streaming server: performing fast re-load")
                streamingServer.fastReload = false
                root.launchServer()
            } else {
                stayAliveStreamingServer.start()
            }
        }
        onAddressReady: function (address) {
            transport.serverAddress = address
            transport.event("server-address", address)
        }
        onErrorThrown: function (error) {
            if (root.quitting) return; // inhibits errors during quitting
            if (streamingServer.fastReload && error == 1) return; // inhibit errors during fast reload mode;
                                                                  // we'll unset that after we've restarted the server
            transport.queueEvent("server-crash", {"code": error, "log": streamingServer.getErrBuff()});
            showStreamingServerErr(error)
        }
    }


    //
    // Splash screen
    // Must be over the UI
    //
    Rectangle {
        id: splashScreen;
        color: "#0c0b11";
        anchors.fill: parent;

        Column {
            anchors.centerIn: parent
            spacing: 20
            Image {
                id: splashLogo
                source: "qrc:///images/stremio.png"
                anchors.horizontalCenter: parent.horizontalCenter

                SequentialAnimation {
                    id: pulseOpacity
                    running: true
                    NumberAnimation { target: splashLogo; property: "opacity"; to: 1.0; duration: 600;
                        easing.type: Easing.Linear; }
                    NumberAnimation { target: splashLogo; property: "opacity"; to: 0.3; duration: 600;
                        easing.type: Easing.Linear; }
                    loops: Animation.Infinite
                }
            }

            Column {
                height: 90 //Height of updateScreen elements 45 + 30 + 15
                width: 100
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    //Connection to show update Screen. Needed because autoupdater runs in different thread
    QtObject {
        id: autoUpdateTransport
        signal showUpdateScreen()
    }

    Connections {
        target: autoUpdateTransport
        function onShowUpdateScreen() {
            updateScreen.visible = true;
            updateScreen.focus = true;
        }
    }

    //
    // Update screen
    // Must be over the UI
    //
    Rectangle {
        id: updateScreen
        color: "#0c0b11"
        anchors.fill: parent
        visible: false

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Image {
                id: updateLogo
                source: "qrc:///images/stremio.png"
                anchors.horizontalCenter: parent.horizontalCenter // Align like splashLogo
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15

                Text {
                    text: "Stremio update available!"
                    color: "white"
                    font.bold: true
                    font.pointSize: 14
                    height: 30
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 25

                    Button {
                        width: 80
                        height: 45
                        background: Rectangle {
                            id: updateButtonBg
                            color: parent.hovered ? "#6B64F2" : "#5351D9"
                            radius: 5
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                            }
                        }
                        contentItem: Text {
                            text: "Update"
                            color: "white"
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            anchors.fill: parent
                        }
                        onClicked: {
                            updateScreen.visible = false
                            autoUpdater.onNotifClicked();
                        }
                    }

                    Button {
                        width: 80
                        height: 45
                        background: Rectangle {
                            id: laterButtonBg
                            color: parent.hovered ? "#4A4A4A" : "#353637"
                            radius: 5
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onEntered: parent.hovered = true
                                onExited: parent.hovered = false
                            }
                        }
                        contentItem: Text {
                            text: "Later"
                            color: "white"
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            anchors.fill: parent
                        }
                        onClicked: {
                            // Handle postpone action
                            updateScreen.visible = false
                            webView.visible = true
                            webView.focus = true
                        }
                    }
                }
            }
        }
    }

    FileDialog {
        id: fileDialog

        property bool selectExisting: false
        property bool selectFolder: false
        property bool selectMultiple: false
        property var userData: {} // Renamed from data to userData

        Component.onCompleted: {
            if (selectFolder) {
                //TODO
                fileDialog.fileMode = FileDialog.Directory
            } else if (selectMultiple) {
                fileDialog.fileMode = FileDialog.OpenFiles
            } else if (selectExisting) {
                fileDialog.fileMode = FileDialog.ExistingFile // or OpenFile depending on your logic
            } else {
                // Default mode
                fileDialog.fileMode = FileDialog.OpenFile
            }
        }

        onAccepted: {
            var fileProtocol = "file://"
            var onWindows = Qt.platform.os === "windows" ? 1 : 0
            var pathSeparators = ["/", "\\"]
            var files = fileDialog.currentFiles.filter(function(fileUrl) {
                return fileUrl.startsWith(fileProtocol)
            }).map(function(fileUrl) {
                return decodeURIComponent(fileUrl.substring(fileProtocol.length + onWindows))
                    .replace(/\//g, pathSeparators[onWindows])
            })

            transport.event("file-selected", {
                files: files,
                title: fileDialog.title,
                selectExisting: fileDialog.selectExisting,
                selectFolder: fileDialog.selectFolder,
                selectMultiple: fileDialog.selectMultiple,
                nameFilters: fileDialog.nameFilters,
                selectedNameFilter: fileDialog.selectedNameFilter,
                data: fileDialog.userData // Use userData here
            })
        }

        onRejected: { // onRejected replaced by onCanceled in Qt6 FileDialog
            transport.event("file-rejected", {
                title: fileDialog.title,
                selectExisting: fileDialog.selectExisting,
                selectFolder: fileDialog.selectFolder,
                selectMultiple: fileDialog.selectMultiple,
                nameFilters: fileDialog.nameFilters,
                selectedNameFilter: fileDialog.selectedNameFilter,
                data: fileDialog.userData
            })
        }
    }

    //
    // Err dialog
    //
    MessageDialog {
        id: errorDialog
        title: "Stremio - Application Error"
        // onAccepted handler does not work
        //icon: StandardIcon.Critical
        //standardButtons: StandardButton.Ok
    }


    // Screen saver - enable & disable
    ScreenSaver {
        id: screenSaver
        property bool disabled: false // track last state so we don't call it multiple times
    }
    // This is needed so that 300s after the remote control has been used, we can re-enable the screensaver
    // (if the player is not playing)
    Timer {
        id: timerScreensaver
        interval: 300000
        running: false
        onTriggered: function () { shouldDisableScreensaver(isPlayerPlaying()) }
    }

    //
    // Binding window -> app events
    //
    onWindowStateChanged: function(state) {
        updatePreviousVisibility();
        transport.event("win-state-changed", { state: state })
    }

    onVisibilityChanged: {
        var enabledAlwaysOnTop = root.visible && !root.wasFullScreen;
        systemTray.alwaysOnTopEnabled(enabledAlwaysOnTop);
        if (!enabledAlwaysOnTop) {
            root.flags &= ~Qt.WindowStaysOnTopHint;
        }

        updatePreviousVisibility();
        transport.event("win-visibility-changed", { visible: root.visible, visibility: root.visibility,
            isFullscreen: root.wasFullScreen })
    }

    property int appState: Qt.application.state;
    onAppStateChanged: {
        // WARNING: CAVEAT: this works when you've focused ANOTHER app and then get back to this one
        if (Qt.platform.os === "osx" && appState === Qt.ApplicationActive && !root.visible) {
            root.show()
        }
    }

    onClosing: function(event){
        event.accepted = false
        root.hide()
    }

    //
    // AUTO UPDATER
    //
    signal autoUpdaterErr(var msg, var err);
    signal autoUpdaterRestartTimer();

    // Explanation: when the long timer expires, we schedule the short timer; we do that,
    // because in case the computer has been asleep for a long time, we want another short timer so we don't check
    // immediately (network not connected yet, etc)
    // we also schedule the short timer if the computer is offline
    Timer {
        id: autoUpdaterLongTimer
        interval: 2 * 60 * 60 * 1000
        running: false
        onTriggered: function() { autoUpdaterShortTimer.restart() }
    }
    Timer {
        id: autoUpdaterShortTimer
        interval: 5 * 60 * 1000
        running: false
        onTriggered: function() { } // empty, set if auto-updater is enabled in initAutoUpdater()
    }

    //
    // On complete handler
    //
    Component.onCompleted: function() {
        console.log('Stremio Shell version: '+Qt.application.version)

        // Kind of hacky way to ensure there are no Qt bindings going on; otherwise when we go to fullscreen
        // Qt tries to restore original window size
        root.height = root.initialHeight
        root.width = root.initialWidth

        // Start streaming server
        var args = Qt.application.arguments
        if (args.indexOf("--development") > -1 && args.indexOf("--streaming-server") === -1)
            console.log("Skipping launch of streaming server under --development");
        else
            launchServer();

        // Handle file opens
        var lastArg = args[1]; // not actually last, but we want to be consistent with what happens when we open
                               // a second instance (main.cpp)
        if (args.length > 1 && !lastArg.match('^--')) onAppOpenMedia(lastArg)

        // Check for updates
        console.info(" **** Completed. Loading Autoupdater ***")
        Autoupdater.initAutoUpdater(autoUpdater, root.autoUpdaterErr, autoUpdaterShortTimer, autoUpdaterLongTimer, autoUpdaterRestartTimer, webView.profile.httpUserAgent);
    }


    //
    // Timers
    //

    // getWebUrl Timer
    Timer {
        id: retryTimer
        interval: 1000
        running: false
        onTriggered: function () {
            webView.tries++
            // we want to revert to the mainUrl in case the URL we were at was the one that caused the crash
            //webView.reload()
            webView.url = webView.mainUrl;
        }
    }


    // We want to remove the splash after a minute
    Timer {
        id: removeSplashTimer
        interval: 90000
        running: true
        repeat: false
        onTriggered: function () {
            webView.backgroundColor = "transparent"
            injectJS()
        }
    }

    // TimerStreamingServer
    Timer {
        id: stayAliveStreamingServer
        interval: 10000
        running: false
        onTriggered: function () { root.launchServer() }
    }


    //
    // Functions
    //

    function setFullScreen(fullscreen) {
        //Sets Borderless Fullscreen (Borderless fixes many issues on windows + hdr)
        if (!root.wasFullScreen) {
            [root.previousX, root.previousY, root.previousWidth, root.previousHeight] =
                [root.x, root.y, root.width, root.height];
        }
        if (fullscreen) {
            root.flags |= Qt.FramelessWindowHint;
            root.x = Screen.virtualX;
            root.y = Screen.virtualY - 1;
            root.width = Screen.width;
            root.height = Screen.height + 1;
            root.wasFullScreen = true;
        } else {
            root.flags &= ~Qt.FramelessWindowHint;
            [root.x, root.y, root.width, root.height] =
                [root.previousX, root.previousY, root.previousWidth, root.previousHeight];
            root.wasFullScreen = false;
        }
    }

    // System tray function
    function showWindow() {
        if (root.wasFullScreen) {
            setFullScreen(true);
            root.visible = true;
        } else {
            root.visibility = root.previousVisibility;
        }
        root.raise();
        root.requestActivate();
    }

    function updatePreviousVisibility() {
        if (root.visible && !root.wasFullScreen && root.visibility != Window.Minimized) {
            root.previousVisibility = root.visibility;
        }
    }

    //WebView Functions
    function urlIsReachable(url) {
        var xhr = new XMLHttpRequest();
        try {
            xhr.open("HEAD", url, false); // synchronous request
            xhr.send();
            // Consider 2xx and 3xx as reachable
            return (xhr.status >= 200 && xhr.status < 400);
        } catch(e) {
            return false;
        }
    }

    function getWebUrl() {
        var params = "?loginFlow=desktop"
        var args = Qt.application.arguments
        var shortVer = Qt.application.version.split('.').slice(0, 2).join('.')
        var majorVersion = parseInt(Qt.application.version.split('.')[0]);
        var webuiArg = "--webui-url="

        for (var i=0; i!=args.length; i++) {
            if (args[i].indexOf(webuiArg) === 0) return args[i].slice(webuiArg.length)
        }

        if (args.indexOf("--development") > -1 || debug)
            return "http://127.0.0.1:11470/#" + params

        if (args.indexOf("--staging") > -1)
            return "https://staging.strem.io/#" + params

        if (args.indexOf("--v5") > -1 || majorVersion >= 5) {
            var testUrl = "https://zaarrg.github.io/stremio-web-shell-fixes/#" + params;
            if (urlIsReachable(testUrl)) {
                return testUrl;
            } else {
                return "https://web.stremio.com/#" + params;
            }
        }

        return "https://app.strem.io/shell-v" + shortVer + "/#" + params;
    }

    function injectJS() {
        splashScreen.visible = false
        pulseOpacity.running = false
        removeSplashTimer.running = false
        webView.webChannel.registerObject( 'transport', transport )
        // Try-catch to be able to return the error as result, but still throw it in the client context
        // so it can be caught and reported
        var injectedJS = "try { initShellComm() } " +
            "catch(e) { setTimeout(function() { throw e }); e.message || JSON.stringify(e) }"
        webView.runJavaScript(injectedJS, function(err) {
            if (!err) {
                webView.tries = 0
            } else {
                errorDialog.text = "User Interface could not be loaded.\n\nPlease try again later or contact the Stremio support team for assistance."
                errorDialog.informativeText = err
                errorDialog.visible = true

                console.error(err)
            }
        });
    }

    // Streaming Server Functions
    function showStreamingServerErr(code) {
        errorDialog.text = streamingServer.errMessage
        errorDialog.informativeText = 'Stremio streaming server has thrown an error \nQProcess::ProcessError code: '
            + code + '\n\n'
            + streamingServer.getErrBuff();
        errorDialog.visible = true
    }
    function launchServer() {
        var node_executable = applicationDirPath + "/node"
        if (Qt.platform.os === "windows") node_executable = applicationDirPath + "/stremio-runtime.exe"
        console.log('STARTING');
        streamingServer.start(node_executable,
            [applicationDirPath +"/server.js"].concat(Qt.application.arguments.slice(1)),
            "EngineFS server started at "
        )
        console.log('started');
    }

    // Utilities
    function onWindowMode(mode) {
        shouldDisableScreensaver(mode === "player")
    }

    function wakeupEvent() {
        shouldDisableScreensaver(true)
        timerScreensaver.restart()
    }

    function shouldDisableScreensaver(condition) {
        if (condition === screenSaver.disabled) return;
        condition ? screenSaver.disable() : screenSaver.enable();
        screenSaver.disabled = condition;
    }

    function isPlayerPlaying() {
        return root.visible && typeof(mpv.getProperty("path"))==="string" && !mpv.getProperty("pause")
    }

    // Received external message
    function onAppMessageReceived(instance, message) {
        message = message.toString(); // cause it may be QUrl
        showWindow();
        if (message !== "SHOW") {
            onAppOpenMedia(message);
        }
    }

    // May be called from a message (from another app instance) or when app is initialized with an arg
    function onAppOpenMedia(message) {
        var url = (message.indexOf('://') > -1 || message.indexOf('magnet:') === 0) ? message : 'file://'+message;
        transport.queueEvent("open-media", url)
    }

    function quitApp() {
        root.quitting = true;
        webView.destroy();
        systemTray.hideIconTray();
        streamingServer.kill();
        streamingServer.waitForFinished(1500);
        Qt.quit();
    }

}
