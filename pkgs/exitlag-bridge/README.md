# ExitLag Bridge trial on Fenrir

This package adapts Cheaux/exitlag-bridge 0.4.0-alpha.2 for NixOS. It uses
checksum-pinned release DLLs and Wine 11.17 Staging, builds the native routing
helper from the corresponding release source, and replaces its absolute nft
path. Python, shell tools, dynamic Wine dependencies and the protected program
root are adapted to NixOS. The sticky, root-owned `/nix/store` parent is allowed
by the supervisor; the package directories themselves must remain root-owned
and unwritable by other users.

Fenrir does not enable the setuid pkexec wrapper. Routing authorization uses
`sudo -A` with a KDialog password prompt instead; sudo receives the password
directly through its askpass interface.

The launcher normalizes Wine's process-list encoding and requires three
consecutive missing-client checks before stopping routing. After a client exit
it returns to the visible launcher with a stopped status. The local desktop
entry must point to `~/.local/bin/exitlag-bridge`, rather than a previous Nix
store version cached by Plasma. Refresh Plasma's application cache with
`kbuildsycoca6 --noincremental` after replacing that entry.

It is installed locally for this trial, without changing the system generation.
The launcher is `~/.local/bin/exitlag-bridge` and appears as **ExitLag Bridge** in
the application menu. The package GC root is
`~/.local/share/exitlag-bridge-package`. Private state, account data and logs stay
under `~/.local/share/exitlag-bridge` with user-only permissions.

## Build

From the nix-config repository:

```sh
nix build --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    pkgs = import f.inputs.nixpkgs { system = "x86_64-linux"; };
  in import ./pkgs/exitlag-bridge { inherit pkgs; }
' --out-link "$HOME/.local/share/exitlag-bridge-package"
```

Wine uses a private copy so the bridge can install its patched WMI DLL. Scanner,
camera, smart-card, ISDN, OpenCL, packet-capture and legacy FFmpeg 4 Wine drivers
are omitted. Steam's Proton and game prefix are not modified.

## Finish setup and try Aion 2

1. Complete the official vendor wizard using `C:\ExitLag`. Review its terms,
   leave **Launch ExitLag** unchecked, and dismiss the expected NDIS driver
   installation warning if it appears.
2. Wait for the setup supervisor to finish installing and checking the bridge.
   `systemctl --user status exitlag-bridge-setup` shows an ongoing setup;
   `~/.local/share/exitlag-bridge/setup-status.json` records its final result.
3. Open **ExitLag Bridge**. Authorize the routing helper in the system dialog,
   then sign in directly in ExitLag. Select Aion 2 and apply a route.
4. Launch Aion 2 through Steam after applying the route so it establishes fresh
   TCP connections. No Steam launch options are needed.
5. Close ExitLag to stop routing. The supervisor watches the launcher lease and
   removes its dedicated `inet exitlag` nftables table when the session ends.

The private game mapping points to Steam app 3393110's prefix:

```text
wineprefix:/mnt/games/SteamLibrary/steamapps/compatdata/3393110/pfx<TAB>S:\steamapps\common\AION2\Aion2\Binaries\Win64\AION2.exe
```

The actual map uses a literal tab. This identity follows the `s:` drive in the
game's prefix. The private ExitLag prefix also has `dosdevices/s:` pointing to
`/mnt/games/SteamLibrary`. If ExitLag does not recognize that identity, adjust it through
**Configure games** to the executable path its game profile recognizes.

Client startup or game detection alone does not prove relay traffic.
Inspect `/run/exitlag-bridge-1000/backend.log` as root for
actual redirects, then test a stable gameplay session. Local client diagnostics
are in `~/.local/share/exitlag-bridge/client.log`; keep account state private.

### Trial result, 2026-11-19

Package build, fresh Wine/WMI initialization, official client installation and
login succeeded with ExitLag 5.24.0. The **Aion 2 Global** profile recognized
world connections. The server-list connection on TCP 13700 and startup HTTPS
connections stayed direct; world connections on TCP 13328 received an active
DNAT to ExitLag's local proxy. The game/proxy sockets and ExitLag relay sockets
showed bytes moving in both directions.

Gameplay was unstable: world connections repeatedly restarted at roughly
five-second intervals while the helper and client remained running. After
stopping the launcher/routing helper, the user confirmed direct gameplay was
stable. This establishes detection and actual relay transport, not working
gameplay compatibility. The exact cause within the bridge, Wine client, relay
selection or game session handling remains unresolved. Routing was left off;
the local package and launcher remain available for an explicit further trial.

An [offline cause investigation](INVESTIGATION.md) identifies Windows-side
socket ownership/connection cleanup as the leading hypothesis. This has not
been confirmed by a capture of the Aion disconnect. ExitLag stays stopped.

## Remove the trial

Quit ExitLag Bridge and any installer first. Remove the local launcher and
desktop entry, then the package GC root. Preserve private account state unless
you explicitly want to delete it:

```sh
rm "$HOME/.local/bin/exitlag-bridge"
rm "$HOME/.local/share/applications/exitlag-bridge.desktop"
rm "$HOME/.local/share/exitlag-bridge-package"
```

Upstream: https://github.com/Cheaux/exitlag-bridge
