# Windows Internet Slowdown Diagnostic Capture

A small Windows batch script for capturing useful network diagnostics when an Internet connection feels slow, inconsistent, or unreliable.

The tool is designed for intermittent problems where a user may report that websites or Internet-connected applications feel slow even though speed tests or basic system performance appear normal. It gives a non-technical user a simple way to collect a detailed snapshot for later troubleshooting.

## What v3 checks

Version 3 performs fourteen read-only diagnostic steps:

1. **Raw IPv4 connectivity** - Pings `1.1.1.1` 20 times to check basic Internet reachability, latency, and packet loss.
2. **Hostname connectivity** - Pings `www.google.com` 20 times to combine name resolution with a connectivity test.
3. **DNS resolution** - Runs `nslookup` against `www.google.com` using the system's configured DNS resolver.
4. **IP configuration** - Captures `ipconfig /all`, including addresses, gateways, DHCP information, and DNS servers.
5. **Routing table** - Captures `route print` to show active IPv4 and IPv6 routes.
6. **Network adapter status** - Reports adapter names, descriptions, status, link speed, MAC address, and interface index.
7. **IP and DNS configuration by adapter** - Captures adapter-specific IP addresses, gateways, and DNS server assignments.
8. **Enabled network adapter bindings** - Captures enabled networking components and bindings.
9. **WinHTTP proxy configuration** - Runs `netsh winhttp show proxy`.
10. **Current-user proxy configuration** - Reads `ProxyEnable`, `ProxyServer`, `AutoConfigURL`, and `AutoDetect`.
11. **Default HTTPS timing** - Records DNS, TCP connect, TLS, first-byte, and total request timing using the normal network path.
12. **IPv4 HTTPS timing** - Repeats the HTTPS timing test while forcing IPv4.
13. **IPv6 HTTPS timing** - Repeats the HTTPS timing test while forcing IPv6.
14. **Active connection and process correlation** - Captures `netstat -ano`, TCP connection counts by PID, and a PID/process-name list.

The script does not change network settings.

## What's new in v3

Version 2 focused on expanded proxy detection.

Version 3 adds deeper troubleshooting data intended to help distinguish between problems involving:

- DNS
- IPv4 versus IPv6 behavior
- routing
- network adapters
- adapter bindings
- proxy configuration
- HTTPS connection setup
- TLS negotiation
- active network connections
- processes with unusually high numbers of connections

This version is still designed as a capture tool rather than an automated diagnosis engine.

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
Internet_Diagnostic_2026-09-04_19-30-00.txt
```

Existing logs are not overwritten.

## Configuring the test targets

The default targets are defined near the top of the batch file:

```bat
set "PING_TARGET=1.1.1.1"
set "TEST_HOST=www.google.com"
```

They can be changed before deployment if different public test targets are preferred.

## HTTPS timing fields

The default, IPv4, and IPv6 HTTPS tests record:

- `RemoteIP` - destination address used for the request
- `HTTP` - returned HTTP status code
- `DNS` - DNS lookup time
- `Connect` - TCP connection time
- `TLS` - time until the TLS handshake completes
- `FirstByte` - time until the first response byte is received
- `Total` - total request time

Example:

```text
RemoteIP:142.251.157.119
HTTP:200
DNS:0.009239s
Connect:0.026927s
TLS:0.061986s
FirstByte:0.124994s
Total:0.175185s
```

These values can be useful when ping tests look healthy but web browsing or applications still feel slow.

For example, a low DNS time combined with a very high TLS time may point troubleshooting toward HTTPS inspection, security software, or another layer above basic IP connectivity.

## Interpreting the results

The tool is primarily intended to capture evidence while a problem is actively happening.

### Healthy raw connectivity, slow hostname-based tests

If the raw IP ping is healthy but hostname-based tests pause or fail, DNS becomes more interesting.

### IPv4 and IPv6 behave differently

If forced IPv4 HTTPS requests are fast while forced IPv6 requests are consistently slow or fail, investigate IPv6 routing, filtering, or configuration.

The reverse can also occur.

### Healthy ping, slow TLS or first-byte timing

If ping latency is low but TLS or first-byte time is unusually high, the delay may be occurring above the basic IP layer.

Possible areas to investigate include:

- security software
- HTTPS inspection
- endpoint protection
- VPN software
- network filtering
- application-specific behavior

The script does not automatically determine which of these is responsible.

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

Version 3 captures significantly more information than earlier releases.

Review diagnostic logs before posting them publicly or sharing them outside the organization.

Depending on the system, the log may include:

- local IP addresses
- public and private destination IP addresses
- DNS server addresses
- default gateways
- MAC addresses
- DHCP information
- routing information
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

The HTTPS timing tests record timing and status information only.

## Scope

Version 3 is intended as a practical diagnostic capture tool for intermittent Windows network slowdowns.

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
- **v3** - adds detailed adapter, routing, DNS, timing, connection, and process correlation data

## License

This project is licensed under the MIT License.
