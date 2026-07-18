# reference/

A frozen snapshot of the live CachyOS environment on `neogaia`, captured before the NixOS migration.

This is a **read-only reference**, not part of the flake.
Nothing here is imported or built — it exists so the NixOS rebuild can be diffed against the environment it replaces.
Files mirror their real home paths under `home/` (e.g. `home/.config/nvim/` was `~/.config/nvim/`).

## What's here

- **Terminal / shell / editor:** alacritty, fish (minus `fish_variables`), tmux, nvim, micro (`settings.json` + colorschemes only).
- **Shell RCs:** bash and zsh rc/profile files, `.profile`.
- **KDE Plasma (curated):** the meaningful config (`kdeglobals`, `kwinrc`, `kglobalshortcutsrc`, `kxkbrc`, `kcminputrc`, panel applets, konsole, dolphin, spectacle, power management, monitor layout) — pure runtime state was skipped.
- **Theming / fonts:** gtk-3.0, gtk-4.0, gtkrc-2.0, fontconfig, xsettingsd, Qt config.
- **Misc:** `mimeapps.list`, `user-dirs.dirs`, `shelly/config.json`, `.gitconfig`, `.gitignore`.

## What was deliberately excluded

- **Secrets / keys:** `.ssh`, `.claude*`, `tea` (Gitea token), `kdeconnect` (device keys), `libaccounts-glib`, `kwalletrc`, `.pki`.
- **Browser data:** mozilla profiles.
- **Electron app state:** open-whispr (230M, contained a `.env` and encrypted keys), obsidian (per-vault config lives in each vault), VSCodium (no user `settings.json` existed — only default state).
- **Caches / runtime state:** `.cache`, `.npm`, `.cargo`, `.rustup`, `.local`, `.var`, dconf, pulse, micro's shipped `syntax/` defs, `*.bak`.

## Known cleanups the rebuild must apply

- fish `config.fish` sources CachyOS-only `cachyos-config.fish`, and hardcodes impure `~/.bun` / `~/.local/opt/node` PATHs.
- fish aliases include Arch/pacman-specific entries that don't apply on NixOS.
- The KDE and Arch package-manager (`shelly`) configs are environment-specific and only partially relevant.
