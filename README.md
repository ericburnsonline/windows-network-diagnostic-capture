# Windows Internet Slowdown Diagnostic Capture

A small Windows batch script for capturing basic network diagnostics when an Internet connection feels slow or unreliable.

The script is intended for intermittent problems where a user may report that websites or Internet-connected applications feel slow even though the computer otherwise appears healthy. It gives a non-technical user a simple way to collect several useful network checks in one text file for later review.

## What v2 checks

Version 2 performs six read-only tests:

1. **Raw IP connectivity** - Pings `1.1.1.1` 20 times to check basic Internet reachability, latency, and packet loss.
2. **Hostname connectivity** - Pings `www.google.com` 20 times to combine name resolution with a connectivity test.
3. **DNS resolution** - Runs `nslookup` against `www.google.com` using the system's configured DNS resolver.
4. **HTTPS connectivity** - Uses `curl` to make an HTTPS request and records the returned HTTP status code.
5. **WinHTTP proxy configuration** - Runs `netsh winhttp show proxy`.
6. **Current-user proxy configuration** - Reads the Windows Internet Settings values for:
   - `ProxyEnable`
   - `ProxyServer`
   - `AutoConfigURL`
   - `AutoDetect`

The script does not change network settings.

## What's new in v2

Version 1 checked only the WinHTTP proxy configuration.

Version 2 adds the current user's Windows Internet Settings proxy values. This helps identify proxy configurations used by Windows applications and browsers, including an explicitly configured proxy server or a proxy auto-configuration (PAC) URL.

Version 2 remains intentionally lightweight. More detailed adapter, routing, connection, DNS, IPv4/IPv6, and timing diagnostics are outside the scope of this release.

## Requirements

- Windows 10 or later
- Windows PowerShell
- No administrator privileges are required
- `curl` is optional. If it is unavailable, the script records that fact and continues with the remaining tests.

Modern Windows 10 and Windows 11 installations normally include `curl`.

## Usage

1. Download `internet-slowdown-diagnostic.bat`.
2. Place it somewhere the user can easily find, such as the Desktop.
3. When the Internet connection feels slow, double-click the batch file.
4. Wait for all six tests to finish.
5. Press a key when prompted to close the window.
6. Open the `NetworkDiagnostics` folder created next to the batch file.
7. Send the corresponding `.txt` file to the person troubleshooting the problem.

Each run creates a new timestamped log, for example:

```text
Internet_Diagnostic_2026-09-03_16-45-30.txt
```

Existing logs are not overwritten.

## Configuring the test targets

The default targets are defined near the top of the batch file:

```bat
set "PING_TARGET=1.1.1.1"
set "TEST_HOST=www.google.com"
```

They can be changed before deployment if different public test targets are preferred.

## Interpreting the results

The script is designed primarily to capture evidence while a problem is happening.

A successful ping to `1.1.1.1` with low latency and no packet loss suggests that basic IP connectivity is working. If that test succeeds but hostname-based tests fail or pause, DNS becomes more interesting.

The HTTPS test provides a simple application-layer check. An HTTP status code confirms that the system was able to resolve the hostname, establish a connection, negotiate HTTPS, and receive an HTTP response.

### Proxy results

The WinHTTP section shows whether the Windows WinHTTP subsystem is configured for direct access or a proxy server.

The current-user proxy section reports Windows Internet Settings values:

- `ProxyEnable` - whether an explicit proxy is enabled for the current user
- `ProxyServer` - the configured proxy server, if present
- `AutoConfigURL` - the configured PAC file URL, if present
- `AutoDetect` - the Windows automatic proxy-detection setting, when defined

These checks improve proxy visibility but do not prove that all traffic bypasses third-party VPN, firewall, antivirus, endpoint-security, or network-filtering software.

## Privacy

Diagnostic logs should be reviewed before they are posted publicly or shared outside the organization.

Version 2 may record a configured proxy hostname, IP address, port, or PAC URL. Those values may reveal internal infrastructure details.

The script does **not** collect browser history, credentials, cookies, or page content. The HTTPS test records only the HTTP status code rather than full response headers.

## Scope

Version 2 is intentionally a small incremental release focused on improved proxy detection.

It does not collect detailed network adapter configuration, routing tables, active connections, process lists, filter bindings, DNS-server comparisons, or separate IPv4/IPv6 timing data.

## License

This project is licensed under the MIT License.
