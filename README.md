<p align="center">
  <img src="https://www.stremio.com/website/stremio-logo-small.png" alt="Stremio Web Desktop Logo" width="200" />
</p>
<div align="center">
  <h1>🌌 Stremio Desktop<br/><span style="font-size: 0.6em; font-weight: normal;">Community</span></h1>
</div>

<p align="center">Stremio Desktop app with the latest Stremio web UI v5, built with Qt6</p>
<p align="center">
  <!-- Qt6 badge (official Qt logo and brand color) -->
  <img src="https://img.shields.io/badge/Qt6-41CD52?style=for-the-badge&logo=qt&logoColor=white" alt="Qt6" />
  <!-- C++ badge -->
  <img src="https://img.shields.io/badge/C++-00599C?style=for-the-badge&logo=c%2B%2B&logoColor=white" alt="C++" />
  <!-- QML badge (custom static badge, since there’s no official QML logo) -->
  <img src="https://img.shields.io/badge/QML-696969?style=for-the-badge&logo=qt&logoColor=white" alt="QML" />
  <!-- WebView badge -->
  <img src="https://img.shields.io/badge/WebView-FF6E40?style=for-the-badge&logo=web&logoColor=white" alt="Qt WebView" />
  <!-- MPV badge (custom static badge) -->
  <img src="https://img.shields.io/badge/MPV-663399?style=for-the-badge&logo=mpv&logoColor=white" alt="MPV" />
</p>

## 🌟 **Features**
- 🚀 **Latest Technology**: Built with Qt6 to provide the newest features and best performance
- 🌐 **Latest Web Ui**: Always up-to-date with Stremio Web v5
- 🎞️ **Native Playback**: Integrated Player for native 4K playback, hardware decoding, and fastest video performance

<p align="center">
  <img src="https://i.imgur.com/xvM5lp8.png" alt="Stremio Web Desktop Screenshot" width="600" />
</p>

## 🔧 Installation

1. **Windows (x64)** 
- **Install using the** `Installer`. Download `stremio-5.0.0.exe` and run it.
- **Install using the** `Archive`. Download `stremio-5.0.0.rar` extract it and run `stremio.exe`

> **⏳ Note:** If you have stremio-desktop v4.x.x installed make sure to uninstall it first. Otherwise there will be issues.

2.**Windows (x86), macOS, Linux**
- Coming soon!

## ⚙️ **Start Arguments**
Use these extra arguments when launching the application:

| Argument            | Example                                               | Description                                                                                                     |
|---------------------|-------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| --development       |                                                       | Loads from `http://127.0.0.1:11470` instead of `https://app.strem.io` and does not force start streaming server |
| --staging           |                                                       | Loads web ui from `https://staging.strem.io`                                                                    |
| --webui-url=        | --webui-url=https://web.stremio.com/                  | Loads web ui from `https://web.stremio.com/`                                                                    |
| --streaming-server  |                                                       | When used with `development`, it would try to start a streaming server. Default behaviour in prod               |
| --autoupdater-force |                                                       | Forces Autoupdater to check for a new version                                                                   |
| --autoupdater-force-full           |                                                       | Forces Autoupdate to always do a `full-update` rather than `partial`                                            |
| --autoupdater-endpoint=           | --autoupdater-endpoint==https://verison.mydomain.com/ | Overrides default checking endpoint for the autoupdater                                                         |

> **⏳ Note:** By default will use as ``webui-url`` the [stremio-web-shell](https://github.com/Zaarrg/stremio-web-shell-fixes) web-ui hosted [here](https://zaarrg.github.io/stremio-web-shell-fixes/#/) which includes fixes to run smoothly with qt6

## 📚 **Guide / Docs**
If you want to build this app yourself, check the “docs” folder in this repository for setup instructions and additional information.


## ⚠️ **Disclaimer**
This project is not affiliated with **Stremio** in any way.

## 🤝 **Support Development**
If you enjoy this project and want to support further development, consider [buying me a coffee](https://ko-fi.com/zaarrg). Your support means a lot! ☕

<p align="center">
  <strong>⭐ Made with ❤️ by <a href="https://github.com/Zaarrg">Zaarrg</a> ⭐</strong>
</p>