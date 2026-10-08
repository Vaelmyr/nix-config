# Updating Godot previews

From the repository root, update to the newest Godot 4 preview with both standard
and Mono export templates:

```sh
./pkgs/godot/update.sh
```

Or select a specific published release:

```sh
./pkgs/godot/update.sh preview pkgs/godot/preview/default.nix 4.8-dev7
```

Requires Nix; the script loads its tools automatically from the pinned nixpkgs.
It updates `preview/default.nix` and `preview/deps.json`, then evaluates both
editor packages. If the version is already current, it exits without changes.

Updates happen in place. If a command fails, earlier edits remain; restore the
release files to their previous state before retrying.
