@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Windows Internet Slowdown Diagnostic Capture - v3
REM
REM Runs read-only network diagnostics and saves the results to a
REM uniquely timestamped text file.
REM
REM Version 3 adds:
REM - IP and DNS configuration
REM - Routing table
REM - Network adapter status
REM - Enabled adapter bindings
REM - Default, IPv4, and IPv6 HTTPS timing
REM - Active TCP connections
REM - Process correlation
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
call :section "DIAGNOSTIC HEADER"
>>"%LOGFILE%" echo Started: %DATE% %TIME%
>>"%LOGFILE%" echo Windows version:
>>"%LOGFILE%" ver
>>"%LOGFILE%" echo Ping target: %PING_TARGET%
>>"%LOGFILE%" echo Test host:   %TEST_HOST%
>>"%LOGFILE%" echo.

echo Running enhanced network diagnostics...
echo.

REM ---- 1. Raw IPv4 connectivity ------------------------------------
echo [1 of 14] Testing raw IPv4 connectivity...
call :section "PING IPv4 - %PING_TARGET%"
ping %PING_TARGET% -n 20 >>"%LOGFILE%" 2>&1

REM ---- 2. Hostname connectivity ------------------------------------
echo [2 of 14] Testing hostname connectivity...
call :section "PING %TEST_HOST%"
ping %TEST_HOST% -n 20 >>"%LOGFILE%" 2>&1

REM ---- 3. DNS lookup ------------------------------------------------
echo [3 of 14] Testing configured DNS resolution...
call :section "NSLOOKUP %TEST_HOST%"
nslookup %TEST_HOST% >>"%LOGFILE%" 2>&1

REM ---- 4. IP configuration ------------------------------------------
echo [4 of 14] Capturing IP configuration...
call :section "IPCONFIG /ALL"
ipconfig /all >>"%LOGFILE%" 2>&1

REM ---- 5. Routing table ---------------------------------------------
echo [5 of 14] Capturing routing table...
call :section "ROUTE PRINT"
route print >>"%LOGFILE%" 2>&1

REM ---- 6. Network adapters ------------------------------------------
echo [6 of 14] Capturing network adapters...
call :section "GET-NETADAPTER"
powershell -NoProfile -Command ^
    "Get-NetAdapter | Sort-Object Status,Name | Format-Table -AutoSize Name,InterfaceDescription,Status,LinkSpeed,MacAddress,ifIndex" ^
    >>"%LOGFILE%" 2>&1

REM ---- 7. IP and DNS configuration ----------------------------------
echo [7 of 14] Capturing IP and DNS configuration...
call :section "GET-NETIPCONFIGURATION"
powershell -NoProfile -Command ^
    "Get-NetIPConfiguration | Format-List InterfaceAlias,InterfaceDescription,IPv4Address,IPv6Address,IPv4DefaultGateway,IPv6DefaultGateway,DNSServer" ^
    >>"%LOGFILE%" 2>&1

call :section "DNS CLIENT SERVER ADDRESSES"
powershell -NoProfile -Command ^
    "Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses.Count -gt 0} | Format-Table -AutoSize InterfaceAlias,AddressFamily,ServerAddresses" ^
    >>"%LOGFILE%" 2>&1

REM ---- 8. Enabled adapter bindings ----------------------------------
echo [8 of 14] Capturing enabled adapter bindings...
call :section "ENABLED NETWORK ADAPTER BINDINGS"
powershell -NoProfile -Command ^
    "Get-NetAdapterBinding -Name '*' | Where-Object Enabled | Sort-Object Name,DisplayName | Format-Table -AutoSize Name,DisplayName,ComponentID" ^
    >>"%LOGFILE%" 2>&1

REM ---- 9. WinHTTP proxy ---------------------------------------------
echo [9 of 14] Checking WinHTTP proxy configuration...
call :section "WINHTTP PROXY"
netsh winhttp show proxy >>"%LOGFILE%" 2>&1

REM ---- 10. Current-user proxy settings ------------------------------
echo [10 of 14] Checking current-user proxy settings...
call :section "USER / BROWSER PROXY SETTINGS"
powershell -NoProfile -Command ^
    "$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings';" ^
    "[pscustomobject]@{" ^
    "ProxyEnable=$p.ProxyEnable;" ^
    "ProxyServer=$p.ProxyServer;" ^
    "AutoConfigURL=$p.AutoConfigURL;" ^
    "AutoDetect=$p.AutoDetect" ^
    "} | Format-List" >>"%LOGFILE%" 2>&1

REM ---- 11. Default HTTPS timing -------------------------------------
echo [11 of 14] Testing default HTTPS timing...
call :curltest "DEFAULT HTTPS" ""

REM ---- 12. IPv4 HTTPS timing ----------------------------------------
echo [12 of 14] Testing IPv4 HTTPS timing...
call :curltest "IPv4 HTTPS" "-4"

REM ---- 13. IPv6 HTTPS timing ----------------------------------------
echo [13 of 14] Testing IPv6 HTTPS timing...
call :curltest "IPv6 HTTPS" "-6"

REM ---- 14. Active connections and process correlation ---------------
echo [14 of 14] Capturing active connections and processes...
call :section "NETSTAT -ANO"
netstat -ano >>"%LOGFILE%" 2>&1

call :section "TOP TCP CONNECTION COUNTS BY PID"
powershell -NoProfile -Command ^
    "$c = Get-NetTCPConnection -ErrorAction SilentlyContinue; if ($c) { $c | Group-Object OwningProcess | Sort-Object Count -Descending | Select-Object -First 25 @{n='PID';e={$_.Name}},Count | Format-Table -AutoSize }" ^
    >>"%LOGFILE%" 2>&1

call :section "PROCESS LIST FOR NETWORK CORRELATION"
powershell -NoProfile -Command ^
    "Get-Process | Sort-Object Id | Select-Object Id,ProcessName | Format-Table -AutoSize" ^
    >>"%LOGFILE%" 2>&1

REM ---- Finish -------------------------------------------------------
call :section "DIAGNOSTIC COMPLETE"
>>"%LOGFILE%" echo Completed: %DATE% %TIME%

echo.
echo Diagnostics complete.
echo Log saved to:
echo %LOGFILE%
echo.
echo Review the log before sharing it with others.
echo.
pause
goto :eof

REM ===================================================================
REM Helper: formatted section header
REM ===================================================================
:section
>>"%LOGFILE%" echo.
>>"%LOGFILE%" echo ============================================================
>>"%LOGFILE%" echo %~1
>>"%LOGFILE%" echo ============================================================
exit /b

REM ===================================================================
REM Helper: HTTPS timing test
REM Records timing only, not response headers or page content.
REM ===================================================================
:curltest
call :section "%~1"

where curl >nul 2>&1
if errorlevel 1 (
    >>"%LOGFILE%" echo curl is not installed or is not available in PATH.
    exit /b
)

curl %~2 -o NUL -sS --connect-timeout 15 --max-time 30 ^
    -w "RemoteIP:%%{remote_ip}\nHTTP:%%{http_code}\nDNS:%%{time_namelookup}s\nConnect:%%{time_connect}s\nTLS:%%{time_appconnect}s\nFirstByte:%%{time_starttransfer}s\nTotal:%%{time_total}s\n" ^
    "https://%TEST_HOST%/" >>"%LOGFILE%" 2>&1
exit /b
