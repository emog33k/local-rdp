; Moonlight LocalRDP installer (the laptop).
; Built by scripts\make-installers.bat:
;   makensis /DSTAMP=yyyymmdd /DVERSION=x.y.z /DDEPLOY=<deploy folder> /DICON=<ico> /DOUT=<file> moonlight-localrdp.nsi
;
; Installs for the current Windows user into %LOCALAPPDATA%\Programs\Moonlight LocalRDP
; (no administrator rights). It keeps its settings and pairing keys next to the
; program (portable.dat), so it never touches a regular Moonlight on the same laptop,
; and only this user can read them (the folder is in their profile). The folder is
; fixed on purpose: a folder picked elsewhere (e.g. C:\Moonlight) could be readable
; and writable by other users.

Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel user
ManifestDPIAware true

!include MUI2.nsh
!include LogicLib.nsh

!define PRODUCT "Moonlight LocalRDP"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\MoonlightLocalRDP"
; Where Moonlight keeps its settings in portable mode (QSettings: organization\application.ini)
!define SETTINGS_DIR "Moonlight Game Streaming Project"

Name "${PRODUCT}"
OutFile "${OUT}"
InstallDir "$LOCALAPPDATA\Programs\Moonlight LocalRDP"
ShowInstDetails show
ShowUninstDetails show
BrandingText "LocalRDP"

VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1049 "ProductName" "${PRODUCT}"
VIAddVersionKey /LANG=1049 "FileDescription" "Установка ${PRODUCT}"
VIAddVersionKey /LANG=1049 "FileVersion" "${VERSION}-${STAMP}"
VIAddVersionKey /LANG=1049 "ProductVersion" "${VERSION}-${STAMP}"
VIAddVersionKey /LANG=1049 "LegalCopyright" "GPLv3, Moonlight Game Streaming Project"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_WELCOMEPAGE_TITLE "Установка ${PRODUCT}"
!define MUI_WELCOMEPAGE_TEXT "Moonlight с панелью как в AnyDesk: общий буфер обмена и файлы, мониторы, звук, блокировка ПК.$\r$\n$\r$\nУстанавливается только для вас, права администратора не нужны. Обычный Moonlight (если он есть) не затрагивается.$\r$\n$\r$\nПри обновлении настройки и спаривание с ПК сохраняются."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Запустить ${PRODUCT}"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchMoonlight
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Russian"

!define POWERSHELL "$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe"

; Closes Moonlight started from this folder (never another Moonlight). A running
; program can't be replaced, so asks first; Cancel stops the (un)install.
!macro CloseOurMoonlight un
Function ${un}CloseOurMoonlight
    ${IfNot} ${FileExists} "$INSTDIR\Moonlight.exe"
        Return
    ${EndIf}
    ClearErrors
    FileOpen $0 "$INSTDIR\Moonlight.exe" a
    ${IfNot} ${Errors}
        FileClose $0
        Return ; not running
    ${EndIf}
    MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION "${PRODUCT} сейчас запущен. Закрыть его и продолжить?" /SD IDOK IDOK close
    Abort
close:
    DetailPrint "Закрываю запущенный ${PRODUCT}..."
    ; The path goes in through an environment variable: no quoting problems with any user name
    System::Call 'kernel32::SetEnvironmentVariable(t "LOCALRDP_EXE", t "$INSTDIR\Moonlight.exe")'
    nsExec::Exec '"${POWERSHELL}" -NoProfile -ExecutionPolicy Bypass -Command "Get-Process Moonlight -ErrorAction SilentlyContinue | Where-Object { $$_.Path -ieq $$env:LOCALRDP_EXE } | ForEach-Object { Stop-Process -Id $$_.Id -Force; Wait-Process -Id $$_.Id -Timeout 10 -ErrorAction SilentlyContinue }"'
    Pop $0
    ClearErrors
    FileOpen $0 "$INSTDIR\Moonlight.exe" a
    ${If} ${Errors}
        MessageBox MB_OK|MB_ICONSTOP "Не удалось закрыть ${PRODUCT}. Закройте его и запустите установку снова." /SD IDOK
        Abort
    ${EndIf}
    FileClose $0
FunctionEnd
!macroend
!insertmacro CloseOurMoonlight ""
!insertmacro CloseOurMoonlight "un."

; The program's own files (everything except settings, pairing keys, logs and cache)
!macro RemoveProgramFiles
    Delete "$INSTDIR\Moonlight.exe"
    Delete "$INSTDIR\*.dll"
    Delete "$INSTDIR\gamecontrollerdb.txt"
    Delete "$INSTDIR\portable.dat"
    Delete "$INSTDIR\LICENSE.txt"
    RMDir /r "$INSTDIR\qml"
    RMDir /r "$INSTDIR\platforms"
    RMDir /r "$INSTDIR\imageformats"
    RMDir /r "$INSTDIR\iconengines"
    RMDir /r "$INSTDIR\networkinformation"
    RMDir /r "$INSTDIR\tls"
    RMDir /r "$INSTDIR\translations"
    RMDir /r "$INSTDIR\styles"
    RMDir /r "$INSTDIR\generic"
    ; Compiled QML of the old version
    RMDir /r "$INSTDIR\qmlcache"
!macroend

Function LaunchMoonlight
    ; Portable mode looks for portable.dat in the current folder
    SetOutPath "$INSTDIR"
    Exec '"$INSTDIR\Moonlight.exe"'
FunctionEnd

Section "Install"
    Call CloseOurMoonlight
    ; An update: old program files go (a file the new version no longer has must
    ; not stay behind); settings and pairing stay
    !insertmacro RemoveProgramFiles

    SetOutPath "$INSTDIR"
    File /r /x portable.dat /x portable.dat.inactive "${DEPLOY}\*"
    File "/oname=LICENSE.txt" "${LICENSE}"
    ; Settings and pairing keys next to the program, in this user's profile
    FileOpen $0 "$INSTDIR\portable.dat" w
    FileClose $0

    WriteUninstaller "$INSTDIR\Uninstall.exe"

    ; Shortcuts start in the program folder (portable mode needs it)
    CreateShortcut "$SMPROGRAMS\${PRODUCT}.lnk" "$INSTDIR\Moonlight.exe" "" "$INSTDIR\Moonlight.exe" 0
    CreateShortcut "$DESKTOP\${PRODUCT}.lnk" "$INSTDIR\Moonlight.exe" "" "$INSTDIR\Moonlight.exe" 0

    WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${PRODUCT}"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}-${STAMP}"
    WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "LocalRDP"
    WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\Moonlight.exe"
    WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
    WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
    WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" 150000
SectionEnd

Section "Uninstall"
    Call un.CloseOurMoonlight
    !insertmacro RemoveProgramFiles
    Delete "$INSTDIR\Uninstall.exe"
    Delete "$SMPROGRAMS\${PRODUCT}.lnk"
    Delete "$DESKTOP\${PRODUCT}.lnk"
    DeleteRegKey HKCU "${UNINST_KEY}"

    ; Settings, pairing keys, logs, cache: only if the user says so (kept when silent)
    MessageBox MB_YESNO|MB_ICONQUESTION "Удалить также настройки и спаривание с ПК?$\r$\n$\r$\nЕсли оставить, при повторной установке ничего не придётся настраивать заново." /SD IDNO IDNO keep
    RMDir /r "$INSTDIR\${SETTINGS_DIR}"
    RMDir /r "$INSTDIR\cache"
    RMDir /r "$INSTDIR\boxart"
    Delete "$INSTDIR\Moonlight-*.log"
    Delete "$INSTDIR\*.log"
keep:
    ; Only removed when empty
    RMDir "$INSTDIR"
SectionEnd
