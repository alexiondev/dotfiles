# Migration findings: ~/wrk/dotfiles (old) → ~/.dotfiles (new)

Exploratory session comparing the archived i3/X11/bash dotfiles repo
(`~/wrk/dotfiles`, GitHub, 2023-2025) against the current bare-repo setup
(`~/.dotfiles`, Gitea, started 2026-07-03) on a fresh CachyOS + KDE Plasma
(Wayland) machine. Goal: not a literal port — for each old feature, decide
whether CachyOS/KDE already covers it for free (skip) or whether it needs an
equivalent tracked in the new repo (port). Nothing below has been
implemented yet; this is a planning doc only.

## Resolved — no action needed (already covered by KDE/CachyOS defaults)

- **Package management split** (old: `pacman.gui/nogui` + `aur.gui/nogui` +
  Makefile/aurman installer). New `dot install` + flat `packages/pacman`
  stays as-is — no plan to port the old list wholesale, just add packages as
  needed.
- **Touchpad `xorg.conf`** — `kcminputrc`/System Settings has caused no
  issues; not tracking it.
- **i3 tiling paradigm** (focus-by-direction, split/layout toggle, floating
  toggle, resize, move-by-pixel, gaps, borders) — dropped entirely. No KWin
  tiling script (Polonium/Bismuth/Krohnkite) installed or wanted; primary
  tiling-like workflow now happens in tmux. KDE's native floating +
  quick-tile (`Meta+Arrow`) is accepted as-is.
- **i3 workspace switch/move** (`Super+1-9,0` / `Super+Shift+1-9,0`) —
  already matched by existing KDE defaults: `Meta+1-9` (Switch to Desktop
  N), `Meta+Shift+1-9` i.e. `Meta+!/@/#/...` (Window to Desktop N).
- **Desktop count** — KDE has 9 virtual desktops configured; confirmed
  sufficient, no change to 10.
- **Workspace/window assignment rules** (`assign firefox → ws1`, `plexamp →
  ws10`) — skipped. `kwinrulesrc` stays empty for now.
- **Kill/reload/restart WM keys** — functionally covered by KDE defaults
  (`Alt+F4` close, `Meta+Ctrl+Esc` kill window).
- **Terminal launch** (`Super+Return` → alacritty) — already identically
  bound: `Meta+Return` → Alacritty, confirmed in `kglobalshortcutsrc`.
- **App launcher** (rofi) — superseded by KRunner (default `Alt+Space`/`Alt+F2`).
- **Media keys** (volume, mic mute, play/pause/next/prev) — already covered
  natively via hardware key bindings, exceeding the old `wpctl`+`playerctl`
  setup.
- **Brightness/backlight keys** — already covered via hardware
  `Monitor Brightness Up/Down` bindings (powerdevil).
- **picom, Xresources, dracula color theme** — dropped. Not using dracula
  going forward; kwin compositor replaces picom with no config needed.
- **rofi power menu** (lock/shutdown/restart/switch-user) — covered by
  existing KDE defaults: `Meta+L` (Lock Session), `Ctrl+Alt+Del` (Show
  Logout Screen = full power menu). *Note: `Meta+L` will be reassigned, see
  below — Lock Session needs to move to `Meta+X`.*
- **polybar → Plasma panel** — nearly the entire module set already exists
  as stock, **unmodified** Plasma panel defaults on this machine: workspace
  indicator → Pager applet, battery → Battery applet (machine has `BAT0`),
  backlight → Brightness applet, date/time → Digital Clock applet, volume →
  system tray audio, now-playing → Media Controller applet (present, just
  nothing to show — no MPRIS player installed currently). Only non-exact
  match is polybar's centered window-title label (closest KDE equivalent is
  the icon-only taskbar) — decided not worth adding a dedicated Window Title
  applet. Whole row needs no tracking; see also the panel-layout finding
  below (it's CachyOS's own shipped default, reproduces automatically).

## Resolved — needs porting (design agreed, not yet built)

- **Extra groups** (old: `.extra_groups` → `video`, `docker` via
  `setup_users` in `bin/dot init`). Missing in new repo; not urgently needed
  yet but a real gap.
  - **Architecture decision**: new `dot` subcommand, e.g. `dot setup` (name
    tentative), separate from `dot init`. `dot init` stays scoped to the
    one-shot bootstrap (clone + checkout) and explicitly refuses to re-run;
    `dot setup` is idempotent/re-runnable and is the new home for
    machine-setup tasks (extra groups, folder layout, future ones), mirroring
    the old `bin/dot init`'s `setup_users`/`setup_folders` sub-task split.
- **Folder naming / XDG dirs** (old: `setup_folders` renamed
  `Desktop→.desktop`, `Documents→doc`, `Downloads→dwn`, `Music→mus`,
  `Pictures→pic`, `Videos→vid`, `Templates/Public→.ignoreme`).
  - **Decision**: restore the short-name convention (better for fish
    autocompletion — shorter shared prefixes, e.g. `doc`/`dwn` only share one
    character vs `Documents`/`Downloads`).
  - Replace old `Projects`-style folder with **`wrk`** (matches the existing
    `~/wrk` directory already in active use, e.g. `~/wrk/dotfiles`).
  - `user-dirs.dirs` currently untracked and diverged (has full names +
    an ad hoc `XDG_PROJECTS_DIR=$HOME/Projects` not in the old file at all).
    Needs to be regenerated to the short-name convention (with `wrk`) and
    then tracked, as part of the `dot setup` folders task.
- **Caps-lock/Escape swap** — user confirmed this needed manual
  configuration (`kxkbrc`: `Options=caps:escape_shifted_capslock`), it is
  **not** a KDE default. Needs tracking. No kcfg schema backs this setting —
  it's a freeform string; "default" = the `Options=` line being absent
  entirely. Simple to declare directly, no diffing tooling needed for this
  one.
- **Screenshots** (old: `Print`/`Ctrl+Print`/`Shift+Print` via `maim`+`xclip`
  → `~/pic/screenshots/`, save + clipboard copy).
  - **New keybinds**: `Meta+L` = full-screen capture, `Ctrl+Meta+L` = select
    region, `Shift+Meta+L` = window capture — all via **Spectacle** (built-in
    capture + clipboard; `maim`/`xclip` not needed, `xclip` isn't even
    installed).
  - **Consequence**: `Meta+L` is currently KDE's default Lock Session
    shortcut — must be freed and Lock Session rebound to **`Meta+X`**.
  - **Folder**: rename Spectacle's default save-folder name from
    `Screenshots` (capital) to lowercase `screenshots`, matching the rest of
    the short-folder convention.
  - **Open detail**: exact Spectacle shortcut action IDs (likely
    `FullScreenScreenShot`, `RectangularRegionScreenShot`,
    `ActiveWindowScreenShot`) need to be verified via System Settings →
    Shortcuts at implementation time — only `CurrentMonitorScreenShot` and
    `OpenWithoutScreenshot` show up in the current `kglobalshortcutsrc` dump
    (both unset), the others aren't customized yet so don't appear there.

## KDE config-tracking architecture (cross-cutting decision)

**Problem**: KDE rc files (`kxkbrc`, `kglobalshortcutsrc`, `kwinrc`,
`plasma-org.kde.plasma.desktop-appletsrc`, `kdeglobals`, etc.) mix real user
intent with large amounts of machine-specific/volatile noise (timestamps,
UUIDs, window state, plugin caches). Whole-file tracking (what naive
dotfiles repos do, e.g. `dnephin/dotfiles`) produces noisy diffs and risks
clobbering machine-specific state.

**Considered and rejected (for now)**: `chezmoi_modify_manager`-style
filtered source-of-truth + merge script. Powerful (tracks a minimal "intent"
INI fragment + per-file ignore/set rules, merges onto the live file), but
it's real tooling to build from scratch outside of chezmoi, and not
justified yet for the ~2 settings currently in scope.

**Decision**: track KDE settings as a declarative list of key/value pairs
applied imperatively via `kwriteconfig6`, run through `dot setup` (or
wherever machine-setup tasks land, see above) — not one-off hand-written
`kwriteconfig6` calls accumulating over time.

**Auto-detection tooling to build** (exploratory design only — not
implemented):

- **Command**: `dot config kde` — deliberately dispatchable, implies a
  `dot config <target>` family with room for non-KDE targets later.
- **Language**: Python 3 (already installed) for XML/kcfg parsing — nested
  `<group>`/`<entry>`/`<default>` structures are painful to parse in
  fish/`xmllint` one-liners. Invoked from a fish wrapper
  (`~/.config/dot/commands/config.fish` → `_dot_config` → sub-dispatch to
  KDE logic), following the existing help-then-argparse /
  `_dot_<name>_usage` convention.
- **Coverage**: as broad as possible across known KDE rc files, not just
  `kwinrc` — files/settings with nothing customized are expected to return
  empty, that's fine.
- **Per-file-type handling** (three different mechanisms, no single
  approach covers everything):
  1. **`kglobalshortcutsrc`** — self-describing, no schema needed. Each line
     is `Action=Current,Default,FriendlyName`; diff field 1 vs field 2,
     report only mismatches. Fully automatic.
  2. **KConfigXT schema-backed settings** — real schemas exist at
     `/usr/share/config.kcfg/*.kcfg` (41 files on this machine) with
     `<default>` tags per `<entry>` inside `<group>` blocks. **Caveat**: not
     every kcfg statically declares its target rc file — some use
     `<kcfgfile arg="true" />` (e.g. `kwin.kcfg`), meaning the target file is
     supplied at runtime by the owning app, not in the XML. Full automatic
     discovery isn't possible in all cases; a curated `(rcfile → [kcfg
     files])` mapping table needs to be hardcoded from domain knowledge —
     confirmed acceptable. Known `kwinrc` mapping so far:
     `virtualdesktopssettings.kcfg`, `kwindecorationsettings.kcfg`,
     `workspaceoptions_kwinsettings.kcfg`, several accessibility kcfg files,
     plus `kwin.kcfg` itself (needs manual mapping, `arg="true"`). For each
     entry: read the live value via
     `kreadconfig6 --file <rcfile> --group <group> --key <key>` and compare
     against the schema's `<default>`.
  3. **Freeform/schema-less string settings** (e.g. `kxkbrc`'s `Options=`
     line) — no kcfg exists; "default" simply means the key/line is absent.
     Trivial, no diffing tooling needed, just declare directly.
  4. **Plasma panel layout** (`plasma-org.kde.plasma.desktop-appletsrc`) —
     not schema-based at all; generated once from a shipped `layout.js`.
     Confirmed CachyOS ships its **own** look-and-feel/layout
     (`/usr/share/plasma/look-and-feel/CachyOS-Nord/`), not vanilla KDE
     Breeze — so the current panel *is* "default" by construction and
     reproduces automatically on any fresh CachyOS install. No tracking
     needed, no diffing possible/necessary.
  5. **Empirical fallback** (not needed yet, noted for completeness): for
     anything not covered by the above, spin up a scratch
     `HOME`/`XDG_CONFIG_HOME`, let the app initialize its config fresh, diff
     against the real file.

**Status**: design only, per explicit instruction — do not implement until
asked.

## Also noted, not yet actioned

- Once any of the above keybind changes are actually made (screenshot
  rebinds, `Meta+L`→`Meta+X` lock move, etc.), remember the project's own
  convention: add/update rows in `~/.github/keybindings.md` for each changed
  keybind, per `~/.config/dot/CLAUDE.md`.

## dot voice — hands-free dictation (shelved, 2026-07-04)

Built and then fully reverted a `dot voice` subcommand for hands-free
dictation into Claude Code: local Silero VAD (torch-free, onnxruntime
only) segmenting mic audio into utterances, each POSTed to a
`whisper-server` instance running remotely on a Proxmox host with an
NVIDIA GPU (Vulkan backend), transcribed text buffered at the cursor via
`ydotool`, submitted on a spoken "send it" and cancelled on "scratch
that".
Iterated through several accuracy levers in one session: dropped then
restored a literal-vocabulary `initial_prompt` (helped once on the
stronger model), a deterministic post-transcription `replacements.txt`
for persistent single-word misses, per-request `temperature`/
`temperature_inc`, beam search (`-bs`/`-bo`, ruled out as a factor),
and a quantization bump from `q5_0` to full fp16 `medium.en` (helped
substantially).
Also fixed a real bug along the way: whisper-server can return multi-
segment text joined by newlines, and `ydotool type` sends an embedded
`\n` as a literal Enter keypress — this was silently submitting partial
dictation mid-sentence. Fixed by collapsing all whitespace before typing.
Despite all of that, real-world accuracy over the laptop's built-in mic
was still not good enough for daily use — small word-substitution and
dropped-word errors persisted even with the best config found (fp16,
no beam search, prompt restored).
**Shelved reason**: audio input quality was the one variable never
tested — everything tuned this session was server/decoding-side. The
user's only better-microphone option is their desktop, which doesn't
have this dotfiles setup yet.
**If resumed**: test with a real microphone (headset/USB) before any
further server-side tuning — it's suspected to matter more than any of
the software changes made so far. Also worth trying `large-v3-turbo`
given the Proxmox GPU had comfortable headroom even at fp16 `medium.en`
(~0.1–0.5s per utterance).
**State**: fully reverted, nothing left in the tree or installed
packages list. The full implementation existed as local commit
`745e417f19a02bc589c5b32853e629993adaa01f` ("dotcli: Voice dictation
software using whisper"), never pushed, then hard-reset away — not
recoverable via normal git history, only via reflog for a limited time
if urgently needed. The KDE global shortcut (`Meta+Ctrl+Space` → `dot
voice arm`) was configured in System Settings and was **not** undone by
this revert — check System Settings → Shortcuts → Custom Shortcuts if
this work is ever picked back up or fully abandoned.
