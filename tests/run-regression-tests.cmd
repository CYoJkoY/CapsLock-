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

call :run "tests\QuickPhraseTargetRegressionTests.ahk"
if errorlevel 1 exit /b %errorlevel%

exit /b 0

:run
set "SCRIPT=%~dp0..\%~1"
set "RESULT=%TEMP%\capslock-ahk-%RANDOM%-%RANDOM%.result"

del /q "%RESULT%" 2>nul

echo Running %~1

"%AHK%" /Launch "%SCRIPT%" "%RESULT%"
set "PID=%errorlevel%"

if not defined PID (
    echo AutoHotkey launcher did not return a script PID.
    exit /b 2
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p = Get-Process -Id %PID% -ErrorAction SilentlyContinue; if ($null -eq $p) { exit 0 }; if (-not $p.WaitForExit(60000)) { try { $p.Kill() } catch {}; exit 124 }; exit $p.ExitCode"

set "WAIT_CODE=%errorlevel%"

if "%WAIT_CODE%"=="124" (
    echo AutoHotkey test timed out after 60 seconds: %~1
    exit /b 124
)

if not exist "%RESULT%" (
    echo AutoHotkey test exited without reporting a result: %~1
    echo Launcher PID: %PID%
    echo Process wait code: %WAIT_CODE%
    exit /b 1
)

set "STATUS="
set /p STATUS=<"%RESULT%"

if /i not "%STATUS%"=="PASS" (
    echo AutoHotkey test reported failure: %~1
    type "%RESULT%"
    exit /b 1
)

if not "%WAIT_CODE%"=="0" (
    echo AutoHotkey test returned unexpected exit code %WAIT_CODE% after reporting PASS: %~1
    type "%RESULT%"
    exit /b 1
)

del /q "%RESULT%" 2>nul
exit /b 0
