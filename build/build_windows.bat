@echo off
REM ============================================
REM Build and prepare the dist-win folder
REM ============================================

REM Check if BUILD_DIR is provided as an argument
if "%~1"=="" (
    REM Prompt the user for BUILD_DIR
    set /p BUILD_DIR="Please enter the path to the build directory (e.g., C:\path\to\build): "
) else (
    set "BUILD_DIR=%~1"
)

REM Check if SSL_BIN_DIR is provided as an argument
if "%~2"=="" (
    REM Prompt the user for SSL_BIN_DIR
    set /p SSL_BIN_DIR="Please enter the path to the OpenSSL bin directory (e.g., C:\Program Files\OpenSSL-Win64\bin): "
) else (
    set "SSL_BIN_DIR=%~2"
)

REM Remove trailing backslash from BUILD_DIR if present
if "%BUILD_DIR:~-1%"=="\" set "BUILD_DIR=%BUILD_DIR:~0,-1%"


REM Define variables
set "PROJECT_NAME=stremio"
pushd %~dp0..
set "SOURCE_DIR=%CD%\"
popd
set "DIST_DIR=%SOURCE_DIR%dist\win"
set "BUILD_DIR=%SOURCE_DIR%%BUILD_DIR%"

REM Define paths to MPV DLL and other dependencies
set "MPV_DLL=%SOURCE_DIR%deps\libmpv\x86_64\libmpv-2.dll"

REM Step 0: Check if windeployqt.exe exists

REM Check if windeployqt.exe exists in PATH
where windeployqt.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "WINDEPLOYQT_EXECUTABLE=windeployqt.exe"
    echo Found windeployqt.exe in PATH.
) else (
    echo windeployqt.exe not found in PATH.
    REM Check if windeployqt.exe exists at the default path
    set "DEFAULT_QT_BIN=C:\Qt\6.8.1\msvc2022_64\bin"
    if exist "%DEFAULT_QT_BIN%\windeployqt.exe" (
        set "WINDEPLOYQT_EXECUTABLE=%DEFAULT_QT_BIN%\windeployqt.exe"
        echo Found windeployqt.exe at default path: %WINDEPLOYQT_EXECUTABLE%
    ) else (
        REM Prompt the user for the qt5\bin path
        set /p QT_BIN_DIR="Please enter the path to qt5\bin directory (e.g., C:\Qt\5.15.2\msvc2019_64\bin): "
        if exist "%QT_BIN_DIR%\windeployqt.exe" (
            set "WINDEPLOYQT_EXECUTABLE=%QT_BIN_DIR%\windeployqt.exe"
            echo Found windeployqt.exe at: %WINDEPLOYQT_EXECUTABLE%
        ) else (
            echo Error: windeployqt.exe not found at specified location.
            pause
            exit /b 1
        )
    )
)

REM Start the build process
echo ============================================
echo Building and preparing the dist-win folder
echo ============================================

REM Step 1: Clean and create dist-win directory
echo Cleaning and creating dist-win directory...
if exist "%DIST_DIR%" (
    REM Remove read-only attributes
    attrib -R "%DIST_DIR%" /S /D
    REM Force delete directory
    rmdir /S /Q "%DIST_DIR%"
)
mkdir "%DIST_DIR%"

REM Step 2: Copy executable to dist-win
echo Copying executable to dist-win...
if exist "%BUILD_DIR%\%PROJECT_NAME%.exe" (
    copy "%BUILD_DIR%\%PROJECT_NAME%.exe" "%DIST_DIR%" /Y >nul
) else (
    echo Error: Executable %PROJECT_NAME%.exe not found in %BUILD_DIR%.
    pause
    exit /b 1
)

REM Verify that the executable exists in dist-win
if exist "%DIST_DIR%\%PROJECT_NAME%.exe" (
    echo Executable copied successfully.
) else (
    echo Error: Executable %PROJECT_NAME%.exe not found in %DIST_DIR%.
    pause
    exit /b 1
)

REM Step 3: Copy MPV DLL into dist-win
echo Copying MPV DLL into dist-win...
copy "%MPV_DLL%" "%DIST_DIR%" /Y >nul

REM Step 4: Copy server.js into dist-win
echo Copying server.js into dist-win...
copy "%SOURCE_DIR%utils\windows\server.js" "%DIST_DIR%" /Y >nul

REM Step 5: Copy node.exe into dist-win
echo Copying node.exe into dist-win...
copy "%SOURCE_DIR%utils\windows\node.exe" "%DIST_DIR%" /Y >nul

REM Step 6: Copy required DLLs into dist-win
echo Copying required OpenSSL DLLs into dist-win...

set DLL_LIST=libcrypto-3-x64.dll libssl-3-x64.dll

for %%D in (%DLL_LIST%) do (
    echo Copying %%D...
    copy "%SSL_BIN_DIR%\%%D" "%DIST_DIR%" /Y >nul
)


REM Step 7: Copy all files from windows\DS\ into dist-win
echo Copying DS files into dist-win...
xcopy "%SOURCE_DIR%utils\windows\DS\*" "%DIST_DIR%\" /E /I /Y >nul

REM Step 7.1: Copy all files from windows\DS\ into dist-win
echo Copying stremio-runtime files into dist-win...
xcopy "%SOURCE_DIR%utils\windows\stremio-runtime.exe" "%DIST_DIR%\" /Y >nul

REM Step 7.2: Copy all files from windows\ffmpeg\ into dist-win
echo Copying ffmpeg files into dist-win...
xcopy "%SOURCE_DIR%utils\windows\ffmpeg\*" "%DIST_DIR%\" /E /I /Y >nul

REM Step 8: Run windeployqt in dist-win
echo Deploying Qt dependencies with windeployqt...
%WINDEPLOYQT_EXECUTABLE% --qmldir %SOURCE_DIR% %DIST_DIR%\%PROJECT_NAME%.exe

REM Check if windeployqt succeeded
if %ERRORLEVEL% NEQ 0 (
    echo Error: windeployqt failed.
    pause
    exit /b 1
)

echo ============================================
echo Build and preparation of dist-win completed.
echo ============================================

pause