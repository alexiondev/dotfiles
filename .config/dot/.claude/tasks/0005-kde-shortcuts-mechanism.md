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

- [ ] An identifier whose rc file is `kglobalshortcutsrc` dispatches to the `kglobalaccel` D-Bus mechanism rather than the schema-backed or freeform paths
- [ ] `dot kde save <identifier>` and `dot kde save` (refresh) read a shortcut's current value via `shortcut(actionId)`, resolving the friendly-name fields dynamically
- [ ] `dot kde apply` writes a declared shortcut via `setShortcut(actionId, keys, NoAutoloading)`, verified manually to take effect immediately in the running session
- [ ] `dot kde diff` reports a declared shortcut mismatch by comparing against `defaultShortcut(actionId)`, verified manually
- [ ] The Spectacle and Lock-Session (`Meta+X`) keybind changes are applied through `dot kde save`/`apply` and tracked in the manifest
- [ ] `keybindings.md` is updated to reflect the new bindings in the same change
