# A2Tools DPS Meter

The package repackages upstream's native Linux binary for NixOS. Fenrir enables
it with `programs.a2tools-dps-meter.enable = true;` in `hosts/fenrir/default.nix`.
The imported module installs the desktop launcher and grants only `CAP_NET_RAW`
through a NixOS security wrapper. No manual `setcap` is needed.

From the configuration repository, install with:

```sh
sudo nixos-rebuild switch --flake path:.#fenrir
```

Launch **A2Tools DPS Meter** from KDE/KRunner, or run `a2tools-dps-meter`.
Use `GDK_BACKEND=x11 a2tools-dps-meter` for upstream's XWayland click-through
support. Start AION 2 under Proton in borderless or windowed mode.

To remove the installation and capture permission, change the enable option to
`false` and run the same rebuild command. Settings and fight history under
`~/.local/share/com.a2tools.dps-meter/` are preserved.

## Updates

Update `version` and `src.hash` in `default.nix`, then rebuild. Upstream publishes
the Debian download through a rolling `latest` URL, so a fresh build of the old
pin can fail its checksum after an upstream release. Download the current file,
inspect its version with `dpkg-deb -f`, and calculate its hash with `nix hash file`
before updating both values. Do not use the app's package-manager updater on NixOS.

Validate the package without activating the system:

```sh
nix build --no-link 'path:.#nixosConfigurations.fenrir.pkgs.a2tools-dps-meter'
```

Upstream documentation: <https://github.com/taengu/A2Tools-DPS-Meter/blob/main/docs/linux.md>

## Local Cube Nearby plugin

[Cube Nearby](plugins/cube-nearby/README.md) adds Hidden Cube alerts, world
coordinates and an estimated compass direction using your last reported
position. Load `plugins/cube-nearby` through **Settings → Plugins → Plugin
developer mode → Load plugin folder…**. No NixOS rebuild is required.
