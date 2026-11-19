{ lib, appimageTools, fetchurl }:

let
    pname = "curseforge";
    version = "1.326.0-42377";
    src = fetchurl {
        # Upstream uses a rolling URL; update the version and hash together.
        url = "https://curseforge.overwolf.com/downloads/curseforge-latest-linux.AppImage";
        hash = "sha256-hy0GpwDqKi3ujEdA1aBRA/DBbHyWn1jMoiw2TErBAjo=";
    };
    contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
    inherit pname version src;

    extraInstallCommands = ''
        install -Dm644 ${contents}/curseforge.desktop $out/share/applications/curseforge.desktop
        substituteInPlace $out/share/applications/curseforge.desktop \
            --replace-fail "Exec=AppRun" "Exec=curseforge"
        install -Dm644 ${contents}/curseforge.png $out/share/icons/hicolor/1024x1024/apps/curseforge.png
    '';

    meta = {
        description = "Official CurseForge mod and addon manager";
        homepage = "https://www.curseforge.com/download/app";
        license = lib.licenses.unfree;
        sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
        platforms = [ "x86_64-linux" ];
        mainProgram = "curseforge";
    };
}
