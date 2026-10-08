# Entry point for nix-shell and nixpkgs' traditional package updaters.
{ system ? builtins.currentSystem, ... } @args:

let
    flake = builtins.getFlake (toString ./.);
    pkgs = import flake.inputs.nixpkgs (args // { inherit system; });
in
pkgs // {
    godotPackages_preview = pkgs.callPackage ./pkgs/godot { };
}
