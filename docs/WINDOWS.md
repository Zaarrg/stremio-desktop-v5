
# Building on Windows

---

## 🚀 Quick Overview

This guide walks you through the process of building Stremio on Windows. Follow the steps carefully to set up the environment, build dependencies, and compile the project.

---

## 🛠️ Requirements

Ensure the following are installed on your system:

- **Operating System**: Windows 7 or newer
- **Utilities**: [7zip](https://www.7-zip.org/) or similar
- **Tools**:
    - [Git](https://git-scm.com/download/win)
    - [Microsoft Visual Studio](https://visualstudio.microsoft.com/)
    - [CMake](https://cmake.org/)
    - [Qt](https://www.qt.io/)
    - [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html)
    - [Node.js](https://nodejs.org/)
    - [FFmpeg](https://ffmpeg.org/download.html)
    - [MPV](https://sourceforge.net/projects/mpv-player-windows/)

---

## 📂 Setup Guide

### 1️⃣ **Install Essential Tools**
- **Git**: [Download](https://git-scm.com/download/win) and install.
- **Visual Studio**: [Download Community 2022](https://visualstudio.microsoft.com/de/downloads/).
- **Node.js**: Get version [v8.17.0](https://nodejs.org/dist/v8.17.0/win-x86/node.exe).
- **FFmpeg**: [Download](https://ffmpeg.zeranoe.com/builds/win32/static/ffmpeg-3.3.4-win32-static.zip).  
  *(Other versions may also work)*.

---

### 2️⃣ **Build Qt (6.8.1)**


1. Download Qt Online installer [here](https://www.qt.io/download-dev). Sadly a Qt Account must be created just for the download.

2. Run the installer and login

3. Select `Qt > Qt 6.8.1` and `Extensions > Qt WebEngine > Qt 6.8.1`

> **⏳ Note**: You can as well only select the needed modules which are 
> `qt5-webview qt5-websockets qt5-webglplugin qt5-webengine qt5-webchannel qt5-tools qt5-declarative qt5-quickcontrols2 qt5-quickcontrols`
> and `MSVC 2020`
> 
---

### 3️⃣ **Prepare the MPV Library**

- Download the MPV library: [MPV libmpv](https://sourceforge.net/projects/mpv-player-windows/files/libmpv/).
- Use the `mpv-dev-i686` version.
> **⏳ Note:** The submodule https://github.com/Zaarrg/libmpv already includes .lib, just make sure to unzip the actual .dll for x64 systems.
---

### 4️⃣ **Clone and Configure the Repository**

1. Clone the repository:
   ```cmd
   git clone --recursive git@github.com:Zaarrg/stremio-desktop-v5.git
   cd stremio-shell
   ```
2. Update system Envs:
   ```cmd
   set CMAKE_PREFIX_PATH=C:/Qt/6.8.1/msvc2022_64
   set Qt6_DIR=C:/Qt/6.8.1/msvc2022_64/lib/cmake/Qt6
   set PATH=C:/Qt/6.8.1/msvc2022_64/bin;C:/Program Files/OpenSSL-Win64/bin;%PATH%
   ```

3. Download the `server.js` file:
   ```cmd
   powershell -Command Start-BitsTransfer -Source "https://s3-eu-west-1.amazonaws.com/stremio-artifacts/four/v%package_version%/server.js" -Destination server.js
   ```
---

### 5️⃣ **Build / Deploying the Shell**

1. Make sure to run the following in the `x64 Native Tools Command Prompt for VS 2022`

2. Run the deployment script in the ``build`` folder
   ```cmd
   node deploy_windows.js --installer
   ```
> **⏳ Note:** This script uses common paths for ``qt`` and ``openssl`` make sure those are installed. If running with ``--installer`` make sure u installed ``nsis`` with the needed ``nsprocess`` plugin at least once.

3. Done. This will build the `installer` and ``dist/win`` folder.

> **⏳ Note:** This will create `dist/win` with all necessary files like `node.exe`, `ffmpeg.exe`. Also make sure to have `node.exe, stremio-runtime.exe, server.js` are in `utils\windows\` folder
---

## 📦 Installer (Optional)

1. Download and install [NSIS](https://nsis.sourceforge.io/Download).  
   Default path: `C:\Program Files (x86)\NSIS`.

2. Generate the installer:
   ```cmd
    FOR /F "tokens=4 delims=() " %i IN ('findstr /C:"project(stremio VERSION" CMakeLists.txt') DO @set "package_version=%~i"
   "C:\Program Files (x86)\NSIS\makensis.exe" utils\windows\installer\windows-installer.nsi
   ```
    - Result: `Stremio %package_version%.exe`.

---

## 🔧 Silent Installation

Run the installer with `/S` (silent mode) and configure via these options:

- `/notorrentassoc`: Skip `.torrent` association.
- `/nodesktopicon`: Skip desktop shortcut.

Silent uninstall:
```cmd
"%LOCALAPPDATA%\Programs\LNV\Stremio-4\Uninstall.exe" /S /keepdata
```

---

✨ **Happy Building!**
