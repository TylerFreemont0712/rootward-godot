@AGENT.md

# Commands (Godot 4.7.2 at `~/godot`, `godot` on PATH)

- First, on a fresh checkout: `scripts/fetch-sandbox.sh` installs the sandbox runtime (wasmtime, CPython and
  QuickJS for WASI, about 100 MB, pinned by SHA-256) into `game/sandbox/runtime/`. The sandbox tests need it.
- Tests (gdUnit4 6.2.1, headless): `scripts/test.sh`; one suite: `scripts/test.sh -a res://test/core/rng_test.gd`.
  It runs an import pass first, so a new `class_name` is visible.
- Lint: `scripts/lint.sh` (gdlint and a gdformat check through `uvx`, gdtoolkit 4.5.0 pinned). Format a file you
  wrote with `uvx --from gdtoolkit==4.5.0 gdformat --line-length 120 <file>`.
- Screenshot a scene: `scripts/screenshot.sh res://scenes/boot/boot.tscn shots/boot.png [frames]`. It renders on the
  GPU under a private Xvfb display, so nothing opens on the desktop. `shots/` is ignored.
- Sandbox timings: `godot --headless --path game -s res://tools/bench_sandbox.gd`.
- Run the game: `godot --path game`. Open the editor: `godot --path game -e`.
- Differential fixtures from the old engine: `node tools/fixtures/<name>.ts` writes `game/test/fixtures/<name>.json`.
  It imports `../ProgramMe` directly, so the old repo must be checked out beside this one with `node_modules`.

# Conventions

- Typed GDScript everywhere: `var x := ...` or `var x: T`, typed parameters and returns, typed arrays
  (`Array[String]`) where the element type is known. `project.godot` makes untyped declarations an error.
- Names: `snake_case` files, functions and variables; `PascalCase` classes and nodes; a `class_name` on every script
  other code refers to. Content JSON is snake_case, and so is runtime state (one naming scheme end to end).
- `game/core/` is pure: `RefCounted` classes and static functions over Dictionaries and typed arrays, no nodes, no
  file or network I/O, all randomness from `Rng`. State is plain data (Dictionaries) so it saves as JSON.
- 32-bit integer maths (hashes, RNG) masks with `& 0xFFFFFFFF` and multiplies through `Rng.imul`.
- Tests live in `game/test/`, mirror the source tree, and end in `_test.gd`. Fixtures from the old engine are compared
  exactly; floats that were 32-bit words are compared as words (`Fixtures.word`).
- `# LEARN:` comments for the non-obvious, with an entry in `docs/LEARNING_LOG.md`. The next ADR number is in
  `docs/decisions/README.md`.
