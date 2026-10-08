{ lib, appimageTools, fetchurl, cacert, glib-networking }:

let
    pname = "orca-slicer";
    version = "2.4.2";
    src = fetchurl {
        url = "https://github.com/OrcaSlicer/OrcaSlicer/releases/download/v${version}/OrcaSlicer_Linux_AppImage_Ubuntu2404_V${version}.AppImage";
        hash = "sha256-0S+4yOrBrs0t+2N3rNSPmU+PpDntUpL6Uy3YKIDwKf0=";
    };
    contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
    inherit pname version src;

    extraPkgs = pkgs: with pkgs; [
        glib-networking
        libsoup_3
        webkitgtk_4_1
        (gst_all_1.gst-plugins-good.override { gtkSupport = true; })
        gst_all_1.gst-plugins-bad
    ];

    # Upstream's AppRun also sets LC_ALL=C for the Bambu network plugin.
    profile = ''
        export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
        export GIO_EXTRA_MODULES=${glib-networking}/lib/gio/modules
        export WEBKIT_DISABLE_COMPOSITING_MODE=1
    '';

    extraInstallCommands = ''
        install -Dm644 ${contents}/com.orcaslicer.OrcaSlicer.desktop \
            $out/share/applications/com.orcaslicer.OrcaSlicer.desktop
        substituteInPlace $out/share/applications/com.orcaslicer.OrcaSlicer.desktop \
            --replace-fail 'Exec=AppRun %F' 'Exec=orca-slicer %U' \
            --replace-fail 'MimeType=' 'MimeType=x-scheme-handler/orcaslicer;x-scheme-handler/bambustudio;x-scheme-handler/bambustudioopen;'
        install -Dm644 ${contents}/OrcaSlicer.png $out/share/pixmaps/OrcaSlicer.png
    '';

    meta = {
        description = "Slicer for 3D printers (official AppImage)";
        homepage = "https://github.com/OrcaSlicer/OrcaSlicer";
        license = lib.licenses.agpl3Only;
        platforms = [ "x86_64-linux" ];
        mainProgram = "orca-slicer";
    };
}
