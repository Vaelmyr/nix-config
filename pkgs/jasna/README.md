# Jasna (AMD)

Packages the official Jasna 0.12.3 Linux AMD release in an FHS environment.
The release bundles its own Python and ROCm libraries. Nixpkgs' AMF 1.4.37 is used
for video decoding and encoding; no AMD installer or replacement
kernel driver is needed on the host.

The FHS environment also supplies a compiler and explicitly passes Nix's C/C++
header paths to AMD COMGR for MIOpen's runtime GPU kernel compilation.
An application-specific fontconfig file exposes CustomTkinter's bundled fonts,
including its shapes font, without relying on NixOS scanning `~/.fonts`.

## Run

Fenrir includes `jasna` through `modules/nixos/packages.nix`. After rebuilding,
launch **Jasna** from the application menu or run `jasna` in a terminal.

To install for the current user before a system rebuild:

```sh
nix profile add 'path:.#nixosConfigurations.fenrir.pkgs.jasna'
```

Once the system rebuild provides it through Home Manager, the temporary profile
entry can be removed with `nix profile remove jasna`.

On first launch, the launcher copies the release into
`${XDG_DATA_HOME:-$HOME/.local/share}/jasna/0.12.3`, using filesystem reflinks
where supported. Jasna needs writable files beside its executable for models,
compiled kernels and settings. Each release uses a separate directory; old
release directories are retained. The download is about 3.6 GB and the unpacked
release about 12 GB.

## AMD support

Upstream lists Radeon RX 6000 as experimental and untested. Use **BasicVSR++**
on these cards; LTX requires RX 7000/9000. Fenrir's Navi 21 GPU is `gfx1030`,
which is included in this release's ROCm kernel packs. Jasna identifies the card
as an RX 6900 XT. Upstream's recommended AMF 26.20 failed to initialize its PAL
encoder on this card; Nixpkgs' older AMF successfully encoded H.264.

See the [upstream requirements](https://github.com/Kruk2/jasna#what-you-need).
Supporter models require a separately obtained upstream license.

## Validation

On Fenrir, the package build and NixOS configuration evaluation passed. A
24-frame synthetic H.264 video completed with GPU RF-DETR detection,
BasicVSR++ initialization, AMF decoding and AMF encoding; `ffprobe` confirmed
24 output frames at 320x240. This checks the processing pipeline, not restoration
quality on actual mosaics.
The GUI font probe passed, and the main window and first-run system-check
wizard opened successfully.

## Update

Update the release version and both archive hashes in `default.nix` together.
The `.part000` and `.part001` assets form one concatenated Zstandard archive.
Keep the release's libraries and RPATHs intact: its frozen executable checks
the installation at startup. Check upstream's required AMF version when updating.
