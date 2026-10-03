{ config, pkgs, lib, ... }:
let
    personalGitIdentity = {
        name = "Vaelmyr";
        email = "sdistefano.dev@gmail.com";
        signingKey = "${config.home.homeDirectory}/.ssh/id_ed25519_github_personal";
    };

    davinciGitIdentity = {
        name = "Salvatore Distefano";
        email = "s.distefano@davinci.care";
        signingKey = "${config.home.homeDirectory}/.ssh/id_ed25519_github_davinci";
    };
in
{
    direnv = {
        enable = true;
        enableZshIntegration = true;
        enableGitIntegration = true;
        nix-direnv.enable = true;
    };

    eza = {
        enable = true;
        enableZshIntegration = true;
        icons = "auto";
        git = true;
        extraOptions = [ "--group-directories-first" ];
    };

    atuin = {
        enable = true;
        enableZshIntegration = true;
        flags = [ "--disable-up-arrow" ];

        settings = {
            style = "compact";
            inline_height = 20;
            enter_accept = false;
            sync.records = true;

            history_filter = [
                "^pwd$"
                "^ls$"
                "^cd$"
            ];
        };
    };

    zsh = {
        enable = true;
        autocd = true;

        # Ghost-writes the rest of a command from history; right-arrow accepts.
        autosuggestion.enable = true;

        # Colors a command red until it resolves to something runnable.
        syntaxHighlighting.enable = true;

        history.ignorePatterns = [
            "pwd"
            "ls"
            "cd"
        ];

        shellAliases = {
            open = "xdg-open";
        };
    };

    git = {
        enable = true;
        lfs.enable = true;
        signing = {
            format = "ssh";
            signByDefault = true;
        };

        settings = {
            user.useConfigOnly = true;
            init.defaultBranch = "main";

            # Route SSH internally, keeping the original remote URLs.
            url."git@github-personal:".insteadOf = [
                "git@github.com:"
            ];
            url."ssh://git@github-personal/".insteadOf = [
                "ssh://git@github.com/"
            ];

            # Git chooses the longest matching prefix for DaVinci repositories.
            url."git@github-davinci:DavinciSalute/".insteadOf = [
                "git@github.com:DavinciSalute/"
            ];
            url."ssh://git@github-davinci/DavinciSalute/".insteadOf = [
                "ssh://git@github.com/DavinciSalute/"
            ];
        };

        includes = [
            # Personal GitHub
            {

                condition = "hasconfig:remote.*.url:git@github.com:*/**";
                contents.user = personalGitIdentity;
            }
            {
                condition = "hasconfig:remote.*.url:https://github.com/*/**";
                contents.user = personalGitIdentity;
            }
            {
                condition = "hasconfig:remote.*.url:ssh://git@github.com/*/**";
                contents.user = personalGitIdentity;
            }

            # DaVinci GitHub
            {
                condition = "hasconfig:remote.*.url:git@github.com:DavinciSalute/**";
                contents.user = davinciGitIdentity;
            }
            {
                condition = "hasconfig:remote.*.url:https://github.com/DavinciSalute/**";
                contents.user = davinciGitIdentity;
            }
            {
                condition = "hasconfig:remote.*.url:ssh://git@github.com/DavinciSalute/**";
                contents.user = davinciGitIdentity;
            }
        ];
    };

    ssh = {
        enable = true;
        enableDefaultConfig = false;

        settings = {
            "github-personal" = {
                User = "git";
                HostName = "github.com";
                IdentitiesOnly = true;
                IdentityFile = personalGitIdentity.signingKey;
            };

            "github-davinci" = {
                User = "git";
                HostName = "github.com";
                IdentitiesOnly = true;
                IdentityFile = davinciGitIdentity.signingKey;
            };

            "*" = {
                # Set the default values we want to keep
                SendEnv = [ "LANG" "LC_*" ];
                HashKnownHosts = true;
            };
        };
    };
}
