@echo off
setlocal EnableExtensions

REM ============================================================
REM Windows Internet Slowdown Diagnostic Capture - v2
REM
REM Runs a small set of read-only network tests and saves the
REM results to a uniquely timestamped text file.
REM
REM Version 2 expands proxy detection beyond WinHTTP to include
REM the current user's Windows Internet Settings proxy values.
REM
REM Administrator privileges are not required.
REM ============================================================

REM ---- Test targets -------------------------------------------------
REM Change these values if you prefer different public test targets.
set "PING_TARGET=1.1.1.1"
set "TEST_HOST=www.google.com"

REM ---- Create a locale-independent timestamp ------------------------
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "STAMP=%%I"

if not defined STAMP (
    echo ERROR: Unable to create a timestamp.
    echo PowerShell is required to run this script.
    pause
    exit /b 1
)

REM ---- Create a log directory next to this script -------------------
set "LOGDIR=%~dp0NetworkDiagnostics"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

if not exist "%LOGDIR%" (
    echo ERROR: Unable to create the log directory:
    echo %LOGDIR%
    echo.
    echo Try moving this script to a folder where you have write access.
    pause
    exit /b 1
)

REM Every run receives a new filename, so earlier logs are preserved.
set "LOGFILE=%LOGDIR%\Internet_Diagnostic_%STAMP%.txt"

REM ---- Log header ---------------------------------------------------
> "%LOGFILE%" echo ============================================================
>>"%LOGFILE%" echo WINDOWS INTERNET SLOWDOWN DIAGNOSTIC - v2
>>"%LOGFILE%" echo ============================================================
>>"%LOGFILE%" echo Started: %DATE% %TIME%
>>"%LOGFILE%" echo Windows version:
>>"%LOGFILE%" ver
>>"%LOGFILE%" echo Ping target: %PING_TARGET%
>>"%LOGFILE%" echo Test host:   %TEST_HOST%
>>"%LOGFILE%" echo ============================================================
>>"%LOGFILE%" echo.

echo Running network diagnostics...
echo.

REM ---- 1. Raw IP connectivity --------------------------------------
echo [1 of 6] Testing raw IP connectivity...
>>"%LOGFILE%" echo ==================== PING %PING_TARGET% ====================
ping %PING_TARGET% -n 20 >>"%LOGFILE%" 2>&1
>>"%LOGFILE%" echo.

REM ---- 2. Name resolution plus connectivity ------------------------
echo [2 of 6] Testing hostname connectivity...
>>"%LOGFILE%" echo ==================== PING %TEST_HOST% ====================
ping %TEST_HOST% -n 20 >>"%LOGFILE%" 2>&1
>>"%LOGFILE%" echo.

REM ---- 3. DNS lookup ------------------------------------------------
echo [3 of 6] Testing DNS resolution...
>>"%LOGFILE%" echo ==================== NSLOOKUP %TEST_HOST% ====================
nslookup %TEST_HOST% >>"%LOGFILE%" 2>&1
>>"%LOGFILE%" echo.

REM ---- 4. HTTPS request ---------------------------------------------
REM Record only the HTTP status instead of response headers. This avoids
REM unnecessarily placing cookies or other response metadata in the log.
echo [4 of 6] Testing HTTPS connectivity...
>>"%LOGFILE%" echo ==================== HTTPS %TEST_HOST% ====================
where curl >nul 2>&1
if errorlevel 1 (
    >>"%LOGFILE%" echo curl is not installed or is not available in PATH.
) else (
    curl -sS -o NUL --connect-timeout 15 --max-time 30 ^
        -w "HTTP status: %%{http_code}\n" "https://%TEST_HOST%/" >>"%LOGFILE%" 2>&1
)
>>"%LOGFILE%" echo.

REM ---- 5. WinHTTP proxy ---------------------------------------------
echo [5 of 6] Checking WinHTTP proxy configuration...
>>"%LOGFILE%" echo ==================== WINHTTP PROXY ====================
netsh winhttp show proxy >>"%LOGFILE%" 2>&1
>>"%LOGFILE%" echo.

REM ---- 6. Current-user Internet Settings proxy ----------------------
REM These values are commonly used by Windows applications and browsers.
REM Only proxy configuration values are recorded. No browser history,
REM credentials, cookies, or browsing content are collected.
echo [6 of 6] Checking current-user proxy settings...
>>"%LOGFILE%" echo ==================== USER / BROWSER PROXY SETTINGS ====================
powershell -NoProfile -Command ^
    "$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings';" ^
    "[pscustomobject]@{" ^
    "ProxyEnable=$p.ProxyEnable;" ^
    "ProxyServer=$p.ProxyServer;" ^
    "AutoConfigURL=$p.AutoConfigURL;" ^
    "AutoDetect=$p.AutoDetect" ^
    "} | Format-List" >>"%LOGFILE%" 2>&1
>>"%LOGFILE%" echo.

REM ---- Finish -------------------------------------------------------
>>"%LOGFILE%" echo ============================================================
>>"%LOGFILE%" echo Completed: %DATE% %TIME%
>>"%LOGFILE%" echo ============================================================

echo.
echo Diagnostics complete.
echo Log saved to:
echo %LOGFILE%
echo.
echo Review the log before sharing it with others.
echo.
pause

endlocal
