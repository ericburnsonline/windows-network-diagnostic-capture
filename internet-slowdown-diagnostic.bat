@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Windows Internet Slowdown Diagnostic Capture - v4
REM
REM Runs read-only network diagnostics and saves the results to a
REM uniquely timestamped text file.
REM
REM Version 4 adds:
REM - Dedicated DNS resolution timing
REM - Independent TCP/443 connection timing
REM - Default gateway detection and latency test
REM - Network adapter packet/error/discard statistics
REM - Conditional Wi-Fi link diagnostics
REM - Multiple configurable HTTPS test hosts
REM
REM Administrator privileges are not required.
REM ============================================================

REM ---- Test targets -------------------------------------------------
REM Change these values if you prefer different public test targets.
set "PING_TARGET=1.1.1.1"
set "TEST_HOST_1=www.google.com"
set "TEST_HOST_2=www.microsoft.com"
set "TEST_PORT=443"

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
>>"%LOGFILE%" echo Test host 1: %TEST_HOST_1%
>>"%LOGFILE%" echo Test host 2: %TEST_HOST_2%
>>"%LOGFILE%" echo TCP test port: %TEST_PORT%
>>"%LOGFILE%" echo.

echo Running enhanced network diagnostics...
echo.

REM ---- 1. Raw IPv4 connectivity ------------------------------------
echo [1 of 19] Testing raw IPv4 connectivity...
call :section "PING IPv4 - %PING_TARGET%"
ping %PING_TARGET% -n 20 >>"%LOGFILE%" 2>&1

REM ---- 2. Hostname connectivity ------------------------------------
echo [2 of 19] Testing hostname connectivity...
call :section "PING %TEST_HOST_1%"
ping %TEST_HOST_1% -n 20 >>"%LOGFILE%" 2>&1

REM ---- 3. Traditional DNS lookup ------------------------------------
echo [3 of 19] Testing configured DNS resolution...
call :section "NSLOOKUP %TEST_HOST_1%"
nslookup %TEST_HOST_1% >>"%LOGFILE%" 2>&1

REM ---- 4. Dedicated DNS timing --------------------------------------
echo [4 of 19] Measuring DNS resolution timing...
call :dnstiming "%TEST_HOST_1%"
call :dnstiming "%TEST_HOST_2%"

REM ---- 5. Independent TCP connection timing -------------------------
echo [5 of 19] Measuring TCP connection timing...
call :tcptiming "%TEST_HOST_1%" "%TEST_PORT%"
call :tcptiming "%TEST_HOST_2%" "%TEST_PORT%"

REM ---- 6. Default gateway test --------------------------------------
echo [6 of 19] Detecting and testing the active IPv4 gateway...
call :section "DEFAULT IPv4 GATEWAY"
set "DEFAULT_GATEWAY="
for /f "usebackq delims=" %%G in (`powershell -NoProfile -Command "$r=Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue ^| Where-Object {$_.NextHop -ne '0.0.0.0'} ^| Sort-Object RouteMetric ^| Select-Object -First 1 -ExpandProperty NextHop; if($r){$r}"`) do set "DEFAULT_GATEWAY=%%G"

if defined DEFAULT_GATEWAY (
    >>"%LOGFILE%" echo Gateway: !DEFAULT_GATEWAY!
    ping !DEFAULT_GATEWAY! -n 10 >>"%LOGFILE%" 2>&1
) else (
    >>"%LOGFILE%" echo No active IPv4 default gateway was detected.
)

REM ---- 7. IP configuration ------------------------------------------
echo [7 of 19] Capturing IP configuration...
call :section "IPCONFIG /ALL"
ipconfig /all >>"%LOGFILE%" 2>&1

REM ---- 8. Routing table ---------------------------------------------
echo [8 of 19] Capturing routing table...
call :section "ROUTE PRINT"
route print >>"%LOGFILE%" 2>&1

REM ---- 9. Network adapters ------------------------------------------
echo [9 of 19] Capturing network adapters...
call :section "GET-NETADAPTER"
powershell -NoProfile -Command ^
    "Get-NetAdapter | Sort-Object Status,Name | Format-Table -AutoSize Name,InterfaceDescription,Status,LinkSpeed,MacAddress,ifIndex" ^
    >>"%LOGFILE%" 2>&1

REM ---- 10. Adapter packet/error statistics --------------------------
echo [10 of 19] Capturing network adapter statistics...
call :section "GET-NETADAPTERSTATISTICS"
powershell -NoProfile -Command ^
    "Get-NetAdapterStatistics | Sort-Object Name | Format-Table -AutoSize Name,ReceivedBytes,SentBytes,ReceivedUnicastPackets,SentUnicastPackets,ReceivedDiscardedPackets,OutboundDiscardedPackets,ReceivedPacketErrors,OutboundPacketErrors" ^
    >>"%LOGFILE%" 2>&1

REM ---- 11. IP and DNS configuration ---------------------------------
echo [11 of 19] Capturing IP and DNS configuration...
call :section "GET-NETIPCONFIGURATION"
powershell -NoProfile -Command ^
    "Get-NetIPConfiguration | Format-List InterfaceAlias,InterfaceDescription,IPv4Address,IPv6Address,IPv4DefaultGateway,IPv6DefaultGateway,DNSServer" ^
    >>"%LOGFILE%" 2>&1

call :section "DNS CLIENT SERVER ADDRESSES"
powershell -NoProfile -Command ^
    "Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses.Count -gt 0} | Format-Table -AutoSize InterfaceAlias,AddressFamily,ServerAddresses" ^
    >>"%LOGFILE%" 2>&1

REM ---- 12. Enabled adapter bindings ---------------------------------
echo [12 of 19] Capturing enabled adapter bindings...
call :section "ENABLED NETWORK ADAPTER BINDINGS"
powershell -NoProfile -Command ^
    "Get-NetAdapterBinding -Name '*' | Where-Object Enabled | Sort-Object Name,DisplayName | Format-Table -AutoSize Name,DisplayName,ComponentID" ^
    >>"%LOGFILE%" 2>&1

REM ---- 13. Conditional Wi-Fi diagnostics ----------------------------
REM Capture useful link-health fields while intentionally excluding
REM SSID and BSSID values from the diagnostic log.
echo [13 of 19] Checking Wi-Fi link information...
call :section "WI-FI LINK DIAGNOSTICS"
netsh wlan show interfaces >"%TEMP%\wndc_wifi_%STAMP%.txt" 2>&1
findstr /I /C:"State" /C:"Radio type" /C:"Channel" /C:"Receive rate" /C:"Transmit rate" /C:"Signal" "%TEMP%\wndc_wifi_%STAMP%.txt" >>"%LOGFILE%" 2>&1
if errorlevel 1 (
    >>"%LOGFILE%" echo No Wi-Fi interface information was available.
)
del "%TEMP%\wndc_wifi_%STAMP%.txt" >nul 2>&1

REM ---- 14. WinHTTP proxy --------------------------------------------
echo [14 of 19] Checking WinHTTP proxy configuration...
call :section "WINHTTP PROXY"
netsh winhttp show proxy >>"%LOGFILE%" 2>&1

REM ---- 15. Current-user proxy settings ------------------------------
echo [15 of 19] Checking current-user proxy settings...
call :section "USER / BROWSER PROXY SETTINGS"
powershell -NoProfile -Command ^
    "$p = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings';" ^
    "[pscustomobject]@{" ^
    "ProxyEnable=$p.ProxyEnable;" ^
    "ProxyServer=$p.ProxyServer;" ^
    "AutoConfigURL=$p.AutoConfigURL;" ^
    "AutoDetect=$p.AutoDetect" ^
    "} | Format-List" >>"%LOGFILE%" 2>&1

REM ---- 16. Default HTTPS timing -------------------------------------
echo [16 of 19] Testing default HTTPS timing...
call :curltest "DEFAULT HTTPS - %TEST_HOST_1%" "" "%TEST_HOST_1%"
call :curltest "DEFAULT HTTPS - %TEST_HOST_2%" "" "%TEST_HOST_2%"

REM ---- 17. IPv4 HTTPS timing ----------------------------------------
echo [17 of 19] Testing IPv4 HTTPS timing...
call :curltest "IPv4 HTTPS - %TEST_HOST_1%" "-4" "%TEST_HOST_1%"
call :curltest "IPv4 HTTPS - %TEST_HOST_2%" "-4" "%TEST_HOST_2%"

REM ---- 18. IPv6 HTTPS timing ----------------------------------------
echo [18 of 19] Testing IPv6 HTTPS timing...
call :curltest "IPv6 HTTPS - %TEST_HOST_1%" "-6" "%TEST_HOST_1%"
call :curltest "IPv6 HTTPS - %TEST_HOST_2%" "-6" "%TEST_HOST_2%"

REM ---- 19. Active connections and process correlation ---------------
echo [19 of 19] Capturing active connections and processes...
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
REM Helper: dedicated DNS timing
REM Measures Resolve-DnsName independently of curl.
REM ===================================================================
:dnstiming
call :section "DNS TIMING - %~1"
powershell -NoProfile -Command ^
    "$hostName='%~1';" ^
    "$sw=[System.Diagnostics.Stopwatch]::StartNew();" ^
    "try {" ^
    "$r=Resolve-DnsName -Name $hostName -DnsOnly -ErrorAction Stop;" ^
    "$sw.Stop();" ^
    "$addresses=$r | Where-Object {$_.IPAddress} | Select-Object -ExpandProperty IPAddress -Unique;" ^
    "Write-Output ('Host: ' + $hostName);" ^
    "Write-Output ('Resolution: SUCCESS');" ^
    "Write-Output ('TimeMs: ' + $sw.ElapsedMilliseconds);" ^
    "if($addresses){Write-Output 'Addresses:'; $addresses | ForEach-Object {Write-Output ('  ' + $_)}} else {Write-Output 'Addresses: none returned'}" ^
    "} catch {" ^
    "$sw.Stop();" ^
    "Write-Output ('Host: ' + $hostName);" ^
    "Write-Output 'Resolution: FAILED';" ^
    "Write-Output ('TimeMs: ' + $sw.ElapsedMilliseconds);" ^
    "Write-Output ('Error: ' + $_.Exception.Message)" ^
    "}" >>"%LOGFILE%" 2>&1
exit /b

REM ===================================================================
REM Helper: independent TCP connection timing
REM Resolves the host first, then times at most one IPv4 and one IPv6
REM address without performing TLS or HTTP.
REM ===================================================================
:tcptiming
call :section "TCP TIMING - %~1:%~2"
powershell -NoProfile -Command ^
    "$hostName='%~1'; $port=%~2; $timeoutMs=5000;" ^
    "try {$all=[System.Net.Dns]::GetHostAddresses($hostName)} catch {Write-Output ('DNS resolution failed: ' + $_.Exception.Message); exit};" ^
    "$v4=$all | Where-Object {$_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork} | Select-Object -First 1;" ^
    "$v6=$all | Where-Object {$_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6} | Select-Object -First 1;" ^
    "$addresses=@($v4,$v6) | Where-Object {$_};" ^
    "if(-not $addresses){Write-Output 'No IPv4 or IPv6 addresses were returned.'; exit};" ^
    "foreach($address in $addresses) {" ^
    "$client=New-Object System.Net.Sockets.TcpClient($address.AddressFamily);" ^
    "$sw=[System.Diagnostics.Stopwatch]::StartNew();" ^
    "try {" ^
    "$ar=$client.BeginConnect($address,$port,$null,$null);" ^
    "if(-not $ar.AsyncWaitHandle.WaitOne($timeoutMs,$false)){throw 'Connection timed out'};" ^
    "$client.EndConnect($ar);" ^
    "$sw.Stop();" ^
    "Write-Output ('Address: ' + $address.IPAddressToString);" ^
    "Write-Output ('Family: ' + $address.AddressFamily);" ^
    "Write-Output 'TCP: SUCCESS';" ^
    "Write-Output ('ConnectTimeMs: ' + $sw.ElapsedMilliseconds)" ^
    "} catch {" ^
    "$sw.Stop();" ^
    "Write-Output ('Address: ' + $address.IPAddressToString);" ^
    "Write-Output ('Family: ' + $address.AddressFamily);" ^
    "Write-Output 'TCP: FAILED';" ^
    "Write-Output ('ConnectTimeMs: ' + $sw.ElapsedMilliseconds);" ^
    "Write-Output ('Error: ' + $_.Exception.Message)" ^
    "} finally {$client.Close()};" ^
    "Write-Output ''" ^
    "}" >>"%LOGFILE%" 2>&1
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
    "https://%~3/" >>"%LOGFILE%" 2>&1
exit /b
