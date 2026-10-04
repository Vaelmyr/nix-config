{ config, secrets, user, ... }:

{
    age = {
        identityPaths = [
            "/var/lib/agenix/id_ed25519_agenix"
        ];

        secrets = {
            openpgp-passphrase = {
                file = "${secrets}/openpgp-passphrase.age";
                owner = user;
                group = "users";
                mode = "0400";
            };

            openpgp-private-key = {
                file = "${secrets}/openpgp-private-key.age";
                owner = user;
                group = "users";
                mode = "0400";
            };

            github-personal = {
                file = "${secrets}/id_ed25519_github_personal.age";
                path = "${config.users.users.${user}.home}/.ssh/id_ed25519_github_personal";
                owner = user;
                group = "users";
            };

            github-davinci = {
                file = "${secrets}/id_ed25519_github_davinci.age";
                path = "${config.users.users.${user}.home}/.ssh/id_ed25519_github_davinci";
                owner = user;
                group = "users";
            };

            user-password = {
                file = "${secrets}/user-password.age";
            };

            smb-home-server = {
                file = "${secrets}/smb-home-server.age";
                owner = "root";
                group = "root";
            };
        };
    };
}
