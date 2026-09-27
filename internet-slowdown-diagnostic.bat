@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM Windows Internet Slowdown Diagnostic Capture - v5
REM
REM Read-only diagnostic capture for intermittent Internet
REM slowdowns, especially when local LAN applications remain fast.
REM
REM Version 5 adds:
REM - LAN-vs-Internet comparison
REM - Per-resolver DNS timing
REM - Service/process correlation for common filtering software
REM - TCP state counts grouped by process name
REM - Two-snapshot adapter statistics with deltas
REM - NIC driver metadata
REM - Lightweight CPU/memory/disk snapshot
REM - Two connection-state snapshots with deltas
REM
REM Administrator privileges are not required for normal use.
REM ============================================================

REM ---- Configurable targets -----------------------------------------
set "PING_TARGET=1.1.1.1"
set "TEST_HOST_1=www.google.com"
set "TEST_HOST_2=www.microsoft.com"
set "TEST_PORT=443"

REM Optional known-good LAN target.
REM Set this to the LAN application's server IP/hostname if known.
REM Leave blank to skip direct LAN-target testing.
set "LAN_TARGET="

REM Delay between first and second diagnostic snapshots.
set "SNAPSHOT_DELAY_SECONDS=10"

REM ---- Timestamp ----------------------------------------------------
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HH-mm-ss"') do set "STAMP=%%I"

if not defined STAMP (
    echo ERROR: Unable to create timestamp.
    pause
    exit /b 1
)

REM ---- Output directory ---------------------------------------------
set "LOGDIR=%~dp0NetworkDiagnostics"
if not exist "%LOGDIR%" mkdir "%LOGDIR%" >nul 2>&1

if not exist "%LOGDIR%" (
    echo ERROR: Unable to create:
    echo %LOGDIR%
    pause
    exit /b 1
)

set "LOGFILE=%LOGDIR%\Internet_Diagnostic_%STAMP%.txt"
set "TMPBASE=%TEMP%\wndc_%STAMP%"

REM ---- Header -------------------------------------------------------
call :section "DIAGNOSTIC HEADER"
>>"%LOGFILE%" echo Started: %DATE% %TIME%
>>"%LOGFILE%" echo Windows version:
>>"%LOGFILE%" ver
>>"%LOGFILE%" echo Ping target: %PING_TARGET%
>>"%LOGFILE%" echo Test host 1: %TEST_HOST_1%
>>"%LOGFILE%" echo Test host 2: %TEST_HOST_2%
>>"%LOGFILE%" echo Test port: %TEST_PORT%
if defined LAN_TARGET (
    >>"%LOGFILE%" echo LAN target: %LAN_TARGET%
) else (
    >>"%LOGFILE%" echo LAN target: not configured
)
>>"%LOGFILE%" echo Snapshot delay: %SNAPSHOT_DELAY_SECONDS% seconds
>>"%LOGFILE%" echo.

echo Running Windows Internet Slowdown Diagnostic v5...
echo.

REM ---- 1. Raw Internet IPv4 -----------------------------------------
echo [1 of 24] Testing raw Internet IPv4 connectivity...
call :section "PING IPv4 - %PING_TARGET%"
ping %PING_TARGET% -n 20 >>"%LOGFILE%" 2>&1

REM ---- 2. Primary hostname ping -------------------------------------
echo [2 of 24] Testing hostname connectivity...
call :section "PING %TEST_HOST_1%"
ping %TEST_HOST_1% -n 20 >>"%LOGFILE%" 2>&1

REM ---- 3. Default gateway -------------------------------------------
REM Uses the first active IPv4 default route reported by route.exe.
echo [3 of 24] Detecting and testing default gateway...
set "DEFAULT_GATEWAY="
for /f "tokens=3" %%G in ('route print -4 ^| findstr /R /C:"^[ ]*0\.0\.0\.0[ ]*0\.0\.0\.0"') do (
    if not defined DEFAULT_GATEWAY set "DEFAULT_GATEWAY=%%G"
)

call :section "DEFAULT IPv4 GATEWAY"
if defined DEFAULT_GATEWAY (
    >>"%LOGFILE%" echo Gateway: !DEFAULT_GATEWAY!
    ping !DEFAULT_GATEWAY! -n 10 >>"%LOGFILE%" 2>&1
) else (
    >>"%LOGFILE%" echo No active IPv4 default gateway detected.
)

REM ---- 4. Optional LAN target ---------------------------------------
echo [4 of 24] Testing optional LAN target...
call :section "LAN TARGET TEST"
if defined LAN_TARGET (
    >>"%LOGFILE%" echo Target: %LAN_TARGET%
    ping %LAN_TARGET% -n 10 >>"%LOGFILE%" 2>&1
) else (
    >>"%LOGFILE%" echo LAN_TARGET is not configured. Test skipped.
)

REM ---- 5. Traditional DNS -------------------------------------------
echo [5 of 24] Testing configured DNS...
call :section "NSLOOKUP %TEST_HOST_1%"
nslookup %TEST_HOST_1% >>"%LOGFILE%" 2>&1

REM ---- 6. Dedicated DNS timing --------------------------------------
echo [6 of 24] Measuring DNS resolution timing...
call :dnstiming "%TEST_HOST_1%"
call :dnstiming "%TEST_HOST_2%"

REM ---- 7. Per-resolver DNS timing -----------------------------------
echo [7 of 24] Measuring each configured DNS resolver...
call :section "PER-RESOLVER DNS TIMING"
powershell -NoProfile -Command ^
    "$hostName='%TEST_HOST_1%';" ^
    "$upIf=(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object {$_.Status -eq 'Up'}).ifIndex;" ^
    "$servers=Get-DnsClientServerAddress -ErrorAction SilentlyContinue | Where-Object {$upIf -contains $_.InterfaceIndex} | ForEach-Object {$_.ServerAddresses} | Where-Object {$_ -and $_ -notmatch '^fec0:'} | Select-Object -Unique;" ^
    "if(-not $servers){Write-Output 'No usable DNS servers found on active adapters.'; exit};" ^
    "foreach($server in $servers) {" ^
    "$sw=[System.Diagnostics.Stopwatch]::StartNew();" ^
    "try {" ^
    "$r=Resolve-DnsName -Name $hostName -Server $server -DnsOnly -ErrorAction Stop;" ^
    "$sw.Stop();" ^
    "$ips=$r | Where-Object {$_.IPAddress} | Select-Object -ExpandProperty IPAddress -Unique;" ^
    "Write-Output ('Server: ' + $server);" ^
    "Write-Output 'Result: SUCCESS';" ^
    "Write-Output ('TimeMs: ' + $sw.ElapsedMilliseconds);" ^
    "if($ips){Write-Output ('Addresses: ' + ($ips -join ', '))}" ^
    "} catch {" ^
    "$sw.Stop();" ^
    "Write-Output ('Server: ' + $server);" ^
    "Write-Output 'Result: FAILED';" ^
    "Write-Output ('TimeMs: ' + $sw.ElapsedMilliseconds);" ^
    "Write-Output ('Error: ' + $_.Exception.Message)" ^
    "}; Write-Output ''" ^
    "}" >>"%LOGFILE%" 2>&1

REM ---- 8. Independent TCP timing ------------------------------------
echo [8 of 24] Measuring independent TCP connection timing...
call :tcptiming "%TEST_HOST_1%" "%TEST_PORT%"
call :tcptiming "%TEST_HOST_2%" "%TEST_PORT%"

REM ---- 9. IP configuration ------------------------------------------
echo [9 of 24] Capturing IP configuration...
call :section "IPCONFIG /ALL"
ipconfig /all >>"%LOGFILE%" 2>&1

REM ---- 10. Routing --------------------------------------------------
echo [10 of 24] Capturing routing table...
call :section "ROUTE PRINT"
route print >>"%LOGFILE%" 2>&1

REM ---- 11. Adapter status -------------------------------------------
echo [11 of 24] Capturing network adapters...
call :section "GET-NETADAPTER"
powershell -NoProfile -Command ^
    "Get-NetAdapter | Sort-Object Status,Name | Format-Table -AutoSize Name,InterfaceDescription,Status,LinkSpeed,MacAddress,ifIndex" ^
    >>"%LOGFILE%" 2>&1

REM ---- 12. NIC driver metadata --------------------------------------
echo [12 of 24] Capturing NIC driver information...
call :section "NETWORK DRIVER INFORMATION"
powershell -NoProfile -Command ^
    "Get-CimInstance Win32_PnPSignedDriver | Where-Object {$_.DeviceClass -eq 'NET'} | Sort-Object DeviceName | Select-Object DeviceName,DriverProviderName,DriverVersion,DriverDate,InfName | Format-Table -AutoSize" ^
    >>"%LOGFILE%" 2>&1

REM ---- 13. IP/DNS by adapter ----------------------------------------
echo [13 of 24] Capturing adapter IP and DNS information...
call :section "GET-NETIPCONFIGURATION"
powershell -NoProfile -Command ^
    "Get-NetIPConfiguration | Format-List InterfaceAlias,InterfaceDescription,IPv4Address,IPv6Address,IPv4DefaultGateway,IPv6DefaultGateway,DNSServer" ^
    >>"%LOGFILE%" 2>&1

call :section "DNS CLIENT SERVER ADDRESSES"
powershell -NoProfile -Command ^
    "Get-DnsClientServerAddress | Where-Object {$_.ServerAddresses.Count -gt 0} | Format-Table -AutoSize InterfaceAlias,AddressFamily,ServerAddresses" ^
    >>"%LOGFILE%" 2>&1

REM ---- 14. Adapter bindings -----------------------------------------
echo [14 of 24] Capturing enabled adapter bindings...
call :section "ENABLED NETWORK ADAPTER BINDINGS"
powershell -NoProfile -Command ^
    "Get-NetAdapterBinding -Name '*' | Where-Object Enabled | Sort-Object Name,DisplayName | Format-Table -AutoSize Name,DisplayName,ComponentID" ^
    >>"%LOGFILE%" 2>&1

REM ---- 15. Wi-Fi diagnostics ----------------------------------------
echo [15 of 24] Capturing Wi-Fi link health...
call :section "WI-FI LINK DIAGNOSTICS"
netsh wlan show interfaces >"%TMPBASE%_wifi.txt" 2>&1
findstr /I /C:"State" /C:"Radio type" /C:"Channel" /C:"Receive rate" /C:"Transmit rate" /C:"Signal" "%TMPBASE%_wifi.txt" >>"%LOGFILE%" 2>&1
if errorlevel 1 (
    >>"%LOGFILE%" echo No Wi-Fi interface information was available.
)
del "%TMPBASE%_wifi.txt" >nul 2>&1

REM ---- 16. Proxy configuration --------------------------------------
echo [16 of 24] Capturing proxy configuration...
call :section "WINHTTP PROXY"
netsh winhttp show proxy >>"%LOGFILE%" 2>&1

call :section "USER / BROWSER PROXY SETTINGS"
powershell -NoProfile -Command ^
    "$p=Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings';" ^
    "[pscustomobject]@{ProxyEnable=$p.ProxyEnable;ProxyServer=$p.ProxyServer;AutoConfigURL=$p.AutoConfigURL;AutoDetect=$p.AutoDetect} | Format-List" ^
    >>"%LOGFILE%" 2>&1

REM ---- 17. Relevant services ----------------------------------------
echo [17 of 24] Capturing network/security service state...
call :section "NETWORK / SECURITY SERVICE STATE"
powershell -NoProfile -Command ^
    "$patterns='ESET|ekrn|Malwarebytes|MBAM|ExpressConnect|Dell Optimizer|DellOptimizer|ECDBWM|AnyConnect|Cisco Secure Client|GlobalProtect|PanGPS|Forti|Zscaler|CrowdStrike|CSFalcon|Sentinel|Sophos|Webroot|Defender|WinDefend|WdNis';" ^
    "$rows=Get-CimInstance Win32_Service | Where-Object {$_.Name -match $patterns -or $_.DisplayName -match $patterns} | Sort-Object DisplayName | Select-Object Name,DisplayName,State,StartMode,ProcessId;" ^
    "if($rows){$rows | Format-Table -AutoSize}else{Write-Output 'No matching network/security services detected.'}" ^
    >>"%LOGFILE%" 2>&1

REM ---- 18. Relevant processes ---------------------------------------
echo [18 of 24] Capturing relevant network/security processes...
call :section "NETWORK / SECURITY PROCESS SNAPSHOT"
powershell -NoProfile -Command ^
    "$patterns='ekrn|egui|Malwarebytes|MBAM|ExpressConnect|ECDBWM|DellOptimizer|OptimizerUI|vpnui|vpnagent|AnyConnect|GlobalProtect|PanGPS|Forti|Zscaler|CrowdStrike|CSFalcon|Sentinel|Sophos|Webroot|MsMpEng|NisSrv|MpDefenderCoreService';" ^
    "$rows=Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -match $patterns} | Sort-Object ProcessName | Select-Object Id,ProcessName,@{n='CPUSeconds';e={if($_.CPU -ne $null){[math]::Round($_.CPU,1)}}},WorkingSet64;" ^
    "if($rows){$rows | Format-Table -AutoSize}else{Write-Output 'No matching network/security processes detected.'}" ^
    >>"%LOGFILE%" 2>&1

REM ---- 19. System performance snapshot ------------------------------
echo [19 of 24] Capturing system performance snapshot...
call :section "SYSTEM PERFORMANCE SNAPSHOT"
powershell -NoProfile -Command ^
    "$cpu=(Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average;" ^
    "$os=Get-CimInstance Win32_OperatingSystem;" ^
    "$freeMB=[math]::Round($os.FreePhysicalMemory/1024,0);" ^
    "$totalMB=[math]::Round($os.TotalVisibleMemorySize/1024,0);" ^
    "Write-Output ('CPU Load Percent: ' + $cpu);" ^
    "Write-Output ('Memory Free MB: ' + $freeMB);" ^
    "Write-Output ('Memory Total MB: ' + $totalMB);" ^
    "Write-Output '';" ^
    "Write-Output 'Highest current process CPU usage:';" ^
    "$proc=Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue | Where-Object {$_.Name -ne '_Total' -and $_.IDProcess -gt 0} | Sort-Object PercentProcessorTime -Descending | Select-Object -First 10 @{n='PID';e={$_.IDProcess}},@{n='Process';e={$_.Name}},@{n='CPUPercent';e={$_.PercentProcessorTime}},@{n='WorkingSetMB';e={[math]::Round($_.WorkingSet/1MB,1)}};" ^
    "if($proc){$proc | Format-Table -AutoSize}else{Write-Output 'Current per-process CPU counters were unavailable.'};" ^
    "Write-Output 'Disk snapshot:';" ^
    "Get-CimInstance Win32_PerfFormattedData_PerfDisk_LogicalDisk -ErrorAction SilentlyContinue | Where-Object {$_.Name -ne '_Total'} | Select-Object Name,PercentDiskTime,AvgDiskQueueLength,DiskReadsPersec,DiskWritesPersec | Format-Table -AutoSize" ^
    >>"%LOGFILE%" 2>&1

REM ---- 20. HTTPS timing ---------------------------------------------
echo [20 of 24] Testing HTTPS timing...
call :curltest "DEFAULT HTTPS - %TEST_HOST_1%" "" "%TEST_HOST_1%"
call :curltest "DEFAULT HTTPS - %TEST_HOST_2%" "" "%TEST_HOST_2%"
call :curltest "IPv4 HTTPS - %TEST_HOST_1%" "-4" "%TEST_HOST_1%"
call :curltest "IPv4 HTTPS - %TEST_HOST_2%" "-4" "%TEST_HOST_2%"
powershell -NoProfile -Command "if(Get-NetRoute -AddressFamily IPv6 -DestinationPrefix '::/0' -ErrorAction SilentlyContinue){exit 0}else{exit 1}"
if errorlevel 1 (
    call :section "IPv6 HTTPS"
    >>"%LOGFILE%" echo No active IPv6 default route detected. IPv6 HTTPS tests skipped.
) else (
    call :curltest "IPv6 HTTPS - %TEST_HOST_1%" "-6" "%TEST_HOST_1%"
    call :curltest "IPv6 HTTPS - %TEST_HOST_2%" "-6" "%TEST_HOST_2%"
)

REM ---- 21. TCP state by process - snapshot 1 ------------------------
echo [21 of 24] Capturing TCP state snapshot 1...
call :tcpstates "TCP STATE COUNTS BY PROCESS - SNAPSHOT 1" "%TMPBASE%_tcp1.csv"

REM ---- 22. Adapter statistics - snapshot 1 --------------------------
echo [22 of 24] Capturing adapter statistics snapshot 1...
call :section "ADAPTER STATISTICS - SNAPSHOT 1"
powershell -NoProfile -Command ^
    "Get-NetAdapterStatistics | Sort-Object Name | Select-Object Name,ReceivedBytes,SentBytes,ReceivedUnicastPackets,SentUnicastPackets,ReceivedDiscardedPackets,OutboundDiscardedPackets,ReceivedPacketErrors,OutboundPacketErrors | Export-Csv -NoTypeInformation '%TMPBASE%_adapter1.csv';" ^
    "Import-Csv '%TMPBASE%_adapter1.csv' | Select-Object Name,@{n='RxBytes';e={$_.ReceivedBytes}},@{n='TxBytes';e={$_.SentBytes}},@{n='RxPkts';e={$_.ReceivedUnicastPackets}},@{n='TxPkts';e={$_.SentUnicastPackets}},@{n='RxDrop';e={$_.ReceivedDiscardedPackets}},@{n='TxDrop';e={$_.OutboundDiscardedPackets}},@{n='RxErr';e={$_.ReceivedPacketErrors}},@{n='TxErr';e={$_.OutboundPacketErrors}} | Format-Table -AutoSize" ^
    >>"%LOGFILE%" 2>&1

REM ---- Wait ---------------------------------------------------------
echo Waiting %SNAPSHOT_DELAY_SECONDS% seconds for delta measurements...
call :section "SNAPSHOT INTERVAL"
>>"%LOGFILE%" echo Waiting %SNAPSHOT_DELAY_SECONDS% seconds before second snapshot.
timeout /t %SNAPSHOT_DELAY_SECONDS% /nobreak >nul

REM ---- 23. TCP state by process - snapshot 2 and delta -------------
echo [23 of 24] Capturing TCP state snapshot 2...
call :tcpstates "TCP STATE COUNTS BY PROCESS - SNAPSHOT 2" "%TMPBASE%_tcp2.csv"

call :section "TCP STATE COUNT DELTAS"
powershell -NoProfile -Command ^
    "$a1=Import-Csv '%TMPBASE%_tcp1.csv';$a2=Import-Csv '%TMPBASE%_tcp2.csv';" ^
    "$keys=@($a1+$a2|ForEach-Object {$_.PID+'|'+$_.Process+'|'+$_.State}|Select-Object -Unique);" ^
    "$deltaRows=foreach($k in $keys){$parts=$k -split '\|',3;$ownerPid=$parts[0];$proc=$parts[1];$state=$parts[2];" ^
    "$x=$a1|Where-Object {$_.PID -eq $ownerPid -and $_.Process -eq $proc -and $_.State -eq $state}|Select-Object -First 1;" ^
    "$y=$a2|Where-Object {$_.PID -eq $ownerPid -and $_.Process -eq $proc -and $_.State -eq $state}|Select-Object -First 1;" ^
    "$c1=if($x){[int]$x.Count}else{0};$c2=if($y){[int]$y.Count}else{0};" ^
    "if($c1 -ne $c2){[pscustomobject]@{PID=$ownerPid;Process=$proc;State=$state;Snapshot1=$c1;Snapshot2=$c2;Delta=($c2-$c1)}}};" ^
    "if($deltaRows){$deltaRows|Sort-Object Process,State|Format-Table -AutoSize}else{Write-Output 'No TCP state-count changes detected during the snapshot interval.'}" ^
    >>"%LOGFILE%" 2>&1

REM ---- 24. Adapter stats snapshot 2 + deltas ------------------------
echo [24 of 24] Capturing adapter statistics snapshot 2 and deltas...
call :section "ADAPTER STATISTICS - SNAPSHOT 2 AND DELTAS"
powershell -NoProfile -Command ^
    "Get-NetAdapterStatistics | Sort-Object Name | Select-Object Name,ReceivedBytes,SentBytes,ReceivedUnicastPackets,SentUnicastPackets,ReceivedDiscardedPackets,OutboundDiscardedPackets,ReceivedPacketErrors,OutboundPacketErrors | Export-Csv -NoTypeInformation '%TMPBASE%_adapter2.csv';" ^
    "$a1=Import-Csv '%TMPBASE%_adapter1.csv';$a2=Import-Csv '%TMPBASE%_adapter2.csv';" ^
    "$deltaRows=foreach($b in $a2){$a=$a1 | Where-Object {$_.Name -eq $b.Name}; if($a){" ^
    "[pscustomobject]@{" ^
    "Name=$b.Name;" ^
    "RxBytes=([int64]$b.ReceivedBytes-[int64]$a.ReceivedBytes);" ^
    "TxBytes=([int64]$b.SentBytes-[int64]$a.SentBytes);" ^
    "RxPkts=([int64]$b.ReceivedUnicastPackets-[int64]$a.ReceivedUnicastPackets);" ^
    "TxPkts=([int64]$b.SentUnicastPackets-[int64]$a.SentUnicastPackets);" ^
    "RxDrop=([int64]$b.ReceivedDiscardedPackets-[int64]$a.ReceivedDiscardedPackets);" ^
    "TxDrop=([int64]$b.OutboundDiscardedPackets-[int64]$a.OutboundDiscardedPackets);" ^
    "RxErr=([int64]$b.ReceivedPacketErrors-[int64]$a.ReceivedPacketErrors);" ^
    "TxErr=([int64]$b.OutboundPacketErrors-[int64]$a.OutboundPacketErrors)" ^
    "}}};" ^
    "$deltaRows | Format-Table -AutoSize" ^
    >>"%LOGFILE%" 2>&1

REM ---- Final full connection/process capture ------------------------
call :section "NETSTAT -ANO"
netstat -ano >>"%LOGFILE%" 2>&1

call :section "PROCESS LIST FOR NETWORK CORRELATION"
powershell -NoProfile -Command ^
    "Get-Process | Sort-Object Id | Select-Object Id,ProcessName | Format-Table -AutoSize" ^
    >>"%LOGFILE%" 2>&1

call :section "DIAGNOSTIC COMPLETE"
>>"%LOGFILE%" echo Completed: %DATE% %TIME%

del "%TMPBASE%_adapter1.csv" >nul 2>&1
del "%TMPBASE%_adapter2.csv" >nul 2>&1
del "%TMPBASE%_tcp1.csv" >nul 2>&1
del "%TMPBASE%_tcp2.csv" >nul 2>&1

echo.
echo Diagnostics complete.
echo Log saved to:
echo %LOGFILE%
echo.
echo Review the log before sharing it.
echo.
pause
goto :eof

REM ===================================================================
:section
>>"%LOGFILE%" echo.
>>"%LOGFILE%" echo ============================================================
>>"%LOGFILE%" echo %~1
>>"%LOGFILE%" echo ============================================================
exit /b

REM ===================================================================
:dnstiming
call :section "DNS TIMING - %~1"
powershell -NoProfile -Command ^
    "$hostName='%~1';$sw=[System.Diagnostics.Stopwatch]::StartNew();" ^
    "try{$r=Resolve-DnsName -Name $hostName -DnsOnly -ErrorAction Stop;$sw.Stop();" ^
    "$addresses=$r | Where-Object {$_.IPAddress} | Select-Object -ExpandProperty IPAddress -Unique;" ^
    "Write-Output ('Host: '+$hostName);Write-Output 'Resolution: SUCCESS';Write-Output ('TimeMs: '+$sw.ElapsedMilliseconds);" ^
    "if($addresses){Write-Output 'Addresses:';$addresses | ForEach-Object {Write-Output ('  '+$_)}}}" ^
    "catch{$sw.Stop();Write-Output ('Host: '+$hostName);Write-Output 'Resolution: FAILED';Write-Output ('TimeMs: '+$sw.ElapsedMilliseconds);Write-Output ('Error: '+$_.Exception.Message)}" ^
    >>"%LOGFILE%" 2>&1
exit /b

REM ===================================================================
:tcptiming
call :section "TCP TIMING - %~1:%~2"
powershell -NoProfile -Command ^
    "$hostName='%~1';$port=%~2;$timeoutMs=5000;" ^
    "try{$all=[System.Net.Dns]::GetHostAddresses($hostName)}catch{Write-Output ('DNS resolution failed: '+$_.Exception.Message);exit};" ^
    "$v4=$all|Where-Object {$_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork}|Select-Object -First 1;" ^
    "$v6=$all|Where-Object {$_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6}|Select-Object -First 1;" ^
    "$addresses=@($v4,$v6)|Where-Object {$_};" ^
    "foreach($address in $addresses){$client=New-Object System.Net.Sockets.TcpClient($address.AddressFamily);$sw=[System.Diagnostics.Stopwatch]::StartNew();" ^
    "try{$ar=$client.BeginConnect($address,$port,$null,$null);if(-not $ar.AsyncWaitHandle.WaitOne($timeoutMs,$false)){throw 'Connection timed out'};$client.EndConnect($ar);$sw.Stop();" ^
    "Write-Output ('Address: '+$address.IPAddressToString);Write-Output ('Family: '+$address.AddressFamily);Write-Output 'TCP: SUCCESS';Write-Output ('ConnectTimeMs: '+$sw.ElapsedMilliseconds)}" ^
    "catch{$sw.Stop();Write-Output ('Address: '+$address.IPAddressToString);Write-Output ('Family: '+$address.AddressFamily);Write-Output 'TCP: FAILED';Write-Output ('ConnectTimeMs: '+$sw.ElapsedMilliseconds);Write-Output ('Error: '+$_.Exception.Message)}" ^
    "finally{$client.Close()};Write-Output ''}" ^
    >>"%LOGFILE%" 2>&1
exit /b

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

REM ===================================================================
:tcpstates
call :section "%~1"
powershell -NoProfile -Command ^
    "$p=@{};Get-Process -ErrorAction SilentlyContinue|ForEach-Object{$p[$_.Id]=$_.ProcessName};" ^
    "$c=Get-NetTCPConnection -ErrorAction SilentlyContinue;" ^
    "if(-not $c){Write-Output 'No TCP connection data available.';@()|Export-Csv -NoTypeInformation '%~2';exit};" ^
    "$rows=$c | Group-Object OwningProcess,State | ForEach-Object {" ^
    "$sample=$_.Group | Select-Object -First 1;" ^
    "$ownerPid=[int]$sample.OwningProcess;" ^
    "$state=[string]$sample.State;" ^
    "[pscustomobject]@{PID=$ownerPid;Process=($p[$ownerPid]);State=$state;Count=$_.Count}" ^
    "};" ^
    "$rows | Sort-Object Process,State | Export-Csv -NoTypeInformation '%~2';" ^
    "$rows | Sort-Object Process,State | Format-Table -AutoSize" ^
    >>"%LOGFILE%" 2>&1
exit /b
