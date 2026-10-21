@echo off
rem Builds and runs the LocalRDP tests:
rem   moonlight-qt\tests\localrdp     - pure logic unit tests
rem   moonlight-qt\tests\localrdp-ui  - Win32 button/menu tests (opens small windows briefly)
rem Build output goes to L:\moonlight-qt\build\tests-* (ignored by git).
rem Pass "unit" or "ui" to run only one suite.
setlocal
call "%~dp0env.bat" || exit /b 1
for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set "VSDIR=%%i"
call "%VSDIR%\VC\Auxiliary\Build\vcvarsall.bat" amd64 >nul || exit /b 1

set JOM=nmake /nologo
where /q jom.exe && set JOM=jom

rem Qt and SDL DLLs are needed at run time.
set "PATH=L:\tools\Qt\6.11.3\msvc2022_64\bin;L:\moonlight-qt\libs\windows\lib\x64;%PATH%"

set RESULT=0
if /I not "%~1"=="ui" call :suite localrdp localrdp_tests || set RESULT=1
if /I not "%~1"=="unit" call :suite localrdp-ui localrdp_ui_tests || set RESULT=1
exit /b %RESULT%

:suite
set "OUT=L:\moonlight-qt\build\tests-%1"
if not exist "%OUT%" mkdir "%OUT%"
pushd "%OUT%"
qmake L:\moonlight-qt\tests\%1\%2.pro || (popd & exit /b 1)
%JOM% release || (popd & exit /b 1)
popd
"%OUT%\release\%2.exe"
exit /b %ERRORLEVEL%
