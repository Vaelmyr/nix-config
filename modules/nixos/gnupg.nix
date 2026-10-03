{ config, pkgs, user, ... }:
{
    programs.gnupg.agent = {
        enable = true;
        pinentryPackage = pkgs.pinentry-qt;
    };

    environment.systemPackages = [ pkgs.gnupg ];

    # Import after login so pinentry can request the key's passphrase if needed.
    home-manager.users.${user}.systemd.user.services.import-openpgp-key = {
        Unit = {
            Description = "Import the agenix-managed OpenPGP private key";
            After = [ "graphical-session-pre.target" ];
        };

        Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.gnupg}/bin/gpg --import ${config.age.secrets.openpgp-private-key.path}";
        };

        Install.WantedBy = [ "graphical-session.target" ];
    };
}
