# Windows Internet Slowdown Diagnostic Capture

A Windows batch script for capturing useful network diagnostics when an Internet connection feels slow, inconsistent, or unreliable.

The tool is designed for intermittent problems where websites or Internet-connected applications may feel slow even though speed tests or basic system performance appear normal. It gives a non-technical user a simple way to collect a detailed, read-only snapshot for later troubleshooting.

## What v4 checks

Version 4 performs nineteen read-only diagnostic steps:

1. **Raw IPv4 connectivity** - Pings a configurable public IP target 20 times to check reachability, latency, and packet loss.
2. **Hostname connectivity** - Pings the primary configurable test host.
3. **Traditional DNS lookup** - Runs `nslookup` against the primary test host using the system's configured DNS resolver.
4. **Dedicated DNS timing** - Measures resolution time for both configured test hosts and records returned IP addresses.
5. **Independent TCP connection timing** - Resolves each configured host and measures TCP connection time to at most one IPv4 and one IPv6 address without performing TLS or HTTP.
6. **Default gateway test** - Detects the active IPv4 default gateway and pings it to help distinguish local-link problems from upstream Internet problems.
7. **IP configuration** - Captures `ipconfig /all`.
8. **Routing table** - Captures `route print`.
9. **Network adapter status** - Reports adapter name, description, status, link speed, MAC address, and interface index.
10. **Network adapter statistics** - Captures byte, packet, discard, and packet-error counters.
11. **IP and DNS configuration by adapter** - Captures adapter-specific IP addresses, gateways, and DNS server assignments.
12. **Enabled network adapter bindings** - Captures enabled networking components and bindings.
13. **Wi-Fi link diagnostics** - Captures selected WLAN link-health fields such as state, signal, radio type, channel, and negotiated rates when available. SSID and BSSID values are intentionally excluded.
14. **WinHTTP proxy configuration** - Runs `netsh winhttp show proxy`.
15. **Current-user proxy configuration** - Reads `ProxyEnable`, `ProxyServer`, `AutoConfigURL`, and `AutoDetect`.
16. **Default HTTPS timing** - Records DNS, TCP connect, TLS, first-byte, and total request timing for both configured test hosts.
17. **IPv4 HTTPS timing** - Repeats the HTTPS timing tests while forcing IPv4.
18. **IPv6 HTTPS timing** - Repeats the HTTPS timing tests while forcing IPv6.
19. **Active connection and process correlation** - Captures `netstat -ano`, TCP connection counts by PID, and a PID/process-name list.

The script does not change network settings.

## What's new in v4

Version 3 added detailed adapter, routing, DNS, HTTPS timing, connection, and process-correlation data.

Version 4 focuses on **layer-by-layer timing and link health**:

- dedicated DNS resolution timing
- TCP connection timing independent of TLS and HTTP
- active default-gateway latency
- adapter error and discard counters
- conditional Wi-Fi link information
- a second configurable test host

These additions make it easier to determine whether a slowdown begins at the local network, DNS layer, TCP connection layer, TLS layer, or application-response layer.

## Requirements

- Windows 10 or later
- Windows PowerShell
- No administrator privileges are required for normal use
- `curl` is optional. If it is unavailable, the script records that fact and continues with the remaining tests.

Modern Windows 10 and Windows 11 installations normally include `curl`.

## Usage

1. Download `internet-slowdown-diagnostic.bat`.
2. Place it somewhere the user can easily find, such as the Desktop.
3. When the Internet connection feels slow, double-click the batch file.
4. Wait for all diagnostic steps to finish.
5. Press a key when prompted to close the window.
6. Open the `NetworkDiagnostics` folder created next to the batch file.
7. Review the generated `.txt` file before sharing it.

Each run creates a new timestamped log, for example:

```text
Internet_Diagnostic_2026-09-22_08-30-00.txt
```

Existing logs are not overwritten.

## Configuring the test targets

The default targets are defined near the top of the batch file:

```bat
set "PING_TARGET=1.1.1.1"
set "TEST_HOST_1=www.google.com"
set "TEST_HOST_2=www.microsoft.com"
set "TEST_PORT=443"
```

These can be changed before deployment.

Using test hosts from different providers can be useful. If one endpoint is slow while another is healthy, that may point away from a general local-network problem.

## Example v4 output

### DNS timing

```text
============================================================
DNS TIMING - www.google.com
============================================================
Host: www.google.com
Resolution: SUCCESS
TimeMs: 18
Addresses:
  142.250.72.196
  2607:f8b0:4007:80d::2004
```

### TCP timing

```text
============================================================
TCP TIMING - www.google.com:443
============================================================
Address: 142.250.72.196
Family: InterNetwork
TCP: SUCCESS
ConnectTimeMs: 22

Address: 2607:f8b0:4007:80d::2004
Family: InterNetworkV6
TCP: SUCCESS
ConnectTimeMs: 27
```

### HTTPS timing

```text
RemoteIP:142.250.72.196
HTTP:200
DNS:0.018000s
Connect:0.041000s
TLS:0.093000s
FirstByte:0.151000s
Total:0.181000s
```

The example values above are illustrative only.

## How the timing layers fit together

The v4 timing tests deliberately measure different parts of a request.

### DNS timing

The dedicated DNS test measures hostname resolution independently.

If DNS takes several seconds while gateway, raw IP, and TCP tests are otherwise healthy, investigate DNS configuration, DNS filtering, VPN behavior, or resolver availability.

### TCP timing

The independent TCP test resolves the hostname first, then times the TCP connection to the resulting IP address. It does not perform a TLS handshake or HTTP request.

This helps separate TCP connection delays from TLS or application delays.

For example:

```text
DNS: 15 ms
TCP: 20 ms
TLS: 4200 ms
```

would make TLS inspection, endpoint security, VPN filtering, or another higher-layer issue more interesting.

### HTTPS timing

The HTTPS test records:

- `RemoteIP` - destination address used for the request
- `HTTP` - returned HTTP status code
- `DNS` - DNS lookup time
- `Connect` - TCP connection time
- `TLS` - time until the TLS handshake completes
- `FirstByte` - time until the first response byte is received
- `Total` - total request time

The default, forced-IPv4, and forced-IPv6 tests make address-family differences easier to spot.

## Interpreting the results

The tool is primarily intended to capture evidence while a problem is actively happening.

### Default gateway is slow

If the default gateway shows high latency or packet loss, investigate the local network before blaming the ISP or DNS.

Possible areas include:

- Wi-Fi signal quality
- Ethernet cabling
- network adapter or driver issues
- local router or switch performance

### Gateway is healthy but public IP is slow

If the gateway remains fast but the public ping target has high latency or packet loss, the problem may be beyond the local link.

That could include the router's upstream connection, ISP path, or another external network issue.

### DNS timing is slow

If raw IP connectivity and gateway latency are healthy but dedicated DNS resolution is slow, DNS becomes a stronger lead.

### TCP is slow but DNS is healthy

If DNS completes quickly but independent TCP connections take a long time, investigate routing, filtering, firewall behavior, endpoint security, or upstream connectivity.

### TCP is fast but TLS is slow

If DNS and TCP are fast but the HTTPS test spends a long time reaching the TLS milestone, investigate software or devices that inspect or filter encrypted traffic.

Examples can include:

- endpoint security
- HTTPS inspection
- VPN software
- firewall products
- network security appliances

The script does not automatically determine which component is responsible.

### IPv4 and IPv6 behave differently

If forced IPv4 HTTPS requests are fast while forced IPv6 requests are consistently slow or fail, investigate IPv6 routing, filtering, or configuration.

The reverse can also occur.

### Adapter errors or discarded packets increase

The adapter-statistics section may expose packet errors or discarded packets.

A single snapshot cannot always establish whether a counter is actively increasing. Comparing a healthy capture with a slow-period capture can be more useful.

Unexpectedly increasing error or discard counts can justify investigating:

- cabling
- Wi-Fi quality
- network adapter drivers
- switch/router ports
- duplex or physical-link problems

### Wi-Fi diagnostics

When Wi-Fi information is available, the script records selected link-health fields such as state, signal, radio type, channel, and negotiated receive/transmit rates. It intentionally excludes SSID and BSSID.

Weak signal or unusually low negotiated rates can help explain a local wireless problem even when the Internet service itself is healthy.

### Unexpected adapter bindings

The enabled adapter bindings section can help identify networking components associated with:

- VPN software
- security software
- packet filters
- virtual networking
- third-party network utilities

Not all filtering software appears as an obvious adapter binding, so a clean binding list does not prove that no filtering software is active.

### Large numbers of connections from one PID

The TCP connection-count section can highlight processes that own an unusually large number of connections.

Use the process list to map the PID to a process name.

A high connection count is not automatically a problem. Browsers, synchronization tools, security software, databases, and other applications may legitimately maintain many connections.

## Proxy results

The WinHTTP section shows whether the Windows WinHTTP subsystem is configured for direct access or a proxy server.

The current-user proxy section reports Windows Internet Settings values:

- `ProxyEnable` - whether an explicit proxy is enabled for the current user
- `ProxyServer` - the configured proxy server, if present
- `AutoConfigURL` - the configured PAC file URL, if present
- `AutoDetect` - the Windows automatic proxy-detection setting, when defined

These checks improve proxy visibility but do not prove that all traffic bypasses third-party VPN, firewall, antivirus, endpoint-security, or other filtering software.

## Privacy

Version 4 captures detailed network-state information.

Review diagnostic logs before posting them publicly or sharing them outside the organization.

Depending on the system, the log may include:

- local IP addresses
- public and private destination IP addresses
- DNS server addresses
- default gateways
- MAC addresses
- DHCP information
- routing information
- selected Wi-Fi link-health information (SSID and BSSID are intentionally excluded)
- proxy server names or addresses
- PAC file URLs
- listening ports
- active remote connections
- process names
- process IDs

The script does **not** intentionally collect:

- browser history
- page content
- credentials
- passwords
- cookies
- full executable paths
- packet contents

The HTTPS timing tests record timing and status information only.

## Scope

Version 4 is intended as a practical diagnostic capture tool for intermittent Windows network slowdowns.

It does not:

- modify network settings
- disable security software
- reset adapters
- change DNS servers
- flush caches
- terminate processes
- automatically identify the root cause
- capture packet contents

For deeper investigation, tools such as Microsoft Sysinternals TCPView, Process Explorer, Autoruns, or Wireshark may still be useful.

## Version progression

- **v1** - basic ping, DNS, HTTPS, and WinHTTP proxy capture
- **v2** - adds current-user proxy and PAC/autodetect information
- **v3** - adds detailed adapter, routing, DNS, HTTPS timing, connection, and process-correlation data
- **v4** - adds dedicated DNS/TCP timing, gateway testing, adapter error statistics, Wi-Fi link information, and multiple test hosts

## License

This project is licensed under the MIT License.
