{ pkgs }:

let
  inherit (pkgs) lib;
  python = pkgs.python3.withPackages (p: [ p.tkinter ]);
  tools = lib.makeBinPath (with pkgs; [ bash coreutils gnugrep gnused gawk util-linux nftables procps ]);
  netd = pkgs.stdenv.mkDerivation {
    pname = "exitlag-netd";
    version = "0.4.0-alpha.2";
    src = pkgs.fetchurl {
      url = "https://github.com/Cheaux/exitlag-bridge/releases/download/v0.4.0-alpha.2/exitlag-bridge-0.4.0-alpha.2-source.zip";
      sha256 = "80f84b78edf50d07fa5846358e291a7e7027cd23d4956672554ce3bcd287b9d8";
    };
    nativeBuildInputs = [ pkgs.unzip ];
    buildInputs = [ pkgs.libmnl ];
    postPatch = ''
      substituteInPlace backend/exitlag-netd.c \
        --replace-fail /usr/bin/nft ${pkgs.nftables}/bin/nft
    '';
    buildPhase = "make -C backend";
    installPhase = "install -Dm755 backend/exitlag-netd $out/bin/exitlag-netd";
  };
  wine = pkgs.stdenv.mkDerivation {
    pname = "exitlag-wine";
    version = "11.17";
    src = pkgs.fetchurl {
      url = "https://github.com/Kron4ek/Wine-Builds/releases/download/11.17/wine-11.17-staging-amd64-wow64.tar.xz";
      sha256 = "278d80f3073f1a81386baafb41b83638d89eedaffb640f31599855145ed4fd7b";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [ stdenv.cc.cc.lib freetype fontconfig libx11 libxext libxrender libxrandr libxcursor libxi libxinerama libxxf86vm libxcomposite libxfixes libGL vulkan-loader dbus udev alsa-lib libpulseaudio gnutls openssl libunwind libusb1 SDL2 ncurses zlib gst_all_1.gstreamer gst_all_1.gst-plugins-base ];
    # Wine loads these drivers and libraries dynamically.
    appendRunpaths = map (p: "${lib.getLib p}/lib") (with pkgs; [ freetype fontconfig libx11 libxext libxrender libxrandr libxcursor libxi libxinerama libxxf86vm libxcomposite libxfixes libGL vulkan-loader dbus udev alsa-lib libpulseaudio gnutls openssl ]);
    dontBuild = true;
    dontStrip = true;
    installPhase = ''
      mkdir -p $out
      cp -a bin lib share $out/
      # ExitLag needs none of Wine's scanner, camera, smart-card, ISDN,
      # OpenCL, packet-capture, or legacy FFmpeg 4 multimedia drivers.
      rm $out/lib/wine/x86_64-unix/{sane,gphoto2,winscard,wpcap,opencl,capi2032,winedmo}.so
    '';
  };
in pkgs.stdenv.mkDerivation {
  pname = "exitlag-bridge";
  version = "0.4.0-alpha.2";
  src = pkgs.fetchurl {
    url = "https://github.com/Cheaux/exitlag-bridge/releases/download/v0.4.0-alpha.2/exitlag-bridge-0.4.0-alpha.2-linux-x86_64.tar.gz";
    sha256 = "f53ad08c2e1283861df1fa8f76af07d76053c089771b9ce05904fc6673b57969";
  };
  nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.makeWrapper python ];
  buildInputs = [ pkgs.libmnl ];
  dontBuild = true;
  dontStrip = true;
  installPhase = ''
    runHook preInstall
    root=$out/lib/exitlag-bridge
    mkdir -p "$root" $out/bin $out/libexec $out/share/applications
    cp -a program/. "$root/"
    chmod -R u+w "$root"
    cp ${netd}/bin/exitlag-netd "$root/backend/exitlag-netd"
    substituteInPlace "$root/installers/linux/app.py" \
      --replace-fail "'pkexec', '/usr/bin/python3'" "'${pkgs.coreutils}/bin/env', 'SUDO_ASKPASS=$out/libexec/exitlag-askpass', '/run/wrappers/bin/sudo', '-A', '${python}/bin/python3'"
    cat > $out/libexec/exitlag-askpass <<'EOF'
    #!${pkgs.runtimeShell}
    exec ${pkgs.kdePackages.kdialog}/bin/kdialog --title 'ExitLag Bridge routing' --password "$1"
    EOF
    chmod +x $out/libexec/exitlag-askpass
    substituteInPlace "$root/installers/linux/run_root.py" \
      --replace-fail "ROOTS = (Path('/usr/lib/exitlag-bridge'), Path('/usr/local/lib/exitlag-bridge'))" "ROOTS = (Path('$root'),)" \
      --replace-fail "PATH='/usr/sbin:/usr/bin:/sbin:/bin'" "PATH='${tools}'" \
      --replace-fail "'/bin/bash'" "'${pkgs.bash}/bin/bash'"
    # /nix/store is root-owned and sticky, with group write for nixbld.
    # Existing root-owned store entries remain protected from replacement.
    substituteInPlace "$root/installers/linux/run_root.py" \
      --replace-fail 'info.st_uid != 0 or info.st_mode & 0o022' \
        "info.st_uid != 0 or (info.st_mode & 0o022 and not (directory == Path('/nix/store') and info.st_mode & stat.S_ISVTX and not info.st_mode & stat.S_IWOTH))"
    # Copy the Nix-patched runtime into the private state directory before
    # upstream installs its WMI DLL. The system/Steam Wine is never modified.
    export EXITLAG_PACKAGE_ROOT="$root"
    ${python}/bin/python3 ${./patch-runtime.py} ${wine}
    ${python}/bin/python3 ${./patch-launcher.py}
    sed -i '/from bridge_setup.core import main/i import sys; from pathlib import Path; sys.path.insert(0, str(Path(__file__).parent))' "$root/installers/setup.py"
    patchShebangs "$root/backend"
    makeWrapper ${python}/bin/python3 $out/bin/exitlag-bridge \
      --add-flags "-I $root/installers/linux/app.py" \
      --prefix PATH : '${tools}'
    makeWrapper ${python}/bin/python3 $out/bin/exitlag-bridge-setup \
      --add-flags "-I $root/installers/setup.py" \
      --prefix PATH : '${tools}'
    cat > $out/share/applications/exitlag-bridge.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=ExitLag Bridge
    Comment=Unofficial ExitLag compatibility launcher
    Exec=$out/bin/exitlag-bridge
    Icon=$root/icon.svg
    Terminal=false
    Categories=Game;Network;
    EOF
    runHook postInstall
  '';
  meta = {
    description = "Unofficial ExitLag TCP bridge with a private Wine runtime";
    homepage = "https://github.com/Cheaux/exitlag-bridge";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "exitlag-bridge";
  };
}
