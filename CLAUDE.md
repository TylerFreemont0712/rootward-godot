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
- Check all content and run every shard's worked examples in the sandbox: `scripts/validate.sh` (`--no-exec` to skip
  the sandbox). Translation coverage: `scripts/locale.sh ja [--missing]`.
- Sandbox timings: `godot --headless --path game -s res://tools/bench_sandbox.gd`.
- Run the game: `godot --path game`. Open the editor: `godot --path game -e`.
- Differential fixtures from the old engine: `node tools/fixtures/<name>.ts` writes `game/test/fixtures/<name>.json`
  (big ones `.json.gz`). It imports `../ProgramMe` directly, so the old repo must be checked out beside this one with
  `node_modules`. The old engine's unit tests are recorded with
  `cd ../ProgramMe/packages/core && npx vitest run --config ../../../Rootward/tools/fixtures/record/vitest.config.mts`.
- Parse-check every script at once (faster than a test run for typos): `scripts/check.sh`.
- A throwaway probe script: run it with `< /dev/null` (`godot --headless --path game -s res://probe.gd < /dev/null`),
  or a script error drops Godot into its interactive debugger and it waits forever.

# Conventions

- Typed GDScript everywhere: `var x := ...` or `var x: T`, typed parameters and returns, typed arrays
  (`Array[String]`) where the element type is known. `project.godot` makes untyped declarations an error.
- Names: `snake_case` files, functions and variables; `PascalCase` classes and nodes; a `class_name` on every script
  other code refers to. Content JSON is snake_case, and so is runtime state (one naming scheme end to end).
- `game/core/` is pure: `RefCounted` classes and static functions over Dictionaries and typed arrays, no nodes, no
  file or network I/O, all randomness from `Rng`. State is plain data (Dictionaries) so it saves as JSON.
- `game/core/shardrun/` mirrors the old engine's semantics exactly (ADR-0003): `JsMath.js_round` for `Math.round`,
  float division wherever JavaScript divided, and `JsJson.stringify` for anything sent to shard code.
- Reserved or shadowing names to avoid: `trait` (a keyword in 4.7), `log` (the built-in logarithm).
- 32-bit integer maths (hashes, RNG) masks with `& 0xFFFFFFFF` and multiplies through `Rng.imul`.
- Tests live in `game/test/`, mirror the source tree, and end in `_test.gd`. Fixtures from the old engine are compared
  exactly; floats that were 32-bit words are compared as words (`Fixtures.word`).
- Content is JSONC under `game/content/` (ADR-0004): data in `<id>.jsonc` named after its id, a shard's code in
  `<id>.py` and `<id>.js` beside it, prose translated in `packs/<pack>/locales/<locale>/*.jsonc` keyed by the English.
  New fields go into `ShardrunSchemas` (with a default if old files lack them) before any content uses them.
- `# LEARN:` comments for the non-obvious, with an entry in `docs/LEARNING_LOG.md`. The next ADR number is in
  `docs/decisions/README.md`.
