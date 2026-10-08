# OrcaSlicer

This package wraps the official Linux AppImage. The source build in the pinned
nixpkgs crashes inside the proprietary Bambu network plugin (`std::locale`),
including during login.

The upstream launcher sets `LC_ALL=C`; the Nix wrapper supplies the system CA
bundle and GIO TLS backend. Existing profiles in `~/.config/OrcaSlicer` are reused.

To update, change `version` and the AppImage `hash` in `default.nix`.

Home Manager registers OrcaSlicer for `orcaslicer://`, `bambustudio://` and
`bambustudioopen://` links. Fenrir allows Bambu discovery announcements on UDP
1990/2021 from `192.168.1.0/24`.
