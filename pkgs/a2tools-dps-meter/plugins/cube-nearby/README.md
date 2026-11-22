# Cube Nearby 0.2.0

Local A2Tools DPS Meter plugin for AION 2. Alerts when the game sends a known
Hidden Cube object, shows its world X/Y/Z position, and shows a map-oriented
compass arrow, approximate planar distance and height difference when your own
position is available. Requires A2Tools 2.0.62+ (plugin API 2); developed against
the 2.0.99 installation and current upstream host/SDK source.

## Load it

1. In A2Tools, open **Settings → Plugins** and enable **Plugin developer mode**.
2. Choose **Load plugin folder…** and select this directory:

   `/home/vaelmyr/Projects/Personal/nix-config/pkgs/a2tools-dps-meter/plugins/cube-nearby`

3. Open **Cube Nearby**. Keep it enabled; it can raise its panel when a new cube
   arrives. After editing its files, use **Check for updates** to reload.
   Version 0.2.0 adds the `widgets` permission for its floating compass.

No NixOS rebuild or packet logging is required. Only objects received after the
plugin is loaded are detected; enter the zone again or move away and return to
receive an already nearby cube. The banner says **Unreviewed plugin**, since
this is a local developer plugin. Remove its folder from the developer plugin
list to unload it. It is not submitted to the official catalog.

## Reading the panel

- **Floating compass:** enabled by default and shown while a cube is actively
  detected. In **Options & status**, choose **Move overlay**, drag the compass
  where you want it, then tick **Lock overlay (click-through)**. Locking lets
  clicks pass through to the game. The meter remembers its placement. Disable
  **Floating compass overlay** to hide it. It closes when the cube is opened,
  removed, or goes out of view; remembered coordinates stay in the panel.
- **Opened this session:** counts your completed cube-key openings since this
  plugin page loaded or you last pressed **Reset count**. Map/character changes
  and clearing sightings do not reset it. Reloading the plugin or restarting
  the meter starts a new session. Old buffered openings and duplicate events
  do not count. An opening still counts if its spawn preceded plugin loading.

- The arrow is relative to **map north**, not your character or camera. The
  default north is world **−Y**; this mapping needs an in-game check. In
  **Options & status**, change **Map north** to match the map if needed.
- Distances use 100 world units per metre. They are estimates based on your
  **last reported position**, not continuous movement tracking. Positions
  update on self buffs, some skills/hits, map loads and teleports. Cast a self
  buff to obtain a fresh fix. After eight seconds the arrow dims and the panel
  explicitly marks the direction/distance as based on the last fix.
- World coordinates are raw game coordinates, not the game's map-grid labels.
  Cube coordinates remain useful without a player fix. There is no camera
  heading or screen projection in this plugin. Camera-relative guidance needs
  a separate minimap screen reader or a new host API. This version remains
  plugin-only as requested; no helper or screen capture is added.
- **Out of view** remembers a cube the server stopped streaming; it does not
  mean the cube is still there. After two minutes without another spawn, an
  active sighting is marked **Last seen**. Sightings expire after ten minutes,
  or clear on map load, teleport, character change, game close, or **Clear
  sightings**. Opening or removal ends the nearby alert.

## Detection and permissions

Built-in templates:

| ID | Evidence |
| --- | --- |
| 1301199 | User-labeled capture, 2026-11-19 near Tranein Highland / Munin's Bridge: spawn 19:42:11.496, opening 19:42:20.447, completion 19:42:24.646, loot, removal 19:42:25.345 (Europe/Rome). |
| 1200039, 1200041 | Verteron cube types corroborated by the external Cube Radar project; not encountered in this local capture. |

An unknown object's template is learned only after your own `3A 36` completion
has count 1 and item 630900003, the observed cube-key signature. The template
is saved through the SDK and can alert on subsequent sightings. Other cube
variants are not guaranteed to be detected on the first encounter.

Manifest decoders read object spawns/removals, your own object interactions,
map/teleport records and your own position from buffs/skills. All position
decoders that name an actor use the host's `self` filter. Buff variants are
checked against their flags before accepting coordinates. Non-self teleports
and invalid positions are ignored. No network, memory reading, injection,
automation, file access or other players' movement decoder is used.

Storage holds preferences and learned template IDs; sightings and the session
count are only in memory. Notifications/window permission provide alerts;
widgets permission provides the floating compass. The frame stays within
A2Tools' standard plugin sandbox.

## Verification

From the repository root:

```sh
nix shell nixpkgs#nodejs --command node --test pkgs/a2tools-dps-meter/tests/*.test.cjs
```

Tests decode the actual captured encounter using the manifest, including the
self filter, and verify position updates, cube detection, opening/removal,
unknown-template learning, stale fixes, replay-notification suppression, map
reset, character reset and malformed/other-player data. Capture fixtures contain
only the small numeric object/position records needed for these checks.

Offline replay and host/catalog schema checks do not establish live operation.
Live checks: load the folder, use a self buff, approach a new cube, confirm the
panel and coordinates, align map north, and open it to confirm the alert clears.

Validation on 2026-11-19: the user confirmed version 0.1.0 works in-game.
Version 0.2.0 passed all 15 tests, including the full private capture replay
(175,898 decoded frames, two known cube sightings), session count/reset and
overlay lifecycle/race checks. Upstream's catalog validator accepted its
manifest and bundle. DOM harnesses using the actual A2Tools SDK passed panel
and widget event flow, position text, counting/reset, drag/lock, and stale/empty
states. The new floating widget's native placement and click-through behavior
remain to be checked in-game; browser/native-app control was unavailable.

Protocol references (consulted 2026-11-19):

- https://github.com/taengu/A2Tools-Plugins/blob/main/CONTRIBUTING.md
- https://github.com/taengu/A2Tools-DPS-Meter/blob/main/src-tauri/src/plugins/decoder.rs
- https://github.com/taengu/A2Tools-DPS-Meter/blob/main/src-tauri/src/capture/abnormal.rs
- https://github.com/dr89mh/aion2-cube-radar/blob/main/config/cubes.json
- https://github.com/dr89mh/aion2-cube-radar/blob/main/docs/FINDINGS.md

License: GPL-3.0-only.
