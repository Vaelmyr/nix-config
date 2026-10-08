{ config, pkgs, lib, user, ... }:

{
    imports = [
        ./hardware-configuration.nix
        ./disko.nix
        ../../modules/nixos/secrets.nix
        ../../modules/nixos/gnupg.nix
    ];

    # Hardware configuration, merged from `hardware-configuration.nix`
    boot = {
        loader = {
            systemd-boot = {
                enable = true;
                configurationLimit = 10;
            };

            efi.canTouchEfiVariables = true;
        };

        initrd.systemd = {
            enable = true;
            tpm2.enable = true;
        };

        kernelPackages = pkgs.linuxPackages_latest;
    };

    # Compressed swap in RAM, without disk swap or hibernation.
    zramSwap.enable = true;

    # Hardware platform
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    # Hardware support for gaming
    hardware = {
        bluetooth = {
            enable = true;
            powerOnBoot = true;
        };

        graphics = {
            enable = true;
            enable32Bit = true;
        };

        # Required to support the XBOX Wireless Elite Series 2 Controller
        xpadneo.enable = true;
    };

    # Existing data disk and network storage
    fileSystems = {
        "/mnt/games" = {
            device = "/dev/disk/by-uuid/fca1c79b-8482-4b83-889b-34287999c9df";
            fsType = "btrfs";
            options = [
                "subvol=@games"
                "compress=zstd"
                "noatime"
                "nofail"
                "x-systemd.device-timeout=10s"
            ];
        };

        "/mnt/nas" = {
            device = "//home-server/nas";
            fsType = "cifs";
            options = [
                "credentials=${config.age.secrets.smb-home-server.path}"
                "uid=${toString config.users.users.${user}.uid}"
                "nofail"
                "x-systemd.automount"
                "x-systemd.mount-timeout=15s"
            ];
        };
    };

    # Networking
    networking = {
        hostName = "fenrir";

        networkmanager.enable = true;
        nftables.enable = true;

        # Firewall enabled with nftables instead of iptables.
        firewall = {
            enable = true;

            extraInputRules = ''
                # SSH from trusted LANs/VPN
                ip saddr 192.168.1.0/24 tcp dport 22 accept

                # Bambu Lab printer discovery announcements from the LAN.
                ip saddr 192.168.1.0/24 udp dport { 1990, 2021 } accept
            '';
        };

        # Custom hosts entries
        extraHosts = ''
            192.168.1.3 home-server
        '';
    };

    # Time zone
    time.timeZone = "Europe/Rome";

    # Internationalization properties
    i18n = {
        defaultLocale = "en_US.UTF-8";

        extraLocaleSettings = {
            LC_CTYPE = "en_US.UTF-8";
            LC_MESSAGES = "en_US.UTF-8";
            LC_COLLATE = "en_US.UTF-8";

            LC_ADDRESS = "it_IT.UTF-8";
            LC_MEASUREMENT = "it_IT.UTF-8";
            LC_MONETARY = "it_IT.UTF-8";
            LC_NAME = "it_IT.UTF-8";
            LC_NUMERIC = "it_IT.UTF-8";
            LC_PAPER = "it_IT.UTF-8";
            LC_TELEPHONE = "it_IT.UTF-8";
            LC_TIME = "it_IT.UTF-8";
        };
    };

    # Programs configuration
    programs = {
        zsh.enable = true;

        localsend = {
            enable = true;
            openFirewall = true;
        };

        steam = {
            enable = true;
            remotePlay.openFirewall = true;
            dedicatedServer.openFirewall = true;
            localNetworkGameTransfers.openFirewall = true;
        };
    };

    # Let SDL use xpadneo mappings so Steam can configure the Elite Series 2 paddles.
    environment.sessionVariables.SDL_JOYSTICK_HIDAPI = "0";

    # Console configuration for virtual terminals
    console.useXkbConfig = true;

    # Services configuration
    services = {
        xserver = {
            enable = true;
            videoDrivers = [ "amdgpu" ];

            xkb = {
                layout = "it";
            };
        };

        displayManager = {
            sddm.enable = true;

            autoLogin = {
                enable = true;
                user = user;
            };
        };

        desktopManager.plasma6.enable = true;

        # Enable CUPS to print documents
        printing = {
            enable = true;
            drivers = [ pkgs.hplip ];
        };

        avahi = {
            enable = true;
            nssmdns4 = true;
            nssmdns6 = true;
            openFirewall = true;
        };

        # Disable PulseAudio in favor of PipeWire for audio management
        pulseaudio.enable = false;

        pipewire = {
            enable = true;
            pulse.enable = true;

            alsa = {
                enable = true;
                support32Bit = true;
            };
        };

        # Enable the OpenSSH daemon.
        openssh = {
            enable = true;
            openFirewall = false;

            settings = {
                PasswordAuthentication = true;
                KbdInteractiveAuthentication = false;
                PermitRootLogin = "no";
            };
        };
    };

    # Allows PipeWire to use the realtime scheduler for increased performance
    security.rtkit.enable = true;

    # Users configuration
    users = {
        users.${user} = {
            isNormalUser = true;
            description = "Vaelmyr";
            shell = pkgs.zsh;
            uid = 1000;

            extraGroups = [
                "wheel"
                "networkmanager"
                "docker"
            ];

            hashedPasswordFile = config.age.secrets.user-password.path;
        };
    };

    # Agenix creates the SSH directory before users; fix its ownership for Home Manager.
    systemd.tmpfiles.rules = [
        "d ${config.users.users.${user}.home}/.ssh 0700 ${user} users -"
    ];

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;

    # Overlays for custom package definitions
    nixpkgs.overlays = import ./overlays.nix;

    # List packages installed in system profile. To search, run:
    #   $ nix search <pkg>
    environment.systemPackages = with pkgs; [
        vim
        nano
        git
        wl-clipboard
        btop
        lm_sensors
    ];

    # Docker
    virtualisation.docker.enable = true;

    # Fonts
    fonts.packages = import ../../modules/shared/fonts.nix { inherit pkgs; };

    # Nix-related settings
    nix = {
        settings = {
            allowed-users = [ user ];
            trusted-users = [
                "root"
                user
            ];

            substituters = [
                "https://nix-community.cachix.org"
            ];

            trusted-public-keys = [
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            ];

            experimental-features = [
                "nix-command"
                "flakes"
            ];
        };

        # Garbage collection to remove old generations and reduce disk space usage
        gc = {
            automatic = true;
            dates = "weekly";
            options = "--delete-older-than 30d";
        };

        # Deduplicate identical files in the Nix store using hard links
        optimise = {
            automatic = true;
            dates = [ "weekly" ];
        };
    };

    # Initial system state version
    system.stateVersion = "26.05";
}
