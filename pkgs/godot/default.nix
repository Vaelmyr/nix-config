{ lib, stdenv, callPackage, godot, dotnetCorePackages, fetchFromGitHub, fetchurl }:

let
    release = import ./preview;

    previewAttrs = attrs: attrs // {
        env = (attrs.env or { }) // {
            GODOT_VERSION_STATUS = lib.last (lib.splitString "-" release.version);
        };
        meta = (attrs.meta or { }) // {
            changelog = "https://github.com/godotengine/godot-builds/releases/tag/${release.version}";
        };
    } // lib.optionalAttrs (attrs ? sconsFlags) {
        # 4.8-dev7 needs OpenXR headers newer than those in the pinned nixpkgs.
        sconsFlags = attrs.sconsFlags ++ [ "builtin_openxr=true" ];
    };

    # Reuse nixpkgs' source build, desktop integration, .NET wrapper and tests.
    preview = godot.override {
        inherit (release) version hash;
        inherit (release.default) exportTemplatesHash;

        updateScript = [ ./update.sh "preview" "pkgs/godot/preview/default.nix" ];

        # Apply the preview status to the editor and source export templates.
        stdenv = stdenv // {
            mkDerivation = args: (stdenv.mkDerivation args).overrideAttrs previewAttrs;
        };

        # Build the exact source commit used for the published preview release.
        fetchFromGitHub = args: fetchFromGitHub (
            builtins.removeAttrs args [ "tag" ] // { rev = release.rev; }
        );

        # Apply the preview URL to wrapped and unwrapped editor templates.
        callPackage = path: args: callPackage path (args //
            lib.optionalAttrs (builtins.baseNameOf path == "export-templates-bin.nix") {
                fetchurl = fetchArgs: fetchurl (fetchArgs // {
                    url = lib.replaceStrings [ "godot/releases" ] [ "godot-builds/releases" ] fetchArgs.url;
                });
            }
        );

        # common.nix selects SDK 8 internally; 4.8-dev7 needs SDK 10.
        dotnetCorePackages = dotnetCorePackages // {
            sdk_8_0-source = dotnetCorePackages.sdk_10_0-source;
            sdk_9_0-source = dotnetCorePackages.sdk_10_0-source;
        };
    };
in
lib.recurseIntoAttrs rec {
    godot = preview;
    godot-mono = godot.override {
        withMono = true;
        inherit (release.mono) exportTemplatesHash nugetDeps;
    };

    export-template = godot.export-template;
    export-template-mono = godot-mono.export-template;
    export-templates-bin = godot.export-templates-bin;
    export-templates-mono-bin = godot-mono.export-templates-bin;
}
