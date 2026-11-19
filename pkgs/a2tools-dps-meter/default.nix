{ lib, stdenvNoCC, fetchurl, autoPatchelfHook, wrapGAppsHook3, dpkg
, gtk3, webkitgtk_4_1, libsoup_3, glib, glib-networking, libpcap
, libayatana-appindicator, libX11, stdenv, util-linux }:

stdenvNoCC.mkDerivation {
    pname = "a2tools-dps-meter";
    version = "2.0.99";

    src = fetchurl {
        # Upstream only publishes a rolling URL. Update version and hash together.
        url = "https://cdn.a2tools.app/linux/a2tools-dps-meter-latest_amd64.deb";
        hash = "sha256-iqI13DYeRselzFVlhhHmAQdWb125b3dzrXfBC8w6G0g=";
    };

    nativeBuildInputs = [ dpkg autoPatchelfHook wrapGAppsHook3 ];
    buildInputs = [ gtk3 webkitgtk_4_1 libsoup_3 glib glib-networking stdenv.cc.cc.lib ];
    # These libraries are opened dynamically rather than linked by the executable.
    # libpcap keeps its shared objects in a separate `lib` output.
    runtimeDependencies = map lib.getLib [ libpcap libayatana-appindicator libX11 ];

    unpackPhase = ''
        runHook preUnpack
        dpkg-deb -x "$src" .
        runHook postUnpack
    '';
    dontBuild = true;
    # Only the public launcher needs the GTK environment. Keep the executable
    # used by security.wrappers, and its sibling helper, unwrapped.
    dontWrapGApps = true;

    installPhase = ''
        runHook preInstall
        mkdir -p "$out/bin" "$out/libexec"
        cp -r usr/share "$out/share"
        cp -r usr/lib "$out/lib"
        install -m755 usr/bin/a2tools-dps-meter "$out/libexec/a2tools-dps-meter"
        install -m755 usr/bin/a2tools-hotkeys "$out/libexec/a2tools-hotkeys-unwrapped"

        # The capability-bearing entry point is created by the NixOS module.
        cat > "$out/bin/a2tools-dps-meter" <<'EOF'
        #!${stdenvNoCC.shell}
        exec /run/wrappers/bin/a2tools-dps-meter "$@"
        EOF
        chmod +x "$out/bin/a2tools-dps-meter"

        # NixOS wrappers use ambient capabilities. The portal helper must drop
        # those before starting, otherwise the desktop cannot inspect its process.
        cat > "$out/libexec/a2tools-hotkeys" <<EOF
        #!${stdenvNoCC.shell}
        exec ${util-linux}/bin/setpriv --ambient-caps=-all --inh-caps=-all \\
            "$out/libexec/a2tools-hotkeys-unwrapped" "\$@"
        EOF
        chmod +x "$out/libexec/a2tools-hotkeys"

        substituteInPlace "$out/share/applications/A2Tools DPS Meter.desktop" \
            --replace-fail 'Exec=a2tools-dps-meter' "Exec=$out/bin/a2tools-dps-meter" \
            --replace-fail 'Categories=' 'Categories=Game;Utility;'
        runHook postInstall
    '';

    postFixup = ''
        wrapProgram "$out/bin/a2tools-dps-meter" "''${gappsWrapperArgs[@]}"
    '';

    meta = {
        description = "Native AION 2 damage meter and overlay";
        homepage = "https://github.com/taengu/A2Tools-DPS-Meter";
        license = lib.licenses.gpl3Only;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "x86_64-linux" ];
        mainProgram = "a2tools-dps-meter";
    };
}
