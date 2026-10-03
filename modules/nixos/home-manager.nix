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
}
