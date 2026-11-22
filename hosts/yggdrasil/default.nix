{ config, lib, pkgs, user, secrets, ... }:

let
    # Read the access list from the private input and ignore blank/comment lines.
    authorizedKeysFile = "${secrets}/authorized_keys/yggdrasil";
    authorizedKeys = builtins.filter
        (line: line != "" && !(lib.hasPrefix "#" line))
        (map lib.trim (lib.splitString "\n" (builtins.readFile authorizedKeysFile)));
in
{
    imports = [
        ./hardware-configuration.nix
        ./disko.nix
        ./secrets.nix
    ];

    # Prevent an installation with no authorized SSH clients.
    assertions = [
        {
            assertion = authorizedKeys != [ ];
            message = "Yggdrasil requires an SSH public key in nix-secrets/authorized_keys/yggdrasil before installation.";
        }
    ];

    # Boot configuration, with disk mounts and encryption supplied by disko.
    boot = {
        loader = {
            systemd-boot = {
                enable = true;
                configurationLimit = 5;
            };

            efi.canTouchEfiVariables = true;
        };

        initrd.systemd = {
            tpm2.enable = true;
        };

        kernelPackages = pkgs.linuxPackages;
    };

    # Compressed swap in RAM, without disk swap or hibernation.
    zramSwap.enable = true;

    # Hardware platform
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    # Hardware support for the headless server
    hardware = {
        bluetooth = {
            enable = true;
            powerOnBoot = true;
        };
    };

    # Power management
    powerManagement = {
        enable = true;
        cpuFreqGovernor = "powersave";

        # Moderate SATA link power saving; independent of HDD spin-down policy.
        scsiLinkPolicy = "med_power_with_dipm";
    };

    # Networking
    networking = {
        hostName = "yggdrasil";

        networkmanager.enable = true;
        nftables.enable = true;

        # Firewall enabled with nftables instead of iptables.
        firewall = {
            enable = true;

            extraInputRules = ''
                # SSH from trusted LANs/VPN
                ip saddr 192.168.1.0/24 tcp dport 22 accept
            '';
        };
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

    # Console configuration for virtual terminals
    console.useXkbConfig = true;

    # Programs configuration
    programs = {
        zsh.enable = true;
    };

    # Services configuration
    services = {
        # XKB supplies the console keymap without enabling the X server.
        xserver = {
            xkb = {
                layout = "it";
            };
        };

        # Enable the OpenSSH daemon.
        openssh = {
            enable = true;
            openFirewall = false;

            settings = {
                PasswordAuthentication = false;
                KbdInteractiveAuthentication = false;
                PermitRootLogin = "no";
            };
        };

        # Periodic SSD TRIM through the encrypted volume's discard support.
        fstrim.enable = true;

        # Request low GPU clocks while the temporary RX590 is installed.
        udev.extraRules = ''
            # Also handles a GPU appearing after boot; harmless when it is removed.
            ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", TEST=="power_dpm_force_performance_level", ATTR{power_dpm_force_performance_level}="low"
            ACTION=="bind", SUBSYSTEM=="pci", DRIVER=="amdgpu", TEST=="power_dpm_force_performance_level", ATTR{power_dpm_force_performance_level}="low"
        '';
    };

    # Users configuration
    users.users.${user} = {
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
        openssh.authorizedKeys.keyFiles = [ authorizedKeysFile ];
    };

    # Stay available over SSH rather than entering a sleep state.
    systemd.sleep.settings.Sleep = {
        AllowSuspend = false;
        AllowHibernation = false;
        AllowHybridSleep = false;
        AllowSuspendThenHibernate = false;
    };

    # System administration, power measurement, and storage recovery tools
    environment.systemPackages = with pkgs; [
        vim
        nano
        git
        btop
        lm_sensors
        powertop
        pciutils
        smartmontools
        cryptsetup
        tpm2-tools
    ];

    # Docker
    virtualisation.docker.enable = true;

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
