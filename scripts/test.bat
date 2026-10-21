@echo off
rem Builds and runs the LocalRDP unit tests (moonlight-qt\tests\localrdp).
rem Output goes to L:\moonlight-qt\build\tests-localrdp (ignored by git).
setlocal
call "%~dp0env.bat" || exit /b 1
set VSLANG=1033
for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath`) do set "VSDIR=%%i"
call "%VSDIR%\VC\Auxiliary\Build\vcvarsall.bat" amd64 >nul || exit /b 1

set "OUT=L:\moonlight-qt\build\tests-localrdp"
if not exist "%OUT%" mkdir "%OUT%"
pushd "%OUT%"
qmake L:\moonlight-qt\tests\localrdp\localrdp_tests.pro || (popd & exit /b 1)
set JOM=nmake /nologo
where /q jom.exe && set JOM=jom
%JOM% release || (popd & exit /b 1)
popd

rem Qt DLLs are needed at run time.
set "PATH=L:\tools\Qt\6.11.3\msvc2022_64\bin;%PATH%"
"%OUT%\release\localrdp_tests.exe"
exit /b %ERRORLEVEL%
