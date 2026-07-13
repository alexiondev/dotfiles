---
name: gitea
description: Use when interacting with Gitea — issues, pull requests, reviews, comments, releases, labels, milestones, notifications — via the `tea` CLI, e.g. on repos hosted at git.alexion.dev. Covers listing, creating, editing, reviewing, and merging non-interactively.
---

Drive Gitea from the terminal with `tea`.
The recipes below are the fast path for common tasks; run `tea <command> --help` for the full flag list of any command, which is authoritative and always current.

## Core rules

These apply to every recipe.

**Run `tea` from inside the target repo.**
It infers the repo and login from the checkout's remote, so you normally pass neither.
The default login is `alexion` on `git.alexion.dev`.
Only when acting on a repo other than `$PWD`'s do you add `--repo <owner>/<name>` (and `--login alexion` if the remote doesn't resolve a login).

**Pick output by purpose.**
Add `--output json` when you need to extract a value to act on — a PR index, a state, a comment id.
Use the default table output when the result is only being shown to the user.

**Never invoke an interactive `tea` command** — it opens a TUI or prompt and hangs a non-interactive agent.
The traps and their non-interactive replacements:

- `tea pulls review` → use `approve` / `reject` / a comment (see Pull requests below).
- Bare `tea pulls create` or `tea issues create` → always pass `--title` (and `--base` for PRs), which skips the prompt.
- `--comments` on a view command → pass it explicitly to include comments; never leave it to prompt.

**Confirm hard-to-reverse writes first.**
Read commands (list, view, search, notifications) run freely.
Reversible writes — create issue/PR, comment, label, assign, open/close, edit — run without asking; report what you did after.
Get explicit confirmation before **merging a PR, deleting anything (`rm`), or publishing a release**.

## Issues

- List open issues assigned to you: `tea issues ls --assignee alexion`
- Search across all states: `tea issues ls --state all --keyword "flaky test"`
- Filter: `tea issues ls --labels bug --milestones v1 --author someone`
- View one in detail (with its comments): `tea issues 42 --comments`
- Create: `tea issues create --title "..." --description "..." --labels bug --assignees alexion --milestone v1`
- Assign / (un)label / retitle / set milestone: `tea issues edit 42 --add-assignees alexion --add-labels bug --remove-labels wip --milestone v1`
- Close / reopen: `tea issues close 42` · `tea issues reopen 42`

## Pull requests

`pr` is the alias for `pulls`.

- List / view: `tea pulls ls --state all` · `tea pulls 17`
- Open a PR from the current branch against `main`: `tea pulls create --base main --title "..." --description "..."`
  (head defaults to the current branch; add `--draft` for a WIP draft, `--head user:branch` for a cross-repo source.)
- Check out a PR locally: `tea pulls checkout 17`
- Merge (confirm first): `tea pulls merge 17 --style squash` — styles: `merge`, `rebase`, `squash`, `rebase-merge`.
- Delete the merged feature branch afterward: `tea pulls clean 17`

**Review a PR non-interactively** — do not use `tea pulls review`:

- Approve: `tea pulls approve 17 "looks good"`
- Request changes: `tea pulls reject 17 "needs tests"`
- Plain comment: `tea comments add 17 "..."`
- Read existing review threads: `tea pulls review-comments 17`
- Resolve / unresolve a thread: `tea pulls resolve <comment-id>` · `tea pulls unresolve <comment-id>`

## Comments

Comments work on an issue or PR by its index.

- Add: `tea comments add 42 "..."`
- List: `tea comments ls 42`
- Edit: `tea comments edit <comment-id> "..."`
- Delete (confirm first): `tea comments rm <comment-id>`

## Labels & milestones

- Labels: `tea labels ls` · `tea labels create --name bug --color "#ee0701" --description "..."` · `tea labels update ...` · `tea labels rm <id>` (confirm first)
- Milestones: `tea milestones ls` · `tea milestones create --title v1 --description "..." --deadline 2026-08-01` · `tea milestones close v1` · `tea milestones reopen v1`

## Notifications

Use these to find work waiting on you.

- Across all your repos: `tea notifications ls --mine`
- Current repo only: `tea notifications ls`
- Mark read: `tea notifications read` (all filtered) or `tea notifications read <id>`

## Releases

- List: `tea releases ls`
- Create for a tag: `tea releases create --tag v1.0.0 --title "..." --note "..."` — or `--note-file NOTES.md`; add `--draft` / `--prerelease`.
- Delete (confirm first): `tea releases rm v1.0.0`

## Repos & branches

- List repos you can access: `tea repos ls` — search the whole instance: `tea repos search <query>`
- Create: `tea repos create --name foo --private --init`
- Clone: `tea clone <owner>/<repo>`
- List branches: `tea branches ls`
