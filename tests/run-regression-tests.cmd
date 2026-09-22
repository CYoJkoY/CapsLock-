@echo off
setlocal EnableExtensions

set "AHK=%~dp0..\autohotkey\AutoHotkey64.exe"

if not exist "%AHK%" (
    echo AutoHotkey executable not found: "%AHK%"
    exit /b 2
)

call :run "tests\AhkExitSmoke.ahk"
if errorlevel 1 exit /b %errorlevel%

call :run "tests\RegressionTests.ahk"
if errorlevel 1 exit /b %errorlevel%

call :run "tests\CloudSyncRegressionTests.ahk"
if errorlevel 1 exit /b %errorlevel%

call :run "tests\QuickPhraseRegressionTests.ahk"
if errorlevel 1 exit /b %errorlevel%

exit /b 0

:run
set "SCRIPT=%~dp0..\%~1"

echo Running %~1

"%AHK%" "%SCRIPT%"
set "WAIT_CODE=%ERRORLEVEL%"

if not "%WAIT_CODE%"=="0" (
    echo AutoHotkey test failed with exit code %WAIT_CODE%: %~1
    exit /b %WAIT_CODE%
)

exit /b 0
