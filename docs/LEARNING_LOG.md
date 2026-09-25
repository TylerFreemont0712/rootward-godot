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

## A schema language in 250 lines (`game/content/schema.gd`)
The old game's zod schemas did three jobs: say what shape a file must have, fill in defaults, and explain what is
wrong in words. `Schema.check` does the same with plain Dictionaries as schemas ({"type": "int", "min": 1}), so a
content rule is data too. Tagged unions (a relic effect's `kind` picks which fields it has) are the one idea worth
studying: they make "this field only exists for that kind" checkable.

## Keeping comments when converting formats (`tools/content/convert.ts`)
`JSON.stringify(yaml.parse(text))` would have dropped every comment. Walking the YAML *document* (its syntax tree)
instead of its value keeps each comment attached to the key it explained.

## Coroutines: `await` without freezing the game (`game/app/shardrun_session.gd`)
A GDScript function that contains `await` pauses there and lets the game go on drawing; it resumes when the awaited
signal fires or the awaited coroutine returns. A cast runs its spell in the sandbox on a thread (`Background.run`
checks every frame whether the thread is done), so the screen stays alive while Python thinks. Everything that calls a
coroutine has to `await` it as well, all the way up to the button that started it (`ShardrunScreen.send`).

## One writer, many readers (ADR-0006)
Screens never change the run. They send a command to `ShardrunSession`, which asks the rules, saves, and hands back the
state before and after. That single door is why a refused command changes nothing, why saves are always whole, and
why a test can drive the real screen with a bot.

## The same run for the preview and the cast (`game/app/spell_runs.gd`)
A shard may be random, so "run it again when the player casts" could land something other than what the preview
promised. Instead every run is remembered by its exact input, written out as JSON text (`SpellRuns.key_of`): same
spell, same battle, same text, same run. A cache key made of the whole input is a simple way to be sure two things are
"the same".

## A 3D actor on a 2D screen (`game/scenes/shardrun/fight/hero_view.gd`)
A `SubViewport` with `own_world_3d` and a transparent background is a little 3D world of its own; a
`SubViewportContainer` shows what its camera sees as a picture in the interface. The fight stays a 2D screen of
controls, with one 3D character standing in the painted arena.

## Hit-stop (`game/scenes/shardrun/fight/battle_stage.gd`)
Freezing the action for 70 ms on a heavy hit makes it feel heavy. `Engine.time_scale` slows every timer and tween at
once; the timer that ends the freeze must ignore the time scale (the fourth argument of `create_timer`), or it would be
frozen too.

## A new `class_name` needs an import pass
Godot finds classes by name through a cache it rebuilds on import. A script that uses a class added since the last
import fails to compile, and a script error in a `-s` run can leave Godot waiting in its debugger. `scripts/test.sh`
and `scripts/screenshot.sh` run `godot --headless --import` first for that reason; a hand-run probe should too.

## Saving without ever leaving half a file (`game/app/save_store.gd`)
Write the new save to `spellbook.json.tmp`, then rename it over `spellbook.json`. A rename on the same disk is atomic:
either the old file or the new one is there, never a torn one, even if the game crashes mid-write.

## One canvas, any window (`game/project.godot`, ADR-0006)
The game is laid out on a fixed 1920x1080 canvas, and Godot's `canvas_items` stretch mode scales that canvas to the
window, re-drawing text at the new size so it stays sharp. Choosing the canvas size is choosing how big everything
looks: the same 15-pixel font is 15 pixels in a 1920x1080 window and about 20 in a maximized 2560x1440 one. With the
`expand` aspect, a window of another shape gets extra canvas at the sides or bottom instead of black bars, so layouts
use anchors and containers rather than fixed positions.

## Shapes as distance functions (`pipeline/blender/vesper/sdf.py`, ADR-0007)
A signed distance field is a function that says, for any point, how far it is from a surface (negative inside). A
sphere is `|p - c| - r`; the union of two shapes is the smaller of their two distances. The smooth minimum
`smin(a, b, k)` is that union with the corner rounded over a width `k`, which is how an arm grows out of a shoulder
without a seam. To see the shape you sample the field on a grid and find where it crosses zero (OpenVDB's
`convertToQuads`); sampling only blocks near the surface keeps a 0.6 mm grid affordable.

## Cloth has one face and a thickness (`pipeline/blender/vesper/cloth.py`)
A 4 mm cloth shell meshed as two walls looks fine until the mesh is reduced: the reducer does not know the walls
belong apart and lets them cross, so the lining shows through in patches. Keeping only the outer face, reducing that,
and then adding the thickness (a copy of the sheet moved back along smoothed normals, joined at the edges) makes the
inner wall follow the outer one exactly, whatever the reduction did. Blender's Solidify did the same job badly here: its
simple mode tilts the edge vertices and folds the lining out past the hem, and its complex mode throws spikes.

## Toon shading and bumps (`pipeline/blender/build_vesper.py`)
A toon shader turns light into shadow at one threshold, so a surface's small bumps become ragged dark blotches. The
fix is to keep the geometry and smooth only the normals the shader reads (custom normals averaged with their
neighbours, but never across a sharp edge like a cloth's rim). A face uses a stronger version: its normals are bent
toward an ellipsoid's, so a nose never casts a toon shadow.

## `materials.clear()` resets every face (`pipeline/blender/vesper/shading.py`)
Each face stores which material slot it uses. Clearing an object's slot list sets every face back to slot 0, so
putting the same materials back does not restore the look. Swap materials by assigning into the slots in place.

## A video model draws a clip together (`pipeline/sprites/`, ADR-0008)
An image model asked for frames one at a time redraws the character a little differently each time, and the sheet
shimmers. A video model (Wan 2.1 VACE) draws every frame of a clip in one pass, with attention across time, so the
frames are one motion. It is steered three ways at once: a skeleton per frame (the pose), one reference drawing (the
look), and pinned frames, pictures it must keep exactly, which is how every clip starts and ends on the same drawing.

## One sprite, many effects (`game/scenes/shardrun/fight/spell_sprite.gdshader`)
A dissolve keeps each pixel while a noise texture is above a threshold that rises over time; lighting the pixels just
above the threshold makes the edge glow, so the picture burns away instead of fading. With a reveal (an angle that
sweeps round the centre), a wobble (UVs pushed by scrolling noise) and a shimmer, the same painted burst or seal can
appear, hold and leave in several ways, which is cheaper than painting every frame.

