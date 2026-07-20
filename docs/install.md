# Installing and provisioning a host

This document covers the procedures that put a machine into the fleet and keep its secrets readable.

- [Installing a host from the live ISO](#installing-a-host-from-the-live-iso), the destructive one-shot that turns a host in this flake into a running, encrypted machine.
- [Provisioning an already-running host](#provisioning-an-already-running-host), done live on the machine with no reimage.
- [Editing secrets](#editing-secrets), the day-to-day workflow.
- [Recovering a wrongly-provisioned machine](#recovering-a-wrongly-provisioned-machine) from the live ISO.

The install is destructive: it formats the target disk in full.
Read it end to end before starting, because on a single-machine fleet the reimage is irreversible.

## What arrives by hand

Exactly one secret is entered by hand: the **LUKS passphrase** that encrypts the disk, typed when the disk is formatted and again at every boot.

Everything else arrives declared.
The login password is a `sops`-encrypted secret consumed through `hashedPasswordFile`, and the SSH host keys are restored from secrets rather than generated.
No password is set interactively at any point, and `users.mutableUsers = false` means one set by hand would be ignored anyway.

## Identity before first boot

A machine reads its secrets with an **age identity** at `/var/lib/sops-nix/key.txt` on its encrypted root.
Its public half must be registered as a recipient of every secrets file the machine needs, and the re-keyed files must be in the flake's git tree when the system is built, because the ciphertext is baked into the store.

**A host's identity is therefore generated and registered before its first boot, not after it.**
The login password arrives only from a decrypted secret and there is no fallback credential — no interactive password, no unlocked root account, no authorized SSH key.
A first boot without a registered identity cannot decrypt the password hash, so the account it would log in as has no usable password and the machine has no way in short of the [recovery procedure](#recovering-a-wrongly-provisioned-machine).

Identities come in two tiers.
The **admin identity** lives in Proton Pass, is a recipient of every file, and is the credential that authorizes registering a new host.
Each **host identity** is generated on its own machine, never transmitted, and reads only that machine's file plus the shared one.
A host identity is deliberately not derived from the machine's SSH host key, which is what frees those host keys to be secrets in their own right.

## Tooling

Neither `sops` nor `age` is installed by this flake.
Run them from nixpkgs as needed:

```console
$ nix run nixpkgs#sops -- <args>
$ nix shell nixpkgs#age -c age-keygen <args>
```

On the live ISO these need `--extra-experimental-features 'nix-command flakes'`, since the ISO's daemon has neither enabled.

## Installing a host from the live ISO

### 0. Push the repo to Gitea

From your working checkout, make sure `main` is committed and pushed to the Gitea remote:

```console
$ git push origin main
```

The clone in step 2 sees only what has been pushed, so anything left behind in your working checkout will not reach the machine.
Changes made inside that clone afterwards are a separate matter — step 4 makes one there deliberately.

### 1. Boot the live ISO and join wifi

Boot from a NixOS live ISO (the minimal installer is enough).
The installer logs in as the `nixos` user, who has passwordless `sudo`.

On the minimal ISO, bring up wifi with `wpa_supplicant`:

```console
$ sudo systemctl start wpa_supplicant
$ wpa_cli
> add_network
0
> set_network 0 ssid "YOUR_SSID"
> set_network 0 psk "YOUR_WIFI_PASSWORD"
> enable_network 0
> quit
```

On the graphical ISO, which ships NetworkManager, use `nmcli` instead:

```console
$ nmcli device wifi connect "YOUR_SSID" password "YOUR_WIFI_PASSWORD"
```

Confirm you have connectivity (`ping -c1 github.com`) before continuing.

### 2. Clone the repo locally

Clone this repo onto the live ISO and work from that local checkout:

```console
$ git clone ssh://gitea@git.alexion.dev:2022/alexion/dotfiles.git
$ cd dotfiles
```

Cloning over SSH needs your Gitea SSH key present in the live session, since the ISO starts with none.
If getting the key onto the ISO is inconvenient, clone over HTTPS instead and tell git to skip the self-signed certificate:

```console
$ git -c http.sslVerify=false clone https://git.alexion.dev/alexion/dotfiles.git
$ cd dotfiles
```

Do **not** point `disko-install` straight at the Gitea flake URL.
Gitea serves HTTPS with a self-signed certificate and expects authentication, and Nix's flake fetcher has no easy way to skip certificate verification or supply those credentials mid-install.
A plain `git clone` sidesteps that entirely — over SSH there is no TLS, and over HTTPS git takes the `sslVerify=false` above that the flake fetcher won't — and then `disko-install` consumes the flake from a local path, where no fetch of our repo happens during the build.
(Every other flake input is public and still fetched from GitHub over ordinary, valid TLS; only our own repo is the problem the local clone solves.)

### 3. Generate the host identity

Generate the identity in the live session and keep it there until step 6 writes it onto the installed root:

```console
$ nix shell nixpkgs#age -c age-keygen -o /tmp/key.txt
Public key: age1...
```

`age-keygen` prints the public recipient on generation.
Recover it later from the identity itself if the line scrolls away:

```console
$ nix shell nixpkgs#age -c age-keygen -y /tmp/key.txt
```

The private half never leaves this session except onto the target disk.
Do not copy it into the repo, and do not carry it to another machine.

### 4. Register the recipient and re-key

Add the public recipient to `.sops.yaml` as a named anchor, then list it under every file the host must read:

```yaml
keys:
  - &admin age1m0pk94ysjlw3lmf6pyuv5l5pepvdjss8w0vxjv90dq6ndp02tdgsdwdvue
  - &neogaia age14a04vphzjq74epfrz9a09wjw8lzchtru84awzuq2n45d8f42ychqjs89qe
  - &newhost age1...

creation_rules:
  - path_regex: secrets/shared\.yaml$
    key_groups:
      - age:
          - *admin
          - *neogaia
          - *newhost
```

If the host gets a secrets file of its own, give it a rule too.
`sops` matches a file against these rules to decide who to encrypt it to, and refuses a file no rule matches with `no matching creation rules found`:

```yaml
  - path_regex: secrets/newhost\.yaml$
    key_groups:
      - age:
          - *admin
          - *newhost
```

Then re-key each file you changed, which rewrites its data key for the new recipient list without touching any value:

```console
$ SOPS_AGE_KEY_FILE=/path/to/admin-identity \
    nix run nixpkgs#sops -- updatekeys secrets/shared.yaml
```

Re-keying requires an identity that can already decrypt the file.
The live ISO holds no host identity of its own, so paste the admin identity out of Proton Pass into a file in the live session for this step.

Then populate that file, which needs no existing identity because encrypting only reads recipients:

```console
$ nix run nixpkgs#sops -- secrets/newhost.yaml
```

A host with `modules.ssh.enable` expects one entry per key type, named `ssh-host-<type>-key`, each holding a private key generated with `ssh-keygen -t <type> -N "" -f /tmp/<type>`.
The build fails at evaluation if a declared secret is absent from the file, so a host that enables the daemon without these will not install.
Commit the matching public halves beside the host's configuration in plaintext, since publishing them is their purpose.

Stage everything you changed.
A flake sees only git-tracked files, so an unstaged `secrets/newhost.yaml` is invisible to evaluation even though it exists on disk:

```console
$ git add .sops.yaml secrets/
```

Staging is enough for the build.
The commit comes in step 8, and no push is needed here because the install builds from this local clone.

### 5. Run `disko-install`

Run the install as root from inside the clone:

```console
$ sudo nix --extra-experimental-features 'nix-command flakes' run \
    github:nix-community/disko/latest#disko-install -- \
    --flake .#neogaia \
    --disk main /dev/nvme0n1 \
    --write-efi-boot-entries \
    --option extra-substituters https://nyx-cache.chaotic.cx/ \
    --option extra-trusted-public-keys nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=
```

What each part does:

- `--flake .#neogaia` installs the `neogaia` `Host` from the local clone.
- `--disk main /dev/nvme0n1` maps disko's `main` disk to the NVMe device; it matches the device declared in `hosts/neogaia/disk.nix` and is stated explicitly so there is no doubt about the target.
- `--write-efi-boot-entries` writes the systemd-boot entry into this machine's NVRAM, because the disk stays in the machine it was installed from.
- The two `--option` lines are the important part: they hand the **chaotic binary cache** to the install-time Nix daemon on the live ISO.

The chaotic substituter must be passed here explicitly.
The `nix.settings` in the flake configure the substituters of the *installed* system, not the live ISO's daemon that runs this build; the ISO's daemon has no `substituters` beyond `cache.nixos.org`.
Without these two `--option` flags, the build cannot fetch the prebuilt CachyOS kernel and **compiles `linuxPackages_cachyos` (and its toolchain) from source on the USB stick** — a very long detour that the cache avoids.
Because the install runs as root, and root is a trusted Nix user, the daemon honours these client-supplied substituter settings.

Partway through, disko formats the LUKS container and **prompts for a disk-encryption passphrase**.
This is the passphrase you will type at every boot to unlock the disk; choose it deliberately.

When it finishes it prints `disko-install succeeded`.
`disko-install` unmounts the target filesystem on exit, so nothing is mounted at this point — step 6 remounts it.

### 6. Write the identity onto the installed root

Remount the just-installed system with disko, which reopens the LUKS container (prompting for the passphrase from step 5) and mounts the subvolumes under `/mnt`:

```console
$ sudo nix --extra-experimental-features 'nix-command flakes' run \
    github:nix-community/disko/latest#disko -- \
    --mode mount --flake .#neogaia
```

Then place the identity generated in step 3, owned by root and readable by nobody else:

```console
$ sudo install -d -m 0755 /mnt/var/lib/sops-nix
$ sudo install -m 0400 -o root -g root /tmp/key.txt /mnt/var/lib/sops-nix/key.txt
```

It goes on the root subvolume rather than anywhere mounted later because the password secret is decrypted before user accounts are created, which is earlier than any other mount.

Confirm the identity matches the recipient you registered before rebooting, since this is the last cheap moment to catch a mismatch:

```console
$ sudo nix shell nixpkgs#age -c age-keygen -y /mnt/var/lib/sops-nix/key.txt
```

### 7. Reboot

Unmount and reboot into the installed system:

```console
$ sudo umount -R /mnt
$ sudo reboot
```

Remove the USB stick.
At boot you are prompted for the LUKS passphrase from step 5.
After unlocking, log in at the console as `alexion` with the password from the shared secrets file, and you have a working system with fish, tmux, nvim, and Claude Code.

If the login is rejected, the identity and the registered recipient disagree — see [recovery](#recovering-a-wrongly-provisioned-machine).

### 8. Commit the recipient change

The re-key from step 4 exists only in the live session's clone, which is gone.
From a machine that is already a recipient of the affected files, repeat the `.sops.yaml` edit and re-key, then commit and push:

```console
$ sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
    nix run nixpkgs#sops -- updatekeys secrets/shared.yaml
$ git add .sops.yaml secrets/
$ git commit -m "feat(secrets): register newhost as a recipient"
$ git push origin main
```

Until this lands, the repo's copy of each file has one recipient fewer than the copy the new machine was built from, and the next rebuild from the repo would lock it out.

## Provisioning an already-running host

A machine that is up and running gets its identity live.
There is no reimage and no live ISO, because the running generation is the fallback: if activation fails, the rebuild fails and the machine keeps working as it is.

Generate the identity on the machine itself, straight into place:

```console
$ sudo install -d -m 0755 /var/lib/sops-nix
$ sudo nix shell nixpkgs#age -c age-keygen -o /var/lib/sops-nix/key.txt
$ sudo chmod 0400 /var/lib/sops-nix/key.txt
```

Register the printed public recipient in `.sops.yaml` and re-key each file the host must read, exactly as in [step 4](#4-register-the-recipient-and-re-key), using the admin identity.

Then rebuild:

```console
$ sudo nixos-rebuild switch --flake .#neogaia
```

Activation decrypts the secrets with the new identity.
Confirm they materialized before trusting the change:

```console
$ sudo ls -l /run/secrets/ /run/secrets-for-users/
```

Both directories matter.
Ordinary secrets land in `/run/secrets/`, but a secret marked as needed for user creation is decrypted in an earlier stage and lands in `/run/secrets-for-users/` — which is where the login password hash goes, so it is the one to check before rebooting.

Commit and push the recipient change once the rebuild succeeds.

## Editing secrets

Opening a file decrypts it into an editor and re-encrypts on save:

```console
$ sudo SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
    nix run nixpkgs#sops -- secrets/shared.yaml
```

`sudo` is needed because the identity is mode `0400` and owned by root.

**What the workstation can do alone** is anything to a file it is already a recipient of.
For `neogaia` that is `secrets/shared.yaml` and `secrets/neogaia.yaml`: changing a value, adding a key, and even adding another recipient all work from the host identity, because each only requires decrypting a file the machine can already decrypt.

**What needs the admin identity** is any file the workstation is not a recipient of — another machine's `secrets/<host>.yaml`.
Unlock the admin identity out of Proton Pass for that session and point `SOPS_AGE_KEY_FILE` at it:

```console
$ SOPS_AGE_KEY_FILE=/path/to/admin-identity \
    nix run nixpkgs#sops -- secrets/zeus.yaml
```

That friction is the point.
A workstation that could decrypt every machine's material would make the admin identity ceremonial, and a compromised laptop would carry the whole fleet with it.
The admin identity stays a break-glass credential rather than something sitting unlocked on a machine.

Two changes need more than a save.
Rotating the login password means generating a fresh hash with `mkpasswd`, since `users.mutableUsers = false` makes `passwd` inert, and rebuilding.
Re-keying the SSH host keys restarts `sshd`, which is declared and automatic.

## Recovering a wrongly-provisioned machine

A machine whose identity and registered recipient disagree boots but cannot be logged into: the password hash never decrypts, and there is no fallback credential.
Recovery is from the live ISO.

Boot the ISO, join wifi, and clone the repo as in steps 1 and 2.
Then reopen and mount the encrypted root:

```console
$ sudo nix --extra-experimental-features 'nix-command flakes' run \
    github:nix-community/disko/latest#disko -- \
    --mode mount --flake .#neogaia
```

Read the identity actually on the disk, and compare it against the recipient the repo registered:

```console
$ sudo nix shell nixpkgs#age -c age-keygen -y /mnt/var/lib/sops-nix/key.txt
```

**If the repo's recipient is right and the disk's identity is wrong**, replace the identity with the one that matches and reboot.
Nothing was built against the wrong key, so no rebuild is needed:

```console
$ sudo install -m 0400 -o root -g root /path/to/correct-key.txt /mnt/var/lib/sops-nix/key.txt
$ sudo umount -R /mnt && sudo reboot
```

**If the disk's identity is right and the repo's recipient is wrong**, re-key against the identity on the disk, using the admin identity to decrypt, then rebuild the target from the ISO:

```console
$ SOPS_AGE_KEY_FILE=/path/to/admin-identity \
    nix run nixpkgs#sops -- updatekeys secrets/shared.yaml
$ git add .sops.yaml secrets/
$ sudo NIX_CONFIG="experimental-features = nix-command flakes" \
    nixos-install --root /mnt --flake .#neogaia --no-root-password \
    --option extra-substituters https://nyx-cache.chaotic.cx/ \
    --option extra-trusted-public-keys nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=
$ sudo umount -R /mnt && sudo reboot
```

The rebuild is required here and not in the first case, because the secrets file is baked into the system closure at build time.
`nixos-install` reuses the already-formatted disk rather than touching the partition table, so the LUKS container and its passphrase are untouched, and it is idempotent if it fails partway.
The substituter flags matter for the same reason they do during the install: without them the CachyOS kernel is compiled from source on the USB stick.

If neither identity is recoverable, generate a new one as in [step 3](#3-generate-the-host-identity), register it, re-key, and rebuild — the machine's own secrets are lost, but everything encrypted to the admin identity survives.
