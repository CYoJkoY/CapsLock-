@echo off
setlocal

set "AHK=%~dp0..\autohotkey\AutoHotkey64.exe"

if not exist "%AHK%" (
    echo AutoHotkey executable not found: "%AHK%"
    exit /b 2
)

call :run "tests\RegressionTests.ahk"
if errorlevel 1 exit /b %errorlevel%

call :run "tests\CloudSyncRegressionTests.ahk"
if errorlevel 1 exit /b %errorlevel%

call :run "tests\QuickPhraseRegressionTests.ahk"
if errorlevel 1 exit /b %errorlevel%

call :run "tests\QuickPhraseTargetRegressionTests.ahk"
if errorlevel 1 exit /b %errorlevel%

exit /b 0

:run
echo Running %~1
start "" /wait "%AHK%" "%~dp0..\%~1"
set "code=%errorlevel%"
echo Exit code: %code%
exit /b %code%
