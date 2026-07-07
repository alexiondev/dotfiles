## Problem Statement

Editors with tree-sitter support (Neovim, Helix, Zed, Emacs) have no reliable way to get syntax highlighting for Cooklang recipe files today.
Cooklang's own documentation recommends wiring up the community grammar `addcninblue/tree-sitter-cooklang` via `nvim-treesitter`, but that grammar ships no highlight queries at all: it has no `queries/` directory, and its own README lists "Syntax highlighting" as an unchecked TODO item.
The documented setup snippet also has a bug (`branch = "main"`, but the repo's actual default branch is `master`).
Following the documented path exactly produces a parser that compiles and attaches to `.cook` buffers, but renders no highlighting whatsoever, because nothing tells tree-sitter which grammar nodes map to which highlight groups.

## Solution

Write a new, standalone tree-sitter grammar for Cooklang from scratch, grounded in the official EBNF spec (`cooklang/spec`) and validated against that same repo's official `canonical.yaml` conformance test suite — the same correctness bar every official and community Cooklang parser implementation (Rust, Swift, Go, and others) is held to.
Pair the grammar with a hand-authored `highlights.scm` query file, so the result actually produces working syntax highlighting once wired into any tree-sitter-consuming editor, rather than a parser with no highlighting story.

## User Stories

1. As a Cooklang recipe author, I want ingredients, cookware, timers, quantities/units, comments, and metadata each highlighted distinctly, so recipes are visually parseable at a glance.
2. As a grammar maintainer, I want the grammar to correctly parse the full Cooklang canonical test suite, so the highlighting reflects real document structure rather than an approximation.
3. As a grammar maintainer, I want corpus tests derived directly from `canonical.yaml`, so the grammar's correctness tracks the same bar every other Cooklang implementation must pass, rather than a bespoke set of hand-picked examples.
4. As a grammar maintainer, I want the grammar published as a normal, git-clonable repository, so any tree-sitter consumer's parser-install mechanism (e.g. nvim-treesitter's `install_info.url`) can point at it exactly like any other community grammar.
5. As an editor user on any tree-sitter-consuming editor (not just Neovim), I want the grammar to be generic and editor-agnostic, so it's reusable beyond one person's personal config.
6. As a grammar maintainer, I want `highlights.scm` to map onto standard tree-sitter highlight captures (`@string`, `@number`, `@comment`, etc.), so it renders correctly under any standard colorscheme without bespoke handling.

## Implementation Decisions

- New standalone repository, with its own git history — not bundled into any other project. Hosting, naming, and publishing logistics are the maintainer's own call and deliberately not specified here.
- Grammar authored from scratch using tree-sitter's `grammar.js` DSL. A hand-written external scanner (in C) is expected to be necessary, for the same reason the community grammar needed one: Cooklang's comment syntax (`-- ...`, `[- ... -]`), metadata lines, and ingredient/cookware/timer modifier braces (`{...}`) require context-sensitive lexing that a pure CFG can't express.
- Ground truth for grammar structure: `cooklang/spec`'s EBNF (`EBNF.md`). Ground truth for correctness: `cooklang/spec/tests/canonical.yaml` (837 lines as of writing) — every case in that file gets converted into a tree-sitter corpus test (`.cook` source in, expected parse tree out). Passing the full derived corpus is the grammar's release bar, in the same sense "conforming" is used across the other official/community implementations.
- `highlights.scm` is authored by hand against this grammar's own node types — full control over naming, since the grammar is written fresh alongside it, rather than reverse-engineering someone else's node names.
- Scope is highlighting only: no `folds.scm` or `indents.scm`. Nothing in this project calls for code folding or custom indentation behavior for Cooklang files; adding those query files would be building capability nobody asked for.
- Explicitly rejected: reusing `addcninblue/tree-sitter-cooklang` as the grammar. It has real strengths worth recording — a working custom C scanner, and contributions from two recognized tree-sitter-ecosystem contributors (`amaanq`, who did a scanner rewrite; `clason`, who regenerated the parser/bindings) — but it ships no query files at all, and its own README acknowledges highlighting was never finished. The existence of `canonical.yaml` as a rigorous, official test oracle de-risks writing a fresh grammar enough that starting clean (full control over node naming, no inherited "hacky" workarounds — the existing grammar's own README flags one, around punctuation in ingredient names) was judged better than building on an incomplete, unofficial base.

## Testing Decisions

- Correctness: `tree-sitter test` against a corpus derived from `cooklang/spec/tests/canonical.yaml` — each canonical case becomes a corpus fixture. Passing 100% of the derived corpus is the bar for calling the grammar done.
- `highlights.scm` itself is not covered by automated tests as part of this spec. Verification of the query file's output is manual/visual, done from the consuming editor side (see the companion integration spec for how this plays out in this machine's Neovim config). Automated highlight-assertion tests could be added later by a consumer that needs stronger guarantees, but nothing in this spec calls for that.
- No CI/build pipeline decisions are made here — ownership of hosting and any CI is the maintainer's call, out of scope for this spec.

## Out of Scope

- Reusing `addcninblue/tree-sitter-cooklang` as the underlying grammar (evaluated and rejected — see Implementation Decisions).
- `folds.scm` / `indents.scm` (a possible future addition, not built now).
- Any specific editor's integration wiring (the companion `tree-sitter-cooklang-integration` spec covers this machine's Neovim config; no other editor or consumer is addressed here).
- Repository hosting, naming, and CI/publishing logistics.
- Automated highlight-assertion testing.
- Installing or provisioning `tree-sitter-cli`/Node build tooling — a normal prerequisite of grammar authoring, not a design decision this spec needs to make.

## Further Notes

- `addcninblue/tree-sitter-cooklang` (evaluated and passed over): no `queries/` directory, README lists syntax highlighting as an unchecked TODO. The official cooklang.org blog's own documented Neovim setup snippet for it also has a bug — `branch = "main"` in the `install_info`, when the repo's actual default branch is `master` — which would make `:TSInstall cooklang` fail as written.
- `cooklang/spec/tests/canonical.yaml` is the same conformance suite used to validate roughly ten official/community Cooklang parser implementations across languages (Rust's `cooklang-rs`, Swift's `CookInSwift`, Go's `cooklang-go`, and others). Using it here gives this from-scratch grammar the same correctness bar as those.
- Mirrors the existing `gitea-axi` / `gitea-axi-integration` spec pair in this same `.claude/spec/` directory: one spec for the generic, reusable tool, one for how a specific project adopts it.
