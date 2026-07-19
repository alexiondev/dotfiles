# Installing `neogaia`

This is the one-shot procedure that turns the `neogaia` `Host` in this flake into a running, encrypted Dell XPS 13 laptop, installed from the NixOS live ISO.

It is destructive: it formats `/dev/nvme0n1` in full.
Read it end to end before starting, because the laptop is the only machine and the reimage is irreversible.

The whole install is a single `disko-install` against the `neogaia` `Host`, followed by setting a bootstrap login password by hand.
Everything the installed system needs — the LUKS layout, the CachyOS kernel, the wifi firmware, the user, and the terminal tooling — is already declared in the flake, so this document is only the mechanics of getting that flake onto the disk.

## Bootstrap ordering

The install consumes the flake from Gitea, so **the flake must already be on Gitea before you start** — the repo cannot pull a config that hasn't been pushed.
The bootstrap login password is likewise set by hand at the end and is **never committed**, which is what keeps the public repo free of any secret while still yielding a working login on first boot.

Two secrets are set by hand during this install, both entered interactively and neither stored in the repo:

1. The **LUKS passphrase** that encrypts the disk, entered when `disko-install` formats it and again at every boot.
2. The **bootstrap login password** for the `alexion` user, set through `nixos-enter` just before the reboot.

## 0. Push the repo to Gitea

From your working checkout, make sure `main` is committed and pushed to the Gitea remote:

```console
$ git push origin main
```

The install reads only committed, git-tracked content, so anything uncommitted will not make it onto the laptop.

## 1. Boot the live ISO and join wifi

Boot the machine from a NixOS live ISO (the minimal installer is enough).
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

## 2. Clone the repo locally

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
(The public flake inputs — `nixpkgs`, `chaotic`, `disko` — are still fetched from GitHub over ordinary, valid TLS; only our own repo is the problem the local clone solves.)

## 3. Run `disko-install`

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
- `--write-efi-boot-entries` writes the systemd-boot entry into this machine's NVRAM, because the disk stays in the laptop it was installed from.
- The two `--option` lines are the important part: they hand the **chaotic binary cache** to the install-time Nix daemon on the live ISO.

The chaotic substituter must be passed here explicitly.
The `nix.settings` in the flake configure the substituters of the *installed* system, not the live ISO's daemon that runs this build; the ISO's daemon has no `substituters` beyond `cache.nixos.org`.
Without these two `--option` flags, the build cannot fetch the prebuilt CachyOS kernel and **compiles `linuxPackages_cachyos` (and its toolchain) from source on the USB stick** — a very long detour that the cache avoids.
Because the install runs as root, and root is a trusted Nix user, the daemon honours these client-supplied substituter settings.

Partway through, disko formats the LUKS container and **prompts for a disk-encryption passphrase**.
This is the passphrase you will type at every boot to unlock the disk; choose it deliberately.

When it finishes it prints `disko-install succeeded`.
`disko-install` unmounts the target filesystem on exit, so nothing is mounted at this point — step 4 remounts it.

## 4. Set the bootstrap login password

The installed system was written with no login password (`nixos-install --no-root-password`, and the flake sets none for `alexion`), so it cannot yet be logged into.
Set a bootstrap password by hand before rebooting.

First remount the just-installed system with disko, which reopens the LUKS container (prompting for the passphrase from step 3) and mounts the subvolumes under `/mnt`:

```console
$ sudo nix --extra-experimental-features 'nix-command flakes' run \
    github:nix-community/disko/latest#disko -- \
    --mode mount --flake .#neogaia
```

Then enter the installed system and set the password for your user:

```console
$ sudo nixos-enter --root /mnt
[nixos-enter]# passwd alexion
[nixos-enter]# exit
```

This password lives only on the laptop's disk; it is **never committed** anywhere.

## 5. Reboot

Unmount and reboot into the installed system:

```console
$ sudo umount -R /mnt
$ sudo reboot
```

Remove the USB stick.
At boot you are prompted for the LUKS passphrase from step 3; after unlocking, log in at the console as `alexion` with the bootstrap password from step 4 and you have a working system with fish, tmux, nvim, and Claude Code.

## First post-boot task

Setting the login password by hand is a bootstrap shortcut, not the end state.
The first thing to do on the running laptop is to move that password to a `hashedPasswordFile` backed by a `sops-nix` secret, so it is declared and reproducible like everything else.

Per ADR 0002, secrets are decrypted by two tiers of age identity: an admin identity held in a password manager, which is a recipient of every secrets file, and a per-`Host` identity generated on that machine's encrypted root.
A `Host` identity is deliberately *not* derived from its SSH host key, which is what allows the SSH host keys to become secrets in their own right and survive a reimage.

That wiring is out of scope here because this procedure is what produces the machine the identity is generated on.

**Once the password is a secret, step 4 of this procedure stops working.**
`hashedPasswordFile` takes precedence over every other password option, so `passwd` under `nixos-enter` no longer yields a login, and no fallback setting can override it.
From that point on, a `Host` must have its identity provisioned and registered as a recipient *before* its first boot, or it boots with no usable password.
Anyone reinstalling after the secrets work lands should follow the secrets provisioning procedure rather than step 4 as written.
