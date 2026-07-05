## Problem Statement

Several KDE settings on this machine have already been changed by hand away from their KDE/CachyOS defaults — the caps-lock/Escape swap is live right now, and screenshot-related keybind changes (Spectacle bindings, moving Lock Session off `Meta+L`) are planned next — but none of this is tracked anywhere in the dotfiles repo. If the machine were rebuilt today, these settings would silently revert to defaults with no record of what needs to be reapplied. There's also no way to notice *unexpected* drift (a setting that changed without the owner deliberately choosing to change it), and no tooling to bring a manually-tweaked setting under tracking without hand-writing one-off `kwriteconfig6`/D-Bus calls — exactly the accumulation of ad hoc scripts the dotfiles project has otherwise avoided.

## Solution

Add a `dot kde` subcommand family with three verbs:

- **`dot kde apply`** — pushes every setting declared in a tracked manifest onto the live KDE session (repo → system).
- **`dot kde diff`** — a broad, read-only scan reporting every live KDE setting that differs from its default, tagging each mismatch as either already-declared (in the manifest) or undeclared (system → discovery, no write).
- **`dot kde save`** — the write path into the manifest (system → repo). Run with no arguments, it refreshes every already-declared entry's stored value from the live system. Run with explicit coordinates, it begins tracking one new setting, seeded from its current live value.

The manifest is a single flat, mechanism-agnostic file: opaque `identifier=value` lines. `dot kde` internally figures out *how* to read/write a given identifier (three different underlying mechanisms exist across KDE's config surface), so the manifest itself never needs to know or care how KDE happens to store that particular setting.

## User Stories

1. As the machine owner, I want to declare that a KDE setting should have a specific value, so that a freshly-built machine ends up with the same intentional deviations from KDE's defaults without me re-discovering and re-typing the underlying `kwriteconfig6`/D-Bus incantations.
2. As the machine owner, I want `dot kde apply` to push all declared settings onto a live session in one idempotent command, so that re-running it after a KDE update or on a new machine is safe and has no unintended side effects.
3. As the machine owner, I want `dot kde diff` to show me every KDE setting currently different from default, so that I can catch drift I didn't intend, not just check the handful of settings I already know about.
4. As the machine owner, I want `dot kde diff`'s output to distinguish "this is already declared and intentional" from "this is undeclared and I've never seen it before," so that the noise of broad scanning doesn't bury genuinely unexpected changes.
5. As the machine owner, I want to run `dot kde save` with no arguments and have every already-tracked setting's manifest value refreshed from whatever is currently live, so that if I tweak a tracked setting by hand (e.g. change a keybind in System Settings) the manifest catches up without me re-typing its identifier.
6. As the machine owner, I want to run `dot kde save` with an explicit identifier to begin tracking one specific setting I just noticed via `diff`, so that I control exactly what enters the manifest instead of everything non-default being swept in at once.
7. As the machine owner, I want global keyboard shortcuts to be read and written through KDE's own shortcut-management service rather than by hand-editing `kglobalshortcutsrc`, so that changes take effect immediately in the running session and I never have to reconstruct KDE's internal triplet bookkeeping (current/default/friendly-name) myself.
8. As the machine owner, I want KConfigXT-schema-backed settings to have their "default" value discovered automatically wherever KDE's schema declares it, so that broad drift-scanning covers as much of the KDE config surface as possible without me manually cataloguing every setting I might ever care about.
9. As a future contributor to this dotfiles repo, I want `dot kde`'s subcommand files to live alongside its Python helper in one place, discoverable the same way every other `dot` subcommand is, so that adding this feature doesn't require bespoke wiring outside the established convention.

## Implementation Decisions

- **Subcommand family**: `dot kde apply` / `dot kde diff` / `dot kde save`, following the project's existing nested-subcommand dispatch convention (each level checks for `help` as its first positional argument before `argparse`, calling its own usage function).
- **`dot kde save` has two modes**:
  - No arguments: iterate every identifier already in the manifest, read its current live value via the appropriate mechanism, and rewrite the manifest with the refreshed value.
  - Explicit coordinates given: read the current live value for that one setting and add it to the manifest as a new declared entry. This is the only way new entries enter the manifest — there is no bulk/"track everything currently non-default" mode, by design, so that curation stays deliberate.
- **`dot kde diff`**: enumerates every setting it knows how to check (see mechanisms below), compares live vs. default, and reports every mismatch. Each reported mismatch is tagged as declared (present in the manifest, i.e. an intentional, already-tracked deviation) or undeclared (never explicitly declared). Diff never writes anything.
- **Manifest**:
  - Location: a flat file directly under `~/.config/dot/` (not nested in a subdirectory — no near-term plan for multiple KDE-like targets that would justify one), named to convey "the set of KDE settings intentionally different from default."
  - Format: plain text, one entry per line, `identifier=value`, split on the *first* `=` only (so values may themselves contain `=`).
  - Identifier scheme: `file.group.key`, split on the first two `.`s only (so the key portion may contain further dots, spaces, or other characters freely — relevant for `kglobalshortcutsrc` action names, which can contain spaces).
  - The manifest carries no mechanism/type discriminator field. It is a pure `identifier → value` map; `dot kde` decides internally how to resolve a given identifier.
- **Three underlying mechanisms**, dispatched purely by inspecting the identifier (no stored metadata):
  1. **Shortcuts** (`kglobalshortcutsrc.<componentUnique>.<actionUnique>`) — resolved not by editing the rc file directly, but through KDE's `kglobalaccel` D-Bus service:
     - Read current value: `shortcut(actionId)`.
     - Read default value: `defaultShortcut(actionId)`.
     - Write: `setShortcut(actionId, keys, flags)` with `flags = NoAutoloading` (so the declared value always wins over any previously-saved shortcut; using the `Autoloading` flag would make `apply` a no-op after the first run).
     - `actionId` is a 4-element list: `[componentUniqueName, actionUniqueName, componentFriendlyName, actionFriendlyName]` (confirmed against KDE's own `actionIdFields` enum and verified live via `gdbus`). Only `componentUnique`/`actionUnique` are stored in the manifest; the two friendly-name fields (needed to actually place the D-Bus call) are resolved dynamically at call time by looking up the component's shortcut list, not stored.
     - No read-modify-write is needed for this mechanism — `setShortcut` only ever touches the live/current value, never the default, so there's no risk of clobbering KDE's own bookkeeping.
  2. **KConfigXT schema-backed settings** (most `kwinrc`, `kdeglobals`, etc. entries) — read/write via `kreadconfig6`/`kwriteconfig6`; the "default" value comes from the setting's `.kcfg` schema.
     - The `(rcfile → [kcfg files])` mapping table is auto-derived at runtime by scanning the system's `.kcfg` schema directory for files that statically declare their target rc file (`<kcfgfile name="...">`), plus a small hand-maintained list for the exceptions that declare `<kcfgfile arg="true">` (i.e. the target file is only known at runtime by the owning app, not in the schema — `kwin.kcfg` is a known example).
     - This mechanism is what enables `diff`'s broad-scan coverage: every entry reachable through the mapping table can be checked automatically, not just entries someone has already thought to add to the manifest.
  3. **Freeform/schema-less settings** (e.g. `kxkbrc`'s `Options=` line) — read/write via `kreadconfig6`/`kwriteconfig6`; there is no schema, so "default" is defined as "the key is absent." Because there's no schema to enumerate from, this mechanism cannot participate in broad undeclared-drift discovery the way schema-backed settings can — it can only be checked for settings that are already declared in the manifest.
  - Mechanism selection for a given identifier: if the rc file is `kglobalshortcutsrc`, use the shortcuts mechanism; otherwise, if the mapping table resolves the `(rcfile, group, key)` to a schema, use the schema-backed mechanism; otherwise, treat it as freeform.
- **File/module layout**: the fish dispatcher and its Python helper live together in one subdirectory under the project's existing commands location, rather than the Python helper sitting as a same-directory sibling of a same-named fish file at the top level.
- **Cross-cutting change to `dot` itself**: the subcommand-discovery mechanism (used both for help-listing and for dispatch) is extended to glob one additional directory level deep, not just the flat top level — required to support the subcommand-plus-helper layout above. This must be updated in both places the discovery logic currently exists (they are intentionally duplicated today rather than shared, for fish-autoload reasons), and applies to any future subcommand that wants a companion file, not just this one.

## Testing Decisions

- **Guiding principle**: tests should exercise this feature's own logic (manifest parsing, identifier dispatch, mapping-table auto-derivation, mechanism selection), not re-verify that external dependencies (`kreadconfig6`, `kwriteconfig6`, the KDE session itself) work correctly.
- **Primary seam**: full CLI invocation of `dot kde apply` / `dot kde diff` / `dot kde save`, run against a scratch `$HOME`, mirroring the existing project convention for testing `dot` subcommands (override `$HOME` per test case, no mocking of the real `kreadconfig6`/`kwriteconfig6` binaries — they run for real against fixture rc files under the scratch home). This covers the schema-backed and freeform mechanisms end-to-end: manifest read/write, identifier parsing, mechanism dispatch, and mapping-table-driven default lookup.
- **New seam introduced for this feature**: the KConfigXT schema directory is normally a fixed system path outside `$HOME`. To make the auto-derivation logic testable without depending on (or mutating) the real system's schema files, the schema directory location must be overridable (e.g. via an environment variable), defaulting to the real system path in normal use and pointing at a small fixture directory of synthetic `.kcfg` files in tests.
- **Deliberately not covered by automated tests**: the shortcuts mechanism (`kglobalaccel` D-Bus calls). It depends on a live, already-running session service that isn't practically substitutable without building dedicated mock infrastructure, which is disproportionate to what it would protect (three D-Bus calls). This path is verified manually against the real session instead.
- **Prior art**: the existing test suite for `dot`'s other subcommands already establishes the scratch-`$HOME`-plus-`fishtape` pattern this feature reuses.

## Out of Scope

- A `dot setup`-style subcommand for machine bootstrap tasks (extra groups, etc.) — considered during planning and set aside as not currently relevant.
- Folder naming / XDG user-dirs conventions — a real, separate piece of planned work, but standalone from `dot kde` and not part of this spec.
- Tracking Plasma's panel layout (`plasma-org.kde.plasma.desktop-appletsrc`) — previously decided this doesn't need tracking, since the current panel is CachyOS's own shipped default and reproduces automatically on a fresh install.
- An "empirical fallback" mechanism (spinning up a scratch config environment to let an app generate its own default config for diffing) — not needed given the three mechanisms above cover everything currently in scope; noted only as a possible future extension if some setting fits none of them.
- A bulk/`--all` mode for `dot kde save` — deliberately excluded so that every new manifest entry is a deliberate choice.
- Interactive picker UX for `diff`/`save` (e.g. selecting an undeclared entry from a list rather than typing its identifier) — not part of this spec.
- `dot voice` (hands-free dictation) — an unrelated, separately shelved piece of work, not touched by this feature.

## Further Notes

- The caps-lock/Escape swap (`kxkbrc`'s `Options=caps:escape_shifted_capslock`) is already live on this machine by hand, unrecorded anywhere — it's a ready-made first real candidate for the explicit-coordinates form of `dot kde save` once built, and a natural first end-to-end smoke test beyond the automated suite.
- The screenshot-related keybind work (Spectacle bindings, moving Lock Session off `Meta+L` to `Meta+X`, renaming Spectacle's save folder) was the original motivating case for this feature but is applied *through* `dot kde apply`/`save` rather than being separate work — once `dot kde` exists, those keybind changes are just manifest entries.
- Per the project's own cross-cutting convention, once any keybind changes are actually applied via this feature, the corresponding rows in the project's keybindings reference document need to be added/updated in the same change.
