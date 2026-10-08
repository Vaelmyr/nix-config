{ config, pkgs, lib, ... }:
let
    nixos-packages = import ./packages.nix { inherit pkgs; };
    shared-packages = import ../shared/packages.nix { inherit pkgs; };

    shared-programs = import ../shared/home-manager.nix { inherit config pkgs lib; };
in
{
    imports = [
        ./kde-config.nix
    ];

    home = {
        stateVersion = "26.05";
        packages = nixos-packages ++ shared-packages;
    };

    programs = shared-programs;

    # Preserve the other MIME associations managed by Plasma and installed apps.
    home.activation.orcaSlicerMimeApps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        for scheme in orcaslicer bambustudio bambustudioopen; do
            run ${pkgs.xdg-utils}/bin/xdg-mime default \
                com.orcaslicer.OrcaSlicer.desktop "x-scheme-handler/$scheme"
        done
    '';

    # Fonts are installed system-wide; let Plasma manage user font rendering settings.
    fonts.fontconfig.enable = false;
}
