# Yggdrasil installation

Initial target: Ryzen 5 5600, ASUS ROG Strix B350-F Gaming, 32 GB RAM,
256 GB NVMe, wired Ethernet, and an RX590 temporarily installed.
The configuration installs a headless NixOS system with SSH, LUKS2-encrypted
Btrfs, and TPM2 unlocking. It does not configure NAS disks or RAID.

## 1. Prepare firmware and SSH access

Boot in UEFI mode. Enable **Firmware TPM** under **Advanced → AMD fTPM
configuration** (the exact wording depends on the BIOS). Keep CPU idle states
enabled and disable overclocking. Enable CPPC if the BIOS exposes that option,
so Linux can use AMD P-State where supported. For automatic recovery after a power outage,
set **Restore AC Power Loss** to **Power On** if desired.

Finalize the Secure Boot setting before TPM enrollment. This configuration uses
ordinary systemd-boot; it does not provision Secure Boot signing. Do not enable
Secure Boot unless you have separately configured a trusted signed boot chain.

On Fenrir, generate a dedicated SSH key if it does not already exist:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_yggdrasil -C fenrir-to-yggdrasil
```

Choose a passphrase and put the contents of the `.pub` file into
`authorized_keys/yggdrasil` in the private `nix-secrets` repository, one public
key per line. Add the phone and MacBook's own public keys there later. Encrypt
Fenrir's private key as `id_ed25519_ssh_yggdrasil.age` using that repository's
README. Publish the private-repository changes, then in `nix-config` run:

```bash
nix flake update secrets
sudo nixos-rebuild switch --flake path:.#fenrir
```

Fenrir's agenix declaration decrypts that key to
`~/.ssh/id_ed25519_yggdrasil` with mode `0600`. The SSH alias `yggdrasil` uses
this identity; the hostname must resolve through your router/local DNS, or use
the explicit IP command below. Never commit plaintext private keys.
The server reads the public-key list from the pinned private input during
installation/rebuild, without needing a permanent GitHub credential. It refuses
to build with an empty access list. Changes to the access list require updating
the `secrets` input and rebuilding Yggdrasil.

SSH accepts keys for `vaelmyr`, with passwordless `sudo`; password authentication
over SSH and root SSH login are disabled. Local console login uses the same
password as Fenrir, decrypted from `user-password.age`. Access to a client private key therefore grants
server administration. The firewall allows SSH only from `192.168.1.0/24`,
matching Fenrir's LAN; edit this in `default.nix` if the server uses another LAN.
Reserve its DHCP address in the router so reconnecting is predictable.
NetworkManager manages Ethernet automatically and also provides Wi-Fi support;
no interface name or static network profile is required for wired DHCP.

## 2. Boot the NixOS installer

Keep the RX590 and a monitor connected through installation and the first boot.
Boot a recent **minimal x86_64 NixOS ISO** in UEFI mode, connect Ethernet, then:

```bash
sudo -i
passwd root
systemctl start sshd
install -d -m 0700 /run/bootstrap
ip -br -4 address
systemd-cryptenroll --tpm2-device=list
```

The last command must list a TPM2 device. If it does not, check the BIOS version
and fTPM setting before proceeding with an unattended-unlock installation.

From Fenrir, use the installer's IP in place of `INSTALLER_IP`. As in the main
guide, the existing agenix identity fetches private flake inputs and is installed
on the encrypted system disk to decrypt the local account password. Yggdrasil
declares only that password secret, without Fenrir's other credentials.

```bash
scp /path/to/id_ed25519_agenix root@INSTALLER_IP:/run/bootstrap/id_ed25519_agenix
ssh root@INSTALLER_IP
```

In that installer SSH session:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#git nixpkgs#openssh

chmod 0600 /run/bootstrap/id_ed25519_agenix
eval "$(ssh-agent -a /run/bootstrap/ssh-agent.sock -s)"
ssh-add /run/bootstrap/id_ed25519_agenix
git ls-remote ssh://git@github.com/Vaelmyr/nix-secrets.git HEAD
git clone git@github.com:Vaelmyr/nix-config.git /root/nix-config
cd /root/nix-config
```

The installer checkout must contain the new Yggdrasil files and the updated
`flake.lock` that pins your private key-list revision. Until these changes are
committed and available remotely, copy the current
checkout from Fenrir instead of cloning. Run this on **Fenrir**:

```bash
scp -r /home/vaelmyr/Projects/Personal/nix-config root@INSTALLER_IP:/root/
```

Keep the installer shell with the SSH agent open for the following steps;
Nix fetches the public-key list from the private input. Use `path:.` so local
files are included even before Git tracks them.

## 3. Select and inspect the installation disk

In `/root/nix-config` on the installer:

```bash
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN
ls -l /dev/disk/by-id/nvme-*
```

Set the whole-device path for the **256 GB NVMe**, not a `-partN` path:

```bash
install_disk=/dev/disk/by-id/nvme-REPLACE_WITH_ACTUAL_MODEL_AND_SERIAL
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS "$install_disk"
```

The placeholder in `disko.nix` is intentionally unusable. `disko-install --disk`
selects the actual disk; boot uses a partition label, so the placeholder does
not prevent later boots or rebuilds. You may also replace it in `disko.nix` with
the verified by-id path for future maintenance.

Check the proposed hardware profile against the installer hardware scan:

```bash
nixos-generate-config --no-filesystems --show-hardware-config
```

`hardware-configuration.nix` is an initial profile, not a scan from this machine.
Incorporate any missing required modules; disko already supplies filesystems and
the LUKS mapping. Do not copy Fenrir's generated hardware configuration.

Evaluate the complete system before formatting:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  eval --raw path:.#nixosConfigurations.yggdrasil.config.system.build.toplevel.drvPath
```

## 4. Install with disko-install

**This erases the selected NVMe.** Check its model, serial, and size above.
Disconnect other data disks during this initial installation if practical.

```bash
nix --extra-experimental-features 'nix-command flakes' \
  run --inputs-from path:. disko#disko-install -- \
    --flake path:.#yggdrasil \
    --disk main "$install_disk" \
    --write-efi-boot-entries \
    --extra-files /root/nix-config /etc/nixos \
    --extra-files /run/bootstrap/id_ed25519_agenix /var/lib/agenix/id_ed25519_agenix
```

Choose a strong LUKS passphrase when prompted and keep it outside the server.
The NVMe gets a 1 GiB EFI partition and an encrypted Btrfs volume containing
separate `/`, `/home`, and `/nix` subvolumes. Compressed swap in RAM (zram) is
enabled; there is no disk swap or hibernation.

## 5. Enroll TPM2 before the first reboot

Still in the installer, after installation succeeds:

```bash
luks_device=/dev/disk/by-partlabel/disk-main-yggdrasil-root
cryptsetup luksDump "$luks_device"
systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=7 \
  "$luks_device"
```

Enter the LUKS passphrase. Keep its keyslot as the independent recovery method.
PCR 7 binds unlocking to the Secure Boot policy; changing that policy or clearing
the TPM can require the recovery passphrase and re-enrollment. With Secure Boot
disabled, this provides automatic unlocking but does not authenticate the boot
chain or stop someone booting another OS on the complete machine.

Make a header backup in the installer's temporary RAM filesystem:

```bash
cryptsetup luksHeaderBackup "$luks_device" \
  --header-backup-file /run/bootstrap/yggdrasil-nvme-luks-header.img
chmod 0600 /run/bootstrap/yggdrasil-nvme-luks-header.img
```

From **Fenrir**, save it outside the repository before rebooting the installer:

```bash
install -d -m 0700 ~/Backups/yggdrasil
scp root@INSTALLER_IP:/run/bootstrap/yggdrasil-nvme-luks-header.img \
  ~/Backups/yggdrasil/
chmod 0600 ~/Backups/yggdrasil/yggdrasil-nvme-luks-header.img
```

Protect this backup: it contains sensitive keyslot material. Retaining it can
also retain access through passphrases that you later remove from the disk.
No rebuild is needed after TPM enrollment. On the installer:

```bash
reboot
```

Remove the installer USB. Confirm the system unlocks without typing anything.

## 6. Verify access and the power-saving baseline

From Fenrir, using the router's DHCP address for `SERVER_IP`:

```bash
ssh -i ~/.ssh/id_ed25519_yggdrasil vaelmyr@SERVER_IP
```

On Yggdrasil:

```bash
hostname
sudo -n true
systemctl --failed
systemctl status cpufreq cpu-power-saving sshd --no-pager
systemctl status NetworkManager wifi-power-saving --no-pager
nmcli device status
nmcli radio wifi
swapon --show
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
grep . /sys/devices/system/cpu/cpufreq/boost /sys/devices/system/cpu/cpufreq/policy*/boost
grep . /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference
grep . /sys/class/drm/card[0-9]*/device/power_dpm_force_performance_level
sudo cryptsetup luksDump /dev/disk/by-partlabel/disk-main-yggdrasil-root
```

Expected: hostname `yggdrasil`, working sudo, no failed units, `powersave`
governor, boost `0` and energy preference `power` where supported, GPU state
`low`, and a `systemd-tpm2`
token in the LUKS metadata. If a sysfs control is missing, inspect the detected
driver before choosing a replacement setting. The GPU command has no matching
file after the card is removed. Missing boost or energy-preference paths are
also possible depending on the CPU driver; the service skips absent controls.

Before removing the monitor, verify a local console login as `vaelmyr` using
Fenrir's account password. Confirm SSH still rejects password authentication.

The initial profile uses the `powersave` governor, requests the `power` energy
preference where exposed, disables boost when supported, requests low GPU
clocks, enables moderate SATA link power saving and periodic
SSD TRIM, and disables sleep. Bluetooth support is enabled without automatically
powering adapters on. Wi-Fi is managed by NetworkManager, with a startup service
turning its radio off each boot for the initial measurements. It does not force PCIe ASPM or apply
all PowerTOP tunings. These are starting settings to measure, not verified
power savings on this hardware. The RX590 still uses the `amdgpu` kernel driver
without a desktop; removing it requires a successful firmware boot test.

Measure settled idle watts and accumulated energy with the smart plug. Avoid
rebuilds, TRIM runs, and interactive monitoring during an idle sample. Compare
alternative policies for work-completion energy as well as idle watts:
`balance_power` versus `power` energy preference with active AMD P-State, or
`ondemand` versus `powersave` governor with `acpi-cpufreq`. With active AMD
P-State, `powersave` allows dynamic frequency selection; with `acpi-cpufreq`,
it selects minimum frequency. Driver support depends on the BIOS exposing CPPC;
the CPU model alone does not guarantee it.

When the Fenvi card is installed and you want to use its radios:

```bash
nmcli radio wifi on
sudo bluetoothctl power on
```

To keep radios enabled across boots, remove `systemd.services.wifi-power-saving`
and set `hardware.bluetooth.powerOnBoot = true`, then rebuild. Wi-Fi credentials
can be entered with `nmcli --ask device wifi connect SSID` without putting the
password in shell history. Hardware/firmware support for the Fenvi card still
needs verification on the server.

Verify an unattended reboot and a cold boot, then shut down and remove the GPU
and test again while keeping it available for recovery. Future HDD encryption,
RAID, disk standby, and NAS services are configured separately after this test.

## Later configuration changes

The installed checkout is `/etc/nixos`; edit it as root and rebuild with:

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#yggdrasil
```

The flake uses the private `nix-secrets` input for encrypted credentials and
Yggdrasil's public-key list. Operations that fetch or update it require an
appropriate SSH agent. The server retains the root-only agenix identity at
`/var/lib/agenix/id_ed25519_agenix` for local password decryption; its presence
alone does not configure Git authentication. Keep `system.stateVersion` at its
initial installation value. With TPM2 unlocking working, later NAS keys can be
stored on the encrypted system volume, with independent recovery credentials
kept elsewhere so the HDDs remain recoverable after replacing the PC.
