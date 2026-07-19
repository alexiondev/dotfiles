## What to build

Hand ownership of `neogaia`'s hardware facts to the upstream `nixos-hardware` profile for the Dell XPS 13 9380, replacing settings this repo currently guesses or omits.

The profile is adopted wholesale, including the Intel GPU support it pulls in. Those packages are inert on a machine with no display server, and trimming them would mean diverging from upstream for no present benefit.

Adopting it makes four things true that are false on the running machine today: the laptop suspends into deep S3 rather than s2idle, the redundant PS/2 mouse driver stops loading over the i2c touchpad, thermal management runs, and firmware updates become possible.

The microcode setting the `Host` currently declares is dropped, because the profile provides it as a default keyed off the redistributable firmware setting already enabled here.

## Acceptance criteria

- [x] `nixos-hardware` is a flake input
- [x] The Dell XPS 13 9380 profile is imported by the `neogaia` `Host`
- [x] The `Host`'s own Intel microcode setting is removed, now that the profile supplies it
- [x] `nix flake check` builds the `neogaia` toplevel
- [x] Manual confirmation after a rebuild: the default sleep mode is deep rather than s2idle
- [x] Manual confirmation after a rebuild: the thermal and power management services are active, and the PS/2 mouse driver is no longer loaded

## Implementation Notes

Both manual criteria were confirmed on the rebooted machine. The selected sleep
mode moved from s2idle to deep, with the kernel parameter visible on the boot
command line; the thermal and power management services came up active; and the
PS/2 mouse module is no longer loaded. The booted system, the running system and
the freshly built toplevel are all the same store path, so these readings come
from this configuration rather than a surviving older generation.

The firmware update service reads as inactive, which is correct rather than a
failure: it is activated on demand over D-Bus. Its unit is present, its refresh
timer is enabled, and its command-line tool is on the path.

The input follows the base nixpkgs. Locking it without that pulled a second
nixpkgs into the lock file, which nothing evaluates — only the NixOS modules are
consumed — and which would drift silently. Following matches every other input
here except chaotic, whose separate pin is deliberate.

Intel microcode updates now rest on the profile's default rather than an explicit
setting here. The default is overridable, so a `Host` that disables redistributable
firmware would silently lose microcode updates too.
