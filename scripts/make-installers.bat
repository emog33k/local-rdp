@echo off
rem Builds both installers into <project>\dist:
rem   MoonlightLocalRDP-Setup-<yyyymmdd>.exe  - the laptop (Moonlight with the LocalRDP panel)
rem   LocalRDPAgent-Setup-<yyyymmdd>.exe      - the PC with Sunshine (the agent)
rem By default runs the tests and a full release build first (make-bundle.bat, which
rem also makes the portable zip) and builds the agent.
rem   make-installers.bat nobuild   - package the builds that are already there
setlocal
call "%~dp0env.bat" || exit /b 1

set "MAKENSIS=%ProgramFiles(x86)%\NSIS\makensis.exe"
rem (no parentheses around these: the path has "(x86)" in it)
if not exist "%MAKENSIS%" echo NSIS not found: "%MAKENSIS%"
if not exist "%MAKENSIS%" exit /b 1

if /I "%~1"=="nobuild" goto package
call "%~dp0make-bundle.bat" || exit /b 1
call "%~dp0build-agent.bat" || exit /b 1

:package

for /f %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd"') do set STAMP=%%d
set /p VERSION=<L:\moonlight-qt\app\version.txt
set "DEPLOY=L:\moonlight-qt\build\deploy-x64-release"
set "AGENT=L:\moonlight-qt\build\agent-deploy"
if not exist "%DEPLOY%\Moonlight.exe" (echo Missing %DEPLOY%\Moonlight.exe & exit /b 1)
if not exist "%AGENT%\LocalRdpAgent.exe" (echo Missing %AGENT%\LocalRdpAgent.exe & exit /b 1)
if not exist L:\dist mkdir L:\dist

"%MAKENSIS%" /V2 /INPUTCHARSET UTF8 /DSTAMP=%STAMP% /DVERSION=%VERSION% "/DDEPLOY=%DEPLOY%" ^
    "/DICON=L:\moonlight-qt\app\moonlight.ico" "/DLICENSE=L:\moonlight-qt\LICENSE" ^
    "/DOUT=L:\dist\MoonlightLocalRDP-Setup-%STAMP%.exe" "%~dp0installer\moonlight-localrdp.nsi" || exit /b 1

"%MAKENSIS%" /V2 /INPUTCHARSET UTF8 /DSTAMP=%STAMP% "/DAGENT_DIR=%AGENT%" "/DSCRIPTS=L:\scripts" ^
    "/DICON=L:\moonlight-qt\app\moonlight.ico" ^
    "/DOUT=L:\dist\LocalRDPAgent-Setup-%STAMP%.exe" "%~dp0installer\localrdp-agent.nsi" || exit /b 1

echo Installers:
echo   %LOCALRDP_ROOT%\dist\MoonlightLocalRDP-Setup-%STAMP%.exe
echo   %LOCALRDP_ROOT%\dist\LocalRDPAgent-Setup-%STAMP%.exe
exit /b 0
