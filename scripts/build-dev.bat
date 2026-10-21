@echo off
rem Incremental release build of moonlight-qt for development.
rem Needs one full build first (moonlight-qt\scripts\build-arch.bat release) to create
rem build\build-x64-release and the deploy folder with all DLLs. This script recompiles
rem only what changed and refreshes Moonlight.exe in build\deploy-x64-release.
setlocal
call "%~dp0env.bat" || exit /b 1

for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set "VSDIR=%%i"
call "%VSDIR%\VC\Auxiliary\Build\vcvarsall.bat" amd64 >nul || exit /b 1

set "BUILD=L:\moonlight-qt\build\build-x64-release"
set "DEPLOY=L:\moonlight-qt\build\deploy-x64-release"
if not exist "%BUILD%\Makefile" (
    echo Run a full build first: cd /d L:\moonlight-qt ^&^& scripts\build-arch.bat release
    exit /b 1
)

set JOM=nmake
where /q jom.exe && set JOM=jom

pushd "%BUILD%"
qmake L:\moonlight-qt\moonlight-qt.pro || (popd & exit /b 1)
%JOM% release || (popd & exit /b 1)
popd

copy /y "%BUILD%\app\release\Moonlight.exe" "%DEPLOY%\Moonlight.exe" >nul || exit /b 1
echo Dev build OK: %DEPLOY%\Moonlight.exe
exit /b 0
