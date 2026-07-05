---
name: nbdev
description: nbdev conventions for notebooks — directives, cell structure, docments, tests, execution. Use for any .ipynb operation — including reads — in an nbdev project.
---

# nbdev

## Tool Preference

- Use the **Jupyter MCP** for all `.ipynb` operations — read, edit, insert, delete, execute
- Do **not** use the built-in `NotebookEdit` tool; it writes cell source as a single JSON string which breaks standard Jupyter formatting and produces noisy diffs
- Re-read the notebook before editing if it may have changed since your last read — cell indices/IDs can shift under concurrent edits (e.g. via JupyterLab's real-time collaboration), and editing by a stale index can hit the wrong cell

## nbdev Directives

Directives are comments at the top of a cell that control how nbdev processes it:

- `#| export` — include this cell in the exported Python module and in the docs
- `#| hide` — exclude this cell from both the module and the docs
- `#| hide_input` — show cell output in docs but hide the source code
- `#| default_exp module_name` — set which module this notebook exports to (second cell)
- `#| exporti` — export to module but do not show in docs (for internal helpers)
- `#| eval: false` — include in docs but do not execute during `nbdev-test`

Imports needed only for tests or examples should **not** be exported.

Never hand-edit the exported `.py` module files — they're build artifacts regenerated from the notebook by `nbdev_export`. All edits go through the source notebook in `nbs/`.

## Notebook Structure

Every notebook must follow this structure:

**Cell 1 — Markdown frontmatter:**
```markdown
# Module Title

> A one-line description of what this module does
```
The H1 becomes the page title in docs. The blockquote becomes the subtitle.

**Cell 2 — Default export:**
```python
#| default_exp module_name
```

**Body cells** — alternating between exported code, demonstrations, and markdown explanations (see Cell Structure below).

**Last cell:**
```python
#| hide
import nbdev; nbdev.nbdev_export()
```

Before declaring any notebook task complete, restart the kernel and run all cells top-to-bottom to verify it is fully reproducible.

## Cell Structure

Keep cells short. Each exported function gets its own cell, immediately followed by a demonstration. Do not write long functions with comments interspersed — split them into small separate cells with explanations and working examples after each.

The pattern per concept:

1. *(Optional)* A markdown cell explaining what comes next
2. A `#| export` code cell with the function
3. One or more plain code cells demonstrating usage
4. Assertions that double as tests

Example:
```python
#| export
def slugify(text: str) -> str:
    "Convert text to a URL-safe slug"
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
```
```python
slug = slugify("Hello, World!")
assert slug == "hello-world"
slug
```

## Docstrings and Parameter Documentation

Keep docstrings short — a single-line summary is sufficient for most functions. Elaborate in separate markdown or code cells below, where you can use real examples.

Use **docments** (inline parameter comments) instead of verbose docstring parameter sections:

```python
#| export
def greet(
    name: str,           # Person to greet
    greeting: str="Hi",  # Greeting word to use
) -> str:                 # The composed greeting
    "Compose a greeting for name"
    return f"{greeting}, {name}!"
```

This renders as a clean parameter table in the docs automatically — no need to repeat type information in the docstring body.

Use backticks around symbol names in docstrings and markdown — nbdev automatically converts these to hyperlinks to the relevant reference page.

## Code Style

- **Prefer composition**: write small functions that do one thing well
- Each exported function should be focused enough to fit naturally in a single notebook cell — one cell, one idea
- Use type hints on all exported functions
- Avoid classes unless state is genuinely needed — prefer functions that take and return data
- If you do write a class, use `fastcore`'s `@patch` decorator to define each method in its own cell, immediately followed by a demonstration. This avoids long class definitions and keeps examples close to the code

When a class is needed, document its methods with `show_doc`:
```python
from nbdev.showdoc import show_doc
show_doc(MyClass.my_method)
```

## Tests

Every code cell is run as a test by nbdev unless explicitly marked otherwise — any exception fails the test.

- Turn demonstrations into tests by adding `assert` statements
- Use `fastcore.test` helpers for better error messages:
  ```python
  from fastcore.test import test_eq, test_fail
  test_eq(slugify("Hello World"), "hello-world")
  ```
- Document expected error cases with `test_fail`:
  ```python
  test_fail(lambda: slugify(""), contains="empty")
  ```
- Each test/demo cell should import what it needs directly — don't rely on a name imported in a later cell just because it happened to be in scope during a prior run

## Execution

- Always execute cells after writing them to verify they work
- If a cell errors, read the full traceback before attempting a fix — do not guess
- When installing packages, use `%pip install` inside the notebook (not `!pip install`) so they install into the running kernel
- Use autoreload at the top of notebooks that import from other modules in the project:
  ```python
  %load_ext autoreload
  %autoreload 2
  ```

## Documentation

- Use H2 (`##`) markdown cells to group related symbols within a notebook
- Use H4 (`####`) markdown cells to split long explanations within a symbol's section (notes, examples, edge cases, etc.)
- Add rich representations to classes via `_repr_markdown_` where it aids understanding
- Include real code examples, plots, and diagrams — notebooks support rich output, use it

## Outputs

- Never print secrets, tokens, passwords, or API keys into cell output — notebook outputs get committed to git and published in docs, unlike transient script output
- Prefer summaries over dumping large data structures (`.head()`, `len()`, `[:5]`, etc.)
- Large outputs consume context window — keep them concise
