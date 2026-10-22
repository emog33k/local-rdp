; LocalRDP Agent installer (the PC with Sunshine).
; Built by scripts\make-installers.bat:
;   makensis /DSTAMP=yyyymmdd /DAGENT_DIR=<agent-deploy> /DSCRIPTS=<scripts> /DOUT=<file> localrdp-agent.nsi
;
; The work is done by scripts\install-agent.ps1 (the same, tested script as for a
; manual install): it asks for administrator rights itself, copies the agent to
; "C:\Program Files\LocalRDP Agent", gives it its own certificate signed with
; Sunshine's key (key encrypted for the current Windows user), opens TCP 48100 for
; the local subnet only and starts the agent at sign-in. So the installer runs as
; the signed-in user: the agent's key must belong to that user.

Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel user
ManifestDPIAware true

!include MUI2.nsh
!include LogicLib.nsh

!define PRODUCT "LocalRDP Agent"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\LocalRDP Agent"

Name "${PRODUCT}"
OutFile "${OUT}"
; Fixed by install-agent.ps1; only used for the uninstall entry
InstallDir "$PROGRAMFILES64\LocalRDP Agent"
ShowInstDetails show
ShowUninstDetails show
BrandingText "LocalRDP"

VIProductVersion "1.0.0.0"
VIAddVersionKey /LANG=1049 "ProductName" "${PRODUCT}"
VIAddVersionKey /LANG=1049 "FileDescription" "Установка ${PRODUCT}"
VIAddVersionKey /LANG=1049 "FileVersion" "${STAMP}"
VIAddVersionKey /LANG=1049 "ProductVersion" "${STAMP}"
VIAddVersionKey /LANG=1049 "LegalCopyright" "GPLv3"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Установка ${PRODUCT}"
!define MUI_WELCOMEPAGE_TEXT "Агент работает на ПК рядом с Sunshine: общий буфер обмена и файлы, блокировка ПК, список мониторов, курсор как в AnyDesk.$\r$\n$\r$\nНужен установленный Sunshine. Windows попросит права администратора (один раз).$\r$\n$\r$\nУстанавливайте под той учётной записью, в которой работаете: ключ агента шифруется для неё."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "Готово"
!define MUI_FINISHPAGE_TEXT "Агент запущен и будет запускаться при входе в Windows."
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Russian"

; 64-bit PowerShell: this installer is a 32-bit program, and a 32-bit PowerShell
; would see "C:\Program Files (x86)" as Program Files.
!define POWERSHELL "$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe"

Section "Install"
    ; The wizard's pages create $PLUGINSDIR; a silent install (/S) shows none
    InitPluginsDir
    SetOutPath "$PLUGINSDIR\agent"
    File /r "${AGENT_DIR}\*"
    ; The uninstaller goes with the agent into its folder
    WriteUninstaller "$PLUGINSDIR\agent\Uninstall.exe"
    SetOutPath "$PLUGINSDIR"
    File "${SCRIPTS}\install-agent.ps1"

    DetailPrint "Установка агента (Windows спросит права администратора)..."
    nsExec::ExecToLog '"${POWERSHELL}" -NoProfile -ExecutionPolicy Bypass -File "$PLUGINSDIR\install-agent.ps1" -Source "$PLUGINSDIR\agent"'
    Pop $0
    ${If} $0 != 0
        DetailPrint "Ошибка установки (код $0), подробности выше."
        MessageBox MB_ICONSTOP|MB_OK "Агент не установлен (код $0). Подробности в окне установки.$\r$\n$\r$\nЧастые причины: Sunshine не установлен, отказ в запросе прав администратора." /SD IDOK
        SetOutPath "$TEMP"
        Abort
    ${EndIf}

    WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${PRODUCT}"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${STAMP}"
    WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "LocalRDP"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\LocalRdpAgent.exe"
    WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
    WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" 30000
    ; Leave the temporary folder so it can be deleted
    SetOutPath "$TEMP"
SectionEnd

Section "Uninstall"
    InitPluginsDir
    SetOutPath "$PLUGINSDIR"
    File "${SCRIPTS}\uninstall-agent.ps1"
    DetailPrint "Удаление агента (Windows спросит права администратора)..."
    nsExec::ExecToLog '"${POWERSHELL}" -NoProfile -ExecutionPolicy Bypass -File "$PLUGINSDIR\uninstall-agent.ps1"'
    Pop $0
    SetOutPath "$TEMP"
    ${If} $0 != 0
        MessageBox MB_ICONSTOP|MB_OK "Агент не удалён (код $0). Подробности в окне удаления." /SD IDOK
        Abort
    ${EndIf}
    DeleteRegKey HKCU "${UNINST_KEY}"
SectionEnd
