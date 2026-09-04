# Windows Internet Slowdown Diagnostic Capture

A small Windows batch script for capturing basic network diagnostics when an Internet connection feels slow or unreliable.

The script is intended for intermittent problems where a user may report that websites or Internet-connected applications feel slow even though the computer otherwise appears healthy. It gives a non-technical user a simple way to collect several useful network checks in one text file for later review.

## What v1 checks

Version 1 performs five read-only tests:

1. **Raw IP connectivity** - Pings `1.1.1.1` 20 times to check basic Internet reachability, latency, and packet loss.
2. **Hostname connectivity** - Pings `www.google.com` 20 times to combine name resolution with a connectivity test.
3. **DNS resolution** - Runs `nslookup` against `www.google.com` using the system's configured DNS resolver.
4. **HTTPS connectivity** - Uses `curl` to make an HTTPS request and records the returned HTTP status code.
5. **WinHTTP proxy configuration** - Runs `netsh winhttp show proxy` to show whether WinHTTP is configured to use a proxy.

The script does not change network settings.

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
4. Wait for all five tests to finish.
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

The WinHTTP proxy section shows whether Windows' WinHTTP subsystem is configured for direct access or a proxy server. Version 1 does not inspect every possible browser, VPN, firewall, or security-software configuration.

## Privacy

Diagnostic logs should be reviewed before they are posted publicly or shared outside the organization. Network diagnostic output can reveal information about the system's network configuration, DNS provider, public test destinations, and proxy settings.

This version intentionally records only the HTTP status from the HTTPS test rather than saving full HTTP response headers.

## Scope

This is intentionally a small first version. It provides a quick baseline rather than a full Windows network audit.

Later versions can add additional proxy checks, adapter configuration, routing information, IPv4/IPv6 comparisons, connection timing, and other troubleshooting data.

## License

This project is licensed under the MIT License.
