# Authenticating Claude Code without a browser

`neogaia` is driven from the console and over SSH, where no local browser can service Claude Code's default OAuth redirect.
Either of the two paths below signs the CLI in from a bare terminal.
Both are one-time actions per machine; the credentials land under `~/.claude`, which home-manager does not overwrite.

## Paste-code flow (Claude subscription or Console OAuth)

Run `claude` and start the login with the `/login` command (the first run offers it automatically).
On a machine with no browser it cannot open the authorization page itself, so it prints the authorization URL and waits.

1. Copy the printed URL to a browser on any other device (phone, another laptop).
2. Sign in and approve the request there.
3. The page returns a short authorization code; paste it back at the `claude` prompt still waiting in the terminal.

The session then completes and the token is stored, so later runs need no further login.
Because the URL is opened on a *different* device, this works unchanged over SSH.

## API key

For non-interactive use, set an Anthropic API key from <https://console.anthropic.com> in the environment before launching `claude`:

```console
$ export ANTHROPIC_API_KEY=sk-ant-...
$ claude
```

Claude Code reads `ANTHROPIC_API_KEY` on startup and skips the interactive login entirely, so this path needs neither a browser nor the paste-code exchange.
Usage is billed to the Console account that owns the key rather than to a Claude subscription.

The key is a secret and is deliberately not baked into this configuration.
Export it from the shell for a one-off, or source it from a secret store once one exists on the Host.
