---
status: accepted
---

# Stock Firefox with policy-installed extensions

The browser Module ships **stock mainline Firefox** (`pkgs.firefox`, the release train), and installs its three extensions — an ad and content blocker, the operator's password manager, and a video sponsor-skipper — through Mozilla's enterprise `ExtensionSettings` policy, keyed by add-on id with an install URL and `installation_mode = "force_installed"`.
Firefox fetches each signed add-on from Mozilla's add-on site at runtime and enables it automatically.

We chose this over an ESR, unbranded, or Developer Edition build carrying hash-pinned add-on packages from the Nix store.
Stock mainline Firefox refuses to load unsigned locally-built add-ons, so the pinned-package path forces the browser variant: it works only on a build that relaxes signature enforcement, which the mainline release does not.
Pairing the variant to the extension mechanism makes this the pivotal, hard-to-reverse decision — the choice of build dictates the whole extension story — so it is recorded here rather than left implicit in the Module.

The trade-off is deliberate.
The policy path gives up build-time reproducibility of the extension binaries, and needs network on first launch to populate them, in exchange for staying on current mainline Firefox with add-ons that are actually enabled and no new flake input.

## Considered Options

- **Stock mainline Firefox with policy-installed extensions** (chosen).
  Current release train, no signature-enforcement caveat, no extra flake input.
  The extension binaries are fetched signed at runtime rather than pinned, so their exact versions are not reproducible from the flake and first launch needs network.
- **ESR or unbranded Firefox with hash-pinned add-on packages** (e.g. via a NUR add-ons input).
  Rejected: it buys reproducible extension binaries but drags in an older or unusual browser variant to satisfy the signature check the mainline build enforces, plus a new flake input to maintain, for a browser the operator wants on the mainline feature and security cadence.
- **Stock Firefox with extensions installed by hand.**
  Rejected: the state would live outside the flake, would not survive a reimage, and defeats the point of declaring the browser at all.

## Consequences

- The Module needs no new flake input and no add-on package set.
  The extension list is three id/URL pairs under the enterprise policy.
- Extension versions are whatever Mozilla currently serves, not a pinned hash, so the browser tracks upstream add-on updates automatically and the flake does not gate them.
- First launch after a fresh build requires network to fetch the add-ons.
  An offline first boot comes up with the extensions not yet present, populating them once online.
- Moving to a pinned-package posture later would mean changing the browser variant as well, since the two are coupled — the reason this is captured as a decision rather than a detail.
