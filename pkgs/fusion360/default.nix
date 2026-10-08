{ lib, stdenvNoCC, fetchFromCodeberg, buildFHSEnv, writeShellScript, winetricks }:

let
    version = "unstable-7da442d";
    resources = stdenvNoCC.mkDerivation {
        pname = "fusion360-installer-resources";
        dontBuild = true;

        inherit version;

        src = fetchFromCodeberg {
            owner = "Lolig4";
            repo = "Autodesk-Fusion-360-on-Linux";
            rev = "7da442d6af5ac2619e5151475d2be54efe6170bc";
            hash = "sha256-wX6YfBtJDLP+O3tnW6PYbQ6BzGb6+bdtrTGnYjTZX4M=";
        };

        installPhase = ''
            runHook preInstall
            mkdir -p "$out/share/fusion360"
            cp -r files LICENSE.md "$out/share/fusion360/"
            installer="$out/share/fusion360/files/setup/autodesk_fusion_installer_x86-64.sh"

            # Keep helper scripts and templates at the same revision as the installer.
            substituteInPlace "$installer" \
                --replace-fail 'REPO_URL="https://codeberg.org/Lolig4/Autodesk-Fusion-360-on-Linux/raw/branch/main"' \
                    "REPO_URL=\"file://$out/share/fusion360\"" \
                --replace-fail 'WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"' \
                    'WINETRICKS_URL="file://${winetricks}/bin/winetricks"' \
                --replace-fail 'install_required_packages() {' 'install_required_packages() {
                echo "Missing dependencies: ''${MISSING_COMMANDS[*]}. Update the Nix package instead of installing system packages." >&2
                exit 1' \
                --replace-fail 'check_and_install_wine() {' 'check_and_install_wine() {
                if [[ "$SELECTED_RUNNER" == --wine ]] && ! command -v wine >/dev/null; then
                    echo "Use --fusion-wine, or provide Wine through Nix." >&2
                    exit 1
                fi' \
                --replace-fail '    local TEMPORARY_FILE="$FILE.part"' '    local TEMPORARY_FILE="$FILE.part"
                if [[ "$FILE_URL" == file://* ]]; then
                    curl -L --fail "$FILE_URL" -o "$FILE" || exit 1
                    return 0
                fi'

            # Desktop launches and browser login callbacks must enter the FHS environment.
            for desktop in "$out/share/fusion360/files/setup/data/.desktop/"*.desktop; do
                sed -i 's/^Exec=/Exec=fusion360 --exec /' "$desktop"
            done

            runHook postInstall
        '';
    };

    dispatch = writeShellScript "fusion360-dispatch" ''
        case "''${1:-}" in
            --help|-h)
                echo "Usage: fusion360 [--installer [INSTALLER_ARGS...] | --exec COMMAND...]"
                echo "Install: fusion360-installer (defaults to --install fusion --fusion-wine)"
                ;;
            --installer)
                shift
                if [ "$#" -eq 0 ]; then set -- --install fusion --fusion-wine; fi
                if [ "''${1:-}" = --move ] || [ "''${1:-}" = --build ]; then
                    echo "--move and --build are not supported by this Nix package." >&2
                    exit 1
                fi
                exec bash ${resources}/share/fusion360/files/setup/autodesk_fusion_installer_x86-64.sh "$@"
                ;;
            --exec)
                shift
                exec "$@"
                ;;
            *)
                if [ ! -s "$HOME/.local/share/Autodesk-Unofficial/logs/active_fusion.log" ]; then
                    echo "Fusion is not installed. Run fusion360-installer first." >&2
                    exit 1
                fi
                exec bash ${resources}/share/fusion360/files/setup/data/autodesk_fusion_launcher.sh fusion "$@"
                ;;
        esac
    '';
in
buildFHSEnv {
    pname = "fusion360";

    inherit version;

    multiArch = true;

    targetPkgs = pkgs: with pkgs; [
        bash cacert coreutils curl wget gnugrep gnused gawk findutils file gettext
        gnutar gzip xz unzip p7zip cabextract samba lsb-release mesa-demos polkit
        systemd bc mokutil xdg-utils desktop-file-utils util-linux msitools procps
        winetricks xterm zenity python3 which
    ];

    multiPkgs = pkgs: with pkgs; [
        alsa-lib cairo dbus fontconfig freetype glib gnutls gtk3 krb5 libGL libGLU
        libcap libpulseaudio libunwind libva ncurses openssl
        libusb1 libx11 libxcomposite libxcursor libxext libxfixes libxi libxinerama
        libxrandr libxrender libxxf86vm libxcb libxkbcommon libxcrypt libdrm mesa
        openal sane-backends SDL2 udev vulkan-loader wayland zlib cups
        gst_all_1.gstreamer gst_all_1.gst-plugins-base
    ];

    runScript = dispatch;

    profile = ''
        export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
        export LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri:/run/opengl-driver-32/lib/dri
        export __EGL_VENDOR_LIBRARY_DIRS=/run/opengl-driver/share/glvnd/egl_vendor.d:/run/opengl-driver-32/share/glvnd/egl_vendor.d
    '';

    extraInstallCommands = ''
        cat > "$out/bin/fusion360-installer" <<EOF_WRAPPER
        #!${stdenvNoCC.shell}
        exec "$out/bin/fusion360" --installer "\$@"
        EOF_WRAPPER
        chmod +x "$out/bin/fusion360-installer"
    '';

    passthru = { inherit resources; };

    meta = {
        description = "Autodesk Fusion installer and launcher using the upstream patched Wine runtime";
        homepage = "https://codeberg.org/Lolig4/Autodesk-Fusion-360-on-Linux";
        license = lib.licenses.mit; # The integration scripts; Fusion requires an Autodesk license.
        platforms = [ "x86_64-linux" ];
        mainProgram = "fusion360";
    };
}
