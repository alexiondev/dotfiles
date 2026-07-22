---
status: accepted
---

# Hyprland as the keyboard-driven desktop compositor

The graphical desktop is built on **Hyprland**, a keyboard-driven Wayland tiling compositor, as a single choice serving both the laptop (neogaia) and the future desktop (zeus).
It matches how the operator already works: an i3 model of numbered workspaces and manual tiling, ported to bindings reachable entirely on a 60% keyboard.
Among true tilers it comes closest to "just works" through its cohesive first-party companion tools (lock, idle, wallpaper, portal) and a large ecosystem, which buys down the assembly-and-breakage cost that made past minimal tiling setups expensive for the operator.

The gaming and driver dimension does not constrain the choice, because both Hosts drive Wayland without caveats: neogaia is Intel and zeus is AMD.
Notably zeus is AMD, not Nvidia — Raichu is the only Nvidia machine, and it is a server with no desktop — so no Nvidia-on-Wayland pressure shapes the decision.
With gaming survival off the table, the choice rests on workflow and low-friction rather than on tolerating a hostile driver.

## Considered Options

- **Sway.** Rejected: its i3-faithful minimalism is precisely what historically cost the operator hours of assembly and breakage.
  On AMD it games fine, but its only remaining edge over Hyprland was stability and purity — which the repo's pinning already provides, and which the operator's stated "just works" priority actively discounts.
- **KDE Plasma.** Rejected: the most integrated and lowest-friction option, the best AMD gaming desktop, and the operator's prior environment — but mouse-first at its core and only keyboard-navigable at the margins, which works against the primary keyboard-first requirement.
  Its custom-tile-layout feature is an approximation of tiling on a floating desktop, not real automatic tiling.
- **niri.** Rejected: its scrollable-tiling paradigm abandons numbered workspaces, which breaks the operator's core muscle memory of switching by number.
  It also has the smallest community of the candidates, a low-friction risk for a daily-driver desktop.
- **A different compositor per Host** (a keyboard-pure laptop plus a separate gaming desktop). Rejected: it doubles the configuration and maintenance and defeats the goal of one transferable setup.
  It is unnecessary once AMD removes any gaming penalty from a keyboard-first compositor.

## Consequences

- One desktop Module set serves both Hosts.
  zeus adopts the identical desktop by enabling a single flag, with battery-sensitive knobs such as blur flipped on for its AMD headroom.
- Hyprland's churn and occasional breakage are absorbed by the pinned, declarative, reversible configuration rather than by live fixing, so upgrades happen on the operator's schedule.
- The desktop's lock, idle, keybind syntax, and portal are Hyprland-specific, so a future move to another compositor would be a rewrite rather than a swap.
  This is the accepted cost of the first-party-cohesion benefit.
- Hyprland is taken from nixpkgs, with no compositor plugins this pass.
  Adopting the upstream Hyprland flake later, for a plugin or a bleeding-edge feature, is a contained change that mirrors the existing chaotic-nyx input pattern (an input that must not follow nixpkgs, carrying its own binary cache).
