@echo off
rem Build environment for the localrdp forks.
rem Maps the project folder to drive L: (upstream build scripts break on paths with
rem spaces or Cyrillic), then puts Qt and 7-Zip on PATH. Run from any cmd window:
rem     call "<project>\scripts\env.bat"
rem Afterwards work from L:\moonlight-qt (or other forks under L:\).

set "LOCALRDP_ROOT=%~dp0.."
for %%I in ("%LOCALRDP_ROOT%") do set "LOCALRDP_ROOT=%%~fI"

if not exist L:\ (
    subst L: "%LOCALRDP_ROOT%"
)
if not exist L:\scripts\env.bat (
    echo Drive L: is mapped to a different folder. Run "subst L: /D" and try again.
    exit /b 1
)

set "PATH=L:\tools\Qt\6.11.3\msvc2022_64\bin;C:\Program Files\7-Zip;%PATH%"
if exist "E:\tg-local-api\telegram-bot-api\vcpkg\downloads\tools\jom\jom-1_1_4\jom.exe" (
    set "PATH=%PATH%;E:\tg-local-api\telegram-bot-api\vcpkg\downloads\tools\jom\jom-1_1_4"
)
set VSLANG=1033
exit /b 0
