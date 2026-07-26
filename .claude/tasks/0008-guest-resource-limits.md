---
spec: guests
blocked-by: 0002-guest-walking-skeleton
---

## What to build

The Host-side placement that caps a Guest's resources so one misbehaving service cannot starve its Host, plus the boot-start toggle.
A Host sets `limits` — `memory`, `cpu`, and `tasksMax` — applied to the guest's unit, uncapped by default.
A Host sets `autoStart` to control whether the Guest starts at boot, on by default.

## Acceptance criteria

- [x] A Host setting `guests.<path>.limits.memory`, `.cpu`, or `.tasksMax` applies the corresponding cap to the guest's unit.
- [x] Each limit is uncapped when unset.
- [x] `autoStart` starts the Guest at boot by default, and disabling it leaves the Guest defined but not started at boot.
- [x] A Host with a capped Guest builds via `nix flake check`, and the resolved unit caps are verifiable by `nix eval`.

## Implementation Notes

- The caps map to the guest's own systemd unit, `container@<name>.service`, which the container backend generates.
The guest module contributes `serviceConfig.MemoryMax`, `.CPUQuota`, and `.TasksMax`, and the module system merges these with the backend's own `serviceConfig` for that unit.
Only set caps appear: a `filterAttrs` drops any limit left null, so an unset limit contributes no key and systemd keeps its uncapped default rather than the module writing an explicit "infinity".
- `limits.memory` and `limits.cpu` are strings passed through to systemd verbatim (`2G`, `150%`), since systemd already parses size and percentage forms and re-inventing the parsing here would only narrow what the operator can express.
`limits.tasksMax` is a positive int, matching `TasksMax`'s count.
- `autoStart` is now a placement option defaulting true, and the container's `autoStart` reads from it directly rather than the previous `mkDefault true`.
The backend gates `wantedBy = [ "machines.target" ]` on `autoStart`, so `false` leaves the `container@<name>.service` unit fully defined but out of `machines.target` — startable on demand, not at boot — verified by evaluation.
- `neogaia`'s skeleton guest carries modest demonstrative caps (`memory = "1G"`, `cpu = "100%"`, `tasksMax = 512`), following task 0002's precedent of exercising the guest path on this host through its own `nix flake check`.
Its `autoStart` is left at the default so 0002's live boot smoke test is unaffected.
