## What to build

Hand ownership of `neogaia`'s hardware facts to the upstream `nixos-hardware` profile for the Dell XPS 13 9380, replacing settings this repo currently guesses or omits.

The profile is adopted wholesale, including the Intel GPU support it pulls in. Those packages are inert on a machine with no display server, and trimming them would mean diverging from upstream for no present benefit.

Adopting it makes four things true that are false on the running machine today: the laptop suspends into deep S3 rather than s2idle, the redundant PS/2 mouse driver stops loading over the i2c touchpad, thermal management runs, and firmware updates become possible.

The microcode setting the `Host` currently declares is dropped, because the profile provides it as a default keyed off the redistributable firmware setting already enabled here.

## Acceptance criteria

- [ ] `nixos-hardware` is a flake input
- [ ] The Dell XPS 13 9380 profile is imported by the `neogaia` `Host`
- [ ] The `Host`'s own Intel microcode setting is removed, now that the profile supplies it
- [ ] `nix flake check` builds the `neogaia` toplevel
- [ ] Manual confirmation after a rebuild: the default sleep mode is deep rather than s2idle
- [ ] Manual confirmation after a rebuild: the thermal and power management services are active, and the PS/2 mouse driver is no longer loaded
