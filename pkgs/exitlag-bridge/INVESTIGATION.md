# Aion 2 reconnect loop: offline investigation

Date: 2026-11-19. ExitLag remained stopped throughout this investigation. No
server probes, Wine/client launches, game restarts, routing changes or game-prefix
changes were performed. The user's direct gameplay continued.

## Finding

The leading explanation is a mismatch between the external Proton socket owner
and ExitLag's Windows-side connection bookkeeping. Initial identity translation
works, but it does not create a corresponding Windows game process/socket in
ExitLag's separate Wine prefix. The installed ExitLag client contains a cleanup
path that compares tracked connections against Windows TCP ownership and closes
connections absent from that inventory as zombies.

This is a **specific, evidence-backed hypothesis**, not a proven execution trace
of the Aion failure. No packet capture was taken during the trial, so we cannot
yet establish whether ExitLag, a relay or the game server initiated each close.
The retry spacing alone does not prove which timer or code path fired.

## Evidence from this machine

- Real Aion world connections received `DNAT armed; ACCEPT (active)`, with the
  correct Aion identity and a local ExitLag proxy target. This rules out a
  complete detection/mapping/redirect failure.
- The saved socket sample showed matching application/proxy counters: 1,255
  bytes from Aion and 46,032 bytes back through the local proxy, plus sent and
  received bytes on ExitLag's relay connections. This rules out a complete
  one-way black hole, but not corruption, later packet loss or a protocol error.
- Saved backend excerpts show world-connection requests at 18:57:33.132,
  18:57:38.111, 18:57:43.118 and 18:57:48.120 Europe/Rome time. Intervals were
  4.979, 5.007 and 5.002 seconds. These are **retry intervals**, not measured
  connection lifetimes.
- The user confirmed stable direct gameplay after routing stopped.
- The user-readable shim lifecycle log records one control connection at
  18:46:48.017 and its acknowledgement at 18:46:48.018, without an IPC disconnect
  during the subsequent Aion reconnect loop. The helper/client remained alive.
  The five-second shim control-channel timeout therefore does not fit the
  observed failure; it is not a five-second lifetime for game sockets.
- ExitLag.exe still has SHA-256
  `9baa794c84c5a90f1b2c84130877ba8ae5a8b1867ece00866dd3b03d0eccc106`,
  matching the upstream 5.24.0 review. This is not an unexplained updater drift.
  An offline PE import/export check passed: two client modules require 20 nfapi
  exports and the installed shim provides all 20. This does not prove behavioral
  ABI compatibility.

The full root-owned backend log was not reopened with an interactive password
prompt while the user was playing. Timing and redirect observations above use
the excerpts already read during the trial; the shim log and binary checks were
read again during this offline investigation.

## Concrete implementation gap

In the checksum-pinned `v0.4.0-alpha.2` source used for this package:

1. `shim/nfapi/nfapi_stub.cpp::owning_windows_pid()` queries
   `GetExtendedTcpTable` inside ExitLag's Wine prefix.
2. `handle_tcp_connect()` prefers that Windows owner. When none exists, it passes
   the Linux PID and supports a nested name lookup through the native helper.
3. That lookup is enough to obtain a redirect for Aion, but no hook virtualizes
   Windows process enumeration or the original TCP ownership table. Aion runs
   in Steam's separate Proton prefix.
4. Static inspection of the installed, unmodified ExitLag.exe found a Windows
   TCP-table scan and a matching `Closing zombie connection` branch. Relevant
   virtual addresses for this exact binary are:
   - `0x1413606db`: call through the `GetExtendedTcpTable` import at
     `0x146f831e0`;
   - `0x141360860` onward: inspect owning PIDs and construct the local-port
     inventory for tracked processes;
   - `0x141360a54` onward: look up a tracked connection's family/local port;
   - `0x141360ae9`: reference the zombie-connection log message after a miss.

These addresses establish that such a cleanup mechanism exists. They do not
establish that the Aion trial actually took that branch.

The Linux runtime also only forwards TCP connect-request callbacks in its normal
IPC path, whereas Windows process/socket lifecycle information is richer. This
is another compatibility gap to examine if the ownership explanation is not
confirmed; it is not evidence for blindly injecting extra callbacks.

## Comparison with upstream

Upstream records a closely matching Minecraft failure: traffic was relayed,
then a packet capture showed ExitLag itself closing both relay legs and the
local proxy after 4.493 seconds while peers were still delivering data. The
maintainer explicitly leaves its internal cause unproven:

https://github.com/Cheaux/exitlag-bridge/blob/main/docs/pipeline-stages.md

Upstream also documents that ordinary process detection and TCP ownership in
ExitLag's prefix cannot see a game in another Proton/Wine prefix:

https://github.com/Cheaux/exitlag-bridge/blob/main/docs/architecture.md

The stable macOS WoW path uses a Wine-owned socket companion inside the same
prefix, with a real Windows PID and actual Winsock sockets. It does more than
rename a process or translate a filename. That architecture addresses the
missing-ownership boundary and is a plausible basis for a Linux experiment,
but the current adapter is WoW/macOS-specific and is not an Aion fix we can
claim or enable unchanged:

https://github.com/Cheaux/exitlag-bridge/blob/main/macos/README.md

## Alternatives assessed

- **nftables map expiry:** the entries last ten seconds and only establish NAT
  for the initial SYN; conntrack carries the established translation. The code
  does not expire an established game stream after five seconds. No timeout was
  changed on this hypothesis.
- **Missing NDIS driver:** expected and bypassed by this bridge; actual TCP
  redirection and bidirectional bytes demonstrate that it is not the initial
  interception blocker.
- **Missing S: drive:** probes were redirected both before and after adding it
  in the earlier trial, so that addition did not explain or cure the loop.
- **Relay/game protocol rejection, login/world source-IP mismatch or a later
  transport fault:** remain possible. Existing logs do not contain the close
  initiator or application-level reason needed to exclude them.

## Next discriminating check, only after a later trial is authorized

Capture only TCP headers and close/error events for the game-to-proxy and
client-to-relay legs during one short reproduction, with nfapi research tracing
enabled locally. Establish which endpoint sends FIN/RST first and whether the
Windows-side connection is classified as absent/zombie. Avoid collecting game
payloads or credentials. Until then, do not change timeouts, patch the vendor
binary, move ExitLag into the active Steam prefix, or claim a confirmed fix.

If ExitLag-side ownership cleanup is confirmed, investigate a user-owned
socket companion adapted for Linux/Aion, preserving Steam's actual prefix.
Merely launching a dummy AION2.exe would not supply the missing socket ownership.
