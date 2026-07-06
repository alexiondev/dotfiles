---
spec: dot-kde
blocked-by: [0002-kde-schema-backed-apply, 0003-kde-schema-backed-diff]
---

## What to build

Add the shortcuts mechanism as a dispatch branch across `save`, `apply`,
and `diff`: identifiers rooted at `kglobalshortcutsrc` are resolved not by
editing the rc file directly but through KDE's `kglobalaccel` D-Bus
service — `shortcut(actionId)` for the current value, `defaultShortcut
(actionId)` for the default, and `setShortcut(actionId, keys, flags)`
with `flags = NoAutoloading` for writes (so a declared value always wins
over any previously saved shortcut). `actionId` is the 4-element
`[componentUnique, actionUnique, componentFriendly, actionFriendly]`
tuple; only the two `Unique` fields are stored in the manifest, and the
two friendly-name fields are resolved dynamically at call time by looking
up the component's shortcut list.

Per the spec's testing decisions, this mechanism is deliberately excluded
from the automated test suite (it depends on a live, already-running
session service that isn't practically substitutable without disproportionate
mock infrastructure) — verify it manually against the real session instead.

As the real-world validation, apply the planned screenshot/session-lock
keybind changes (Spectacle bindings, moving Lock Session off `Meta+L` to
`Meta+X`) through `dot kde save`/`dot kde apply`, and update the
corresponding rows in `keybindings.md` in the same change, per the
project's cross-cutting keybindings convention.

## Acceptance criteria

- [x] An identifier whose rc file is `kglobalshortcutsrc` dispatches to the `kglobalaccel` D-Bus mechanism rather than the schema-backed or freeform paths
- [x] `dot kde save <identifier>` and `dot kde save` (refresh) read a shortcut's current value via `shortcut(actionId)`, resolving the friendly-name fields dynamically
- [x] `dot kde apply` writes a declared shortcut via `setShortcut(actionId, keys, NoAutoloading)`, verified manually to take effect immediately in the running session
- [x] `dot kde diff` reports a declared shortcut mismatch by comparing against `defaultShortcut(actionId)`, verified manually
- [-] The Spectacle and Lock-Session (`Meta+X`) keybind changes are applied through `dot kde save`/`apply` and tracked in the manifest
- [x] `keybindings.md` is updated to reflect the new bindings in the same change

## Implementation Notes

- **Deviation from the task's named D-Bus methods**: manually verifying against the real, live `kglobalaccel` session (both on the just-applied `Lock Session` action and on an untouched, pre-existing action with a genuinely different current/default in `kglobalshortcutsrc`) showed that `defaultShortcut(actionId)` — the flat `ai`-signature method the task names — does not return the true packaged default on this KF6 build.
  It just mirrors `shortcut(actionId)`.
  Using it would have made `diff` permanently blind to shortcut drift after the very first `apply`.
  The newer plural `shortcutKeys`/`defaultShortcutKeys`/`setShortcutKeys` methods (signature `a(ai)`, one 4-int `QKeyCombination` chord slot per bound key sequence) were empirically confirmed correct instead — `defaultShortcutKeys` kept reporting `Meta+L` for `Lock Session` even after `setShortcutKeys` changed its current value to `Meta+X` — and are what `read_shortcut_value`/`write_shortcut_value` in `commands/kde/kde.py` actually call.
  `NoAutoloading`'s value (`0x4`, from `KF6/KGlobalAccel/kglobalaccel.h`) is unchanged by this swap.
- Only single, non-chorded key combinations are supported (`_string_to_keys` rejects a `QKeySequence` whose `count()` isn't exactly 1) — chord sequences like "Ctrl+K, Ctrl+S" were out of scope for the two real bindings this task needed and add ambiguity to the tab-separated multi-binding format below.
- **Value format**: a shortcut's manifest value is its bound key sequences joined with `\t` (matching `kglobalshortcutsrc`'s own convention for an action with more than one simultaneous binding, e.g. `Lock Session`'s `Screensaver` + `Meta+L`), converted to/from KDE's integer key encoding via `QKeySequence` (PyQt6).
  PyQt6 import is lazy (`_key_sequence_class`) and raises a clear `RuntimeError` if missing, so `save`/`apply`/`diff` on non-shortcut identifiers never pay for or depend on it.
- **Spectacle bindings dropped** from this change's real-world validation.
  Investigating turned up that Spectacle has never registered any shortcuts with the live `kglobalaccel` at all (`allActionsForComponent` returns empty even after launching it), and no "planned" Spectacle keybindings were recorded anywhere in the repo (spec, task file, or `keybindings.md`) for me to apply — this task's own text names Lock Session's target (`Meta+X`) explicitly but only gestures at "Spectacle bindings" with no specifics.
  Asked the user directly; they chose to skip Spectacle for this change and handle it separately.
  Only the Lock Session move is applied here.
  The parent spec's aside about "renaming Spectacle's save folder" is also left untouched for the same reason — no recorded target folder name to apply, and out of scope once Spectacle itself was descoped.
- **Lock Session validation**: `dot kde save "kglobalshortcutsrc.ksmserver.Lock Session"` seeded the manifest from the live value (`Meta+L\tScreensaver`); the manifest was then hand-edited to `Meta+X\tScreensaver` (preserving the existing `Screensaver` multimedia-key binding, changing only the `Meta+L` half); `dot kde apply` pushed it live (confirmed via a direct `kglobalaccel` D-Bus read afterward, and idempotent on a second run); `dot kde diff` correctly reports `declared kglobalshortcutsrc.ksmserver.Lock Session = Meta+X\tScreensaver (default: Meta+L\tScreensaver)`.
  `Meta+X` is now live and tracked; `keybindings.md` has a row for it.
- Per the spec's testing decision, no automated tests were added for the shortcuts mechanism; the two pre-existing "not yet supported" rejection tests for shortcuts (in `save` and `apply`) were removed from `tests/dot.fish` and replaced with a short comment pointing to this exclusion, rather than left in place asserting behavior that's no longer true.
