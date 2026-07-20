## What to build

Make root-requiring work reachable from an agent session without waiving the password, by sharing sudo's credential cache across sessions and failing loudly when it is cold.

Sudo caches an authentication for a timeout window, but keys that cache by terminal under its default `timestamp_type=tty`.
An agent's commands run in subprocesses on a different terminal, so a `sudo -v` typed in the operator's shell is invisible to them and every privileged command fails.
Setting `timestamp_type=global` keys the cache per user instead, so one authentication covers the whole machine for the window.
The timeout is raised to 60 minutes so a session needing root authenticates once rather than every five.

No `NOPASSWD` rule is introduced, and this is the point of the design.
The password remains genuinely required; only its cache is shared.
A `NOPASSWD` entry for `nixos-rebuild` would be indistinguishable from blanket root on this machine, since anything able to edit the flake and then rebuild it owns the system.

The tradeoff is real and bounded: during the window, any process running as the operator can use the cached credential, not only the agent.
That is acceptable on a single-user personal laptop where the agent already runs as that user, and it is the reason this belongs to a laptop rather than to any future server `Host`.

The second half is failure behaviour.
A cold cache today surfaces as a bare non-zero exit with no output, which reads as an unexplained stall: the operator has to notice the agent is stuck and then work out what it wanted.
A `PreToolUse` hook probing `sudo -n true` turns that into an immediate, actionable refusal naming the command to run.

## Acceptance criteria

- [-] `timestamp_type=global` and a 60-minute timeout are declared as plumbing in the shared base config
- [x] No `NOPASSWD` rule is introduced, and the wheel group still requires a password
- [x] Confirmed that NixOS does not already set `timestamp_type` elsewhere, so the declaration is not silently overridden
- [x] A `PreToolUse` hook in the claude-code `Module` denies a privileged command when the cache is cold, naming `sudo -v` in its message
- [x] The hook's behaviour is correct when the harness sandbox, rather than a cold cache, is what blocks the command
- [x] `nix flake check` builds the `neogaia` toplevel
- [x] Manual confirmation after a rebuild: `sudo -v` in one terminal lets a privileged command succeed from an agent session, and that command fails with the hook's message once the window lapses

## Implementation Notes

**The sudo settings are declared in the claude-code module, not in the shared base config.**
The criterion asking for the shared base contradicted this task's own rationale, which argues the widened cache suits a single-user machine and should not reach a future server.
Neither placement was right, though: the setting and the hook that depends on it belong together.
The hook reads the credential cache from a process of its own, which only works under `timestamp_type=global`, so a host enabling the module without the sudo half would get a hook that never sees a cached credential and refuses every privileged command permanently.
Declaring both under the module's `enable` makes that impossible to get wrong, and carries the setting to any future host that runs the agent.

The cost is that enabling a developer tool now changes the machine's sudo posture, which a reader auditing sudo policy would not expect to find there.
The enable option's description carries the warning so it surfaces in generated documentation.
Should a host ever need the agent without the widened cache, that is when a separate sub-option earns its place; adding one now would be speculative.

**Verified against the running system, in both cache states.**
Cold, the hook refuses with its message; warm, it permits and the command uses a credential authenticated in a different terminal.
The hook process is not itself sandboxed, so it reads the real cache rather than refusing unconditionally — the failure mode that would have required it to fail open instead.

One residual is worth knowing.
The hook governs whether a privileged command is attempted, not whether it can run: the agent's own sandbox blocks `sudo` separately, and swallows it into a bare exit with no output.
A permitted command can therefore still fail for that unrelated reason, and needs the sandbox disabled.
The two are distinguishable in practice, since only one of them produces the hook's message.

**The operator must authenticate from a real terminal.**
Warming the cache from inside an agent session does not work: that shell has no controlling terminal, so sudo cannot prompt and reports `a terminal is required to read the password`.
Feeding the password by another route was rejected rather than unexplored.
Reading it from the agent's stdin would route it through the agent, and an askpass helper on this console-only machine could only prompt on the pane the agent already draws to, which trains the operator to type a password into an agent-controlled surface.
A separate terminal is the only safe channel, which is precisely what the global cache keying exists to make useful.

**`jq` is now a home package.**
The hook parses the tool input handed to it on stdin, and nothing on the profile provided a JSON parser.
Matching on the raw JSON text with `grep` was rejected: a command containing quotes or newlines would break it, and this hook fails closed, so a parsing mistake blocks real work.

**The sudo detection is anchored to command position.**
`grep sudo /etc/passwd` and `echo "run sudo -v"` are allowed; `sudo x`, `cd /tmp && sudo x`, and `true; sudo x` are blocked.
A `sudo` inside a quoted string that happens to sit in command position will still trip the guard, which errs toward asking rather than stalling.
