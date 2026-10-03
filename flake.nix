{
    description = "Vaelmyr's NixOS configuration";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

        disko = {
            url = "github:nix-community/disko/latest";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        agenix = {
            url = "github:ryantm/agenix";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        plasma-manager = {
            url = "github:nix-community/plasma-manager";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.home-manager.follows = "home-manager";
        };

        secrets = {
            url = "git+ssh://git@github.com/Vaelmyr/nix-secrets.git?ref=main";
            flake = false;
        };
    };

    outputs = { nixpkgs, disko, agenix, home-manager, plasma-manager, ... } @inputs:
    let
        user = "vaelmyr";
    in
    {
        nixosConfigurations = {
            fenrir = nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                specialArgs = inputs // { inherit user; };

                modules = [
                    disko.nixosModules.disko
                    agenix.nixosModules.default
                    home-manager.nixosModules.home-manager {
                        home-manager = {
                            sharedModules = [ plasma-manager.homeModules.plasma-manager ];
                            useGlobalPkgs = true;
                            useUserPackages = true;


                            users.${user} = { config, pkgs, lib, ... }:
                                import ./modules/nixos/home-manager.nix { inherit config pkgs lib; };
                        };
                    }
                    ./hosts/fenrir
                ];
            };
        };
    };
}
