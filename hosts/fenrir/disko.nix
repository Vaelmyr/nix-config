{ ... }:

{
    disko.devices = {
        disk = {
            main = {
                type = "disk";
                device = "/dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_AA221223NV01kG05593";

                content = {
                    type = "gpt";

                    partitions = {
                        ESP = {
                            priority = 1;
                            name = "ESP";
                            size = "1G";
                            type = "EF00";

                            content = {
                                type = "filesystem";
                                format = "vfat";
                                mountpoint = "/boot";
                                mountOptions = [ "umask=0077" ];
                            };
                        };

                        root = {
                            size = "100%";

                            content = {
                                type = "luks";
                                name = "crypted";
                                extraFormatArgs = [ "--type" "luks2" ];

                                settings = {
                                    allowDiscards = true;
                                    crypttabExtraOpts = [ "tpm2-device=auto" ];
                                };

                                content = {
                                    type = "btrfs";
                                    extraArgs = [ "-f" ];

                                    subvolumes = {
                                        "/rootfs" = {
                                            mountpoint = "/";
                                            mountOptions = [
                                                "compress=zstd"
                                                "noatime"
                                            ];
                                        };

                                        "/home" = {
                                            mountpoint = "/home";
                                            mountOptions = [
                                                "compress=zstd"
                                                "noatime"
                                            ];
                                        };

                                        "/nix" = {
                                            mountpoint = "/nix";
                                            mountOptions = [
                                                "compress=zstd"
                                                "noatime"
                                            ];
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };
}
