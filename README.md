# Installation guide

## 1. Boot the installer

Boot a NixOS installer in UEFI mode through netboot.xyz. On its local console,
open a root shell, set a temporary root password, and start SSH:

```bash
sudo -i
passwd root
systemctl start sshd
install -d -m 0700 /run/bootstrap
ip -br -4 address
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

From another PC, replace the example IP and local paths below. Copy the repository
and the existing agenix identity, then connect to the installer:

```bash
installer_ip=192.168.1.123
scp -r /path/to/nix-config "root@${installer_ip}:/root/nix-config"
scp /path/to/id_ed25519_agenix "root@${installer_ip}:/run/bootstrap/id_ed25519_agenix"
ssh "root@${installer_ip}"
```

On the first connection, match the SSH host fingerprint with the one displayed
on the installer console. Use the temporary root password when prompted. This
password applies only to the live installer.

In the remote root shell:

```bash
cd /root/nix-config
```

Ensure the installer has internet access. The transferred agenix identity must
decrypt the existing secrets; do not generate a replacement key.

Its public key is registered as a deploy key for `nix-secrets`. Load the private
key into the installer's SSH agent before running any flake command:

```bash
chown root:root /run/bootstrap/id_ed25519_agenix
chmod 0600 /run/bootstrap/id_ed25519_agenix
eval "$(ssh-agent -s)"
ssh-add /run/bootstrap/id_ed25519_agenix
git ls-remote ssh://git@github.com/Vaelmyr/nix-secrets.git HEAD
```

If prompted on the first connection, verify GitHub's
[SSH host fingerprint](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints).
Continue in this root shell so Nix can use the agent. The same key will be copied
into the installed system for agenix; no second key is needed to fetch
`nix-secrets` during installation.

Ensure the pinned `nix-secrets` revision contains `smb-home-server.age`. If it was
added after the last lock update, run `nix flake update secrets` before installing.

## 2. Install with disko-install

Check the configured OS disk:

```bash
lsblk -o NAME,PATH,MODEL,SIZE,FSTYPE,MOUNTPOINTS
readlink -f /dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_AA221223NV01kG05593
```

**The next command erases the selected OS disk. Confirm the target first.**
Run it from the repository directory and set a LUKS passphrase when prompted:

```bash
nix run --inputs-from . disko#disko-install -- \
  --flake .#fenrir \
  --disk main /dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_AA221223NV01kG05593 \
  --write-efi-boot-entries \
  --extra-files /run/bootstrap/id_ed25519_agenix /var/lib/agenix/id_ed25519_agenix
```

This uses the disko input pinned in `flake.lock`, partitions and mounts the disk,
copies the bootstrap files with their ownership and permissions, and installs
NixOS and its UEFI boot entry. Do not run `nixos-install` separately.

When installation succeeds, run `reboot`. Keep the LUKS passphrase as a recovery
method and enter it on first boot.

## 3. Enroll TPM2 on the installed system

Finalize any intended Secure Boot configuration before enrollment. Check the
TPM and the configured LUKS2 device:

```bash
luks_device=/dev/disk/by-partlabel/disk-main-root
sudo systemd-cryptenroll --tpm2-device=list
sudo cryptsetup luksDump "$luks_device"
```

If there is no existing TPM2 enrollment, add one using the LUKS passphrase:

```bash
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=7 \
  "$luks_device"
sudo reboot
```

PCR 7 binds unlocking to the Secure Boot policy; this configuration does not
set up Secure Boot or signed kernel images. Keep the passphrase slot: changes
to that policy can require recovery and re-enrollment. No rebuild is needed
solely for enrollment.
