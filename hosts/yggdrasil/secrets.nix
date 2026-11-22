{ config, secrets, user, ... }:

{
    # Agenix creates parent directories as root; Home Manager needs to write here.
    systemd.tmpfiles.rules = [
        "d ${config.users.users.${user}.home}/.ssh 0700 ${user} users -"
    ];

    age = {
        identityPaths = [
            "/var/lib/agenix/id_ed25519_agenix"
        ];

        secrets = {
            github-personal = {
                file = "${secrets}/id_ed25519_github_personal.age";
                path = "${config.users.users.${user}.home}/.ssh/id_ed25519_github_personal";
                owner = user;
                group = "users";
            };

            gitea-personal = {
                file = "${secrets}/id_ed25519_gitea_personal.age";
                path = "${config.users.users.${user}.home}/.ssh/id_ed25519_gitea_personal";
                owner = user;
                group = "users";
            };

            user-password = {
                file = "${secrets}/user-password.age";
            };
        };
    };
}
