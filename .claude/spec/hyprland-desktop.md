## Problem Statement

Neogaia currently boots to a console only.
The laptop minimum viable install deliberately deferred everything graphical, so the operator works entirely from the terminal (fish, tmux, nvim, Claude Code) with no desktop to live in.

The operator wants a graphical desktop, and it must be primarily keyboard-driven.
Their mental model is i3: numbered workspaces, `Super`+number to switch, manual tiling.
They type on a 60% keyboard where arrow keys and the navigation cluster live behind a layer, so a keyboard-first workflow that never reaches for those keys matters.

The same desktop has to transfer to the future desktop Host (zeus), which must game well and stay low-friction in general.
The operator previously ran KDE Plasma 6 bent into an i3 imitation and valued above all that it "just worked", but remembers past i3/Sway minimalism costing hours of fixing random breakage.
That concern is now largely mitigated: NixOS makes the whole stack declarative, pinned, and reversible, and the agent absorbs the discovery and debugging that used to eat evenings.

## Solution

Add a keyboard-driven Wayland desktop built on Hyprland, expressed as a new grouped set of Modules.
Enable it on neogaia now, and design it Host-agnostic so zeus adopts the identical desktop later by flipping a single flag.

Deliver a complete, daily-drivable session in one pass rather than a bare stub, because unlike the reimage this is fully reversible ("edit and rebuild"), so there is no safety reason to under-scope.
The session covers the compositor, a text login, Nord theming, a status bar, a launcher, notifications, lock and idle, a wallpaper, clipboard history, screenshots, screen recording, and the desktop portals, together with the operator's ported keybinds and input tuning.

Theme the whole graphical layer Nord from a single source (Stylix), scoped so it owns only the new graphical surface and leaves the existing terminal Modules' hand-themes untouched.
Leave gaming out entirely; it belongs to a future zeus-oriented Module, and neogaia is not a gaming machine.

## User Stories

1. As the operator, I want neogaia to boot into a keyboard-driven Hyprland session, so that I can live in a graphical desktop without leaving my keyboard-first workflow.
2. As the operator, I want the desktop expressed as Host-agnostic Modules enabled by a single flag, so that zeus can adopt the identical desktop later without rework.
3. As the operator, I want a text-based login, so that I log in mouse-free without a heavy graphical display manager.
4. As the operator, I want the whole graphical layer themed Nord from one source, so that GTK, Qt, the bar, the lock screen, and the launcher cohere without me hand-theming each, while my existing nvim, tmux, and fish themes stay exactly as they are.
5. As the operator, I want a fast modern terminal launched on `Super+Return`, so that my tmux and nvim stack has a clean frame and my old muscle memory for opening a terminal carries over.
6. As the operator, I want a status bar showing workspaces with per-application icons, clock, battery, network, audio, media controls, and a do-not-disturb toggle, so that I can read system state at a glance.
7. As the operator, I want a search-everything launcher covering applications, open windows, math evaluation, and emoji, reused as the frontend for clipboard history and a power menu, so that one keybound tool handles launching and utility menus.
8. As the operator, I want notification toasts with do-not-disturb and history recall, so that I see notifications and can retrieve ones I missed.
9. As the operator, I want a secure lock screen and idle management, so that going idle, suspending, or closing the lid always lands me at a locked screen, and the lock survives even if the locker process crashes.
10. As the operator, I want a single static Nord wallpaper, so that the desktop looks coherent with no extra moving parts and no battery cost.
11. As the operator, I want clipboard history picked through the launcher, so that I can paste from recent copies entirely by keyboard.
12. As the operator, I want keyboard-driven screenshots for a region, the active window, or the full screen that open in an annotation editor by default and land in both the clipboard and a file, so that capturing and marking up is a single reflex.
13. As the operator, I want a keybound screen recorder that selects a region and then toggles recording, so that capturing demos becomes a habit.
14. As the operator, I want screen sharing to work inside applications, so that video calls and browser screen-share function.
15. As the operator, I want my keybinds ported from my KDE/i3 scheme but expressed entirely in `hjkl` and letters with no arrow or navigation-cluster keys, so that every binding is reachable on my 60% keyboard.
16. As the operator, I want numbered-workspace bindings, so that my i3 muscle memory of `Super`+number to switch and `Super`+`Shift`+number to move carries over unchanged.
17. As the operator, I want Caps mapped to Escape, a US-only layout, snappy key-repeat, and touchpad tap-to-click, natural scroll, and disable-while-typing with flat mouse acceleration, so that input feels like home on the laptop.
18. As the operator, I want subtle animations with rounding and small gaps but no blur on the laptop, so that the desktop feels modern without draining the battery.
19. As the operator, I want the desktop built from granular single-purpose Modules grouped together with an explicit aggregator, so that a Host enables the whole desktop with one flag yet can still override any single piece.
20. As the operator, I want gaming deliberately excluded from this pass, so that neogaia's desktop stays focused and the gaming stack lands with zeus.
21. As the operator, I want the whole Host to still build green under the existing check, so that I gain confidence before switching a live machine.

## Implementation Decisions

**Direction and compositor**

- Hyprland is the compositor, on neogaia now and zeus later, chosen as a single keyboard-driven tiler that serves both Hosts.
  It matches the operator's i3 workflow (numbered workspaces, manual tiling) while getting closest to "just works" among true tilers through its cohesive first-party companion tools and large ecosystem.
- The choice was made over Sway (its minimalism is the very thing that cost the operator evenings), KDE Plasma (mouse-first at heart), and niri (its scrollable-tiling paradigm abandons numbered workspaces and so breaks the operator's core muscle memory).
- The gaming/driver dimension does not discriminate here: neogaia is Intel and zeus is AMD, both of which drive Wayland flawlessly, so the decision rested on workflow and low-friction rather than on surviving a hostile driver.
  This corrects a stale assumption in the laptop spec (see Further Notes).
- Hyprland is sourced from nixpkgs rather than the upstream Hyprland flake.
  The NixOS-level program integration owns the session, portals, and polkit, and home-manager owns the user configuration, sharing one Hyprland package so there is never a version split.
  The session is launched through the universal Wayland session manager from the greeter for clean systemd session and environment integration.
  No compositor plugins are adopted this pass, which removes the main reason to take the flake; moving to the flake later is a contained change that mirrors the existing chaotic-nyx pattern (an input that must not follow nixpkgs, with its own binary cache).

**Session and theming**

- Login uses greetd with the tuigreet text greeter.
  This is mouse-free and lightweight, avoiding a heavy graphical display manager and its Qt/GTK weight.
- Theming uses Stylix, scoped to the graphical layer.
  A single Nord base16 scheme drives colors, system fonts, cursor, and the static wallpaper across the new graphical surface (GTK, Qt, bar, lock, launcher, notifications, compositor colors).
  Stylix targets for the existing terminal tools (nvim, tmux, fish) are left off so their established hand-themes stand unchanged.
  The terminal is themed by Stylix where its target is mature, with hand-written Nord as a fallback otherwise.
  This decision is highly reversible: Stylix toggles per target, so the graphical layer can migrate toward or away from manual theming later at low cost.

**Components**

- Terminal: Ghostty.
- Status bar: Waybar, showing workspaces with per-application icons plus clock, battery, network, audio, MPRIS media controls, and a do-not-disturb toggle.
  No overview/exposé plugin is used; the workspace indicators are sufficient.
- Launcher: rofi (the Wayland fork), combining application-run, binary-run, and window-switch modes into one prompt, plus math-evaluation and emoji modes.
  It is reused as the dmenu-style frontend for clipboard history and a power menu, so one tool serves several jobs.
- Notifications: mako, with do-not-disturb and history recall.
  Media controls and the do-not-disturb toggle live in the bar rather than in a separate notification center.
- Lock and idle: hyprlock and hypridle.
  hyprlock uses the compositor session-lock protocol, so the lock surface is owned by the compositor and survives a locker crash.
  hypridle is wired for lock-on-idle, screen-off, lock-before-suspend, and lid-close, with tunable timeouts.
- Wallpaper: a single static image set by Stylix.
- Clipboard: cliphist with wl-clipboard, storing text and image history, picked through rofi.
- Screenshots: grim and slurp wrapped by grimblast, routed through the satty annotation editor so that annotation is the default on region, active-window, and full-screen captures, each exporting to both the clipboard and a file.
- Screen recording: wf-recorder, region-select-first and video-only (no audio), toggled by a keybind with a bar recording indicator and notifications.
- Portals: the Hyprland desktop portal (screencast, screenshot, global shortcuts) plus the GTK portal (file dialogs and appearance).
  Screen sharing in applications depends on these regardless of whether the recorder is present.

**Keybinds**

The scheme ports the operator's KDE/i3 bindings but is expressed entirely in `hjkl` and letters, with no arrow or navigation-cluster keys, so it is fully reachable on a 60% keyboard.
Bindings that were quick-tile-to-half on the floating KDE desktop are reclaimed for real tiling actions, because that gesture is meaningless in an automatic tiler.

| Action | Bind |
|---|---|
| Switch to workspace N | `Super`+`1`..`9` |
| Move window to workspace N | `Super`+`Shift`+`1`..`9` |
| Move focus | `Super`+`h`/`j`/`k`/`l` |
| Move window in layout | `Super`+`Shift`+`h`/`j`/`k`/`l` |
| Resize | `Super`+`Alt`+`h`/`j`/`k`/`l` |
| Terminal | `Super`+`Return` |
| Launcher | `Super`+`R` |
| Lock | `Super`+`X` |
| Toggle floating | `Super`+`Space` |
| Fullscreen | `Super`+`F` |
| Toggle split | `Super`+`T` |
| Close window | `Super`+`Shift`+`Q` |
| Force-kill | `Super`+`Ctrl`+`Q` |
| Screenshot region / window / full (to satty) | `Super`+`L` / `Super`+`Shift`+`L` / `Super`+`Ctrl`+`L` |
| Clipboard history | `Super`+`Shift`+`V` |
| Record toggle (region first) | `Super`+`Shift`+`R` |
| Volume / brightness / media | `XF86` hardware keys |

**Input**

- US-only keyboard layout, with no layout switcher.
- Caps mapped to Escape, with Shift+Caps still producing a real CapsLock.
- Key-repeat tuned snappy (a short delay before repeat begins, a fast repeat rate).
- Touchpad with tap-to-click, natural scroll, and disable-while-typing.
- Mouse with flat acceleration.

**Feel**

- Tasteful, subtle animations with modest rounding and small gaps.
- Blur is off on the laptop, where it is the single biggest battery cost; it remains a knob a Host such as zeus can enable.

**Module structure**

- The desktop is a set of granular, single-purpose Modules grouped under a desktop directory, each independently toggleable so pieces stay reusable and the files stay focused.
  The tightly coupled Hyprland-native pieces (compositor, lock, idle) are grouped in a subdirectory within that group.
- An explicit aggregator Module turns the desktop on.
  Guarded by its own enable, it sets each piece's enable at default priority so that a Host enables the whole desktop with one flag while retaining the ability to override any single piece.
  The aggregator hand-lists the pieces it enables rather than scanning the directory, so a newly added file stays inert until deliberately added to that list; this keeps the whole desktop legible from one file.
- The desktop's enable options are namespaced under a single desktop group, so a Host's checklist gains one desktop entry and the aggregator itself reads as the sub-checklist of what that entry means.
- This uses the existing recursive Auto-loader as-is: every file in the group is imported unconditionally (inert until enabled), so no Skeleton change is needed.
  The aggregator/namespaced-group pattern is a deliberate evolution of the flat Module plus Host-as-checklist convention (see Further Notes).

## Testing Decisions

- A good test asserts externally-observable evaluation and build success of the whole Host, not the internals of any individual Module.
  This mirrors the laptop MVI's stance, where the config-merge model makes the whole-Host build the meaningful unit and the highest available seam.
- Primary seam (required, existing): the neogaia Host evaluates and its system toplevel builds under the flake check.
  Building the toplevel drives the Auto-loader discovering the new Modules, the aggregator fan-out, home-manager integration, the full Stylix wiring, the Hyprland program integration, and package availability, surfacing nearly all config-authoring errors short of rendering a frame.
- Cheap targeted checks: evaluate specific configuration paths to confirm the desktop aggregator fans out, the Stylix scheme resolves to Nord, and Hyprland is enabled, reusing the repo's existing lightweight eval-probe pattern.
- No Module-level unit tests are added; there is no seam below the whole-Host build worth testing here, and the prior art is the laptop MVI's build-the-toplevel check.
- The genuine end-to-end confirmation is manual and irreducible: switch the configuration on neogaia, log in through the greeter, and exercise the live session (keybinds, lock, screenshot, clipboard, launcher).
  A graphical session cannot self-test headless, but unlike the reimage this is reversible, so verification is done by living in it with a safety net (roll back a generation, drop to a console, or disable the desktop flag).
- VM-based graphical CI (boot assertions under a NixOS test) is deferred, consistent with the laptop MVI's stated stance.

## Out of Scope

- The gaming stack (Steam, gamescope, Proton, replay-buffer recording, OBS), which belongs to a future zeus-oriented Module.
- The zeus Host itself, and multi-monitor/output configuration, since there is no second display to design against yet; monitor focus and move bindings are deferred with it.
- Any non-Hyprland desktop; KDE, Sway, and niri were considered and rejected.
- The upstream Hyprland flake and compositor plugins, including workspace-overview/exposé, which are explicitly not adopted this pass.
- Migrating the existing nvim, tmux, and fish themes into Stylix; they stay hand-themed.
- Dynamic, animated, or video wallpaper, and wallpaper cycling.
- Screen-recording audio and a full-screen recording variant.
- A slide-out notification-center panel and a batteries-included desktop panel; both were considered and rejected in favor of the minimal, Stylix-coherent stack.
- Any change to the Skeleton or the Auto-loader; the structure uses them unchanged.
- Any secret wiring.

## Further Notes

- The compositor decision (Hyprland over Sway, KDE, and niri) is hard to reverse and the result of a real trade-off, so it should be recorded as an ADR.
- The aggregator plus namespaced-group Module pattern is a deliberate departure from the flat, Host-as-full-checklist convention, and is worth recording as a short ADR or a conventions note so its intent is not relearned.
- The laptop MVI's out-of-scope line attributing Nvidia to zeus is factually wrong: zeus runs an AMD GPU, and Raichu (a server with no desktop) is the only Nvidia machine.
  The laptop MVI is a historical document and is left unchanged, so the accurate fact is recorded here and in ADR 0003 instead.
- The ported keybind scheme is derived from the operator's prior KDE Plasma 6 configuration (nine numbered desktops, `Super`+number bindings, a terminal on `Super`+`Return`, Caps mapped to Escape, and custom per-desktop tile layouts), which lives in this repo's git history under the old reference config.
- Neogaia is Intel and zeus is AMD, both of which drive Wayland without driver caveats; this is what lets one keyboard-first compositor serve both Hosts rather than forcing a per-Host divergence.
