# ADR-0002: player code runs as WebAssembly under wasmtime, one process per job

- Status: accepted
- Date: 2026-09-24

## Context

Every shard and challenge is real code the player can edit, in Python or JavaScript, and it must run contained: no
files but its own, no network, a time limit, a memory cap, bounded output. The old game ran QuickJS (compiled to Wasm,
in a Node worker) and Pyodide (CPython on Emscripten, which needs a JavaScript host). Godot has neither host.

## Options

1. **In-process Wasm, `godot-wasm` (v0.5.0, Wasmtime or Wasmer).** One process, no spawn cost. But its WASI support is
   "a small subset" with no filesystem, and CPython imports its standard library from files, so Python would need a
   hand-written WASI filesystem in GDScript. Time limits and memory caps are not exposed, and a trap or a hang in the
   guest shares the game's process.
2. **The `wasmtime` CLI as a sidecar process per job**, running official WASI builds: CPython 3.14.7 (the
   `cpython-wasi-build` releases that CPython's WASI maintainer publishes) and QuickJS-ng 0.17.0 (`qjs-wasi.wasm` from
   its releases). Full WASI preview 1, epoch-based time limits (`-W timeout`), memory caps (`-W max-memory-size`), and
   a guest crash that can only end its own process.
3. A native interpreter in the game (an embedded CPython) would not be a sandbox at all.

## Decision

Option 2. `game/sandbox/sandbox.gd` writes each job to a fresh folder that the guest sees as `/work` (the files, a
launcher, standard input as a file), runs `wasmtime` with `OS.execute_with_pipe`, drains stdout and stderr without
blocking, and turns the exit code into the old contract's statuses (`ok`, `compile-error`, `runtime-error`,
`timeout`, `oom`, `sandbox-error`). `scripts/fetch-sandbox.sh` installs the runtime pinned by version and SHA-256 and
prepares it:

- **Precompiled modules.** `wasmtime compile` turns each module into a `.cwasm` for this machine, with epoch
  interruption compiled in so a timeout can stop an endless loop. Startup drops from about 0.8 s to about 0.03 s.
- **Compiled standard library.** CPython's WASI build ships its library as source; `compileall` once at install
  brought a Python run from about 300 ms to about 65 ms (`import traceback` alone had cost 280 ms).
- **A read-only standard library.** wasmtime cannot mount a folder read-only, so the host files are `chmod a-w`: WASI
  has no chmod, and a test proves a write fails.
- **Deterministic Python.** `PYTHONHASHSEED=0`, so a set of strings iterates the same way in a preview and in its
  cast.
- **QuickJS's stack.** QuickJS keeps its C stack in the module's memory (about 2 MB, fixed at build time).
  `--stack-size 1792` keeps its own check under that, so runaway recursion is a catchable RangeError while 5000
  nested calls (the old game's bar) still run; the native Wasm stack gets 8 MB.

Input goes in as a file because Godot cannot close a child's stdin without also closing its stdout.

## Measurements (Ryzen 7 6800H, 2026-09-24, `godot --headless --path game -s res://tools/bench_sandbox.gd`)

| | Python | JavaScript |
|---|---|---|
| first run after the game starts | 67 ms | 11 ms |
| a trivial program (median of 15) | 67 ms | 8 ms |
| a Shardrun turn: 3 spells of 2 to 5 real shards, one job (median) | 74 ms | 11 ms |
| a challenge, 9 io cases, one process each | about 0.6 s | about 0.1 s |

Run on a thread (`Background.run`), none of this costs a frame.

## Proof

- `test/sandbox/sandbox_test.gd`: the old runners' malicious suite ported (endless loops, memory balloons, runaway and
  reasonable recursion, runaway printers, no processes, no network, no host files, no `../` requires, the wall-clock
  backstop), plus the read-only library, and a symlink left in `/work` pointing outside the job, which cleanup must
  not follow (it did, before the guard; a mutation test confirmed the test catches it).
- `test/sandbox/spell_harness_test.gd`: 105 spells (every shard alone, 24 chains, broken and int-sensitive shards) x
  3 inputs x 2 languages match the old server's bolts, traces, work, console output and failures exactly.
- `test/sandbox/io_grader_test.gd`: tally-wisp's solution, starter and a wrong answer grade case for case as the old
  runners graded them.

## Consequences

- The runtime is about 100 MB on disk and is not in git; a fresh checkout runs `scripts/fetch-sandbox.sh`. Only
  Linux x86_64 is pinned today; Windows needs its wasmtime build and the same script's equivalent.
- An exported game has to carry the runtime beside the executable (`ROOTWARD_SANDBOX_RUNTIME` points `Sandbox` at
  it), and the launchers and harnesses must be included in the export filters. Decided when exporting is.
- Hidden tests are in the game's data. In a single-player game with no server there is nowhere else to keep them; they
  are simply never shown.
