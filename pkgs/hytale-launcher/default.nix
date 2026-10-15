{ lib, stdenvNoCC, fetchurl, unzip, buildFHSEnv, writeShellScript, makeDesktopItem }:

let
    version = "2026.10.09-4e41671";
    launcher = stdenvNoCC.mkDerivation {
        pname = "hytale-launcher-unwrapped";
        inherit version;

        # Version and checksum from https://launcher.hytale.com/version/release/launcher.json.
        src = fetchurl {
            url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-${version}.zip";
            hash = "sha256-7VKqz2ymQLvgBLbq5pmVju7cX8E+r5EgtY48Mk5dnf8=";
        };

        nativeBuildInputs = [ unzip ];
        unpackPhase = ''
            runHook preUnpack
            # Upstream prepends metadata; unzip returns 1 after successful extraction.
            unzip "$src" || [ "$?" -eq 1 ]
            runHook postUnpack
        '';
        dontBuild = true;
        dontPatchELF = true;
        dontStrip = true;

        installPhase = ''
            runHook preInstall
            install -Dm755 hytale-launcher "$out/lib/hytale-launcher"
            runHook postInstall
        '';
    };

    desktopItem = makeDesktopItem {
        name = "hytale-launcher";
        desktopName = "Hytale Launcher";
        comment = "Official launcher for Hytale";
        exec = "hytale-launcher %U";
        categories = [ "Game" ];
        startupWMClass = "com.hypixel.HytaleLauncher";
    };
in
buildFHSEnv {
    name = "hytale-launcher";
    inherit version;

    targetPkgs = pkgs: with pkgs; [
        # Launcher UI and HTTPS.
        webkitgtk_4_1 gtk3 glib gdk-pixbuf libsoup_3 cairo pango
        at-spi2-atk harfbuzz glib-networking cacert libsecret
        # Game graphics, input and audio.
        libGL libGLU libglvnd mesa vulkan-loader egl-wayland
        libx11 libxcomposite libxdamage libxext libxfixes libxrandr
        libxcursor libxi libxcb libxscrnsaver libxinerama libxxf86vm
        wayland libxkbcommon libdecor alsa-lib pipewire pulseaudio
        # Game and bundled .NET/JRE runtime dependencies.
        dbus fontconfig freetype glibc nspr nss systemd zlib
        stdenv.cc.cc.lib icu openssl krb5
        coreutils xdg-utils
    ];

    runScript = writeShellScript "hytale-launcher-wrapper" ''
        set -eu
        launcher_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/Hytale"
        launcher_bin="$launcher_dir/hytale-launcher"
        hash_file="$launcher_dir/.bundled_hash"
        bundled_bin="${launcher}/lib/hytale-launcher"

        mkdir -p "$launcher_dir/.nix-tmp"
        bundled_hash=$(sha256sum "$bundled_bin" | cut -d ' ' -f1)

        # Keep the running binary writable so upstream can update itself.
        if [ ! -x "$launcher_bin" ] || [ ! -f "$hash_file" ] ||
           [ "$(cat "$hash_file")" != "$bundled_hash" ]; then
            install -m755 "$bundled_bin" "$launcher_bin"
            printf '%s\n' "$bundled_hash" > "$hash_file"
        fi

        # Updates must be staged on the same filesystem as the launcher.
        unset XDG_CACHE_HOME
        export TMPDIR="$launcher_dir/.nix-tmp"
        export GIO_MODULE_DIR=/usr/lib/gio/modules
        export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
        export WEBKIT_DISABLE_COMPOSITING_MODE=1
        export WEBKIT_DISABLE_DMABUF_RENDERER=1
        export __NV_DISABLE_EXPLICIT_SYNC=1

        exec "$launcher_bin" "$@"
    '';

    extraInstallCommands = ''
        mkdir -p "$out/share/applications"
        cp ${desktopItem}/share/applications/* "$out/share/applications/"
    '';

    meta = {
        description = "Official launcher for Hytale";
        homepage = "https://hytale.com";
        license = lib.licenses.unfree;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "x86_64-linux" ];
        mainProgram = "hytale-launcher";
    };
}
