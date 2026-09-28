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

## A card table as data (`game/app/card_table.gd`, ADR-0009)
Dragging a card is not the move itself: the screen works out the whole table the move would make (every spell's cards,
the hand, the hold) and asks the rules for it. The rules only check that the new table holds the same cards as the old
one, in places they may be. Keeping the move a pure function over plain data is what lets a test make every kind of
move and check the rules accept it, with no screen at all.

## Squash the parent, spin the child (`game/scenes/shardrun/fight/battle_fx.gd`)
A ring lying on the floor is a circle seen at a slant: an ellipse. Squashing the effect node vertically and spinning
the sprite inside it gives a spinning ellipse that stays flat; squashing the sprite after spinning it would tilt the
ellipse with the spin, because a node's own scale is applied after its own rotation.

## Commit a click when the mouse comes up (`game/scenes/shardrun/card_face.gd`)
Godot starts a drag only after the pressed mouse has moved. Moving the card on mouse-down makes the rules redraw the
table and frees that card before the drag can begin. Keep it in place until mouse-up; `_get_drag_data` cancels the
pending click when movement becomes a drag.

## Grade a code lesson by actual stdout (`game/core/verifier_course.gd`)
An intermediate trace checkpoint and a final output prediction make code reading active. The final answer is compared
with stdout from the real JavaScript sandbox; content supplies explanations and trace clues, not a hard-coded final
answer. Keeping the trace optional lets a learner trade a lower score for the help needed to make progress.

## Keep the arena fixed during playback (`game/scenes/shardrun/fight/fight_view.gd`)
Replacing the work surface with a code view can change a container's minimum height and resize the stage above it.
Measure and preserve that height through playback. An impact can use a brief shake and animated effects without
scaling both world and effects around different pivot points.

## Work is what the code did, not what it was given (`game/core/programs/program_rules.gd`, ADR-0012)
Big-O describes how work grows with the size of the input, but a card that grows the volley (7 bolts in, 21 pairs out)
does work in proportion to what it makes as well. The rules take n as the larger of the two sizes the sandbox measured,
and apply the card's complexity class to it: O(n log n) on 21 is about 93 operations, O(2ⁿ) on 12 is 4096. That number
is the program's speed, and every foe with a smaller tempo acts before the program lands.

## Order is an invariant (`game/content/packs/core/programs/cards/binary-execute.py`)
Binary search is O(log n) only because it may skip half of what is left at every step, and it may skip only because the
list is sorted. Binary Execute on an unsorted volley still runs and still answers, but looks in the wrong half and
misses. Cards say what they need (`needs: sorted`) and what they leave (`makes`), and the code panel warns about a
broken order the way a linter would: before the program runs, not after it fails.

## Drawing text yourself (`game/ui/code/rune_code.gd`)
A Label draws a whole string at once. To write code in one character at a time, each first a rune and then the letter,
the control draws every character itself with `draw_char` at `column × character width` (the font is monospaced), and
the runes as short strokes with `draw_polyline`. Only lines still being written are drawn character by character;
settled lines are drawn in runs of one colour, and the control stops redrawing when nothing is moving.

## Sampling without replacement by weight (`game/core/programs/program_draft.gd`)
A pack draws three different cards, rarer ones less often. Setting the drawn card's weight to zero makes the next roll
spread over what is left, in the same proportions, without removing it from the list and shifting every index.

## Options loaded at boot win over a test's (`game/test/scenes/shardrun_screen_test.gd`)
The screen test set the code speed to "off" and then booted the game, which loaded the player's saved options over it,
so every cast played its code in real time and the test took minutes. Setting options after boot made it seconds.
The order of setup matters whenever setup loads state.

## Draw the layout, let the model paint, cut with your own lines (`pipeline/art/layouts.py`, ADR-0013)
A diffusion model will not put a card's window where the game needs it. So the layout is drawn first in flat shapes,
the render starts from it (img2img) and only dresses it, and the finished picture is cut with a mask drawn from the
very same numbers. The numbers are written beside the picture for the game to read, so art and code cannot disagree.
Wherever the game writes text, the post-process repaints the area smooth, because a model told "no text" still writes.

## Tint by saturation (`game/ui/card_tint.gdshader`)
One frame serves every paradigm: in the shader, a pixel's saturation (max minus min of its channels, over max) says
whether it is grey steel or gold. Grey takes the paradigm's colour at its own brightness; gold and the violet crystal
stay as painted.

## Escaping a clipped parent (`game/scenes/shardrun/card_face.gd`)
A card's details must show over the whole screen, but the card sits in a table that clips its contents. A child with
`top_level = true` is placed in the canvas's own coordinates and drawn outside its parents' clipping, and it is still
freed with the card; `get_global_transform() * Rect2(...)` gives where the (lifted, grown) card really is on screen.

## A missing meta with a null default is still an error (`game/scenes/shardrun/fight/hand_view.gd`)
`get_meta(name, null)` reports an error when the key is missing, because Godot reads a null default as "no default";
ask `has_meta` first.

## An animation is a function of time (`pipeline/sprites/spells.py`, ADR-0014)
Each spell animation is one function drawing frame t (0 to 1). Easing does the acting: `into` (slow, then fast) for
things slamming shut or falling, `out` (fast, then slow) for things thrown, `overshoot` for things locking into place,
and a blow that lands on a frame of its own, with a moment of stillness (a hit-stop) after it. Punch is timing and
contrast; brightness only adds glare.

## Light and shade in one pass (`game/scenes/shardrun/fight/spell_anim.gdshader`)
With premultiplied alpha the blend is `out = source.rgb + behind * (1 - source.a)`. Putting the effect's coloured light
in `rgb` and its shade in `a` lets one sprite both add light and darken what is behind it, so a slash can be a dark cut
with bright edges instead of a white smear.

## Counting loops with a line tracer (`game/sandbox/shardrun/spell_harness.py`, ADR-0015)
`sys.settrace` calls a function on every line Python runs (in 3.14 even a comprehension's line, once per round). A
loop's header runs once more than its body, the last check that ends it, so the first line of its body counts its
rounds exactly, even when the loop is entered many times by a recursive function. Tracing only the card's own file
keeps the harness's JSON work out of the counts.

## Instrumenting code on the same line (`game/sandbox/shardrun/spell_harness.js`)
Changing someone's code to measure it must not move it: an error on line 7 has to still say line 7. So every counter is
added to the line it measures (after a loop's `{`, or wrapping a one-line loop as `{ counter; statement }`), never on a
line of its own.

## Measuring balance with a search bot (`docs/research/balance-probe/`)
To learn whether a card game is fair, let a program play it many times. The probe's bot looks one turn ahead:
it lists every ordered choice of cards from the hand (a depth-first search; two prefixes with the same card ids lead to
the same programs, so the second is skipped, which keeps a hand with two Salvos from doubling the work), runs all of
them in *one* sandbox job (starting a process costs far more than running a small function), and replays each cast
through the pure rules to score it. What-ifs change the content in memory and reuse the same seeds, so two experiments
see the same draws and their difference is the change's, not the luck's (a paired comparison).

## A weighted draw that never comes up empty (`game/core/programs/program_loot.gd`)
An elite's loot table weighs rare, epic and legendary relics 70/25/5. If the run already holds every rare, rolling "rare"
and then finding nothing would leave the reward empty. So a tier with nothing left to give is taken out of the draw
before the roll: the remaining weights (25 and 5) keep their proportion, and a relic always comes out while one exists.

## One path for the preview and the cast (`game/core/programs/program_relics.gd`)
Every relic effect is applied inside the same functions the preview and the cast both call (`stages`, `cost_of`,
`resolve`...), never in a screen and never only in one of the two. A preview that is computed differently from the
real thing will drift the moment someone adds a relic; one shared path cannot.

## A worst case is about the input, not only its size (`quick-sort.jsonc`, `ProgramRelics.complexity`)
Quick sort with its first element as pivot is O(n log n) on shuffled input and O(n²) on input that is already sorted:
every split leaves one side empty. The rules already track whether the volley is sorted as cards run (the lint's
`needs`/`makes`), so a card can declare `worst_case: {input: "sorted", complexity: "quadratic"}` and be billed for it.

## An append-only history (`game/app/save_store.gd`, `game/core/shardrun/run_history.gd`)
Finished runs go into a JSON Lines file, one object per line. Adding a run is one append; nothing ever rewrites the
file, so a crash can at worst cut the last line short, and the reader skips a line that does not parse. It is also
the git idea the history borrows: commits are only ever added. `JSON.new().parse()` reports a bad line through its
return value, where `JSON.parse_string()` prints an error for it.

## Check that it exists before asking what it is (`game/scenes/shardrun/fight/log_player.gd`)
The foe "left at a tenth of its HP until the end" bug: `pending is SpellAnim and is_instance_valid(pending)` asked
the type of an animation that had already freed itself, and `is` on a freed object is a script error that stops the
function. The bolts launched after that animation ended never flew, so their damage never reached the bar, and only the
final redraw showed the truth. `is_instance_valid()` first: it is safe on anything. And wait for the events themselves
(a counter of bolts still in the air) rather than for a guess at how long they take; a test plays a real volley in real
time (`test/scenes/fight_playback_test.gd`) and was seen to fail on the old code before the fix.

## A hook runs around code that does not know it (`game/sandbox/shardrun/spell_harness.py`, `.js`)
`import heapq` makes every strike card see the volley strongest first, but no strike card was changed: the harness
calls the import's own function on the volley just before each card of the role it hooks (and `bisect` just after
each source). This is the idea behind decorators and middleware: behaviour wrapped around a function from outside, so
the function stays simple and the wrapper can be added or taken away. The hook is real code in the sandbox, so the
volley a strike card is given is exactly what `heapq.nlargest` returned.

## Importing twice does nothing more (`game/core/programs/program_deck.gd`)
Python keeps every imported module in `sys.modules`; a second `import heapq` finds it there and only binds the name
again. The game follows the language: imports count by module, so a card and its + (or two copies) never stack their
effects. A rule that copies the language's own rule is one less rule to learn.

## A line diff is a longest common subsequence (`game/ui/code/code_diff.gd`)
The forge shows a refactor the way `git diff` does. The lines both versions share, in order, are their longest common
subsequence (a small dynamic programming table, filled from the ends); every other line is a removal or an addition.
The table is n by m lines, which is nothing for a card's function; `git` uses Myers' algorithm, which finds the same
kind of answer faster on long files.

## A warning about orphans that are only queued frees (`game/test/scenes/shardrun_screen_test.gd`)
gdUnit counts nodes that are outside the tree when a test ends as "possible orphans". `Ui.clear` removes a panel's
children and `queue_free`s them, and a queued node is freed at the end of the frame, so a test that ends straight after
a redraw sees them all. `Node.print_orphan_nodes()` two frames later listed none. Letting two frames pass at the end of
the screen tests turned 173 warnings into 0, and the suite's exit code into 0: the warnings were real messages about a
timing, not leaks, and measuring said which.

## One engine's proven content stays that engine's (`game/content/packs/core/programs/foes/`)
A test compares the Shardrun's content with the catalog the old TypeScript engine built, key by key. A speed written
into a shared foe's intents, or a new foe in the shared folder, would change that catalog, so the program run keeps
its own: its foes in `programs/foes/`, its intent speeds in `programs.jsonc`. The same shape as program relics: a
feature that is new lives beside what is proven, never inside it.

## Reference results that can be re-recorded (`game/test/support/fixtures.gd`)
A golden test compares what the engine does with a recording. If the recording can only come from somewhere else (the
old engine), every deliberate change breaks it for good. `Fixtures.expect(holder, key, got)` compares, or, with
`ROOTWARD_GOLDEN=update`, stores `got` in the recording, and the suite writes the file in `after()`: the change and
the fixture's diff are committed together, and the diff is the review of what changed.

## A filter whose cutoff moves (`pipeline/audio/synth.py`, `svf`)
Noise swept through a band-pass whose centre glides is the rush, whistle and tear of most of the fight's sounds. The
Chamberlin state-variable filter is two integrators in a loop, `f = 2 sin(pi fc / fs)` per sample, so the cutoff can
change every sample; it is stable only below about a sixth of the sample rate, so the cutoff is clamped there.

## Randomness in presentation (`game/app/sound.gd`)
The rules take all their randomness from `Rng`, seeded, so a run replays. A sound's take is chosen with `randi()`:
it is presentation, never decides an outcome, and twenty hits of a volley should not be one sample twenty times.

## A gzip stream from Godot (`Fixtures.save_json_gz`)
`PackedByteArray.compress(FileAccess.COMPRESSION_GZIP)` writes a plain gzip stream, the kind `decompress_dynamic`
reads; `FileAccess.open_compressed` writes Godot's own block format, which is not gzip.

## A tooltip above a clipping arena (`game/ui/hover_info.gd`)
An enemy name lives inside a stage that clips its children. Putting a popup inside that stage cuts it off. A
`CanvasLayer` attached to the hovered control draws above the stage while still sharing its lifetime. The popup
recomputes its position from the control's rectangle and clamps to the viewport; keyboard focus calls the same show
path as hovering.

## Pictures have invisible dimensions (`game/scenes/shardrun/fight/foe_view.gd`)
The PNG's width includes transparent margins, so setting a `TextureRect` to a particular size does not set the
creature's visible size. `Image.get_used_rect()` finds the pixels that matter, and an `AtlasTexture` displays that
region. The stage then sizes the visible sprite using both arena height and available width, preserving its aspect.

## A card event can drive art without deciding combat (`game/scenes/shardrun/fight/shard_flourish.gd`)
The code player emits the resolved card as it reads the program. A flourish can draw a motif for that card at that
moment without changing the sandbox output or the combat log. This gives each role a visual language while the
verified program remains the only source of damage and timing.

## A scene cannot add to root while root is attaching it (`game/ui/screen_transition.gd`)
The boot scene calls `Game.go` from `_ready`, while Godot is still attaching the boot scene to the root. Adding the
transition curtain to root at that moment fails, leaving the lantern loading text forever. Queue root's `add_child`
and the transition's start in that order; the deferred start happens after the curtain enters the tree, where it can
create a tween. `game/tools/boot_check.gd` runs that actual boot path and checks it reaches the title.
