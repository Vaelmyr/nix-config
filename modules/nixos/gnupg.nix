{ config, lib, pkgs, user, ... }:
{
    programs.gnupg.agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-qt;
        settings.allow-preset-passphrase = "";
    };

    environment.systemPackages = [ pkgs.gnupg ];

    # Import and unlock the key before Plasma starts opening wallets.
    home-manager.users.${user}.systemd.user.services.import-openpgp-key = {
        Unit = {
            Description = "Import the agenix-managed OpenPGP private key";
            Before = [ "graphical-session-pre.target" ];
        };

        Service = {
            Type = "oneshot";
            ExecStart = lib.getExe (pkgs.writeShellApplication {
                name = "import-openpgp-key";
                runtimeInputs = [ pkgs.gnupg pkgs.gawk ];
                text = ''
                    key=${lib.escapeShellArg config.age.secrets.openpgp-private-key.path}
                    passphrase=${lib.escapeShellArg config.age.secrets.openpgp-passphrase.path}

                    gpg --batch --pinentry-mode loopback --passphrase-file "$passphrase" --import "$key"

                    # Cache the passphrase for the primary key and its subkeys.
                    gpg --batch --with-colons --with-keygrip --show-keys "$key" \
                        | awk -F: '$1 == "grp" { print $10 }' \
                        | while read -r keygrip; do
                            ${pkgs.gnupg}/libexec/gpg-preset-passphrase --preset "$keygrip" < "$passphrase"
                        done
                '';
            });
        };

        Install.WantedBy = [ "graphical-session-pre.target" ];
    };
}
