{ config, lib, pkgs, ... }:

{
    options.programs.a2tools-dps-meter.enable = lib.mkEnableOption "A2Tools DPS Meter for AION 2";

    config = lib.mkIf config.programs.a2tools-dps-meter.enable {
        environment.systemPackages = [ pkgs.a2tools-dps-meter ];

        # Capture packets as the desktop user, without running the GUI as root.
        security.wrappers.a2tools-dps-meter = {
            source = "${pkgs.a2tools-dps-meter}/libexec/a2tools-dps-meter";
            owner = "root";
            group = "root";
            capabilities = "cap_net_raw+ep";
        };
    };
}
