## Problem Statement

This machine's Neovim config (`~/.config/nvim`, tracked in the `dot` dotfiles repo, using `lazy.nvim` + `nvim-treesitter`) has no Cooklang support today: no filetype detection for `.cook` files, and no highlighting.
Once the standalone `tree-sitter-cooklang` grammar (see the companion spec) exists, this repo's Neovim config needs to be wired up to actually use it.

## Solution

Add a new `lua/plugins/filetypes.lua` to the Neovim config. It registers `.cook` as filetype `cooklang` via `vim.filetype.add`, and extends the existing `nvim-treesitter` plugin spec (currently defined in `ui.lua`) — via `lazy.nvim`'s spec-merging for a single plugin across multiple files — to register the `cooklang` parser's `install_info` and add it to `ensure_installed`.
This lets `nvim-treesitter`'s existing eager-load behavior and `dot setup nvim`'s existing headless bootstrap (`Lazy! restore`, which already drives `ensure_installed` as a side effect) pick up, build, and attach the new parser with no changes to either of those existing mechanisms.

## User Stories

1. As the machine owner, I want opening a `.cook` file to be recognized as filetype `cooklang` automatically, so I don't have to set it by hand.
2. As the machine owner, I want that filetype to get tree-sitter-based syntax highlighting from the from-scratch grammar, so recipes are visually readable.
3. As the machine owner, I want the custom-parser registration to live in its own file (`filetypes.lua`) rather than inside `ui.lua`'s generic colorscheme/treesitter block, so a one-off, filetype-specific hack stays separated from generic editor infrastructure, and any future custom filetype has an established home to go in.
4. As the machine owner, I want `filetypes.lua` to hold both the filetype-detection call and the parser registration together, so "everything about custom filetypes" is one discoverable file, rather than split between a native `ftdetect/` file and a `lua/plugins/` file.
5. As the machine owner, I want this to piggyback on the existing `dot setup nvim` headless bootstrap without requiring any change to that command, so a fresh-machine setup keeps working for this new filetype the same way it already does for every other pinned plugin/parser.
6. As the machine owner, I want no folding or indentation behavior changes for `.cook` files, so this change stays scoped to highlighting only, matching what was actually asked for.
7. As the machine owner, I want to verify the result by opening a real `.cook` file and checking the highlighting by eye (plus `:InspectTree`/`:Inspect` for node-level checks), so I don't have to stand up new automated test infrastructure for one query file in a personal config that has no existing automated-test story of its own.

## Implementation Decisions

- New file: `~/.config/nvim/lua/plugins/filetypes.lua`. No wiring changes needed elsewhere — `lazy.nvim`'s existing `{ import = "plugins" }` spec (in `init.lua`/`plugin.lua`) already imports every file under `lua/plugins/`.
- Top of the file: a plain `vim.filetype.add({ extension = { cook = "cooklang" } })` call, executed as a side effect when the module is required (every file under `lua/plugins/` is required unconditionally as part of `lazy.nvim`'s spec collection, so this runs at startup regardless of any plugin's load timing). Deliberately not using the native `ftdetect/` runtime-directory convention, to keep all custom-filetype logic in the one file.
- Below that: the file's returned plugin-spec table contains one entry for `"nvim-treesitter/nvim-treesitter"` using an `opts` function that merges into the plugin's existing options (already defined in `ui.lua`). `lazy.nvim` supports multiple partial specs for the same plugin across different imported files and merges them — this avoids touching or duplicating the existing spec in `ui.lua`.
- That `opts` function registers the `cooklang` parser via `require("nvim-treesitter.parsers").get_parser_configs()` (setting `install_info.url`/`branch`/`files`, pointing at the companion `tree-sitter-cooklang` spec's eventual repo, and `filetype = "cooklang"`), and appends `"cooklang"` to the existing `ensure_installed` list.
- `install_info.url`/`branch` are placeholders until the companion grammar repo actually exists and is hosted somewhere (see companion spec — hosting is explicitly out of scope there too). Filling these in is a mechanical last step once that repo exists, not a design decision this spec needs to resolve.
- No changes needed to `ui.lua` itself, nor to the `dot setup nvim` command or its spec: `nvim-treesitter` already loads eagerly (no lazy-load trigger), and `dot setup nvim`'s headless `Lazy! restore` already drives `ensure_installed` as a side effect of that eager load (per the existing `dot-setup-nvim` spec). The new `cooklang` entry is automatically picked up by both an interactive launch and a headless `dot setup nvim` run with zero code changes to that command.
- No `after/ftplugin/cooklang.lua` or other filetype-specific settings (e.g. no `conceallevel` override, unlike `markdown.lua`'s) — not requested; scope is highlighting only.

## Testing Decisions

- Manual verification only: open a sample `.cook` file, confirm the expected highlight groups render, use `:InspectTree`/`:Inspect` for node-level spot checks.
- No automated test is added to this Neovim config for this change — the config has no existing automated-test story of its own (unlike the `dot` CLI, which has real `fishtape` coverage). Parsing correctness itself is covered by the companion grammar spec's `canonical.yaml`-derived corpus, which is the appropriate seam for that concern — this integration is a downstream consumer of it, not a place to re-test it.
- The existing `dot setup nvim` `fishtape` coverage (fake-`nvim`-binary pattern) is not extended for this change. It already only asserts "every pinned plugin has a directory," not individual tree-sitter parser success — an intentional, pre-existing scope boundary from the `dot-setup-nvim` spec that this integration doesn't change.

## Out of Scope

- Building the grammar itself (fully covered by the companion `tree-sitter-cooklang` spec).
- Hosting or publishing that grammar repository (the maintainer's own responsibility, not detailed in either spec).
- Any `folds.scm`/`indents.scm`-driven behavior for `.cook` files (deferred, matching the companion spec's scope decision).
- Any change to `dot setup nvim`'s own success-check logic.
- A `~/.github/README.md` command-table row — not applicable, since this isn't a `dot` subcommand.
- Automated highlight-assertion tests for the Neovim config.

## Further Notes

- This integration can't actually be completed end-to-end until the companion `tree-sitter-cooklang` repo exists and is reachable by a normal git URL — `install_info.url`/`branch` here are placeholders until then.
- Mirrors the existing `gitea-axi` / `gitea-axi-integration` spec pair already in this `.claude/spec/` directory: one spec for the generic, reusable tool, one for how this specific repo adopts it.
