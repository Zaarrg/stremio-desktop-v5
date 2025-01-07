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
- 🔍 **Video Upscaling**:  Upscaling support through mpv configuration file ``mpv.conf``

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

## 🔍 **Mpv Upscalers**

- 🎥 **[Anime4k](https://github.com/bloc97/Anime4K)**
    - ✅ Included by default.
    - 🔢 Use `CTRL+1` - `CTRL+6` to enable shaders.
    - ❌ Use `CTRL+0` to disable.

- 🎨 **[AnimeJaNai](https://github.com/the-database/mpv-upscale-2x_animejanai)**
    - ❌ Not included by default.
    - 📥 Download from the **Stremio-Desktop-v5** [release tab](https://github.com/Zaarrg/stremio-desktop-v5) the `stremio-animejanai-3.x.x.7z` for Stremio and drop the content of the 7z into `%localAppData%\Programs\LNV\Stremio-5\` and `replace all`
        - 🛠️ **Changes made:**
            - Removed `mpvnet.exe` as Stremio is used as the player.
            - Adjusted `mpv.conf` to work with Stremio.
            - Adjusted `input.conf` to work with Stremio.
- ⌨️ **Possible Keybindings**
    - 🎬 `CTRL+J` Show Upscaler Status
    - 🛠️ `CTRL+E` Open AnimeJaNai ConfEditor
    - ❌ `CTRL+0` Disable Upscaling
    - 🔢 `SHIFT+1` - `SHIFT+3` Select Quality, Balanced or Performance Profiles
    - ⚙️ `CTRL+1` - `CTRL+9` Switch between Custom Profiles
    - 🔗 For more, check [AnimeJaNai](https://github.com/the-database/mpv-upscale-2x_animejanai)

> **⏳ Note:** When using AnimeJaNai on first playback Stremio will be unresponsive and a console will open to build the model via e.g. TensorRT. You will need to wait until the console closes for playback to start. This happens only once per model.


- 🚀 **Nvidia RTX and Intel VSR Scaling**
    - 🔜 Coming soon!

> **⏳ Note:** Nvidia RTX and Intel VSR Scaling support might take some time as this requires quite a big rewrite to support mpv wid embedding with d3d as current libmpv implementation only supports opengl and this as well will allow for proper hdr support.


## 🎛️ **Mpv Configuration**

Enhance your Stremio experience by customizing the MPV player settings. Below are the key configuration files and guidelines to help you get started:

- 📁 **`mpv.conf` Location**
    - The ``mpv.conf`` file can be found in the following location:
        - **Installation Path:** ``%localAppData%\Programs\LNV\Stremio-5\portable_config\mpv.conf``
        - **Shaders Folder:** Located within the installation directory ``..\Stremio-5\portable_config\shaders``.

> **⏳ Note:** Any other configuration files can be just dropped into ``%localAppData%\Programs\LNV\Stremio-5\portable_config`` as this is the mpv ``config-dir`` like ``input.conf``

  - **🎹 Usage example in `input.conf` using [Anime4k](https://github.com/bloc97/Anime4K):**
    ```shell
    # Optimized shaders for higher-end GPU
    CTRL+1 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode A (HQ)"
    CTRL+2 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode B (HQ)"
    CTRL+3 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode C (HQ)"
    CTRL+4 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_Restore_CNN_M.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode A+A (HQ)"
    CTRL+5 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_VL.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Restore_CNN_Soft_M.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode B+B (HQ)"
    CTRL+6 no-osd change-list glsl-shaders set "~~/shaders/Anime4K_Clamp_Highlights.glsl;~~/shaders/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl;~~/shaders/Anime4K_AutoDownscalePre_x2.glsl;~~/shaders/Anime4K_AutoDownscalePre_x4.glsl;~~/shaders/Anime4K_Restore_CNN_M.glsl;~~/shaders/Anime4K_Upscale_CNN_x2_M.glsl"; show-text "Anime4K: Mode C+A (HQ)"
    
    CTRL+0 no-osd change-list glsl-shaders clr ""; show-text "GLSL shaders cleared"
    ```
> **⏳ Note:** Some keys might not work as key presses are converted from js event.codes to literal values for mpv

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
If you want to build this app yourself, check the “[docs](https://github.com/Zaarrg/stremio-desktop-v5/tree/master/docs)” folder in this repository for setup instructions and additional information.

## ⚠️ **Disclaimer**
This project is not affiliated with **Stremio** in any way.

## 🤝 **Support Development**
If you enjoy this project and want to support further development, consider [buying me a coffee](https://ko-fi.com/zaarrg). Your support means a lot! ☕

<p align="center">
  <strong>⭐ Made with ❤️ by <a href="https://github.com/Zaarrg">Zaarrg</a> ⭐</strong>
</p>