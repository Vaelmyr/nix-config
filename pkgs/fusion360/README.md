# Autodesk Fusion on NixOS

This package provides the Lolig4 installer and launcher inside an FHS environment
for upstream's prebuilt `--fusion-wine` runtime. The installer and helper scripts
are pinned to a source commit; Autodesk Fusion and the Wine runtime are downloaded
at runtime and stored in `~/.local/share/Autodesk-Unofficial`.

After rebuilding the configuration, install once from a graphical session:

```sh
fusion360-installer
```

This runs upstream's `--install fusion --fusion-wine`. The `--move` bootstrap is
unnecessary: Nix already provides the installer. The package supplies dependencies
and disables upstream's system package installation. Local Wine/Proton compilation
with `--build` is not supported.

Launch with:

```sh
fusion360
```

Your Linux home is available as drive `H:` in Fusion's file dialogs, including
Documents, Downloads and Projects. The Windows profile and application data stay
inside the Wine prefix. Existing custom `H:` mappings are preserved.

The upstream installer creates application entries and the Autodesk browser login
handler. Both enter the same FHS environment. An Autodesk account and the applicable
Fusion license are still required.

Other installer options can be passed explicitly, for example:

```sh
fusion360-installer --uninstall fusion
```

A rebuild updates the Nix integration, not the Fusion installation in your home.
Fusion and the upstream Wine runner follow their own update mechanisms. The Nix
build can validate the wrapper, but installation, GPU rendering and browser login
must be checked in an interactive graphical session.
