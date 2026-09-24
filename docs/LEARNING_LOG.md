# Learning log

Things worth understanding in this codebase, with pointers. Newest last.

## 32-bit maths in a 64-bit language (`game/core/rng.gd`)
GDScript has one integer type, a signed 64-bit `int`. The hash and the generators are defined on unsigned 32-bit
words, so every step masks with `& 0xFFFFFFFF`, and multiplication splits one factor into 16-bit halves (`Rng.imul`)
so no intermediate product can overflow. JavaScript's `Math.imul` and `>>> 0` did the same job in the old engine.

## Differential tests (`tools/fixtures/`, `game/test/fixtures/`)
When rewriting something that already works, run the old code with fixed inputs, save what it produced, and make the
new code reproduce it exactly. The fixtures are JSON, so they outlive the old code. Random draws are compared as the
32-bit words they came from (`Fixtures.word`), not as decimal text, which can differ in its last digit.

## Invisible characters
The old `randomFor` hashed `` `${seed}\0${stream}` ``: a NUL character that a terminal draws as a space and that makes
`grep` treat the file as binary. When two implementations disagree and the code "looks identical", dump the bytes
(`python3 -c "print(repr(open(p).read()))"`).

## Sandboxing with WebAssembly (`game/sandbox/`, ADR-0002)
A WebAssembly module can only touch what its host hands it. CPython and QuickJS are compiled to WASI (a standard set of
"system calls" for Wasm), and `wasmtime` is the host: it hands over one folder (`--dir job::/work`), no sockets, a
time budget and a memory cap. A shard's `while True: pass` becomes "wasm trap: interrupt" in about the time limit.

## Why startup got 10x faster (ADR-0002)
Two caches, both made once at install: `wasmtime compile` turns Wasm into machine code (`.cwasm`), and `compileall`
turns the Python standard library into bytecode (`.pyc`). Measure before optimizing: the slow part was not starting
Python, it was `import traceback` compiling source on every run.

## Numbers crossing languages (`game/core/util/js_json.gd`)
Godot parses every JSON number as a float and writes it back as `4.0`; JavaScript writes `4`; Python treats `4` and
`4.0` as different types. Anything headed to shard code goes through `JsJson.stringify`. The fixture has a shard that
calls `range(power)`, so the difference cannot slip back in unnoticed.

## Tests that cannot fail (`game/test/sandbox/`)
A test passed on the first try, so it was checked by breaking the code on purpose (a "mutant"): with the symlink guard
removed, cleanup deleted a file outside the job and the test failed, as it should. Another passed with the code broken,
which showed the fixture was too gentle (no spell ever had more than six bolts). Mutate once whenever a test is new.

## Porting by replay (`game/test/core/shardrun/`, ADR-0003)
Three kinds of fixture pin the Shardrun port: a seeded "player" that plays whole runs against the old engine (every
snapshot recorded), direct cases for the pure functions, and a recording of every call the old unit tests made (a
Vitest alias swaps the engine for a wrapper that writes calls down, `tools/fixtures/record/`). The port matched all of
them on its first run, which is exactly when to try breaking it on purpose: mutants that survive are either
equivalent code or holes in the fixtures, and it is worth knowing which.

## When JSON is not quite JSON (`game/test/support/fixtures.gd`)
Godot reads "0.9750000000000001" as 0.975: its number parser is not correctly rounded at 17 digits. Short decimals are
fine. A comparison that forgives one unit in the last place (`Fixtures.same_number`) is honest about that without
hiding real differences.
