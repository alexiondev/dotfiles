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
- [ ] Manual confirmation after a rebuild: the default sleep mode is deep rather than s2idle
- [ ] Manual confirmation after a rebuild: the thermal and power management services are active, and the PS/2 mouse driver is no longer loaded

## Implementation Notes

The two manual criteria are left unresolved deliberately, and this task is not
finished until the operator resolves them. Both require a `nixos-rebuild switch`
followed by a **reboot**, neither of which can be performed here: the rebuild
needs root, and the sleep-mode and module-blacklist changes only take effect on a
fresh boot rather than on activation, since the modules in question are already
loaded.

The strongest evidence obtainable short of that reboot was gathered from the
evaluated configuration, and all of it agrees with the intent: the deep-sleep
kernel parameter is present, the PS/2 mouse module is blacklisted, the thermal,
power and firmware services are enabled, and Intel microcode updates remain on
through the profile's default now that the `Host` no longer sets them. That
confirms what was built, not what the machine does.

The input follows the base nixpkgs. Locking it without that pulled a second
nixpkgs into the lock file, which nothing evaluates — only the NixOS modules are
consumed — and which would drift silently. Following matches every other input
here except chaotic, whose separate pin is deliberate.

Verify after rebooting:

    cat /sys/power/mem_sleep          # expect [deep], currently [s2idle] deep
    systemctl is-active thermald tlp  # expect active, currently inactive
    lsmod | grep psmouse              # expect no output, currently loaded
