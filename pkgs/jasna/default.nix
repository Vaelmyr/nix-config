{ lib, stdenv, stdenvNoCC, glibc, fetchurl, zstd, buildFHSEnv, writeShellScript
, makeDesktopItem, writeText }:

let
    version = "0.12.3";
    archives = [
        (fetchurl {
            url = "https://github.com/Kruk2/jasna/releases/download/v${version}/jasna-linux-amd-${version}.tar.zst.part000";
            hash = "sha256-MtWkEqda7K7xbdDkQwHJP8LLY/9ZZgZlJyKRu5jBDRI=";
        })
        (fetchurl {
            url = "https://github.com/Kruk2/jasna/releases/download/v${version}/jasna-linux-amd-${version}.tar.zst.part001";
            hash = "sha256-PbVXNeJbKDdbTlapnzDzLfcui497gnbv1S+MMavxq/o=";
        })
    ];
    bundle = stdenvNoCC.mkDerivation {
        pname = "jasna-amd-bundle";
        inherit version;
        nativeBuildInputs = [ zstd ];
        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;
        # Preserve the release's bundled ROCm/Python library layout and RPATHs.
        dontFixup = true;
        installPhase = ''
            mkdir -p "$out/lib/jasna"
            cat ${lib.escapeShellArgs (map toString archives)} | \
                tar --zstd -x -C "$out/lib/jasna" --strip-components=1
        '';
    };
    desktopItem = makeDesktopItem {
        name = "jasna";
        desktopName = "Jasna";
        comment = "GPU video restoration (AMD)";
        exec = "jasna";
        icon = "jasna";
        categories = [ "AudioVideo" "Video" ];
    };
    # CustomTkinter copies fonts into ~/.fonts, which NixOS does not scan by
    # default. Expose the bundled fonts directly, within Jasna's font config.
    fontConfig = writeText "jasna-fonts.conf" ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
            <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
            <dir>${bundle}/lib/jasna/customtkinter/assets/fonts</dir>
        </fontconfig>
    '';
in
buildFHSEnv {
    pname = "jasna";
    inherit version;

    targetPkgs = pkgs: with pkgs; [
        # Nixpkgs' AMF 1.4.37 supports Fenrir's RX 6900 XT. AMF 26.20's PAL
        # fails to initialize this card even though its library loads.
        amf
        stdenv.cc
        stdenv.cc.cc.lib
        zlib openssl cacert libdrm numactl pciutils util-linux
        libGL vulkan-loader ocl-icd
        libX11 libXext libXrender libXrandr libXcursor libXi libxcb
        libxkbcommon fontconfig freetype dbus glib
        alsa-lib pulseaudio vlc tcl tk
        coreutils bash
    ];

    # HIPRTC compiles MIOpen kernels at runtime. It ignores CPLUS_INCLUDE_PATH
    # and cannot discover Nix's C/C++ headers through conventional system paths.
    profile = ''
        export AMD_COMGR_DRIVER_OPTIONS_APPEND="-isystem ${stdenv.cc.cc}/include/c++/${stdenv.cc.cc.version} -isystem ${stdenv.cc.cc}/include/c++/${stdenv.cc.cc.version}/${stdenv.hostPlatform.config} -isystem ${lib.getDev glibc}/include''${AMD_COMGR_DRIVER_OPTIONS_APPEND:+ $AMD_COMGR_DRIVER_OPTIONS_APPEND}"
    '';

    runScript = writeShellScript "jasna-launcher" ''
        set -euo pipefail
        data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/jasna"
        # Each release needs a clean directory. The full bundle must be writable:
        # frozen Jasna resolves model_weights relative to its executable.
        install_dir="$data_dir/${version}"
        mkdir -p "$data_dir"
        exec 9>"$data_dir/.install.lock"
        flock 9
        if [ ! -f "$install_dir/.nix-bundle-ready" ]; then
            staging=$(mktemp -d "$data_dir/.${version}.XXXXXX")
            trap 'rm -rf "$staging"' EXIT
            cp -a --reflink=auto ${bundle}/lib/jasna/. "$staging/"
            chmod -R u+w "$staging"
            touch "$staging/.nix-bundle-ready"
            mv -T "$staging" "$install_dir"
            trap - EXIT
        fi
        flock -u 9
        exec 9>&-
        export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
        export FONTCONFIG_FILE=${fontConfig}
        exec "$install_dir/run_jasna_amd.sh" "$@"
    '';

    extraInstallCommands = ''
        mkdir -p "$out/share/applications"
        cp ${desktopItem}/share/applications/jasna.desktop "$out/share/applications/"
        install -Dm644 ${bundle}/lib/jasna/assets/jasna-logo.png \
            "$out/share/icons/hicolor/512x512/apps/jasna.png"
    '';

    meta = {
        description = "GPU video restoration tool (official AMD release)";
        homepage = "https://github.com/Kruk2/jasna";
        # The official bundle includes private protection code and model weights.
        license = lib.licenses.unfree;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "x86_64-linux" ];
        mainProgram = "jasna";
    };
}
