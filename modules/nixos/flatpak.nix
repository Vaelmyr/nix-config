{ config, ... }:

let
    flatpak = "${config.services.flatpak.package}/bin/flatpak";
in
{
    services.flatpak.enable = true;

    # Use the upstream-supported sandbox and runtime for Sober.
    # Keep downloads outside activation so rebuilding also works offline.
    systemd.services.sober-flatpak-install = {
        description = "Install Sober from Flathub";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "30s";
            TimeoutStartSec = "infinity";
        };

        script = ''
            ${flatpak} remote-add --system --if-not-exists \
                flathub https://flathub.org/repo/flathub.flatpakrepo
            ${flatpak} install --system --noninteractive --assumeyes \
                flathub org.vinegarhq.Sober
        '';
    };
}
