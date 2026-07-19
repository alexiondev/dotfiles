---
spec: laptop-mvi
blocked-by: 0001-skeleton-and-building-host
---

## What to build

An nvim `Module` that gives the primary user Neovim configured declaratively through **nixvim**, with **functional parity** to the operator's existing config.
Parity is about the "what" — the same plugins, keymaps, options, colorscheme, and behaviour — not the "how".
The mechanism is deliberately free to follow NixOS's declarative paradigm rather than transplanting the imperative lazy.nvim setup: plugins are managed by Nix (no plugin manager, no runtime cloning, no lockfile), and as much of the config as possible is expressed as typed Nix, with raw Lua kept only as an escape hatch.

## Acceptance criteria

- [x] An nvim `Module` (following the `Enable convention`) is enabled on `neogaia`.
- [x] Neovim is configured via **nixvim**, wired as a flake input (`nixvim.inputs.nixpkgs.follows = "nixpkgs"`), consumed as its home-manager module under `home-manager.users.<user>.programs.nixvim`.
- [x] Functional parity with the previous config: the same plugins (neogit, diffview, gitsigns, oil, snacks, gbprod-nord, render-markdown, which-key, treesitter), keymaps, `vim` options, the `nord` colorscheme, the Neogit blame-toggle autocmd, and markdown concealment — verified headless against the generated config.
- [x] Runtime dependencies `git`, `ripgrep`, and `fd` are provided by Nix; `gcc` is not needed because Nix builds the treesitter grammars.
- [x] The `neogaia` toplevel still builds with the nvim `Module` enabled.

## Implementation Notes

- **nixvim, typed Nix first.** `modules/nvim/nvim.nix` enables `programs.nixvim` with `opts`, `globals`, `keymaps`, and typed `plugins.*` settings. Treesitter uses `plugins.treesitter` (`highlight.enable`, `indent.enable`, `grammarPackages` from the module's own `builtGrammars`) covering nix, lua, bash, fish, markdown, rust, python, java, kotlin, c, cpp, html, css, javascript, typescript, go.
- **The imperative remainder** — the `gbprod/nord.nvim` setup + colorscheme call, the markdown `conceallevel` autocmd, and the Neogit blame-toggle `BufUnload` autocmd — lives in `modules/nvim/config.lua`, pulled in via `extraConfigLua = builtins.readFile ./config.lua`. `gbprod-nord` comes in through `extraPlugins` because nixvim's `colorschemes.nord` is a different plugin.
- **Verification.** `nix build .#…programs.nixvim.build.package` exits 0 and the whole toplevel evaluates. The generated config was exercised headless (launched with `-u` the generated init and a scratch `HOME`, since the wrapper otherwise loads the dev host's real `~/.config/nvim`): all options, keymaps, plugins, the `nord` colorscheme, treesitter highlight + indent, and markdown conceal load with no errors.
