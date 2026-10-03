# NixOS installation guide

## 1. Boot the installer

Boot the NixOS installer and, from its local console, open a root shell and set
a temporary root password:

```bash
sudo -i
passwd root
```

Start the SSH server and prepare a temporary directory for the bootstrap files:

```bash
systemctl start sshd
install -d -m 0700 /run/bootstrap
```

Find the installer's IP address:

```bash
ip -br -4 address
```

From another computer, copy the existing agenix identity to the installer and
connect over SSH. Replace `nixos` with the IP address found above:

```bash
scp /path/to/id_ed25519_agenix root@nixos:/run/bootstrap/id_ed25519_agenix
ssh root@nixos
```

Start a temporary shell containing Git and OpenSSH:

```bash
nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#git nixpkgs#openssh
```

Clone this repository and enter its directory:

```bash
git clone git@github.com:Vaelmyr/nix-config.git /root/nix-config
cd /root/nix-config
```

Set the correct permissions on the agenix identity, start a new SSH agent, and
load the key:

```bash
chown root:root /run/bootstrap/id_ed25519_agenix
chmod 0600 /run/bootstrap/id_ed25519_agenix

eval "$(ssh-agent -a /run/bootstrap/ssh-agent.sock -s)"
ssh-add /run/bootstrap/id_ed25519_agenix
```

Verify that the same identity can access the private `nix-secrets` repository:

```bash
git ls-remote ssh://git@github.com/Vaelmyr/nix-secrets.git HEAD
```

Keep this shell open for the installation so Nix can continue to use the SSH
agent.

## 2. Install with disko-install

> [!WARNING]
> The following command formats the selected disk. Verify the device and make
> sure a current backup exists before continuing.

Run the installation from the repository directory:

```bash
nix \
  --extra-experimental-features 'nix-command flakes' \
  run --inputs-from . disko#disko-install -- \
    --flake .#fenrir \
    --disk main /dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_AA221223NV01kG05593 \
    --write-efi-boot-entries \
    --extra-files /run/bootstrap/id_ed25519_agenix /var/lib/agenix/id_ed25519_agenix
```

When prompted, choose a LUKS encryption passphrase:

```text
Enter password for /dev/disk/by-partlabel/disk-main-root:
```

Keep this passphrase as a recovery method. After the installation completes,
reboot into the installed system.

## 3. Enroll TPM2 on the installed system

Finalize the intended Secure Boot configuration before enrolling the TPM.
Then check the available TPM and inspect the configured LUKS2 device:

```bash
luks_device=/dev/disk/by-partlabel/disk-main-root
sudo systemd-cryptenroll --tpm2-device=list
sudo cryptsetup luksDump "$luks_device"
```

If the device does not already have a TPM2 enrollment, add one using the LUKS
passphrase:

```bash
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=7 \
  "$luks_device"
```

PCR 7 binds automatic unlocking to the Secure Boot policy. This enrollment does
not configure Secure Boot or sign kernel images. Keep the passphrase slot:
changes to the Secure Boot policy may require recovery with the passphrase and
TPM re-enrollment. No NixOS rebuild is required solely for TPM enrollment.

## 4. Enjoy your system

Now you can restart into your freshly installed NixOS:

```bash
sudo reboot
```
