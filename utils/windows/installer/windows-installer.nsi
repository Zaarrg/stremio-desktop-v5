
;Stremio
;Installer Source for NSIS 3.0 or higher

Unicode True

#Tells the compiler whether or not to do datablock optimizations.
SetDatablockOptimize on

;Include Modern UI
!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "fileassoc.nsh"
!include "nsProcess.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

;Parse package.json

!define APP_NAME "StremioCommunity"
!define PRODUCT_VERSION "$%package_version%"
!define ARCH "$%arch%"
!searchparse "${PRODUCT_VERSION}" `` VERSION_MAJOR `.` VERSION_MINOR `.` VERSION_REVISION
!define APP_URL "https://github.com/Zaarrg/stremio-community-v5"
!define DATA_FOLDER "stremio"

!define COMPANY_NAME "Zaarrg"


; ------------------- ;
;      Settings       ;
; ------------------- ;
;General Settings
Name "${APP_NAME}"
Caption "${APP_NAME} ${PRODUCT_VERSION} - Installer"
BrandingText "${APP_NAME} ${PRODUCT_VERSION}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "ProductVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "FileDescription" "${APP_NAME} ${PRODUCT_VERSION} Installer"
VIAddVersionKey "FileVersion" "${PRODUCT_VERSION}"
VIAddVersionKey "CompanyName" "${COMPANY_NAME}"
VIAddVersionKey "LegalCopyright" "${APP_URL}"
VIProductVersion "${PRODUCT_VERSION}.0"
OutFile "../../${APP_NAME} ${PRODUCT_VERSION}-${ARCH}.exe"
ShowInstDetails "nevershow"
ShowUninstDetails "nevershow"
CRCCheck on
;SetCompressor /SOLID lzma
;SetCompressorDictSize 4
;SetCompressor lzma
;SetCompressorDictSize 1
SetCompressor /SOLID lzma
SetCompressorDictSize 128

;Default installation folder
InstallDir "$LOCALAPPDATA\Programs\LNV\${APP_NAME}-${VERSION_MAJOR}"
InstallDirRegKey HKLM Software\SmartCode\Stremio InstallLocation

;Request application privileges
;RequestExecutionLevel highest
RequestExecutionLevel user
;RequestExecutionLevel admin

!define APP_LAUNCHER "Stremio.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"

; ------------------- ;
;     UI Settings     ;
; ------------------- ;
;Define UI settings

;!define MUI_UI_HEADERIMAGE_RIGHT "../../../images/icon.png"
!define MUI_ICON "../../../images/stremio2.ico"
!define MUI_UNICON "../../../images/stremio2.ico"

; WARNING; these bmps have to be generated in BMP3 - convert SMTH BMP3:SMTH.bmp
!define MUI_WELCOMEFINISHPAGE_BITMAP "windows-installer.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "windows-installer.bmp"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\stremio.exe"

; Hack...
!define MUI_FINISHPAGE_SHOWREADME ""
;!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!define MUI_FINISHPAGE_SHOWREADME_TEXT "$(desktopShortcut)"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION finishpageaction
!define MUI_FINISHPAGE_TITLE "Completing the ${APP_NAME} Setup"

; Define header image
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "windows-installer-header.bmp"
!define MUI_HEADERIMAGE_BITMAP_NOSTRETCH
!define MUI_HEADER_TRANSPARENT_TEXT
; also consider MUI_WELCOMEFINISHPAGE_BITMAP

; Beautiful progress bar
XPStyle off
!define MUI_INSTALLCOLORS "000000 643F9E"
!define MUI_INSTFILESPAGE_PROGRESSBAR colored


# Include Sections header so that we can manipulate section properties in .onInit
!include "Sections.nsh"

;ReserveFile /plugin InstallOptions.dll

; Pages
;!insertmacro MUI_PAGE_WELCOME
; !insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
;!insertmacro MUI_PAGE_DIRECTORY

# Perform installation (executes each enabled Section)
!insertmacro MUI_PAGE_INSTFILES
!define MUI_PAGE_CUSTOMFUNCTION_SHOW fin_pg_options
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE fin_pg_leave
!insertmacro MUI_PAGE_FINISH

; Uninstall pages
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Load Language Files
!insertmacro MUI_LANGUAGE "English"

; Progress bar - part 2
!define MUI_PAGE_CUSTOMFUNCTION_SHOW InstShow

; ------------------- ;
;    Localization     ;
; ------------------- ;
LangString removeDataFolder ${LANG_ENGLISH} "Remove all data and configuration?"
LangString noRoot ${LANG_ENGLISH} "You cannot install Stremio in a directory that requires administrator permissions"
LangString desktopShortcut ${LANG_ENGLISH} "Desktop Shortcut"
LangString appIsRunning ${LANG_ENGLISH} "${APP_NAME} is running. Do you want to close it?"
LangString appIsRunningInstallError ${LANG_ENGLISH} "${APP_NAME} cannot be installed while another instance is running."
LangString appIsRunningUninstallError ${LANG_ENGLISH} "${APP_NAME} cannot be uninstalled while another instance is running."

Var Parameters

# Finish page custom options
Var AssociateMagnetCheckbox
Var AssociateMediaCheckbox
Var AssociateTorrentCheckbox
Var checkbox_value
Var InstallStremioServiceCheckbox

Function fin_pg_options
    ; Install Stremio Service checkbox (top)
    ${NSD_CreateCheckbox} 180 -100 100% 8u "Install Stremio Service"
    Pop $InstallStremioServiceCheckbox
    SetCtlColors $InstallStremioServiceCheckbox '0xFF0000' '0xFFFFFF'
    ${NSD_Uncheck} $InstallStremioServiceCheckbox

    ; Leave a visual gap here (e.g., 20 pixels)

    ${NSD_CreateCheckbox} 180 -70 100% 8u "Associate ${APP_NAME} with .torrent files"
    Pop $AssociateTorrentCheckbox
    SetCtlColors $AssociateTorrentCheckbox '0xFF0000' '0xFFFFFF'
    ${NSD_Check} $AssociateTorrentCheckbox

    ${NSD_CreateCheckbox} 180 -50 100% 8u "Associate ${APP_NAME} with magnet links"
    Pop $AssociateMagnetCheckbox
    SetCtlColors $AssociateMagnetCheckbox '0xFF0000' '0xFFFFFF'
    ${NSD_Check} $AssociateMagnetCheckbox

    ${NSD_CreateCheckbox} 180 -30 100% 8u "Associate ${APP_NAME} as media player"
    Pop $AssociateMediaCheckbox
    SetCtlColors $AssociateMediaCheckbox '0xFF0000' '0xFFFFFF'
    ${NSD_Check} $AssociateMediaCheckbox
FunctionEnd

Function fin_pg_leave
    ; Check "Install Stremio Service" checkbox state
    ${NSD_GetState} $InstallStremioServiceCheckbox $checkbox_value
    ${If} $checkbox_value == ${BST_CHECKED}
        SetDetailsPrint textonly
        DetailPrint "Installing Stremio Service..."
        SetDetailsPrint none
        ; Extract StremioServiceSetup.exe
        File "/oname=$PLUGINSDIR\StremioServiceSetup.exe" "..\StremioServiceSetup.exe"
        ExecWait '"$PLUGINSDIR\StremioServiceSetup.exe" /silent' $R0
        SetDetailsPrint textonly
        ${If} $R0 == 0
            DetailPrint "Stremio Service installed successfully."
        ${Else}
            DetailPrint "Failed to install Stremio Service (error: $R0)."
            MessageBox MB_OK|MB_ICONEXCLAMATION "Error installing Stremio Service (error code: $R0)."
        ${EndIf}
        SetDetailsPrint none
    ${EndIf}

    ${NSD_GetState} $AssociateTorrentCheckbox $checkbox_value
    ${If} $checkbox_value == ${BST_CHECKED}
        !insertmacro APP_ASSOCIATE "torrent" "stremio" "BitTorrent file" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
    ${EndIf}

    ; Set friendly name for Stremio in "Open With" menu
    WriteRegStr HKCU "Software\Classes\stremio" "FriendlyTypeName" "${APP_NAME}"
    WriteRegStr HKCU "Software\Classes\stremio\shell\open" "FriendlyAppName" "${APP_NAME}"



    ${NSD_GetState} $AssociateMagnetCheckbox $checkbox_value
    ${If} $checkbox_value == ${BST_CHECKED}
        WriteRegStr HKCU "Software\Classes\magnet" "" "Magnet Protocol"
        WriteRegStr HKCU "Software\Classes\magnet" "URL Protocol" ""
        WriteRegStr HKCU "Software\Classes\magnet\DefaultIcon" "" "$INSTDIR\stremio.exe,0"
        WriteRegStr HKCU "Software\Classes\magnet\shell\open\command" "" '"$INSTDIR\stremio.exe" "%1"'
    ${EndIf}

    ${NSD_GetState} $AssociateMediaCheckbox $checkbox_value

    !macro APP_ASSOCIATE_EXTENSIONS
        ; Define the list of extensions
        Var /GLOBAL FileExtensions
        StrCpy $FileExtensions "mp4 mkv avi mov wmv flv webm mpg mpeg 3gp m4v ts vob f4v m2ts asf divx ogv rm rmvb"

        ; Start of the loop
        Var /GLOBAL CurrentExtension
        LoopStart:
            ; Extract the first extension from the list
            StrCpy $CurrentExtension $FileExtensions 4 ; Copy up to the first space
            StrCpy $FileExtensions $FileExtensions 4 - ; Remove the extracted extension from the list
            ${If} $CurrentExtension != ""
                ; Associate the current extension
                !insertmacro APP_ASSOCIATE "$CurrentExtension" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
                ; Continue the loop
                Goto LoopStart
            ${EndIf}
        ; End of the loop
        ${EndIf}
    !macroend
    ${If} $checkbox_value == ${BST_CHECKED}
        !insertmacro APP_ASSOCIATE "mp4" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "mkv" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "avi" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "mov" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "wmv" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "flv" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "webm" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "mpg" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "mpeg" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "3gp" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "m4v" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "ts" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "vob" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "f4v" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "m2ts" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "asf" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "divx" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "ogv" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "rm" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
        !insertmacro APP_ASSOCIATE "rmvb" "stremio" "Media File" "$INSTDIR\stremio.exe,0" "Play with Stremio" "$INSTDIR\stremio.exe $\"%1$\""
    ${EndIf}
FunctionEnd

!macro RemoveAllExceptDefaultProfile un
Function ${un}RemoveAllExceptDefaultProfile
  ; Hardcoded values for your scenario
  StrCpy $R0 "Default" ; Directory to exclude
  StrCpy $R1 "$INSTDIR\stremio.exe.WebView2\EBWebView"            ; Root directory to operate on

  Push $R2
  Push $R3
  Push $R4

  ClearErrors
  FindFirst $R3 $R2 "$R1\*.*"
  IfErrors Exit

  Top:
    ; Skip special directories "." and ".."
    StrCmp $R2 "." Next
    StrCmp $R2 ".." Next

    ; Skip the excluded directory
    StrCmp $R2 $R0 Next

    ; Build full path for the current item
    StrCpy $R4 "$R1\$R2"

    ; Check if the current item is a directory
    IfFileExists "$R4\*.*" isDir notDir

    notDir:
      ; It's a file, so delete it
      Delete "$R4"
      Goto Next

    isDir:
      ; It's a directory, remove it recursively
      RMDir /r "$R4"
    Next:
      ClearErrors
      FindNext $R3 $R2
      IfErrors Exit
    Goto Top

  Exit:
    FindClose $R3

  Pop $R4
  Pop $R3
  Pop $R2
FunctionEnd
!macroend

!insertmacro RemoveAllExceptDefaultProfile ""
!insertmacro RemoveAllExceptDefaultProfile "un."


; ---------------------------------------------------
;  Removes everything from $INSTDIR except the
;  "stremio.exe.WebView2\stremio.exe.WebView2\EBWebView" and "portable_config" folder.
; ---------------------------------------------------
!macro RemoveAllExceptWebView2 un
Function ${un}RemoveAllExceptWebView2
  ; Hardcoded values for your scenario
  StrCpy $R0 "stremio.exe.WebView2" ; Directory to exclude
  StrCpy $R9 "portable_config" ; Config Directory to exclude
  StrCpy $R1 "$INSTDIR"            ; Root directory to operate on

  Push $R2
  Push $R3
  Push $R4

  ClearErrors
  FindFirst $R3 $R2 "$R1\*.*"
  IfErrors Exit

  Top:
    ; Skip special directories "." and ".."
    StrCmp $R2 "." Next
    StrCmp $R2 ".." Next

    ; Check if this item’s name begins with our backup folder prefix.
    ; Copy the first 23 characters ("portable_config_backup_") into $R5.
    StrCpy $R5 $R2 23
    StrCmp $R5 "portable_config_backup_" 0 notBackup
        ; If equal, skip deletion for this folder.
        Goto next
    notBackup:

    ; Skip the excluded directory
    StrCmp $R2 $R0 Next

    ; Skip the second excluded directory "portable_config"
    StrCmp $R2 $R9 Next

    ; Build full path for the current item
    StrCpy $R4 "$R1\$R2"

    ; Check if the current item is a directory
    IfFileExists "$R4\*.*" isDir notDir

    notDir:
      ; It's a file, so delete it
      Delete "$R4"
      Goto Next

    isDir:
      ; It's a directory, remove it recursively
      RMDir /r "$R4"
    Next:
      ClearErrors
      FindNext $R3 $R2
      IfErrors Exit
    Goto Top

  Exit:
    FindClose $R3

  Pop $R4
  Pop $R3
  Pop $R2
  Call ${un}RemoveAllExceptDefaultProfile
FunctionEnd
!macroend

!insertmacro RemoveAllExceptWebView2 ""
!insertmacro RemoveAllExceptWebView2 "un."

!macro checkIfAppIsRunning AppIsRunningErrorMsg
    ; Check if stremio.exe is running
    ${nsProcess::FindProcess} ${APP_LAUNCHER} $R0

    ${If} $R0 == 0
        IfSilent killapp
        MessageBox MB_YESNO|MB_ICONQUESTION "$(appIsRunning)" IDYES killapp
        ; Check if stremio.exe is still running.
        ; No need to abort if the user manually closes Stremio and answer NO on the prompt
        ${nsProcess::FindProcess} ${APP_LAUNCHER} $R0
        ${If} $R0 == 0
            ; Hide the progress bar
            FindWindow $0 "#32770" "" $HWNDPARENT
            GetDlgItem $1 $0 0x3ec
            ShowWindow $1 ${SW_HIDE}
            ; Abort install
            Abort "${AppIsRunningErrorMsg}"
        ${EndIf}
        killapp:
        ${nsProcess::CloseProcess} "${APP_LAUNCHER}" $R0
        Sleep 2000
    ${EndIf}

    ${nsProcess::Unload}
!macroend

; ------------------- ;
;    WebView Check    ;
; ------------------- ;

Function CheckWebView2
    ClearErrors
    StrCpy $0 ""

    ${If} ${RunningX64}
        ReadRegStr $0 HKLM "SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
        ${If} $0 == ""
            ReadRegStr $0 HKCU "Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
        ${EndIf}
    ${Else}
        ReadRegStr $0 HKLM "SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
        ${If} $0 == ""
            ReadRegStr $0 HKCU "Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}" "pv"
        ${EndIf}
    ${EndIf}

    StrCmp $0 "" NotInstalled 0
    StrCmp $0 "0.0.0.0" NotInstalled 0
    Goto WebViewPresent

NotInstalled:
    ; Switch details printing to text-only mode to display custom messages
    SetDetailsPrint textonly
    DetailPrint "WebView2 Runtime not found. Extracting setup..."

    ; Extract MicrosoftEdgeWebview2Setup.exe only when needed
    File "/oname=$PLUGINSDIR\MicrosoftEdgeWebview2Setup.exe" "..\MicrosoftEdgeWebview2Setup.exe"
    DetailPrint "Extracted WebView2 setup to $PLUGINSDIR."

    DetailPrint "Installing WebView2 Runtime..."
    SetDetailsPrint none
    ExecWait '"$PLUGINSDIR\MicrosoftEdgeWebview2Setup.exe" /silent /install' $R0
    SetDetailsPrint textonly

    ${If} $R0 != 0
        DetailPrint "Failed to install WebView2 Runtime. Error code: $R0."
        MessageBox MB_OK|MB_ICONEXCLAMATION "Error installing WebView2 Runtime (error code: $R0)."
    ${EndIf}

    DetailPrint "Finished installing WebView2 Continuing installation..."
    ; Restore previous details printing mode (last used setting)
    SetDetailsPrint lastused

WebViewPresent:
FunctionEnd


; ------------------- ;
;    Install code     ;
; ------------------- ;
Function .onInit ; check for previous version
    ; Read the previous installation directory from registry
    ReadRegStr $0 HKCU "${UNINSTALL_KEY}" "InstallString"

    ; If registry value is empty, skip version check
    StrCmp $0 "" done

    ; Expected installation directory for current major version (Stremio-5)
    StrCpy $R1 "$LOCALAPPDATA\Programs\LNV\Stremio-5"

    ; Check if the registry path matches the expected directory
    StrCmp $0 $R1 usePrev 0
    ; If it doesn't match, likely an old version, so do not use $0
    Goto done

    usePrev:
    ; If registry path matches the expected path, use it
    StrCpy $INSTDIR $0
done:
    ${GetParameters} $Parameters
    ClearErrors
    ${GetOptions} $Parameters "/addon" $R1

    FileOpen $0 "$INSTDIR\addons.txt" w
    FileWrite $0 "$R1"
    FileClose $0

    ; --- Begin custom override logic ---
    ; Check for overrideInstallDir parameter
    ClearErrors
    ${GetParameters} $Parameters           ; Retrieve all parameters again if needed
    ${GetOptions} $Parameters "/overrideInstallDir=" $0
    StrCmp $0 "" noOverride

    ; If override parameter provided, override $INSTDIR
    StrCpy $INSTDIR $0

    noOverride:
    ; --- End custom override logic ---
FunctionEnd

Var TIMESTAMP
Var day
Var month
Var year
Var day_name
Var hours
Var minutes
Var seconds

Function GetTimestamp
    ; Get local time.
    ${GetTime} "" "L" $day $month $year $day_name $hours $minutes $seconds

    ; Construct the timestamp string.
    ; Example: if day="01", month="04", year="2025", hours="16", minutes="05", seconds="50",
    ; the resulting string will be: "20250401_160550"
    StrCpy $TIMESTAMP "$year$month$day_$hours$minutes$seconds"
FunctionEnd

Function BackupPortableConfig
    ; Check if portable_config exists; if so, back it up.
    IfFileExists "$INSTDIR\portable_config\*.*" 0 backup_done
        ; Get the current timestamp (sets the global variable $TIMESTAMP)
        Call GetTimestamp
        ; Rename portable_config to portable_config_backup_<TIMESTAMP>
        Rename "$INSTDIR\portable_config" "$INSTDIR\portable_config_backup_$TIMESTAMP"
    backup_done:
FunctionEnd

Function RemoveAll
    ; Prepare registers for deletion loop
    Push $R2
    Push $R3
    Push $R4
    Push $R5

    ClearErrors
    FindFirst $R3 $R2 "$INSTDIR\*.*"
    IfErrors removeAllDone

loop:
    ; Skip special directories "." and ".."
    StrCmp $R2 "." next
    StrCmp $R2 ".." next

    ; Check if this item’s name begins with our backup folder prefix.
    ; Copy the first 23 characters ("portable_config_backup_") into $R5.
    StrCpy $R5 $R2 23
    StrCmp $R5 "portable_config_backup_" 0 notBackup
        ; If equal, skip deletion for this folder.
        Goto next
notBackup:
    ; Build the full path of this item.
    StrCpy $R4 "$INSTDIR\$R2"

    ; Check whether it's a file or a directory.
    IfFileExists "$R4\*.*" isDir notDir

notDir:
    Delete "$R4"
    Goto next

isDir:
    RMDir /r "$R4"

next:
    ClearErrors
    FindNext $R3 $R2
    IfErrors removeAllDone
    Goto loop

removeAllDone:
    FindClose $R3

    Pop $R5
    Pop $R4
    Pop $R3
    Pop $R2
FunctionEnd

Section ; App Files
    !insertmacro checkIfAppIsRunning "$(appIsRunningInstallError)"

    ; Check and install WebView2 before proceeding
    Call CheckWebView2

    ; Hide details
    SetDetailsPrint None

    ; *** Prompt the user whether to delete all user data ***
    IfSilent +3
      MessageBox MB_YESNO|MB_ICONQUESTION "Install latest portable configuration? A backup of your portable_config folder will be created if it has been modified. Continue?" IDNO SkipDataDeletion
      Call BackupPortableConfig
      Call RemoveAllExceptWebView2
      Goto DataDeletionDone
    SkipDataDeletion:
      Call RemoveAllExceptWebView2
    DataDeletionDone:

    ;Set output path to InstallDir
    SetOutPath "$INSTDIR"

    ; Prevent overwriting existing files
    SetOverwrite off

    ;Add the files
    File /r "..\..\..\dist\win-${ARCH}\*"

    ; Reset overwrite
    SetOverwrite on

    ;Create uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"

SectionEnd

; ------------------- ;
;      Shortcuts      ;
; ------------------- ;
Section ; Shortcuts
    ; Hide details
    SetDetailsPrint none

    ;Working Directory
    SetOutPath "$INSTDIR"

    ;Start Menu Shortcut
    RMDir /r "$SMPROGRAMS\${APP_NAME}"
    CreateDirectory "$SMPROGRAMS\${APP_NAME}"
    CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\stremio.exe" "" "$INSTDIR\stremio.exe" "" "" "" "${APP_NAME} ${PRODUCT_VERSION}"
    CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe" "" "$INSTDIR\stremio.exe" "" "" "" "Uninstall ${APP_NAME}"

    ;Desktop Shortcut
    Delete "$DESKTOP\${APP_NAME}.lnk"

    ;Add/remove programs uninstall entry
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" "$0"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\stremio.exe"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${COMPANY_NAME}"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallString" "$INSTDIR"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "${APP_URL}"
    WriteRegStr HKCU "${UNINSTALL_KEY}" "NoModify" 1
    WriteRegStr HKCU "${UNINSTALL_KEY}" "NoRepair" 1

    ; Register stremio:// protocol handler
    WriteRegStr HKCU "Software\Classes\stremio" "" "URL:Stremio Protocol"
    WriteRegStr HKCU "Software\Classes\stremio" "URL Protocol" ""
    WriteRegStr HKCU "Software\Classes\stremio\DefaultIcon" "" "$INSTDIR\stremio.exe,1"
    WriteRegStr HKCU "Software\Classes\stremio\shell" "" "open"
    WriteRegStr HKCU "Software\Classes\stremio\shell\open\command" "" '"$INSTDIR\stremio.exe" "%1"'

    IfSilent 0 end
    Call fin_pg_leave
    ${GetOptions} $Parameters /nodesktopicon $R1
    IfErrors 0 end
    Call finishpageaction
    end:
SectionEnd

; ------------------- ;
;     Uninstaller     ;
; ------------------- ;
; ------------------- ;
;     Uninstaller     ;
; ------------------- ;
Section "uninstall"

    ; Macro to check if application is running
    !insertmacro checkIfAppIsRunning "$(appIsRunningUninstallError)"

    SetDetailsPrint none

    ; Remove shortcuts
    RMDir /r "$SMPROGRAMS\${APP_NAME}"
    Delete "$DESKTOP\${APP_NAME}.lnk"

    ; Remove registry entries
    DeleteRegKey HKCU "${UNINSTALL_KEY}"
    DeleteRegKey HKCU Software\Classes\stremio
    DeleteRegKey HKCU Software\Classes\magnet

    ; Remove friendly name registry entry
    DeleteRegKey HKCR Applications\stremio.exe

    !insertmacro APP_UNASSOCIATE "torrent" "stremio"
    !insertmacro APP_UNASSOCIATE "mp4" "stremio"
    !insertmacro APP_UNASSOCIATE "mkv" "stremio"
    !insertmacro APP_UNASSOCIATE "avi" "stremio"
    !insertmacro APP_UNASSOCIATE "mov" "stremio"
    !insertmacro APP_UNASSOCIATE "wmv" "stremio"
    !insertmacro APP_UNASSOCIATE "flv" "stremio"
    !insertmacro APP_UNASSOCIATE "webm" "stremio"
    !insertmacro APP_UNASSOCIATE "mpg" "stremio"
    !insertmacro APP_UNASSOCIATE "mpeg" "stremio"
    !insertmacro APP_UNASSOCIATE "3gp" "stremio"
    !insertmacro APP_UNASSOCIATE "m4v" "stremio"
    !insertmacro APP_UNASSOCIATE "ts" "stremio"
    !insertmacro APP_UNASSOCIATE "vob" "stremio"
    !insertmacro APP_UNASSOCIATE "f4v" "stremio"
    !insertmacro APP_UNASSOCIATE "m2ts" "stremio"
    !insertmacro APP_UNASSOCIATE "asf" "stremio"
    !insertmacro APP_UNASSOCIATE "divx" "stremio"
    !insertmacro APP_UNASSOCIATE "ogv" "stremio"
    !insertmacro APP_UNASSOCIATE "rm" "stremio"
    !insertmacro APP_UNASSOCIATE "rmvb" "stremio"


    ; Prompt user to see if they want to remove data
    IfSilent +3
      MessageBox MB_YESNO|MB_ICONQUESTION "$(removeDataFolder)" IDNO keepUserData
      Goto removeData
    ${GetParameters} $Parameters
    ClearErrors
    ${GetOptions} $Parameters "/keepdata" $R1
    IfErrors 0 keepUserData

  removeData:
    ; User chose to remove data - remove entire install folder (including .WebView2)
    RMDir /r "$INSTDIR"
    Goto done

  keepUserData:
    ; User chose to keep data - remove all but the WebView2 folder
    Call un.RemoveAllExceptWebView2

  done:
    ; Optionally open a farewell page
    IfSilent +2
      ExecShell "open" "https://github.com/Zaarrg/stremio-desktop-v5/blob/webview-windows/docs/GOODBYE.md"

SectionEnd

; ------------------- ;
;  Check if writable  ;
; ------------------- ;
Function IsWritable

  !define IsWritable `!insertmacro IsWritableCall`

  !macro IsWritableCall _PATH _RESULT
    Push `${_PATH}`
    Call IsWritable
    Pop ${_RESULT}
  !macroend

  Exch $R0
  Push $R1

start:
  StrLen $R1 $R0
  StrCmp $R1 0 exit
  ${GetFileAttributes} $R0 "DIRECTORY" $R1
  StrCmp $R1 1 direxists
  ${GetParent} $R0 $R0
  Goto start

direxists:
  ${GetFileAttributes} $R0 "DIRECTORY" $R1
  StrCmp $R1 0 ok

  StrCmp $R0 $PROGRAMFILES64 notok
  StrCmp $R0 $WINDIR notok

  ${GetFileAttributes} $R0 "READONLY" $R1

  Goto exit

notok:
  StrCpy $R1 1
  Goto exit

ok:
  StrCpy $R1 0

exit:
  Exch
  Pop $R0
  Exch $R1

FunctionEnd

; ------------------- ;
;  Check install dir  ;
; ------------------- ;
Function CloseBrowseForFolderDialog
	!ifmacrodef "_P<>" ; NSIS 3+
		System::Call 'USER32::GetActiveWindow()p.r0'
		${If} $0 P<> $HwndParent
	!else
		System::Call 'USER32::GetActiveWindow()i.r0'
		${If} $0 <> $HwndParent
	!endif
		SendMessage $0 ${WM_CLOSE} 0 0
		${EndIf}
FunctionEnd

Function .onVerifyInstDir

  Push $R1
  ${IsWritable} $INSTDIR $R1
  IntCmp $R1 0 pathgood
  Pop $R1
  Call CloseBrowseForFolderDialog
  MessageBox MB_OK|MB_USERICON "$(noRoot)" /SD IDOK
  Abort

pathgood:
  Pop $R1

FunctionEnd

; ------------------ ;
;  Desktop Shortcut  ;
; ------------------ ;
Function finishpageaction
    CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\stremio.exe" "" "$INSTDIR\stremio.exe" "" "" "" "${APP_NAME} ${PRODUCT_VERSION}"
FunctionEnd
