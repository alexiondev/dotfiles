---
spec: firefox
---

## What to build

Add Firefox as a new single-purpose Module under the desktop group, configured entirely through the primary user's home-manager `programs.firefox`, and fold it into the desktop aggregator so the browser comes up as part of the daily-drivable session on any Host that enables the desktop.

The browser is stock mainline Firefox, hardened and de-monetized through locked enterprise policies, carrying a small fixed set of extensions force-installed by policy from Mozilla's add-on site.
Search defaults to DuckDuckGo over a lean, pruned engine list.
The browser is themed Nord from the same single Stylix source as the rest of the graphical layer, and registered as the system default handler for web links.
Bookmarks and container tabs are deliberately not declared, leaving that state to the browser's own runtime management.

The end-to-end result: a Host with the desktop enabled boots into a session where the browser is present, launchable, themed to match, telemetry-quiet, has its extensions installed and enabled on first launch, uses DuckDuckGo, and receives links opened from other applications.

Scope details, all following the domain conventions (Namespace convention, Enable convention, aggregator fan-out):

- **Module and placement.** One `enable` option namespaced to mirror the file's location under the desktop group, guarded by the Enable convention. Configured only through home-manager `programs.firefox`; no NixOS-level Firefox program integration and no manual package override. The desktop aggregator turns it on at default priority alongside the terminal, so the single desktop flag brings it up while a Host can still override it.
- **Package and extensions.** Stock mainline Firefox, not ESR/unbranded/Developer Edition. The three extensions — an ad and content blocker, the operator's password manager, and a video sponsor-skipper — are installed through the enterprise `force_installed` policy keyed by add-on id with an install URL, so Firefox fetches the signed add-on and enables it automatically. No Nix-built or hash-pinned add-on packages, and no native messaging host.
- **Hardening.** Split by intent: policy-backed items are set as locked policies (telemetry, studies, and data reporting off; read-it-later widget off; offer-to-save-logins off; default-browser check off; sponsored shortcuts, stories, and snippets stripped from the new-tab page; Firefox accounts and sync disabled), and the rest as ordinary profile preferences (sponsored address-bar suggestions off, new-tab surface tidied). Fingerprinting resistance stays off.
- **Search.** A single profile, named the default. DuckDuckGo as the default engine, the engine list pruned to a lean set with the general-purpose commercial engines removed, using the module's authoritative-overwrite acknowledgement.
- **Theming.** Enable the Stylix Firefox target against the declared profile, driven from the shared Nord scheme, set from within this Module (mirroring how the theming Module already sets per-Module Stylix targets). No hand-written browser chrome CSS.
- **Default browser.** Register Firefox as the default handler for the web-link schemes and HTML through the user's home-manager mime-association config, placed in this Module.

Record the pivotal, hard-to-reverse decision — stock Firefox plus policy-installed extensions over an ESR/unbranded build with hash-pinned add-on packages — as an ADR, following the ADR format and the next ADR number.

## Acceptance criteria

- [x] A new Firefox Module exists under the desktop group with a single `enable` option, namespaced to mirror its directory per the Namespace convention and guarded per the Enable convention; `modules.desktop.firefox.enable` resolves.
- [x] The Module is configured only through the primary user's home-manager `programs.firefox`; there is no NixOS-level Firefox program integration and no manual package override.
- [x] The desktop aggregator enables the Module at default priority, so `modules.desktop.enable` brings the browser up and a Host can still override the single flag; neogaia carries it through the desktop flag with no per-Host browser line.
- [x] The package is stock mainline Firefox (not ESR, unbranded, or Developer Edition).
- [x] The three extensions are force-installed via enterprise policy keyed by add-on id with an install URL: the ad and content blocker, the password manager, and the video sponsor-skipper; no native messaging host is declared.
- [x] Locked policies turn off telemetry, studies, and data reporting; turn off the read-it-later widget; stop offer-to-save-logins; stop the default-browser check; strip sponsored shortcuts, stories, and snippets from the new-tab page; and disable Firefox accounts and sync.
- [x] Profile preferences turn off sponsored address-bar suggestions and tidy the new-tab surface; fingerprinting resistance is left off.
- [x] A single default profile is declared with DuckDuckGo as the default search engine and the engine list pruned to a lean set (general-purpose commercial engines removed), using the search authoritative-overwrite acknowledgement.
- [x] The Stylix Firefox target is enabled against the declared profile from within this Module, driven from the shared Nord scheme; no hand-written browser chrome CSS is shipped.
- [x] Firefox is registered as the default handler for the web-link schemes and HTML through the user's home-manager mime-association config.
- [x] An ADR (next number) records the stock-Firefox-plus-policy-extensions decision over an ESR/unbranded build with hash-pinned add-on packages, following the ADR format.
- [x] `nix flake check` builds `checks.x86_64-linux.neogaia` green, with the new file staged so evaluation sees it.
- [-] Manual confirmation on neogaia: after switching, the browser launches with the three extensions present and enabled, the Nord theme applied, DuckDuckGo as default search, and a link opened from another application lands in it.

## Implementation Notes

The module lives at `modules/desktop/firefox.nix`, declares `modules.desktop.firefox.enable`, and is fanned out by the desktop aggregator at `lib.mkDefault true`.
Everything is configured through `home-manager.users.<user>.programs.firefox`, with no NixOS-level program integration and no `package` override, so it stays on stock `pkgs.firefox` (built as `firefox-152.0.6`, the mainline release train).

The three force-installed extensions are keyed by their real add-on ids, verified against Mozilla's AMO API rather than guessed: uBlock Origin (`uBlock0@raymondhill.net`), Proton Pass (`78272b6fa58f4a1abaac99321d503a20@proton.me`), and SponsorBlock (`sponsorBlocker@ajay.app`).
Proton Pass is the operator's password manager, per ADR 0002 and the sops spec.

Search pruning deviated from a first pass that merely omitted the commercial engines.
Omission does not remove them: home-manager's search module writes `search.json.mozlz4`, but Firefox reconciles its locale's app-provided engines back in for any not present in the file, so the general-purpose commercial engines would reappear.
The lean set is instead reached by explicitly hiding them with `<engine>.metaData.hidden = true` (the module's documented builtin-hiding idiom), confirmed by decoding the built `search.json.mozlz4`: it carries `_metaData.hidden` on google, bing, ebay, and amazon, with `defaultEngineId = "ddg"`.
DuckDuckGo and Wikipedia remain visible; the hidden engines stay reachable through DuckDuckGo bangs.
Engines are referenced by their current id form (`ddg`, `google`, …), which the module maps from the old display names — `default = "ddg"` is correct, not `"DuckDuckGo"`.

The decision to ship stock Firefox with policy-installed extensions over an ESR/unbranded build with hash-pinned add-ons is recorded as ADR 0005.

The final acceptance criterion is marked `[-]` rather than `[x]`: it is the irreducible manual confirmation the spec calls out (a browser cannot self-test headless), deferred to the operator on the live machine after switching, not dropped work.
Every automatable check — the whole-Host toplevel build, and eval probes for the aggregator fan-out, the three force-installed ids, the DuckDuckGo default, the hidden commercial engines, the Stylix Firefox target, and the mime handlers — passes.
