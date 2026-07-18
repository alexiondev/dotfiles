# Current environment profile — `neogaia` (CachyOS)

A reconstruction of the live CachyOS environment on the laptop, captured before the NixOS migration.
This exists to define what "replicate as closely as possible" concretely means, and to feed the desktop-environment grill branch later.
It is descriptive, not a plan — nothing here is a decision.

Source: the snapshot under `reference/home/`, plus `pacman -Qqett` (167 explicit top-level packages; no AUR, no Flatpaks).

## In one line

KDE Plasma 6 on Wayland, hand-configured to behave like an i3-style keyboard-driven tiling setup, wrapped around a tightly-integrated Alacritty + tmux + Neovim terminal workflow themed in Nord.

## Desktop environment & workflow

- **Plasma 6 on Wayland** (Plasma-6 migration markers, Xwayland scaling, powerdevil-6, SDDM via `plasma-login-manager`).
- Configured as a **tiling, keyboard-driven WM**:
  - **9 virtual desktops**; **`Meta+1…9`** switch, **`Meta+Shift+1…9`** send-window (both custom — not Plasma defaults).
  - **KWin built-in tiling** on every desktop, **0.25 / 0.5 / 0.25** columns; `Meta+T` tile editor.
  - **`Meta+Shift+Q`** close window (i3 muscle memory).
  - Quick-tile `Meta+arrows`; overview `Meta+W`; grid `Meta+G`; peek desktop `Meta+D`.
  - **`Caps Lock → Escape`** (`caps:escape_shifted_capslock`).
- Fast animations (`AnimationDurationFactor=0.25`); touchpad clickfinger.

This is effectively *Plasma-as-a-tiling-WM*.
The future desktop branch therefore forks between **Plasma 6 + this exact config** and a **dedicated Wayland tiler** (Hyprland / niri / sway) reproducing the same i3-like behaviour.

## Terminal workflow (the core)

One integrated, SSH-friendly, keyboard-only system:

- **Alacritty** — MesloLGS Nerd Font Mono 12, opacity 0.8, Nord palette, save-to-clipboard, middle-click paste.
- **tmux** — `Ctrl-Space` prefix, vi mode, **OSC52** clipboard, Nord status bar, no plugins.
- **Neovim** — lazy.nvim; leader Space; **OSC52** clipboard; relativenumber; 2-space expandtab; undofile; smartcase; plugins: snacks picker, oil, neogit/gitsigns/diffview, which-key, treesitter, render-markdown, `nord.nvim`.
- Shared idioms: **`Ctrl+hjkl`** navigation across tmux panes and nvim splits; OSC52 everywhere (no `wl-copy`/`xclip`, survives SSH).

## Theming & fonts (not unified — a replication decision point)

- **DE chrome:** Breeze **Dark** — Qt + GTK (`Breeze`, prefer-dark) + `breeze-dark` icons + `breeze_cursors`.
- **Terminals/editor:** **Nord**.
- **micro:** catppuccin-macchiato (a third theme).
- **Installed but inactive:** `cachyos-nord-kde-theme-git` — a Nord Plasma theme is already available, so unifying the DE onto Nord is plausible.
- **Fonts:** UI Noto Sans 14; KDE mono Hack 14; terminal mono MesloLGS Nerd Font Mono. 96 DPI, 1× scale, slight hinting, antialias on, subpixel none.

## Home layout & environment

- Custom short XDG dirs: `~/dwn ~/doc ~/mus ~/pic ~/vid ~/wrk`; desktop hidden at `~/.desktop`; templates/public → `~/.ignoreme`.
- `EDITOR=nvim`; aliases `vi/vim→nvim`, `tmx=tmux new-session -A -s`, `cp -v`.
- git identity: **alexion / contact@alexion.dev**.

## Toolchains (currently impure — likely "exceptions" on NixOS)

- **Rust** via rustup (`~/.cargo`), **bun** (`~/.bun`), **Node** via a manual `~/.local/opt` unpack, **Android SDK** (`~/Android/Sdk`) on PATH.
- On NixOS these want a decision: Nix-native (nixpkgs / fenix / oxalica / etc.) vs. keeping the imperative installers.

## Package inventory (categorised, meaningful subset)

**Terminal / shell / editor:** alacritty, neovim, kate, micro, fish, zsh, claude-code, tea (Gitea CLI), meld.
**Browser:** firefox.
**Dev / infra:** docker, vscodium, base-devel, whisper-cpp-vulkan (backs the open-whispr dictation app).
**KDE apps:** dolphin, ark, kcalc, konsole, gwenview, haruna (mpv-based video), filelight, spectacle (screenshots), kdeconnect, kwalletmanager, partitionmanager, kinfocenter, plasma-systemmonitor, kscreen.
**Media codecs:** vlc-plugins-all, gst-plugins-{bad,ugly,va,pipewire}, gst-libav, libdvdcss, ffmpegthumbs.
**Fonts:** ttf-meslo-nerd, ttf-opensans, cantarell-fonts, noto-fonts-cjk, gsfonts, awesome-terminal-fonts.
**Networking:** networkmanager-openvpn, plasma-nm, wireguard-tools, nfs-utils, iwd, dnsmasq, bind.
**Hardware / firmware:** intel-ucode, intel-media-sdk, linux-firmware, sof-firmware, alsa-*, bluez-* + bluedevil, fwupd, cpupower, power-profiles-daemon, realtime-privileges.
**Filesystem / snapshots:** btrfs-assistant, snapper (`cachyos-snapper-support`), limine-snapper-sync, plus a broad set of fs tools (f2fs/xfs/jfs/nilfs/exfat/lvm2/dmraid) shipped by CachyOS.
**Printing:** cups-pdf, gutenprint, foomatic-db*, system-config-printer (full stack — verify it's actually used).
**CLI utils:** btop, glances, duf, tree, plocate, rsync, wget, unzip/unrar, pv, hwinfo.
**CachyOS-specific (won't port; NixOS equivalents or drop):** cachyos-* (settings, hooks, mirrorlists, kernel-manager, fish/zsh/micro configs, KDE themes, plymouth, wallpapers), cachy-update, shelly, reflector, rebuild-detector.

## Notable current features to consider replicating

- **btrfs + snapper snapshots** integrated into the boot menu (via Limine + `limine-snapper-sync`). On NixOS the analogue is generations (built-in) plus optionally snapper/btrbk for data snapshots — a future decision, not MVI.
- **KDE Connect** (phone integration), **Bluetooth** (bluedevil), **WireGuard** tooling, **Docker**, **KWallet** (PAM-unlocked).
- **Printing stack** fully installed.
- **fwupd** firmware updates.

## Explicitly absent (don't assume from the old NixOS repo)

- **No gaming** — no Steam / Lutris / Wine / Proton on this laptop (the old repo's `neogaia` had Steam; current reality does not). Gaming is a desktop (`zeus`) concern.
- **No Discord / Spotify / Slack** currently installed.
- **No emulation** stack (the old repo's retroarch/3ds/ps2 are not present here).

## Open replication decisions this surfaces (for later grilling)

1. **Plasma 6 Wayland (replicate config)** vs. **dedicated Wayland tiler** (Hyprland/niri/sway).
2. **Theme:** keep Breeze-Dark-DE + Nord-terminals as-is, or unify on Nord (Stylix)?
3. **Toolchains:** Nix-native Rust/Node/bun/Android vs. keep imperative.
4. **btrfs snapshots:** snapper/btrbk on NixOS, or rely on generations alone?
5. **Which apps are actually wanted** on the laptop vs. artefacts of the CachyOS default install (printing, the broad fs-tools set, etc.).
