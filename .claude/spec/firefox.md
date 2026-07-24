## Problem Statement

Neogaia now boots into the keyboard-driven Hyprland desktop, but the session ships no web browser.
The operator lives in this desktop daily and needs a browser, yet a stock browser install would arrive un-themed, telemetry-on, cluttered with sponsored surfaces, and requiring a round of manual clicking to reach a usable state.
That manual state would also be invisible to the flake and would not survive a reimage or transfer to the future desktop Host.

The operator wants the browser configured the same way as the rest of the system: declared once, hardened and themed by default, and reproduced automatically on any Host that runs the desktop.

## Solution

Add Firefox as a new single-purpose desktop Module, configured entirely through home-manager's `programs.firefox`, and fold it into the desktop aggregator so the browser is part of the daily-drivable session rather than a separate opt-in.

Ship stock mainline Firefox, hardened and de-monetized through locked enterprise policies, with a small fixed set of extensions force-installed by policy from Mozilla's add-on site.
Default search to DuckDuckGo over a lean, pruned engine list.
Theme the browser Nord from the same single Stylix source that themes the rest of the graphical layer, with no hand-maintained browser CSS.
Register Firefox as the system default handler for web links.

Leave the most personal, frequently-changing state — bookmarks and container tabs — to Firefox's own runtime management rather than declaring it, keeping the Module lean and avoiding the destructive overwrite those declarative options impose.

Because the Module joins the aggregator, it comes up on any Host with the desktop enabled: neogaia now, and the future desktop Host for free, with no per-Host browser flag.

## User Stories

1. As the operator, I want a web browser present the moment the desktop comes up, so that a daily-drivable session includes browsing without a separate install step.
2. As the operator, I want the browser expressed as one more enable in the desktop aggregator, so that any Host running the desktop inherits it and the future desktop Host adopts it without rework.
3. As the operator, I want the browser configured declaratively alongside every other Module, so that it is reproduced identically on reimage and never depends on manual post-install clicking.
4. As the operator, I want to stay on current mainline Firefox rather than an older release train, so that I get up-to-date browser features and security without maintaining an unusual package variant.
5. As the operator, I want a fixed set of extensions installed and actually enabled automatically, so that ad-blocking, password management, and sponsor-skipping work on first launch with no add-on hunting.
6. As the operator, I want ad and content blocking, so that pages are lighter and less hostile.
7. As the operator, I want my password manager available in the browser, so that credentials autofill without me reaching for another app.
8. As the operator, I want sponsor segments skipped in videos, so that watching is uninterrupted.
9. As the operator, I want telemetry, studies, the read-it-later widget, and the sponsored surfaces on the new-tab and address bar turned off and kept off, so that the browser is quiet, private, and un-monetized without me policing settings.
10. As the operator, I want the browser to stop offering to save logins and to stop nagging about being the default, so that it does not fight the password manager or interrupt me.
11. As the operator, I want Firefox accounts and sync disabled, so that no account surface appears for a feature I do not use.
12. As the operator, I want DuckDuckGo as the default search with only a lean set of engines present, so that search is private and uncluttered.
13. As the operator, I want the browser themed Nord from the same source as the rest of the desktop, so that it coheres with the bar, launcher, and lock screen without me hand-theming it.
14. As the operator, I want the browser registered as the system default for web links, so that links opened from the bar, notifications, the launcher, or the terminal land in it.
15. As the operator, I want bookmarks and container tabs left to the browser itself, so that the things I add in the moment are never wiped by a rebuild.
16. As the operator, I want the whole Host to still build green under the existing check, so that I gain confidence before switching a live machine.

## Implementation Decisions

**Module and placement**

- A new single-purpose Module is added under the desktop group, namespaced to mirror its location per the Namespace convention, exposing one `enable` option guarded by the Enable convention.
- The Module is configured entirely through the primary user's home-manager `programs.firefox`, matching every other user-facing Module in the repo; no NixOS-level Firefox program integration and no manual package override are used.
- The desktop aggregator turns the Module on at default priority alongside the terminal and the other session pieces, so a single desktop flag brings the browser up while a Host retains the ability to override it.
  The browser is treated as an essential application of the session rather than optional plumbing, following the precedent that the aggregator already enables the terminal.

**Package variant and extension mechanism**

- The package is stock mainline Firefox, not ESR, unbranded, or Developer Edition.
- Extensions are installed through Mozilla's enterprise policy `force_installed`, keyed by add-on id with an install URL, so the browser fetches the signed add-on from Mozilla's add-on site and enables it automatically.
- Nix-built or hash-pinned add-on packages are not used, because stock Firefox refuses unsigned locally-built add-ons; the trade-off — losing build-time reproducibility of the extension binaries in exchange for current mainline Firefox with add-ons that are actually enabled and no new flake input — is accepted deliberately.
  This decision is the pivotal, hard-to-reverse one and is called out for an ADR in Further Notes.

**Extensions**

- Three extensions are force-installed: an ad and content blocker, the operator's password manager, and a video sponsor-skipper.
- All three are self-contained web extensions, so no native messaging host is wired.

**Hardening**

- Hardening is split across two mechanisms by intent: things with a corresponding enterprise policy are set as locked policies so they cannot be toggled back in the UI, and the remainder are set as ordinary profile preferences.
- Locked policies turn off telemetry and studies and data reporting, turn off the read-it-later widget, stop the browser offering to save logins, stop the default-browser check, strip the sponsored shortcuts, sponsored stories, and snippets from the new-tab page, and disable Firefox accounts and sync.
- Profile preferences turn off sponsored address-bar suggestions and tidy the new-tab surface.
- Fingerprinting resistance is deliberately left off, because it breaks enough everyday browsing to be a deliberate per-need choice rather than a baseline.

**Search**

- A single profile is declared, named as the default profile.
- The default engine is DuckDuckGo, and the engine list is pruned to a lean set with the general-purpose commercial engines removed; the removed engines remain reachable through DuckDuckGo's bang syntax.
- Declaring search requires the module's authoritative-overwrite acknowledgement, so engines added later through the UI are not preserved across a rebuild; this is accepted as the point of declaring search.

**Theming**

- The browser is themed by enabling the Stylix Firefox target against the declared profile, driven from the same single Nord scheme that themes the rest of the graphical layer.
- No hand-written browser chrome CSS is shipped; a small chrome-CSS layer remains a later addition on top of Stylix if deeper chrome restyling is ever wanted.
- The Firefox Stylix target is enabled from within the browser Module, mirroring how the theming Module already sets per-Module Stylix targets, so the target only takes effect when the browser is enabled.

**Default browser**

- Firefox is registered as the default handler for the web-link schemes and HTML through the primary user's home-manager mime-association config, placed in the browser Module.

**Existing conventions already satisfied**

- The Waybar workspace indicator already carries a window-rewrite icon mapping for Firefox, so the graphical-application icon convention needs no change.

## Testing Decisions

- A good test asserts externally-observable evaluation and build success of the whole Host, not the internals of the Module.
  This mirrors the desktop and laptop-MVI stance, where the config-merge model makes the whole-Host build the meaningful unit and the highest available seam.
- Primary seam, required and existing: the neogaia Host evaluates and its system toplevel builds under the flake check.
  Building the toplevel drives the Auto-loader discovering the new Module, the aggregator fan-out, home-manager wrapping the Firefox package with the policies, extensions, search, and preferences baked in, the Stylix Firefox target wiring, and the default-handler association, surfacing nearly all config-authoring errors short of launching the browser.
- Cheap targeted checks: evaluate specific configuration paths to confirm the aggregator fans the browser enable out, the rendered policies carry the three force-installed extensions, the default search engine resolves to DuckDuckGo, and the Stylix Firefox target is on, reusing the repo's existing lightweight eval-probe pattern.
- No Module-level unit tests are added; there is no seam below the whole-Host build worth testing here, and the prior art is the desktop and laptop-MVI build-the-toplevel checks.
- The genuine end-to-end confirmation is manual and irreducible: switch the configuration on neogaia, launch the browser, and confirm the three extensions are present and enabled, the Nord theme is applied, DuckDuckGo is the default search, and a link opened from another application lands in the browser.
  A browser cannot self-test headless, but unlike a reimage this is reversible, so verification is done by living in it with a safety net of a generation rollback or the desktop flag.
- The build validates that the policy document is well-formed and baked into the package, but not that Firefox accepts every policy key semantically, since the policy document is only text until the browser loads it; that last mile is part of the manual confirmation.

## Out of Scope

- ESR, unbranded, and Developer Edition Firefox variants, and the nix-built or hash-pinned add-on path they would enable; the reproducibility trade-off was weighed and declined.
- Native messaging hosts of any kind, including a password-manager native connector and desktop browser-integration bridges; none of the chosen extensions need one.
- Declarative bookmarks and declarative container tabs, both deliberately left to the browser's own runtime state.
- The Multi-Account Containers extension and the contextual-identity preference it relies on.
- Multiple Firefox profiles; a single default profile carries everything.
- Custom or Nix-oriented search engines beyond the lean pruned set.
- Hand-written browser chrome CSS and any deep chrome-layout restyling such as compact tabs or a hidden title bar.
- Fingerprinting resistance and any harder privacy posture that routinely breaks everyday browsing.
- Firefox accounts and sync.
- Any second browser, and any per-Host browser divergence; the future desktop Host inherits this same Module unchanged.
- Any Skeleton, Auto-loader, or secret-wiring change; the Module uses the existing plumbing unchanged.

## Further Notes

- The stock-Firefox-plus-policy-extensions decision is hard to reverse — the variant dictates the entire extension mechanism — surprising without context, since a Nix-purist default would expect hash-pinned add-on packages, and the product of a real trade-off between reproducibility and current mainline Firefox with working extensions.
  It should be recorded as an ADR.
- Home-manager's `programs.firefox` was confirmed to expose a top-level policies option that merges into the wrapper's enterprise policies, which is what lets the whole Module, hardening included, live under home-manager rather than needing the NixOS-level program integration.
- The declarative search, bookmarks, and containers options all share one authoritative-overwrite model: the browser owns those files at runtime, so declaring them means home-manager overwrites them wholesale and runtime-added entries do not survive a rebuild.
  This is why bookmarks and containers are left out and why declaring search is an explicit acknowledgement.
- The extension set fetches signed add-ons from Mozilla's add-on site at runtime rather than from the Nix store, so first launch after a fresh build needs network to populate the extensions; this is inherent to the policy-based path chosen over the pinned-package path.
