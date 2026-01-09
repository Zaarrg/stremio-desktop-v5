#include "webview.h"
#include <string>
#include <thread>
#include <cmath>
#include <fstream>
#include <iostream>
#include <Shlwapi.h>
#include <wrl.h>
#include "../core/globals.h"
#include "../utils/crashlog.h"
#include "../utils/helpers.h"
#include "../ui/mainwindow.h"
#include "../utils/extensions.h"

static const wchar_t* EXEC_SHELL_SCRIPT = LR"JS_CODE(
try {
    console.log('Shell JS injected');
    if (window.self === window.top && !window.qt) {
      window.qt = {
        webChannelTransport: {
          send: window.chrome.webview.postMessage,
          onmessage: (ev) => {
            // Will be overwritten by ShellTransport
            console.log('Received message from WebView2:', ev);
          }
        }
      };

      window.chrome.webview.addEventListener('message', (ev) => {
        window.qt.webChannelTransport.onmessage(ev);
      });

      window.onload = () => {
        try {
          initShellComm();
        } catch (e) {
            const errorMessage = {
              type: 6,
              object: "transport",
              method: "handleInboundJSON",
              id: 888,
              args: [
                "app-error",
                [ "shellComm" ]
              ]
            };
          window.chrome.webview.postMessage(JSON.stringify(errorMessage));
        }
      };
    }
} catch(e) {
    console.error("Error exec initShellComm:", e);
    const errorMessage = {
      type: 6,
      object: "transport",
      method: "handleInboundJSON",
      id: 888,
      args: [
        "app-error",
        [ "shellComm" ]
      ]
    };
    if(window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(JSON.stringify(errorMessage));
    }
};
)JS_CODE";

static const wchar_t* INJECTED_KEYDOWN_SCRIPT = LR"JS(
(function() {
    window.addEventListener('keydown', function(event) {
        if (event.code === 'F5') {
            event.preventDefault();
            const ctrlPressed = event.ctrlKey || event.metaKey;
            const msg = {
              type: 6,
              object: "transport",
              method: "handleInboundJSON",
              id: 999,
              args: [
                "refresh",
                [ ctrlPressed ? "all" : "no" ]
              ]
            };
            window.chrome.webview.postMessage(JSON.stringify(msg));
        }
    });
})();
)JS";

static const wchar_t* INJECTED_BUTTON_SCRIPT = LR"JS(
(function() {
  // Create the button element
  var btn = document.createElement('button');
  btn.id = 'goBackStremioBtn';

  // Style the button:
  btn.style.position = 'fixed';
  btn.style.bottom = '15px';
  btn.style.right = '15px';
  btn.style.zIndex = '9999';
  btn.style.backgroundColor = '#121024'; // Purple
  btn.style.color = 'white';
  btn.style.border = 'none';
  btn.style.borderRadius = '30px';
  btn.style.padding = '12px 20px';
  btn.style.fontSize = '16px';
  btn.style.fontWeight = 'bold';
  btn.style.display = 'flex';
  btn.style.alignItems = 'center';
  btn.style.boxShadow = '0 4px 6px rgba(0,0,0,0.1)';
  btn.style.cursor = 'pointer';
  btn.style.transition = 'background-color 0.3s ease';

  // Hover effect:
  btn.addEventListener('mouseenter', function() {
    btn.style.backgroundColor = '#211e39'; // Gray
  });
  btn.addEventListener('mouseleave', function() {
    btn.style.backgroundColor = '#121024';
  });

  // Create an image element for the logo
  var img = document.createElement('img');
  img.src = 'https://stremio.zarg.me/images/stremio_symbol.png';
  img.alt = 'Logo';
  img.style.height = '24px';
  img.style.width = '24px';
  img.style.marginRight = '8px';

img.addEventListener('error', function() {
  img.style.display = 'none';
});

  // Create a text element
  var txt = document.createElement('span');
  txt.textContent = 'Back to Stremio';

  // Append the logo and text to the button
  btn.appendChild(img);
  btn.appendChild(txt);

  // On click go home
  btn.addEventListener('click', function() {
            const payload = {
              type: 6,
              object: "transport",
              method: "handleInboundJSON",
              id: 666,
              args: [
                "navigate",
                [ "home" ]
              ]
            };
          window.chrome.webview.postMessage(JSON.stringify(payload));
  });

  // Append the button to the document body
  document.body.appendChild(btn);
})();
)JS";

const wchar_t* INJECTED_CHAPTERS_SCRIPT_PART1 = LR"JS(
(function() {
    // Idempotency check 
    if (window.stremioChaptersInjected) {
         console.log("[ChapterJS] Already injected, requesting chapters again.");
         try {
            window.chrome.webview.postMessage(JSON.stringify({
                type: 6,
                object: "transport",
                method: "handleInboundJSON",
                id: 1111,
                args: ["request-chapters", []]
            }));
         } catch(e){}
         return;
    }
    window.stremioChaptersInjected = true;

    let chapters = [];
    let currentChapterIdx = -1;
    let duration = 0;
    
    // Elements
    let chapterEl = null;      // The text display
    let markersContainer = null; // Container for lines

    function log(msg) {
        console.log("[ChapterJS]: " + msg);
        try {
            window.chrome.webview.postMessage(JSON.stringify({ type: "log", msg: "[ChapterJS] " + msg }));
        } catch(e){}
    }

    log("Script initializing...");

    function getPlayerBar() {
        const selectors = [
            '[class*="player-controls"]',
            '[class*="playerControls"]',
            '.player-controls',
            '#player-controls',
            '[data-component="player-controls"]'
        ];
        for (const s of selectors) {
            const el = document.querySelector(s);
            if (el) return el;
        }
        return null;
    }

    // Try to find the progress/seek bar container
    function getProgressBar() {
        const seekBars = document.querySelectorAll('[class*="seek-bar"]');
        for (const sb of seekBars) {
             if (sb.offsetParent !== null) return sb;
        }

        // 2. Generic Fallbacks (but filtered)
        const selectors = [
             '[class*="progress-bar"]', 
             '.progress-container',
             '.player-progress',
             'input[type="range"]'
        ];
        
        for (const s of selectors) {
            const candidates = document.querySelectorAll(s);
            for (const el of candidates) {
                // CRITICAL: Exclude dashboard items (posters/cards)
                if (el.closest('[class*="poster-container"]') || 
                    el.closest('[class*="meta-item"]') || 
                    el.closest('.poster-shape-poster')) {
                    continue;
                }
                // Must be somewhat visible/active
                if (el.offsetParent !== null) return el;
            }
        }
        return null;
    }

    function ensureUI() {
        // 1. Text Display
        if (!chapterEl || !document.body.contains(chapterEl)) {
            // Check if existing element is in DOM (re-attach scenario)
            chapterEl = document.getElementById('stremio-chapter-display');
            if(!chapterEl) {
                chapterEl = document.createElement('div');
                chapterEl.id = 'stremio-chapter-display';
                chapterEl.style.color = 'rgba(255, 255, 255, 0.9)';
                chapterEl.style.fontSize = '1.2em';
                chapterEl.style.fontWeight = 'bold';
                chapterEl.style.margin = '0 15px';
                chapterEl.style.zIndex = '2147483647';
                chapterEl.style.textShadow = '0 1px 4px rgba(0,0,0,1)';
                chapterEl.style.pointerEvents = 'none';
                chapterEl.style.fontFamily = 'Segoe UI, sans-serif';
            }
            
            const bar = getPlayerBar();
            if (bar) {
                 chapterEl.style.alignSelf = 'center';
                 // Try to insert cleanly
                 if(bar.firstChild) bar.insertBefore(chapterEl, bar.firstChild);
                 else bar.appendChild(chapterEl);
            } else {
                 chapterEl.style.position = 'fixed';
                 chapterEl.style.bottom = '100px';
                 chapterEl.style.left = '50%';
                 chapterEl.style.transform = 'translateX(-50%)';
                 chapterEl.style.backgroundColor = 'rgba(0,0,0,0.5)';
                 chapterEl.style.padding = '5px 10px';
                 chapterEl.style.borderRadius = '5px';
                 document.body.appendChild(chapterEl);
            }
        }
)JS";

const wchar_t* INJECTED_CHAPTERS_SCRIPT_PART2 = LR"JS(
        // 2. Markers
        if (!markersContainer || !document.body.contains(markersContainer)) {
             markersContainer = document.getElementById('stremio-chapter-markers');
             if(!markersContainer) {
                 markersContainer = document.createElement('div');
                 markersContainer.id = 'stremio-chapter-markers';
                 markersContainer.style.position = 'absolute';
                 markersContainer.style.top = '0';
                 markersContainer.style.left = '0';
                 markersContainer.style.width = '100%';
                 markersContainer.style.height = '100%';
                 markersContainer.style.pointerEvents = 'none';
                 markersContainer.style.zIndex = '10'; // Above background, below knob
             }
             
             const progress = getProgressBar();
             if (progress) {
                 // Re-parent if necessary (e.g. if we moved from dashboard to player, or re-rendered)
                 if (markersContainer.parentElement !== progress) {
                     // log("Attaching markers to: " + progress.className);
                     const computedStyle = window.getComputedStyle(progress);
                     if(computedStyle.position === 'static') {
                         progress.style.position = 'relative';
                     }
                     progress.appendChild(markersContainer);
                 }
             } else {
                 // log("No progress bar found for markers");
             }
        }
    }

    function renderMarkers() {
        if (!markersContainer) return;
        markersContainer.innerHTML = ''; // Clear old keys
        
        if (!chapters || chapters.length === 0 || duration <= 0) return;

        chapters.forEach((ch, idx) => {
            if (!ch.time) return;
            const pct = (ch.time / duration) * 100;
            if (pct < 0 || pct > 100) return;

            const marker = document.createElement('div');
            marker.style.position = 'absolute';
            marker.style.left = pct + '%';
            marker.style.top = '25%';      // Start slightly down
            marker.style.height = '50%';   // Only take up middle 50%
            marker.style.width = '2px';
            marker.style.backgroundColor = 'rgba(255, 255, 255, 0.5)'; // Subtle white
            marker.style.zIndex = '9';     // Below knob (usually 10 or higher)
            marker.style.pointerEvents = 'none';
            marker.title = ch.title || ('Chapter ' + (idx + 1));
            markersContainer.appendChild(marker);
        });
    }

    function updateUI() {
        ensureUI();
        
        // Update Text
        if (currentChapterIdx >= 0 && chapters && chapters[currentChapterIdx]) {
            const ch = chapters[currentChapterIdx];
            const title = ch.title || ('Chapter ' + (currentChapterIdx + 1));
            if(chapterEl) chapterEl.innerText = title;
        } else {
            if(chapterEl) chapterEl.innerText = '';
        }

        // Check if markers correct
        // Re-render if container empty but data exists
        if (markersContainer && markersContainer.childElementCount === 0 && chapters.length > 0) {
            renderMarkers();
        }
    }

    setInterval(() => {
        updateUI();
    }, 2000);

    window.chrome.webview.addEventListener('message', function(event) {
        try {
            const data = JSON.parse(event.data);
            if (data && data.args && Array.isArray(data.args)) {
                const eventName = data.args[0];
                const eventData = data.args[1];

                if (eventName === 'mpv-prop-change') {
                    if (eventData.name === 'chapter-list') {
                        chapters = eventData.data;
                        log("Received chapter-list");
                        renderMarkers();
                        updateUI();
                    } else if (eventData.name === 'chapter') {
                        const newIdx = typeof eventData.data === 'number' ? eventData.data : -1;
                        currentChapterIdx = newIdx;
                        updateUI();
                    } else if (eventData.name === 'duration') {
                        const d = eventData.data;
                        if(typeof d === 'number' && d > 0) {
                            duration = d;
                            // Re-render markers if duration changed
                            renderMarkers();
                        }
                    }
                }
            }
        } catch(e) {}
    });

    log("Requesting cached chapters...");
    window.chrome.webview.postMessage(JSON.stringify({
        type: 6,
        object: "transport",
        method: "handleInboundJSON",
        id: 1111,
        args: ["request-chapters", []]
    }));

})();
)JS";

std::wstring GetInjectedChaptersScript() {
    return std::wstring(INJECTED_CHAPTERS_SCRIPT_PART1) + std::wstring(INJECTED_CHAPTERS_SCRIPT_PART2);
}

void WaitAndRefreshIfNeeded()
{
    std::thread([](){
        const int maxAttempts = 10;
        const int initialWaitTime = 5;
        const int maxWaitTime = 60;

        std::cout << "[WEBVIEW]: Web Page could not be reached, retrying..." << std::endl;

        for(int attempt=0; attempt<maxAttempts; ++attempt)
        {
            int waitTime = (int)(initialWaitTime * pow(1.25, attempt));
            if(waitTime>maxWaitTime) waitTime = maxWaitTime;

            std::this_thread::sleep_for(std::chrono::seconds(waitTime));

            if(g_isAppReady){
                std::cout << "[WEBVIEW]: Web Page ready!" << std::endl;
                g_waitStarted.store(false);
                return;
            }
            std::cout << "[WEBVIEW]: Refreshing attempt " << (attempt+1) << std::endl;
            refreshWeb(false);
        }
        if(!g_isAppReady) {
            AppendToCrashLog("[WEBVIEW]: Could not load after attempts");
            MessageBoxW(nullptr,
                L"Web page could not be loaded after multiple attempts. Make sure the Web UI is reachable.",
                L"WebView2 Page load fail",
                MB_ICONERROR | MB_OK
            );
            PostQuitMessage(1);
            exit(1);
        }
    }).detach();
}

void InitWebView2(HWND hWnd)
{
    std::cout << "[WEBVIEW]: Starting webview..." << std::endl;
    // Setup environment
    Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions> options = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    if(options){
        options->put_AdditionalBrowserArguments(
            L"--autoplay-policy=no-user-gesture-required --disable-features=msWebOOUI,msPdfOOUI,msSmartScreenProtection"
        );
        Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions6> options6;
        if(SUCCEEDED(options.As(&options6))) {
            options6->put_AreBrowserExtensionsEnabled(TRUE);
        }
        Microsoft::WRL::ComPtr<ICoreWebView2EnvironmentOptions5> options5;
        if(SUCCEEDED(options.As(&options5))) {
            options5->put_EnableTrackingPrevention(TRUE);
        }
    }

    // Check for local Edge runtime in "portable_config/EdgeWebView"
    std::wstring exeDir;
    {
        wchar_t buf[MAX_PATH];
        GetModuleFileNameW(nullptr, buf, MAX_PATH);
        exeDir = buf;
        size_t pos = exeDir.find_last_of(L"\\/");
        if(pos!=std::wstring::npos) exeDir.erase(pos);
    }
    std::wstring browserDir = exeDir + L"\\portable_config\\EdgeWebView";
    const wchar_t* browserExecutableFolder = nullptr;
    if(DirectoryExists(browserDir)) {
        browserExecutableFolder = browserDir.c_str();
        std::wcout << L"[WEBVIEW]: Using local WebView2: " << browserDir << std::endl;
    }

    HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(
        browserExecutableFolder, nullptr, options.Get(),
        Microsoft::WRL::Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
        [hWnd](HRESULT res, ICoreWebView2Environment* env)->HRESULT
        {
            if(!env) return E_FAIL;
            env->CreateCoreWebView2Controller(
                hWnd,
                Microsoft::WRL::Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                [hWnd](HRESULT result, ICoreWebView2Controller* rawController)->HRESULT
                {
                    if (FAILED(result) || !rawController) return E_FAIL;
                    std::cout << "[WEBVIEW]: Initializing WebView..." << std::endl;
                    wil::com_ptr<ICoreWebView2Controller> m_webviewController = rawController;
                    if (!m_webviewController) return E_FAIL;

                    g_webviewController = m_webviewController.try_query<ICoreWebView2Controller4>();
                    if (!g_webviewController) return E_FAIL;

                    wil::com_ptr<ICoreWebView2> coreWebView;
                    g_webviewController->get_CoreWebView2(&coreWebView);
                    g_webview = coreWebView.try_query<ICoreWebView2_21>();
                    if (!g_webview) return E_FAIL;

                    wil::com_ptr<ICoreWebView2Profile> webView2Profile;
                    g_webview->get_Profile(&webView2Profile);
                    g_webviewProfile = webView2Profile.try_query<ICoreWebView2Profile8>();
                    if (!g_webviewProfile) return E_FAIL;

                    wil::com_ptr<ICoreWebView2Settings> webView2Settings;
                    g_webview->get_Settings(&webView2Settings);
                    auto settings = webView2Settings.try_query<ICoreWebView2Settings8>();
                    if (!settings) return E_FAIL;

                    if(settings) {
                        #ifndef DEBUG_LOG
                        settings->put_AreDevToolsEnabled(FALSE);
                        #endif
                        settings->put_IsStatusBarEnabled(FALSE);
                        settings->put_AreBrowserAcceleratorKeysEnabled(FALSE);
                        std::wstring customUA = std::wstring(L"StremioShell/") + Utf8ToWstring(APP_VERSION);
                        settings->put_UserAgent(customUA.c_str());
                        if(!g_allowZoom) {
                            settings->put_IsZoomControlEnabled(FALSE);
                            settings->put_IsPinchZoomEnabled(FALSE);
                        }
                    }
                    // Set background color
                    COREWEBVIEW2_COLOR col={0,0,0,0};
                    g_webviewController->put_DefaultBackgroundColor(col);

                    RECT rc; GetClientRect(hWnd,&rc);
                    g_webviewController->put_Bounds(rc);

                    g_webview->AddScriptToExecuteOnDocumentCreated(EXEC_SHELL_SCRIPT,nullptr);
                    g_webview->AddScriptToExecuteOnDocumentCreated(INJECTED_KEYDOWN_SCRIPT,nullptr);
                    g_webview->AddScriptToExecuteOnDocumentCreated(GetInjectedChaptersScript().c_str(), nullptr);

                    SetupWebMods();

                    SetupExtensions();
                    SetupWebMessageHandler();

                    std::thread([](){
                        std::wcout << L"[WEBVIEW]: Checking web ui endpoints..." << std::endl;
                        std::wstring foundUrl = GetFirstReachableUrl();
                        std::wstring* pResult = new std::wstring(foundUrl);
                        g_webuiUrl = foundUrl;
                        PostMessage(g_hWnd, WM_REACHABILITY_DONE, (WPARAM)pResult, 0);
                        FetchAndParseWhitelist();
                    }).detach();
                    return S_OK;
                }).Get()
            );
            return S_OK;
        }).Get()
    );
    if(FAILED(hr)) {
        std::wstring msg = L"[WEBVIEW]: CreateCoreWebView2EnvironmentWithOptions failed => " + std::to_wstring(hr);
        AppendToCrashLog(msg);
        MessageBoxW(nullptr, msg.c_str(), L"WebView2 Initialization Error", MB_ICONERROR | MB_OK);
        PostQuitMessage(1);
        exit(1);
    }
}

static void SetupWebMessageHandler()
{
    if(!g_webview) return;

    EventRegistrationToken navToken;
    g_webview->add_NavigationCompleted(
        Microsoft::WRL::Callback<ICoreWebView2NavigationCompletedEventHandler>(
        [](ICoreWebView2* sender, ICoreWebView2NavigationCompletedEventArgs* args)->HRESULT
        {
            BOOL isSuccess;
            args->get_IsSuccess(&isSuccess);

            // Retrieve the final URL
            wil::unique_cotaskmem_string rawUri;
            sender->get_Source(&rawUri);
            std::wstring finalUri = rawUri ? rawUri.get() : L"";
            std::wcout << L"[WEBVIEW]: Navigation try to " << finalUri << std::endl;

            // Add back to stremio button if not on stremio
            if (finalUri.find(g_webuiUrl) == std::wstring::npos) {
                sender->ExecuteScript(INJECTED_BUTTON_SCRIPT, nullptr);
            }

            if(isSuccess) {
                std::cout<<"[WEBVIEW]: Navigation Complete - Success\n";
                sender->ExecuteScript(EXEC_SHELL_SCRIPT, nullptr);
                sender->ExecuteScript(GetInjectedChaptersScript().c_str(), nullptr);
                // Flush the script queue.
                if (!g_scriptQueue.empty()) {
                    for (const auto &script : g_scriptQueue) {
                        sender->ExecuteScript(script.c_str(), nullptr);
                    }
                    g_scriptQueue.clear();
                }
            } else {
                std::cout<<"[WEBVIEW]: Navigation failed\n";
                if(g_hSplash && !g_waitStarted.exchange(true)) {
                    WaitAndRefreshIfNeeded();
                }
                HandleExtensions(finalUri);
            }
            return S_OK;
        }).Get(),
        &navToken
    );

    EventRegistrationToken contentToken;
    g_webview->add_ContentLoading(
        Microsoft::WRL::Callback<ICoreWebView2ContentLoadingEventHandler>(
            [](ICoreWebView2* sender, ICoreWebView2ContentLoadingEventArgs* args) -> HRESULT {
                std::cout<<"[WEBVIEW]: Content loaded\n";
                sender->ExecuteScript(EXEC_SHELL_SCRIPT, nullptr);
                sender->ExecuteScript(GetInjectedChaptersScript().c_str(), nullptr);
                return S_OK;
            }
        ).Get(),
        &contentToken
    );

    EventRegistrationToken domToken;
    g_webview->add_DOMContentLoaded(
        Microsoft::WRL::Callback<ICoreWebView2DOMContentLoadedEventHandler>(
        [](ICoreWebView2* sender, ICoreWebView2DOMContentLoadedEventArgs* args)->HRESULT
        {
            sender->ExecuteScript(EXEC_SHELL_SCRIPT, nullptr);
            sender->ExecuteScript(GetInjectedChaptersScript().c_str(), nullptr);
            return S_OK;
        }).Get(),
        &domToken
    );

    EventRegistrationToken contextMenuToken;
    g_webview->add_ContextMenuRequested(
        Microsoft::WRL::Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [](ICoreWebView2* sender, ICoreWebView2ContextMenuRequestedEventArgs* args) -> HRESULT {
                // Existing variable declarations
                wil::com_ptr<ICoreWebView2ContextMenuItemCollection> items;
                HRESULT hr = args->get_MenuItems(&items);
                if (FAILED(hr) || !items) return hr;

                #ifdef DEBUG_LOG
                return S_OK; //DEV TOOLS DEBUG ONLY
                #endif

                // Get current URL
                wil::unique_cotaskmem_string currentUri;
                sender->get_Source(&currentUri);
                std::wstring uri(currentUri.get());
                bool isExtensionUrl = uri.starts_with(L"chrome-extension://");

                // Get context menu target
                wil::com_ptr<ICoreWebView2ContextMenuTarget> target;
                hr = args->get_ContextMenuTarget(&target);
                BOOL isEditable = FALSE;
                if (SUCCEEDED(hr) && target) {
                    target->get_IsEditable(&isEditable);
                }

                UINT count = 0;
                items->get_Count(&count);

                if (!isEditable) {
                    // Allow only Back command (ID 33000) for extension URLs
                    std::set<INT32> allowedCommands = isExtensionUrl ?
                        std::set<INT32>{33000} :
                        std::set<INT32>{};

                    for (UINT i = 0; i < count;) {
                        wil::com_ptr<ICoreWebView2ContextMenuItem> item;
                        hr = items->GetValueAtIndex(i, &item);
                        if (FAILED(hr)) {
                            i++;
                            continue;
                        }

                        INT32 commandId;
                        item->get_CommandId(&commandId);

                        if (allowedCommands.find(commandId) == allowedCommands.end()) {
                            items->RemoveValueAtIndex(i);
                            items->get_Count(&count);
                        } else {
                            i++;
                        }
                    }
                    return S_OK;
                }

                // Define allowed command IDs for filtering
                std::set<INT32> allowedCommandIds = {
                    50151, // Cut
                    50150, // Copy
                    50152, // Paste
                    50157, // Paste as plain text
                    50156  // Select all
                };

                for (UINT i = 0; i < count;) {
                    wil::com_ptr<ICoreWebView2ContextMenuItem> item;
                    hr = items->GetValueAtIndex(i, &item);
                    if (FAILED(hr)) {
                        i++;
                        continue;
                    }

                    INT32 commandId;
                    item->get_CommandId(&commandId);

                    if (allowedCommandIds.find(commandId) == allowedCommandIds.end()) {
                        items->RemoveValueAtIndex(i);
                        items->get_Count(&count);
                    } else {
                        i++;
                    }
                }
                return S_OK;
            }).Get(),
        &contextMenuToken
    );

    EventRegistrationToken msgToken;
    g_webview->add_WebMessageReceived(
        Microsoft::WRL::Callback<ICoreWebView2WebMessageReceivedEventHandler>(
        [](ICoreWebView2* /*sender*/, ICoreWebView2WebMessageReceivedEventArgs* args)->HRESULT
        {
            wil::unique_cotaskmem_string msgRaw;
            args->TryGetWebMessageAsString(&msgRaw);
            if(!msgRaw) return S_OK;
            std::wstring wstr(msgRaw.get());
            std::string str = WStringToUtf8(wstr);
            HandleInboundJSON(str);

            return S_OK;
        }).Get(),
        &msgToken
    );

    EventRegistrationToken newWindowToken;
    g_webview->add_NewWindowRequested(
        Microsoft::WRL::Callback<ICoreWebView2NewWindowRequestedEventHandler>(
            [](ICoreWebView2* /*sender*/, ICoreWebView2NewWindowRequestedEventArgs* args) -> HRESULT
            {
                // Mark the event as handled to prevent default behavior
                args->put_Handled(TRUE);

                wil::unique_cotaskmem_string uri;
                if (SUCCEEDED(args->get_Uri(&uri)) && uri)
                {
                    std::wstring wuri(uri.get());
                    // Check if the URI is a local file (starts with "file://")
                    if (wuri.rfind(L"file://", 0) == 0)
                    {
                        std::wstring filePath = wuri.substr(8);
                        std::string utf8FilePath = WStringToUtf8(filePath);
                        std::string decodedFilePathUtf8 = decodeURIComponent(utf8FilePath);
                        std::string baseName = std::filesystem::path(decodedFilePathUtf8).filename().string();
                        if (isSubtitle(filePath)) {
                            std::vector<std::string> subaddArgs = {"sub-add",decodedFilePathUtf8, "select", baseName + " External", "Other Tracks"};
                            HandleEvent("mpv-command", subaddArgs);
                            json j;
                            j["type"] = "SubtitleDropped";
                            j["path"] = utf8FilePath;
                            SendToJS("SubtitleDropped", j);
                            return S_OK;
                        }
                        json j;
                        j["type"] = "FileDropped";
                        j["path"] = decodedFilePathUtf8;
                        SendToJS("FileDropped", j);
                        return S_OK;
                    }
                    if (URLContainsAny(wuri)) {
                        g_webview->Navigate(wuri.c_str());
                        return S_OK;
                    }
                    // For non-file URIs, open externally
                    ShellExecuteW(nullptr, L"open", uri.get(), nullptr, nullptr, SW_SHOWNORMAL);
                }
                return S_OK;
            }
        ).Get(),
        &newWindowToken
    );

    // For redirects like window.location.replace
    EventRegistrationToken navstartedToken;
    g_webview->add_NavigationStarting(
        Microsoft::WRL::Callback<ICoreWebView2NavigationStartingEventHandler>(
            [](ICoreWebView2* sender, ICoreWebView2NavigationStartingEventArgs* args) -> HRESULT
            {
                wil::unique_cotaskmem_string uri;
                args->get_Uri(&uri);
                std::wstring destination(uri.get());

                if (!URLContainsAny(destination)) {
                    args->put_Cancel(TRUE);
                    ShellExecuteW(nullptr, L"open", uri.get(), nullptr, nullptr, SW_SHOWNORMAL);
                }
                return S_OK;
            }
        ).Get(),
        &navstartedToken
    );

    // FullScreen
    EventRegistrationToken cfeToken;
    g_webview->add_ContainsFullScreenElementChanged(
        Microsoft::WRL::Callback<ICoreWebView2ContainsFullScreenElementChangedEventHandler>(
            [](ICoreWebView2* sender, IUnknown* /*args*/) -> HRESULT
            {
                // FullScreen Toggle Handle
                BOOL inFull = FALSE;
                sender->get_ContainsFullScreenElement(&inFull);
                ToggleFullScreen(g_hWnd, inFull != FALSE);
                return S_OK;
            }
        ).Get(),
        &cfeToken
    );
}

static void SetupExtensions()
{
    if(!g_webview || !g_webviewProfile) return;

    // e.g. from "portable_config/extensions"
    std::wstring exeDir;
    {
        wchar_t buf[MAX_PATH];
        GetModuleFileNameW(nullptr, buf, MAX_PATH);
        exeDir = buf;
        size_t pos = exeDir.find_last_of(L"\\/");
        if(pos!=std::wstring::npos) exeDir.erase(pos);
    }
    std::wstring extensionsRoot = exeDir + L"\\portable_config\\extensions";

    try {
        for(const auto& entry : std::filesystem::directory_iterator(extensionsRoot)) {
            if(entry.is_directory()) {
                std::wstring folderName = entry.path().filename().wstring();
                HRESULT hr = g_webviewProfile->AddBrowserExtension(
                    entry.path().wstring().c_str(),
                    Microsoft::WRL::Callback<ICoreWebView2ProfileAddBrowserExtensionCompletedHandler>(
                    [folderName](HRESULT result, ICoreWebView2BrowserExtension* extension)->HRESULT
                    {
                        if (SUCCEEDED(result) && extension)
                        {
                            wil::unique_cotaskmem_string extId;
                            HRESULT hrId = extension->get_Id(&extId);
                            if (SUCCEEDED(hrId) && extId)
                            {
                                // Store extension ID in the global map
                                g_extensionMap[folderName] = extId.get();
                                std::wcout << L"[EXTENSIONS]: " << folderName
                                           << L" => " << extId.get() << std::endl;
                            }
                            std::wcout << L"[EXTENSIONS]: Added extension " << folderName << std::endl;
                        } else {
                            std::wstring err = L"[EXTENSIONS]: Failed to add extension => " + std::to_wstring(result);
                            AppendToCrashLog(err);
                        }
                        return S_OK;
                    }).Get()
                );
                if(FAILED(hr)) {
                    std::wstring err = L"[EXTENSIONS]: AddBrowserExtension failed => " + std::to_wstring(hr);
                    AppendToCrashLog(err);
                }
            }
        }
    } catch(...) {
        std::cout<<"[EXTENSIONS]: No extensions folder or iteration failed.\n";
    }
}

static void SetupWebMods()
{
    if (!g_webview) return;

    wchar_t buf[MAX_PATH];
    GetModuleFileNameW(nullptr, buf, MAX_PATH);
    std::wstring exeDir = buf;
    size_t pos = exeDir.find_last_of(L"\\/");
    if (pos != std::wstring::npos) exeDir.erase(pos);

    const std::filesystem::path root = std::filesystem::path(exeDir) / L"portable_config" / L"webmods";
    if (!std::filesystem::exists(root) || !std::filesystem::is_directory(root)) {
        std::wcout << L"[WEBMODS] Folder not found: " << root.wstring() << std::endl;
        return;
    }

    std::vector<std::filesystem::path> cssFiles, jsFiles;
    for (const auto& e : std::filesystem::recursive_directory_iterator(root)) {
        if (!e.is_regular_file()) continue;
        auto ext = e.path().extension().wstring();
        std::transform(ext.begin(), ext.end(), ext.begin(), ::towlower);
        if (ext == L".map" || ext == L".bak" || ext == L".tmp") continue;
        if (ext == L".css") cssFiles.push_back(e.path());
        else if (ext == L".js") jsFiles.push_back(e.path());
    }

    auto relStr = [&](const std::filesystem::path& p){
        try { return std::filesystem::relative(p, root).wstring(); }
        catch(...) { return p.wstring(); }
    };
    auto sorter = [&](const std::filesystem::path& a, const std::filesystem::path& b){
        auto ra = relStr(a), rb = relStr(b);
        return _wcsicmp(ra.c_str(), rb.c_str()) < 0;
    };
    std::sort(cssFiles.begin(), cssFiles.end(), sorter);
    std::sort(jsFiles.begin(), jsFiles.end(), sorter);

    auto makeId = [&](const std::filesystem::path& p){
        std::wstring id = relStr(p);
        for (auto& ch : id) if (!iswalnum(ch)) ch = L'_';
        return id;
    };

    for (const auto& p : cssFiles) {
        std::string content;
        if (!ReadFileUtf8(p.wstring(), content)) continue;
        const std::wstring id = makeId(p);
        const std::wstring script = MakeInjectCssScript(id, content);
        g_webview->AddScriptToExecuteOnDocumentCreated(script.c_str(), nullptr);
        std::wcout << L"[WEBMODS] CSS: " << relStr(p) << std::endl;
    }

    for (const auto& p : jsFiles) {
        std::string content;
        if (!ReadFileUtf8(p.wstring(), content)) continue;
        const std::wstring id = makeId(p);
        const std::wstring script = MakeInjectJsScript(id, content);
        g_webview->AddScriptToExecuteOnDocumentCreated(script.c_str(), nullptr);
        std::wcout << L"[WEBMODS] JS: " << relStr(p) << std::endl;
    }
}

void refreshWeb(const bool refreshAll) {
    if (g_webviewProfile && refreshAll)
    {
        HRESULT hr = g_webviewProfile->ClearBrowsingData(
            COREWEBVIEW2_BROWSING_DATA_KINDS_DISK_CACHE |
            COREWEBVIEW2_BROWSING_DATA_KINDS_CACHE_STORAGE |
            COREWEBVIEW2_BROWSING_DATA_KINDS_SERVICE_WORKERS |
            COREWEBVIEW2_BROWSING_DATA_KINDS_FILE_SYSTEMS |
            COREWEBVIEW2_BROWSING_DATA_KINDS_WEB_SQL |
            COREWEBVIEW2_BROWSING_DATA_KINDS_INDEXED_DB,
            Microsoft::WRL::Callback<ICoreWebView2ClearBrowsingDataCompletedHandler>(
                [](HRESULT result) -> HRESULT {
                    std::cout << "[BROWSER]: Cleared browser cache successfully" << std::endl;
                    return S_OK;
                }
            ).Get()
        );
        if (FAILED(hr)) {
            std::cout << "[BROWSER]: Could not clear browser cache" << std::endl;
        }
    }
    if (g_webview) {
        g_webview->Reload();
    }
}