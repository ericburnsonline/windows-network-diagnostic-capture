# Windows Internet Slowdown Diagnostic Capture

A Windows batch script for capturing useful network diagnostics when an Internet connection feels slow, inconsistent, or unreliable.

The tool is especially useful for intermittent problems where local LAN applications remain responsive while websites, cloud services, or other Internet-connected applications become painfully slow. It gives a non-technical user a simple way to collect a detailed, read-only snapshot for later troubleshooting.

## What v5 checks

Version 5 performs a layered set of read-only diagnostics designed to separate local LAN health from Internet, DNS, TCP, TLS, filtering, and workstation-performance problems.

The script captures:

1. **Raw Internet IPv4 connectivity** - Pings a configurable public IP target to check basic Internet reachability, latency, and packet loss.
2. **Hostname connectivity** - Pings the primary configurable Internet test host.
3. **Default gateway health** - Detects the active IPv4 default gateway and pings it.
4. **Optional LAN target health** - Pings a configurable LAN server or application host when one is supplied.
5. **Traditional DNS lookup** - Runs `nslookup` against the primary test host.
6. **Dedicated DNS timing** - Measures hostname-resolution time for both configured Internet test hosts.
7. **Per-resolver DNS timing** - Tests each configured DNS server individually and records success/failure and response time.
8. **Independent TCP connection timing** - Resolves each configured test host and measures TCP connection time to at most one IPv4 and one IPv6 address without performing TLS or HTTP.
9. **IP configuration** - Captures `ipconfig /all`.
10. **Routing table** - Captures `route print`.
11. **Network adapter status** - Reports adapter names, descriptions, state, link speed, MAC address, and interface index.
12. **NIC driver information** - Captures network-adapter driver provider, version, date, and INF name.
13. **IP and DNS configuration by adapter** - Captures adapter-specific IP addresses, gateways, and DNS server assignments.
14. **Enabled network adapter bindings** - Captures enabled networking components and bindings.
15. **Wi-Fi link diagnostics** - Captures selected WLAN link-health fields such as state, signal, radio type, channel, and negotiated rates when available. SSID and BSSID are intentionally excluded.
16. **Proxy configuration** - Captures both WinHTTP and current-user Windows Internet proxy settings.
17. **Network and security service state** - Detects common security, VPN, and network-optimization services and records their current state.
18. **Relevant network/security processes** - Captures process information for common filtering, endpoint-security, VPN, and network-optimization software.
19. **System performance snapshot** - Records CPU load, available memory, disk activity, and top CPU-consuming processes.
20. **HTTPS timing** - Measures DNS, TCP connect, TLS, first-byte, and total request timing for two Internet endpoints using default, forced-IPv4, and forced-IPv6 paths.
21. **TCP connection-state snapshot 1** - Groups TCP connections by PID, process name, and state.
22. **Adapter-statistics snapshot 1** - Captures byte, packet, discard, and error counters.
23. **TCP connection-state snapshot 2 and deltas** - Repeats the TCP-state capture after a short delay and records changes.
24. **Adapter-statistics snapshot 2 and deltas** - Repeats adapter statistics and calculates byte, packet, discard, and error-counter changes.

The script also captures a final `netstat -ano` and process list for correlation.

The script does not change network settings.

## What's new in v5

Version 4 focused on DNS, TCP, gateway, adapter, and Wi-Fi timing.

Version 5 focuses on diagnosing cases where the **LAN remains healthy while Internet traffic becomes slow**.

New capabilities include:

- optional known-good LAN target testing
- per-DNS-resolver timing
- NIC driver metadata
- common network/security service discovery
- common network/security process discovery
- system CPU, memory, and disk snapshot
- TCP states grouped directly by process name
- two TCP-state snapshots with deltas
- two network-adapter statistics snapshots with deltas

These additions make it easier to distinguish between:

- local LAN problems
- router/gateway problems
- DNS delays
- Internet routing problems
- TCP connection delays
- TLS/security inspection delays
- endpoint security or VPN interference
- network-optimization software
- NIC/driver problems
- workstation CPU, memory, or disk stalls

## Requirements

- Windows 10 or later
- Windows PowerShell
- No administrator privileges are required for normal use
- `curl` is optional. If it is unavailable, the script records that fact and continues with the remaining tests.

Modern Windows 10 and Windows 11 installations normally include `curl`.

## Usage

1. Download `internet-slowdown-diagnostic.bat`.
2. Place it somewhere the user can easily find, such as the Desktop.
3. Optionally configure a known-good LAN server or application host.
4. When the Internet connection feels slow, double-click the batch file.
5. Wait for all diagnostic steps to finish.
6. Press a key when prompted to close the window.
7. Open the `NetworkDiagnostics` folder created next to the batch file.
8. Review the generated `.txt` file before sharing it.

Each run creates a new timestamped log, for example:

```text
Internet_Diagnostic_2026-09-27_10-30-00.txt
```

Existing logs are not overwritten.

## Configuring the test targets

The default targets are defined near the top of the batch file:

```bat
set "PING_TARGET=1.1.1.1"
set "TEST_HOST_1=www.google.com"
set "TEST_HOST_2=www.microsoft.com"
set "TEST_PORT=443"
set "LAN_TARGET="
set "SNAPSHOT_DELAY_SECONDS=10"
```

These values can be changed before deployment.

### LAN target

`LAN_TARGET` is optional.

Use it for the hostname or IP address of a device or server that should remain reachable on the local network even when the Internet is unavailable.

Good examples include:

- a LAN-only application server
- a file server
- a NAS
- a printer
- an internal database server
- another reliable local host that normally responds quickly

For example:

```bat
set "LAN_TARGET=10.1.10.86"
```

or:

```bat
set "LAN_TARGET=fileserver"
```

Choose a target that is expected to stay available during an Internet outage. Avoid using a cloud service, public website, or anything that depends on Internet connectivity.

If you do not have a suitable local target, leave the value blank:

```bat
set "LAN_TARGET="
```

The LAN-target test will be skipped, but the rest of the diagnostics will run normally.

A configured LAN target is especially useful when users report:

> Local applications are fast, but Internet applications are slow.

During a slowdown, compare:

```text
LAN target
Default gateway
Public IP target
DNS timing
TCP timing
TLS timing
HTTP first-byte timing
```

If the LAN target and default gateway remain fast while Internet DNS, TCP, TLS, or HTTP timing becomes slow, the problem is less likely to be the local LAN itself.

If the LAN target is also slow, investigate the local network, switch, Wi-Fi, cabling, network adapter, or local server before focusing on the ISP or Internet path.

## Understanding the diagnostic layers

Version 5 deliberately tests different network layers separately.

### LAN target

The optional LAN target checks whether communication to a known-good local server remains healthy.

If the LAN application is fast while Internet traffic is slow, compare:

```text
LAN target
Default gateway
Public IP target
DNS timing
TCP timing
TLS timing
HTTP first-byte timing
```

That sequence helps isolate where the slowdown begins.

### Default gateway

The gateway test helps distinguish a local-network problem from an upstream problem.

If both the LAN target and gateway are slow, investigate the local network first.

If the LAN target and gateway are fast but the Internet target is slow, the problem is likely farther upstream.

### DNS timing

The dedicated DNS tests measure hostname resolution independently.

Version 5 also tests each configured resolver separately.

This can reveal cases where:

- one DNS resolver is slow while another is healthy
- IPv4 and IPv6 resolvers behave differently
- DNS is the only slow layer
- the system is repeatedly falling back between resolvers

### TCP timing

The independent TCP test resolves the hostname first, then measures the TCP connection itself.

It does not perform TLS or HTTP.

For example:

```text
DNS: 12 ms
TCP: 18 ms
TLS: 3800 ms
```

would make TLS inspection, endpoint security, VPN filtering, or another higher-layer issue more interesting.

### HTTPS timing

HTTPS timing records:

- `RemoteIP`
- `HTTP`
- `DNS`
- `Connect`
- `TLS`
- `FirstByte`
- `Total`

The script performs default, IPv4-only, and IPv6-only tests against two different providers.

If one provider is slow and another is healthy, the problem may not be a general local-network issue.

## Process and connection-state diagnostics

Version 5 groups TCP connections by:

- PID
- process name
- TCP state
- connection count

This makes states such as these easier to correlate directly with applications:

- `ESTABLISHED`
- `SYN_SENT`
- `CLOSE_WAIT`
- `TIME_WAIT`
- `LISTEN`

The script takes two snapshots separated by a configurable delay.

Changes between the two snapshots can be more useful than a single static count.

Examples of potentially interesting patterns include:

- rapidly increasing `SYN_SENT` counts
- a process accumulating large numbers of `CLOSE_WAIT` connections
- unusually large changes associated with a security or VPN process

A high connection count alone is not proof of a problem.

Browsers, synchronization tools, databases, security software, and other applications may legitimately maintain many connections.

## Network and security software discovery

The script looks for common names associated with:

- endpoint security
- antivirus
- VPN clients
- web filtering
- network optimization
- secure-access software

Examples include products or components associated with:

- ESET
- Malwarebytes
- Dell ExpressConnect / Dell Optimizer
- Cisco / AnyConnect
- Palo Alto GlobalProtect
- Fortinet
- Zscaler
- CrowdStrike
- Sentinel
- Sophos
- Webroot

These names are not assumptions about the computer being tested.

They are simply common products that may affect Internet traffic and are useful to identify during troubleshooting.

The checks are read-only.

## Adapter statistics and deltas

Version 5 captures adapter statistics twice.

The second snapshot is compared with the first to calculate changes in:

- bytes received/sent
- packets received/sent
- received discards
- outbound discards
- receive errors
- transmit errors

A single cumulative counter is often difficult to interpret.

A counter that increases during the diagnostic interval is more useful.

Unexpected increases may justify investigation of:

- cabling
- network adapter drivers
- switch/router ports
- Wi-Fi quality
- physical-link problems

## NIC driver information

The diagnostic captures network-driver information including:

- adapter/device name
- driver provider
- driver version
- driver date
- INF name

This can help compare machines or determine whether an intermittent problem correlates with a particular driver release.

## System performance snapshot

Internet slowness can sometimes be caused by a workstation stall rather than the network itself.

Version 5 therefore records:

- CPU load
- free and total memory
- top CPU-consuming processes
- basic logical-disk activity

This helps identify cases where Internet applications only appear slow because the machine is temporarily overloaded.

## Proxy results

The WinHTTP section shows whether the Windows WinHTTP subsystem is configured for direct access or a proxy server.

The current-user proxy section reports:

- `ProxyEnable`
- `ProxyServer`
- `AutoConfigURL`
- `AutoDetect`

These checks improve proxy visibility but do not prove that traffic bypasses third-party VPN, endpoint-security, firewall, antivirus, or network-filtering software.

## Privacy and data-sharing risks

Version 5 captures detailed network, process, service, and system-state information.

**Generated diagnostic logs should be treated as potentially sensitive operational data. Review them before posting them publicly, attaching them to support tickets, sharing them in forums, or sending them outside the organization.**

A single item in the log may seem harmless, but several fields together can reveal useful information about a person's computer, local network, security software, and internal infrastructure.

Depending on the system and configuration, generated logs may include:

- computer hostname
- local/private IP addresses and subnet information
- public IPv6 addresses
- public and private destination IP addresses
- the configured `LAN_TARGET`
- internal server or device addresses
- DNS server addresses
- default gateways
- MAC addresses
- DHCP information
- routing information
- network adapter models
- NIC driver provider, version, date, and INF name
- selected Wi-Fi link-health information
- proxy server names or addresses
- PAC file URLs
- listening ports
- active remote connections
- process names
- process IDs
- running service names and states
- names of installed or running security products
- names of installed or running VPN or network-optimization software
- CPU, memory, and disk-performance information

This information can reveal details such as:

- internal IP-address ranges
- internal server locations or naming conventions
- what security or VPN software is in use
- what applications are actively communicating over the network
- network topology and gateway information
- adapter and driver versions that may identify the machine or environment

The script intentionally avoids collecting:

- passwords
- credentials
- browser history
- browser page contents
- cookies
- packet payloads
- Wi-Fi SSID
- Wi-Fi BSSID
- full executable paths in the general process correlation list

The HTTPS timing tests record timing and status information only and do not save webpage content.

### Before sharing a diagnostic log

Review the file and consider removing or redacting:

- computer names
- usernames if present in paths or other output
- internal hostnames
- private or public IP addresses
- MAC addresses
- DNS server addresses
- proxy or PAC URLs
- internal routes
- LAN target values
- process or service names that reveal security tooling or internal applications

For troubleshooting inside a trusted organization, keeping those fields may be useful. For public sharing, they should be reviewed carefully.

The script itself is designed to remain organization-independent and does not contain customer-specific addresses, credentials, or internal hostnames. `LAN_TARGET` is blank by default.

## Public repository use

The batch file is designed to remain generally useful and organization-independent.

The default configuration uses public Internet targets and leaves the LAN target blank.

Before publishing an organization-specific copy, verify that no internal hostnames, IP addresses, DNS servers, credentials, or other private values have been added to the configurable section.

Generated logs should not be committed to the repository.

## Scope

Version 5 is intended as a practical diagnostic capture tool for intermittent Windows network slowdowns.

It does not:

- modify network settings
- disable security software
- restart services
- reset network adapters
- change DNS servers
- flush DNS caches
- terminate processes
- alter firewall rules
- automatically identify the root cause
- capture packet contents

For deeper investigation, tools such as Microsoft Sysinternals TCPView, Process Explorer, Autoruns, Windows Performance Monitor, or Wireshark may still be useful.

## Version progression

- **v1** - basic ping, DNS, HTTPS, and WinHTTP proxy capture
- **v2** - adds current-user proxy and PAC/autodetect information
- **v3** - adds detailed adapter, routing, DNS, HTTPS timing, connection, and process-correlation data
- **v4** - adds dedicated DNS/TCP timing, gateway testing, adapter statistics, Wi-Fi link information, and multiple Internet test hosts
- **v5** - adds LAN-vs-Internet testing, per-resolver DNS timing, driver metadata, service/process discovery, system-performance capture, and two-snapshot connection/adapter deltas

## License

This project is licensed under the MIT License.
