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
verified program remains the only source of damage and timing. (The flourish itself was retired for the magic
circle's layers, ADR-0039; the principle holds for them too.)

## A scene cannot add to root while root is attaching it (`game/ui/screen_transition.gd`)
The boot scene calls `Game.go` from `_ready`, while Godot is still attaching the boot scene to the root. Adding the
transition curtain to root at that moment fails, leaving the lantern loading text forever. Queue root's `add_child`
and the transition's start in that order; the deferred start happens after the curtain enters the tree, where it can
create a tween. `game/tools/boot_check.gd` runs that actual boot path and checks it reaches the title.

## Orientation belongs to foe content (`game/content/shardrun_schemas.gd`)
Foes stand on the right and should look left toward the player. A repaint may be excellent yet face the wrong way;
the existing `FoeView` can flip its texture when content says `mirror`. That field first existed only on program foes,
so adding it to a shared foe failed validation and made the whole catalog unloadable. Putting it in the shared foe
schema lets both playstyles use the same display rule, and a battle screenshot verifies the result.

## Review sprite art where the player sees it (`pipeline/art/sprite-polish-pass-3.json`)
An isolated render can look sharp but disappear when reduced into the arena or a 30-pixel relic row. Review the
accepted image in a real fight, with adjacent foes and the UI visible. This pass checked all remaining playable foes
in boss and regular battle layouts; the relics and shards were checked in the relic row and card hand. Strong outer
shape and one bright focal point survived reduction better than small internal ornaments.

## Arrays compare by value (`game/core/programs/program_rules.gd`)
The Quine cannot be hurt by the program that ran just before (its fixed point, `docs/NewEnemies.md`). The check is a
plain `foe.last_cards == context.cards`. In GDScript, `==` between two Arrays compares their elements in order, not their
identity: the Quine keeps its own `duplicate()` of last turn's card list, and a new list with the same ids in the same
order still matches, while the same ids in another order do not. That order sensitivity is the rule itself: reordering
a program is changing it. (Dictionaries compare by content too; for identity, `is_same()` exists.)

## An icon can be beautiful and still name the wrong thing (`docs/ArtUpdate.md`)
At 32 pixels, the old Priority Queue looked like a brush and Cross Product like a framed eye. The fourth art pass
starts with the object's meaning: ranked gems for a queue, crossing axes for a product, and visible tally cuts for
a census. Compare each candidate at the actual card and relic size, beside other icons, before checking it off.
Guardian concepts that are not playable yet can be reviewed together at intended battle scale; the playable Quine
was also checked in the Root arena.

## Test teardown needs a frame after `queue_free` (`game/test/scenes/shardrun_screen_test.gd`)
Waiting two frames inside the longer screen tests was not enough: the suite's `after_test` queued the entire screen
for deletion after those waits. gdUnit counted 31 possible orphans even though all 195 assertions passed. Waiting
two frames after teardown removed that warning in the affected suite.

## Multi-part art needs mating shapes (`game/assets/foes/spaghetti-hydra-head.png`)
The Hydra body and separate head each looked finished, but both originally ended in projecting plug pins. Side-by-side
review exposed the mismatch. The head now has a recessed socket for the body's pins; the edit also needed a second
pass to remove a faint halo outside the transparent cutout. Multi-part sprites need a shared connector design as
well as a shared palette.

## Judge shard art after reduction (`docs/images/artupdate-shards-pass6.png`)
The full-size concepts for Crowd Surge, Headcount, Take Two, Transduce and Triage had the intended objects, but their
small enemy details, gate and crystal geometry collapsed at 32 pixels. Keep those older icons until a simpler drawing
reads in the actual card hand. A strong silhouette survived reduction for thirteen other shard replacements.

## Give similar effects different silhouettes (`docs/images/artupdate-shards-pass7.png`)
The second full shard pass pairs readable forms with mechanics: shields convert or preserve defense, linked bolts show
pairing, and large targets show foe selection. Effects that depend on a crowd or target still need distinct anchors;
compare both names together in the hand as well as at card size, and simplify again if their silhouettes converge.

## A forged shard keeps its base icon (`game/app/shardrun_views.gd`)
The Archives hides `-plus` shards as duplicate rows and opens each upgrade from its base shard. The upgraded entry has
no separate icon, so `ShardrunViews.art` removes `-plus` and displays the base picture. The same resolver now checks
all 77 catalog shard variants, while Spellforge labels the card list “Shards” and counts its 72 base entries.

## A glide that ignores the frame rate (`game/scenes/shardrun/map_view.gd`)
The map's scroll eases toward where it was asked to go. The usual `lerp(current, target, 0.15)` every frame moves 15%
of the gap per frame, so a 144 Hz screen glides more than twice as fast as a 60 Hz one. Keeping `exp(-rate * delta)` of
the gap instead (`lerpf(target, current, exp(-GLIDE * delta))`) gives the same curve per second at any frame rate: two
frames of 1/120 s leave exactly what one frame of 1/60 s does, because e^(-a)·e^(-b) = e^(-(a+b)).

## A stable nudge without the run's Rng (`game/scenes/shardrun/map_canvas.gd`)
Rooms sit a little off the grid so the map reads as a place. Drawing those offsets from the run's `Rng` would change
the stream the rules depend on (and the reference results). `hash(room_id)` is the same number on every run for the
same String, so its low bytes make a nudge that never moves and never touches the rules.


## Wrapping into a signed byte (`game/core/programs/guardian_landing.gd`)
INT_MAX stores each bolt's damage in a signed byte, -128 to 127. The wrap is one line: `posmod(damage + 128, 256) - 128`.
Shifting by 128 moves the range to 0..255, `posmod` wraps any number into it (unlike `%`, it never returns a negative),
and shifting back gives what two's complement hardware does: 128 becomes -128, 200 becomes -56. Its Count intent
doubles 16, 32, 64, and 128 is exactly where it wraps too, so the boss's own overflow is the same rule.

## Hard to find, easy to check (`game/core/programs/guardian_landing.gd`)
Karp asks for bolts that add up to exactly its target: subset sum, an NP-complete problem. The check builds a table of
reachable totals (`came[total] = [value's position, total before]`), one pass per value, so it costs values × target
steps and can walk back to the bolts that made the total. That is the lesson the boss teaches: finding the answer may
be hard in general, but checking a proposed answer (the volley you landed) is cheap. Keys are visited from a snapshot
(`came.keys()` before the loop adds to it), so one value is never used twice in the same total.

## A wrapped label's first size is a guess (`game/scenes/shardrun/card_detail.gd`)
A card's details are placed beside it from their own size, every frame. But a label that wraps, and rich text that fits
its content, only know their height after a layout pass has given them a width: on the first frame Merge Sort's details
measured 797 px tall, on the second 445. Placed from the guess, the panel appeared in one spot and snapped to another
on every hover, and beside a hand card that lifts as it is pointed at, it slid along. The fix waits: the details stay
transparent until two frames agree on their size and on where the card is (with a cap of 20 frames), and once shown
they stay shown. Measuring before showing is the general cure for layout that settles over frames.
## A copied save may be played before migration is confirmed (`game/app/profile_store.gd`)
The migration copies each legacy file and compares its bytes before publishing the new profile. On the next launch,
the copied run may already have changed because the player continued it. The confirmation therefore checks that the
copy still exists while retaining the original byte comparison as the migration proof. The source folder stays in
place, so a recovery path is available even if a later run becomes unreadable.

## A lesson should watch the outcome, not just the button (`game/core/trial_rules.gd`)

Pip's speed race originally advanced on any cast, so the story could say the foe moved first when it had not. The
Trial now checks the accepted command's new battle log for `tempo`, and the sorted-input lesson checks card order in
the submitted Program. The budget lesson checks an exact scripted card sequence and the real `timeout` log, then
verifies that no damage landed. Scripted hands and foe tempo are setup data; the cast still goes through the real
sandbox and combat rules. This keeps the lesson honest without adding a tutorial branch to the battle engine.

## One animation, every skeleton: retargeting through a profile (`game/characters/moves/rootward.glb.import`)
Two humanoid models never agree on their bones' axes, so a rotation keyed on one twists the other. Godot's importer
solves it with a *profile*: a BoneMap names each bone by its role (`LeftUpperArm`), and "overwrite axis" rewrites
every rest pose to the profile's reference, adjusting the animation to match. godot-vrm does the same to each VRM
skin, so a clip imported this way plays on any of them. One import option, `remove_tracks/except_bone_transform`,
turned out to strip the rotation tracks entirely (one track left per clip): a setting worth checking with a probe
rather than trusting its name.

## A pose made of readable numbers (`pipeline/blender/build_moves.py`)
A bone's own axes are arbitrary, so `rotation_quaternion = (0.7, 0.1, ...)` means nothing to a person. The clips
instead say `"LeftUpperArm": {"raise": 20, "forward": 70}`, a rotation `D` in the armature's axes at rest, applied at
the bone's head and carried by its parent: the bone's local rotation is `R⁻¹ D R`, with `R` its rest orientation.
Mirroring the right side is `S D S` with `S` the reflection through the body's mid-plane (x → -x). Easing is done on
the numbers, not on the rotations, so an overshoot or a 360-degree spin is just a number passing its target.

## Keying at one frame rate, exporting at another (`pipeline/blender/build_moves.py`)
The glTF exporter converts frame numbers to seconds with the scene's frame rate. Keys placed on frames 0..69 of a
30 fps clip, in a scene left at Blender's default 24 fps, came out 1.25 times too slow, and every release missed its
beat. Setting the scene's rate before keying fixes it. In the same file: while an action is assigned, any update
re-evaluates it at the scene's frame, so a pose set by hand is overwritten; read a posed bone by moving the scene to
that frame instead.

## A world of its own has no sun (`game/scenes/shardrun/fight/hero_view.gd`)
The hero is drawn in a SubViewport with `own_world_3d`, so no light from anywhere else reaches it. Emberfox's toon
shader is unshaded and brings its own light, so this never showed; a VRM's MToon material is lit like any other and
came out as a black silhouette. The view now adds its own warm key light and ambient light for a VRM skin.

## Reading a look out of someone else's shader (`docs/decisions/ADR-0029-the-anime-look-and-normalised-skins.md`)
"Make it look like Zenless Zone Zero" became concrete by dumping a fan rig's Blender node graphs as text (every node,
its settings, every link) and reading them as code. The graph said: shade colour chosen per material slot by a mask's
red channel in bands of 0.2, a light term remapped over 0 to 0.25 (a nearly hard edge), specular over N·H 0.75 to 1
times the mask's blue, and a LUT read through log2 with the constants 0.048 and 0.386, which are Unity's ARRI LogC
curve. Knowing *why* it looks that way is what lets our own shaders reach the look without its assets.

## An SDF face lightmap (`game/characters/anime_face.gdshader`)
A face lit by its normals gets blotchy shadows. Anime games paint a greyscale map instead: each texel stores the light
angle at which it falls into shadow. The shader flattens the light onto the head's horizontal plane, takes its angle
from the head's forward (0 in front, 1 behind), mirrors the map when the light is on the other side, and compares:
a clean edge that sweeps across the cheek as the light moves. It needs the head's facing each frame, which
`StageCharacter._process` computes as the Head bone's turn from its rest.

## Folding a production rig onto a humanoid (`pipeline/blender/normalize_rig.py`)
A studio rig deforms with hundreds of bones (twist, correctives, face) driven by control bones through constraints
that glTF cannot carry. Instead of exporting it, the script builds a fresh humanoid skeleton at the source's joints and
moves the weights: every vertex's weights are summed per target bone (a twist bone's weight goes to its limb, a face
bone's to the head), then trimmed to four and renormalised. Any bone not named in the map gives its weight to its
nearest kept ancestor. The mesh never changes; only who moves it does.

## A connected bone does not move (`pipeline/blender/build_moves.py`)
Every clip keyed a hip lift, and none of it showed. Printing the posed bones settled it: the Hips' location channel
read -0.51 m while its head stayed at 0.944 m. On the VRoid skeleton the hips are *connected* to their parent, and
Blender ignores the location of a connected bone (its head is glued to the parent's tail). Disconnecting it in edit
mode lets the hips travel. When a number "does nothing", measure the thing it is supposed to move.

## Planting feet with two-bone IK (`pipeline/blender/build_moves.py`, `game/characters/leg_planting.gd`)
Forward kinematics moves a foot whenever the hips move, so a breathing bob or a crouch lifts the feet off the floor.
Inverse kinematics works backwards from where the foot must be: with thigh a, shin b and hip-to-target distance d, the
law of cosines gives the thigh's angle from the hip-to-target line, acos((a² + d² - b²) / 2ad), bent toward where the
knee already points. The build solves it per frame (in Blender), and the game solves it again per skin (Godot's
TwoBoneIK3D), because a foot planted on one skeleton hovers on a skeleton with longer or shorter legs.

## Limited animation: fewer drawings on purpose (`game/characters/character.gd`)
Interpolating between keys every frame is what makes 3D look 3D. Anime and Guilty Gear hold each drawing for a few
frames instead. In Godot the mixer and the skeleton's modifiers can be driven by hand (`callback_mode_process` and
`modifier_callback_mode_process` set to manual): the character accumulates time and, fifteen times a second, advances
the animation, re-aims the leg IK and steps the springs by the whole accumulated time at once. `advance()` still
honours `speed_scale`, so a cast timed to its sigil lands on the same beat.

## Follow-through on a spring (`pipeline/moves/motion.py`)
Stiff animation is every joint starting and stopping together. Real limbs lag the body that carries them and carry on
past it when it stops. A damped spring does that with two numbers: x'' = w²(target - x) - 2ζw·x', where the target is
the keyed pose, w = 2π·frequency sets how tightly the bone follows and ζ (damping) below 1 lets it overshoot and
settle. It is stepped in small sub-steps (semi-implicit Euler: update the speed, then the position with the new
speed), which stays stable where a single step per frame would blow up. A looping clip runs one lap first, so the
spring's state at its end matches its start.

## Waiting in the wind-up, not the strike (`game/characters/character.gd`)
A cast must land its strike when the circle completes, and circles take 0.6 to 1.2 seconds. Slowing the whole clip
to fit made the strike itself mushy. The clip marks where its coil ends (`charge`): only the time before it is
stretched (speed = coil left / (wait - strike length)), and once the playhead passes it the speed returns to 1, so the
snap is always the same speed. Anticipation can be any length; the action never.

## A circle seen side-on is a transform, not a picture (`game/scenes/shardrun/fight/magic_circle.gd`)
A disc facing the foes is seen from the camera narrowed. Everything is drawn in a flat "disc space" (a circle of
radius r), and `draw_set_transform_matrix` maps that space to the screen: scale x by 0.46, lean it back, offset it
along the cast axis for the smaller circles stacked in front. Spinning a ring is one more rotation inside that
transform, so rings, star and runes all narrow correctly however they turn. Additive blending
(`CanvasItemMaterial.BLEND_MODE_ADD`) makes overlapping strokes brighten like light rather than cover each other.

## Measure the bone before blaming the pose (`game/characters/dummy/`)
The dummy's feet looked broken in every clip. A probe printed each foot's toe pitch and sole tilt in the idle, with the
leg IK on and off: both were 0, so the animation was right and the model was not. Two causes, both found by looking
at the model at rest: the skeleton's toe joint sits at ankle height (so feet built on it hovered), and the importer's
*fix silhouette*, meant to straighten an A-pose into a T-pose, also re-aimed the T-pose skeleton's feet. A rest-pose
check (no clip, no IK) separates "the model" from "the motion" in one picture.

## Retargeting by the turn away from a T-pose (`pipeline/blender/retarget.py`)
Two skeletons rarely agree on which local axis a bone points along, so copying local rotations breaks limbs. Both are
matched in a T-pose instead (the source at a frame where it stands in one, ours at rest), and each bone copies the
*world-space turn away from that T-pose*: ours(t) = theirs(t) · theirs(T)⁻¹ · ours(T). The local pose a bone needs is
then worked out down the hierarchy (a child is carried by its parent's posed matrix). The hips copy the pelvis's
travel, scaled by the ratio of the hip heights, and the feet are planted afterwards as for any clip.

## A cross-fade needs something to fade from (`game/characters/character.gd`)
Godot's AnimationMixer is deterministic by default: it blends a new clip over what the playing clips still
contribute, starting from the rest pose. A clip that has *finished* contributes nothing, so a fade started in
`animation_finished` blended up out of the rest pose: on the dummy, a T-pose arm flashed to shoulder height on every
return to the idle. Measured by printing the hand's height each frame across the hand-off; fixed by starting the next
clip a blend's length before the old one ends, while it still plays.

## A local theme is a copied resource (`game/scenes/title/foundry_ui.gd`)
Godot themes are shared Resources: changing a style on the shared instance changes every screen using it. A deep
duplicate lets the Foundry use larger type and warm panels while the battle menus keep their existing theme.

## Visible alpha is more useful than the file's rectangle (`game/scenes/title/foundry_ui.gd`)
A generated transparent wordmark can contain almost invisible pixels far below its letters. Cropping to every
nonzero pixel leaves the logo small inside a tall rectangle. Inspecting a thumbnail and finding alpha above 0.25
gives a stable visible rectangle for an AtlasTexture, without changing the original image.

## Modal focus has to be restored (`game/scenes/title/title.gd`)
A dim overlay blocks the mouse but does not remove the controls underneath from keyboard navigation. Opening a
modal stores their focus modes, disables them, and returns focus to the opener on close. Rebuilding an option list
also saves the focused button's index. Deferred focus must check that the control is still inside the scene tree:
the page may have closed before that call runs.

## Reduced motion needs a clock we own (`game/scenes/title/foundry_lights.gdshader`)
The shader's built-in TIME continues while the user changes settings. A supplied clock advances only while motion
is enabled, so reduced motion can freeze the light immediately. Local Gaussian masks keep the tiny brightness
change at the lanterns and lift core instead of pulsing the whole painting.

## Sharing art means sharing the reference (`game/app/shardrun_views.gd`)
Copying a polished PNG to two filenames leaves two assets that can drift apart. A validated optional `icon` id in
the program-card record lets both modes load the same cached Texture2D. Refactors keep that reference too. Mapping
by the operation matters: program Charge converts to spark like Spellforge Arc; Spellforge Charge is a multiplier
operation. The tests check both the canonical id and Resource identity, alongside the existing missing-art fallback.

## Review the silhouette in its actual frame (`game/tools/program_icon_sheet.gd`)
A large, attractive transparent image can still disappear in a square card window. The first Two Pointers candidate
was a long horizontal row; its arrows shrank too far at card size. A compact diagonal version fills the window and
keeps both inward pointers visible. The review fixture instantiates the real CardFace at its normal hand size,
without overlap, so it checks the same layout the player sees without changing the battle menus.

## A button must outlive its own click (`game/scenes/title/title.gd`)
Switching the title's locale rebuilt the utility bar with `free()`, destroying the button while its `pressed`
signal was still being dispatched. The player's log reported that error followed by a native segmentation fault.
Removing the old bar from its parent hides it immediately; `queue_free()` keeps the emitting button alive until
the frame ends. Calling a navigation method directly misses this failure, so the regression emits the actual
signal and `scripts/menu-navigation.sh` sends mouse press/release events through the viewport, including scene
handoffs and returns with motion both enabled and disabled. Its profiles and settings are isolated per process.

## Shrink the layout before shrinking the letters (`game/scenes/title/`)
Scaling an entire menu also scales its text and click targets. The compact Foundry panels instead reduce padding,
group preferences in a row, and place the optional tutorial on its own tab. Normal text remains 18 pixels in the
design canvas. The carousel is the exception: its existing card geometry can be scaled inside a plain Control,
but a surrounding wrapper must reserve the scaled footprint because containers measure unscaled minimum sizes.
English and Japanese layout tests check the resulting panel bounds, and screenshots check the actual text flow.

## Compact typography needs consistent button states (`game/scenes/title/foundry_ui.gd`)
The next density pass reduces body text to 16 pixels and adjusts captions, padding and section gaps together.
Godot uses `hover_pressed` for a selected button under the pointer: leaving that state inherited can restore the
shared theme's larger padding and boxed appearance. Every button state, including focus, needs the same compact
margins. Local Library rows also override the shared archive's minimum height after each refresh, keeping the
run's archive unchanged. Screenshots caught clipped action captions at 48 pixels; 52 pixels keeps both lines visible.

## A boss is an encounter role (`game/scenes/title/foundry_bestiary.gd`)
Sprite size and names cannot reliably distinguish bosses: a guardian can contain multiple small parts, and the
two modes use different guardian pools. Build the Library's locations from the effective run catalog, just as the
map does. Annotate deep copies so adding locations and search descriptions cannot modify combat content. The
tests compare both modes, the fourth layer and the unchanged source catalogue.

## Focus reveals scroll entries before a mouse can click them (`game/tools/menu_navigation.gd`)
Finding a button in the scene tree does not mean its rectangle is inside its scroll viewport. The first mouse
walkthrough missed the Quine because it was below the visible boss list. Focusing it and letting the layout settle
uses the list's `follow_focus` to reveal it before sending the real mouse press/release. Rebuilding the list also
restores focus to the selected row, so keyboard browsing does not jump back to the room header.

## An unattached container still needs disposal (`game/scenes/title/foundry_library.gd`)
The filter row is only attached for collections with filters. Creating it for every collection and leaving the
empty ones unattached leaked two orphan nodes in the navigation tests. Free unused, unattached containers; defer
deletion for attached controls that may still be emitting a click. Check for a null focus owner before asking
whether a list contains it: an open menu can legitimately have no focused control yet.

## Conceal the swap before revealing the room (`game/scenes/title/archive_passage.gd`)
A fade that starts after adding the new room exposes both screens at once. The passage first covers the old view,
emits its midpoint when every pixel is opaque, then reveals the new room. Shader progress comes from the same
Tween that times the swap, so mist, sigil arcs and drifting sparks stay synchronized. The veil owns keyboard focus
and accepts input until it clears; restoring station focus at the midpoint would let Enter launch a run behind it.

## A shrinking minimum does not shrink a freely placed Control (`game/scenes/title/foundry_library_room.gd`)
Wrapped labels initially reported a larger minimum, expanding the catalogue beyond the screen. Later its minimum
shrunk, but the freely placed wrapper kept its expanded size. The centred container now remeasures the panel, and
its minimum-size change restores the wrapper’s intended room rectangle. The geometry tests caught the overflow.
A deferred closure captures a WeakRef to the page: capturing a freed node directly reports an error before the
closure can check its validity. Resolving the WeakRef inside the callback avoids passing a freed typed argument.

## Start feedback before loading the destination (`game/scenes/title/title.gd`)
The Library click built 71 buttons and synchronously loaded every icon before creating its transition. Profiling
with actual rendering measured 1.09–1.24 seconds for the panel alone. The passage now starts in the click handler,
and the destination is built at its opaque midpoint. The same panel builds in 8–26 ms after removing eager row
art loads. A transparent warm-up draw compiles the circle shader during title loading rather than on first click.

## Threaded loading still needs ownership (`game/scenes/title/foundry_library_art.gd`)
Only visible rows request canonical artwork, with two jobs in flight and a bounded cache held by the title.
`load_threaded_get` blocks if called too soon: poll status and retrieve only completed resources, one per frame.
Retained texture references avoid reloading the same icons after a list rebuild or room reopening. At final cache
disposal, consume outstanding jobs so Godot does not retain unclaimed resource loads. Missing individual artwork
still uses the existing atlas/null fallback. Godot’s headless dummy renderer reported null texture
initialization from loading threads; it now loads one visible texture synchronously per frame. The rendered
143-click navigation walkthrough separately checks the real threaded path. No second copy of Spellforge art is
introduced.


## Swap typography without rebuilding the game (`game/ui/ui_theme.gd`)
A Theme is a shared Resource. Updating its font references changes inherited lettering immediately without
throwing away a scene's state. Front-end theme copies are weakly registered with their own heading convention;
font refresh changes fonts alone, retaining local text sizes and spacing. Dead copies are pruned on registration.
Decorative proportional faces need a separate `code_font` role: RuneCode measures one fixed character cell, and
source/diff panels rely on indentation. Their explicit monospaced font keeps both execution visuals and code
inspection aligned while menus and card identity adopt the selected face.

## Preview actual font resources, including fallbacks (`game/ui/ui_fonts.gd`)
The font picker uses the same bundled FontVariation resources as the game, with a weight axis for four candidates
and static regular/semibold Spectral files. Six samples can be compared before changing the live theme. Japanese
serif/sans system fallback follows the candidate's style; the current default retains its original fallback chain.
The original face's `has_char` does not enumerate automatically supplied system glyphs, although rendered Japanese
works. Tests check explicit Japanese support for candidates and screenshots verify the actual default/fallback
rendering. Persist validated ids so missing/invalid fields in older saves select the original face.


## Rehearse on a local clock (`game/scenes/title/foundry_rehearsal.gd`)
A preview must not slow the rest of the game or silently equip the skin being inspected. HeroView accepts a
preview appearance independently of saved equipment, while sprite time and AnimationPlayer speed belong to the
local actor. The rehearsal drives MagicCircle manually with scaled delta and disables its automatic processing;
this keeps formation, turning, particles, closing and practice pulses together at every speed. Disabling the actor
subtree freezes its animation and secondary motion. Sampling an animation before freezing also matters: a new 3D
model that never advances a frame can otherwise display its rest pose. A direct, zero-blend seek applies the idle
pose immediately and makes paused frame inspection accurate.

## Preserve an explicit choice when changing a default (`game/app/settings.gd`)
The old `default` font id is also a selectable Original face. Changing its meaning would make a saved Original
choice ambiguous. Keep that id and add a preference revision: migrate legacy defaults once, then retain explicit
Original selections in revised saves. Validate both the id and revision's type before comparing them; GDScript
cannot compare an integer Variant with a String. Fresh and invalid preferences use Cinzel while other chosen
candidates continue to persist.


## Keep the carousel alive while replacing its preview (`game/scenes/title/foundry_character.gd`)
The skin carousel and practice actor have different lifetimes. Browsing replaces the actor, but rebuilding its
controls on every skin_ready signal would also replace the wheel and cut off its gliding portraits. Keep the
active Skins subtree intact and rebuild native animation controls only when another tab needs them. The wheel
reuses the existing base layout at a smaller scale; a wrapper reserves its scaled footprint because Godot's
containers measure unscaled minimums. Clicking any card browses only, while the explicit equip action saves.


## Size the camera to the model, not the model to the camera (`game/scenes/shardrun/fight/hero_view.gd`)
An orthographic camera's `size` is the height of the world it shows (the view keeps its height), so a figure
`stature` metres tall fills `stature / size` of the view. One fixed camera made a 1.75 m model larger than a 1.39 m
one and both larger than a drawn skin with its own framing. Measuring each model once (the top of its meshes'
AABBs in the rest pose, walking local transforms so it works before the node is in the tree) and setting
`camera.size = stature / fill` puts every skin at the same height; effects then size by that height, not by the view.

## A stage with a clock of its own (`game/scenes/shardrun/fight/battle_stage.gd`)
Slow motion for one part of the screen cannot use `Engine.time_scale`, which slows the whole game. The rehearsal's
stage keeps `_clock`: waits poll it on `process_frame` (and so stand still while the stage is disabled), effects
multiply their `delta` by a `time_scale` the stage sets, and tweens it creates are kept so their `set_speed_scale`
follows its tempo and `custom_step` can move them a frame by hand. Disabling the stage (`PROCESS_MODE_DISABLED`)
pauses its processing and the tweens bound to its nodes at once. A test cast is then the fight's own playback,
not an imitation of it.

## Booting resets where settings are saved (`game/test/app/cosmetics_test.gd`)
`Game.boot` reads `user://settings.json` and points `Settings.path` back at it; `Game.select_profile` saves. A
test that boots and then switches profiles writes the player's real settings unless it redirects the path after
booting. A diff of the real file before and after a full run is the cheap check.

## Let the data choose the picture, and make clashes deterministic (`game/core/circle_layers.gd`)
A spell's circle has one layer per shard, and which figure a shard draws is a pure function of the card: its role picks
a family of looks, the FNV hash of its id picks the member. Two different cards in one spell must not look alike, so a
clash nudges the later one to the next free member (then the next free kind) in a fixed order: still deterministic,
and the first card played keeps its natural look. The same card played twice keeps its look and turns the other way.
Keeping this in a pure function means the mapping is unit-tested and pinned, and the scene only draws what it is told.

## Share progress, not just completion callbacks (`game/scenes/shardrun/fight/program_code.gd`)
A callback at a function's return can only begin an animation after the work is over. To show construction during
the function, the walkthrough supplies a monotonic progress share while traversing its lines and loops. The same
share interpolates that call's recorded work. Circle strokes no longer finish on an independent timer, and work
thresholds can unlock recorded enemy actions while the code keeps moving. Those entries must be consumed once:
replaying the normal log afterward would otherwise apply the same damage twice. Their recorded order stays
authoritative, even when battle order differs from tempo order.

## Separate visual time from execution progress (`game/scenes/shardrun/fight/magic_circle.gd`)
The circle needs a clock for drawing strokes and rotation, but that clock cannot decide which shards have run:
slow walkthroughs and pauses would otherwise construct unvisited layers. Shard Weave records an arrival time only
when `shard_resolved(index)` fires. Each layer interpolates from that timestamp; the frame follows their combined
progress. Exact call indices distinguish repeated shards, and sealing a partial program never fills missing slots.

## Draw fills as bands, not discs (`game/scenes/shardrun/fight/circle_layer_art.gd`)
Six figures that each fill a disc pile into mush when nested. Giving every layer an outer and an inner radius (the next
layer's) and making the filling kinds (spokes, a spiral, a honeycomb, a rosette) draw only inside their band keeps each
one readable, and the layers still accumulate from the rim inward. Stroke widths scale with the circle's radius
(`CircleLayerArt.weight`), since the same hairline reads fine at 100 px and vanishes at 400.

## A property that derives from another keeps old callers working (`game/scenes/title/foundry_rehearsal.gd`)
The fitting room used to choose a tier; it now chooses a shard count and the tier follows. `tier` stayed as a
property whose getter is `CircleLayers.tier_for(shards)` and whose setter picks as many shards as that tier holds, so
the older callers (a tool, a test, the carousel's browse-to-try) did not change.

## Test the visible geometry, not just the progress value (`game/scenes/shardrun/fight/script_loom.gd`)
An animation can report a partial progress value while drawing a whole circle underneath it. Full-disc glows and
arrival rings made the first construction look complete even though shard counters advanced correctly. Script Loom
has no underlying full shape: a function owns an angular sector, and its paths are clipped by total traversed
distance. A geometry test proves the first function leaves other quadrants empty. Holding geometry still while
the tip moves makes construction legible; rotation can start after completion without obscuring that movement.

## A pure function for a rule that has three callers (`game/core/cosmetic_rules.gd`)
Which circle style a constructed cast draws used to be decided in three places (the stage, the rehearsal and the card
preview), each with its own `if`. `CosmeticRules.construction_style` holds the precedence once (a centred style worn in
Spells, then the move's own, then the worn circle), so adding Ring Bloom was one list entry and one function, and a
test states the order.

## Draw a ring whole, animate only what turns it (`game/scenes/shardrun/fight/ring_bloom.gd`)
The earlier circles clip their strokes by progress so a figure appears to be written. For a ring that must appear at
once, the progress value is spent on something else: opacity over the first part, a small pop in scale, and the
remaining turn of its ornaments. A plain circle looks the same however it turns, so the turn only shows on the ticks,
beads, dashes and polygon. Direct `_draw()` calls fail outside the draw notification: a test that must exercise drawing
queues a redraw and waits a frame.

## Draw glyphs as strokes, not text (`game/scenes/shardrun/fight/rune_glyphs.gd`)
A font may lack the characters a magic circle wants (futhark, alchemical signs), and the project's fonts are chosen by
the player. Twenty-three glyphs are a few polylines each in a half-by-two box; placing one on a ring is a rotation of
its points. They draw the same in every font and under the circle's slanted transform, and a test can count them.

## A preview should show the thing at rest (`game/scenes/title/look_art.gd`)
A card that advances an animation to the moment it finishes shows the flare of finishing: a blown-out core. The card
now builds the circle layer by layer and then lets it settle for a second before it shows it.


## Swap the list before you touch the nodes (`game/scenes/shardrun/fight/hand_view.gd`)
Setting a pointed-at card's `mouse_filter` to IGNORE makes Godot send `mouse_exited` at once, in the middle of the
loop that is sending the old hand to the discard pile. The handler re-arranged `cards`, which still named the old hand,
and cancelled the discard tweens of the cards already sent: they stayed on screen as a ghost of the previous hand. A
handler that can fire during a loop must see the finished state, so `cards` and `hovered` are swapped before any card
leaves. The bug needed a real pointer to show (the headless tests never hover), so the test fires `mouse_exited` itself
from inside the loop.

## One line for a volley (`game/scenes/shardrun/log_digest.gd`)
The rules record one entry per bolt, right for the stage that plays each one and wrong for a person reading the log: a
thirty-bolt cast was thirty copies of one sentence. A digest at the point of reading folds the bolts of a volley by
kind and foe into one entry carrying the sums, so the tallies still add up, and leaves the recorded entries alone, so
the rules, the saves and the reference results never change for the sake of wording.

## The silhouette fixer tips the toes up (`game/characters/_local/*/*.glb.import`, `test/characters/skin_import_test.gd`)
Godot's rest fixer can re-aim an A-pose rig's limbs into the T-pose the moves were keyed in (`fix_silhouette`). It
re-aims every bone it judges off the reference silhouette, the feet included, and a foot whose bone runs down to the
toes is turned until it runs level: the mesh it carries ends up toes-up even at rest. Its `filter` leaves bones out;
the normalised skins list both feet and toes there, and a test checks every skin import that uses the fixer.

## A smoothness check is angular speed per frame (`pipeline/blender/build_moves.py`, `pipeline/moves/clips/`)
Two things read as a jerk: one frame much faster than its neighbours (a key whose ease arrives in about a frame: the
snap's torso turn), and a jump from standing still to full speed (`cubic_out` straight after a dead hold). Measured
as each bone's world rotation between frames, both show as numbers, and the fixes are in the keys: let the body's
turn arrive with the hand's rise, coil slowly through a wait, and accelerate out of it (`sine`) instead of starting
at full speed. Measure with the quaternions' shortest angle, min(θ, 360° − θ): q and −q are the same turn.

## One function for the cast and its preview (`game/core/programs/program_rules.gd`, `play`)
The preview used to repeat the cast's landing steps in its own code, and the two drifted: the cast let faster foes act
first and gave the relics' block after landing, the preview did neither, so a preview could promise 10 damage the
cast never landed (docs/PHASE2.md P2-01, P2-02). Now both call `play`, the preview on a deep copy of the state with
`rehearsal` set (no win or loss is declared on the copy). A rule added to `play` reaches both at once. The same
lesson as "don't repeat yourself", but with a sharper reason: here two copies of a rule are a bug waiting to happen,
because the game promises they agree.

## Check a limit before you leave the loop (`game/sandbox/sandbox.gd`, `run`)
The sandbox polls a running program: drain its pipes, then stop if it has exited, else check the output cap and the
clock. A program that printed 6 KB against a 1 KB cap and exited within one poll left through "it has exited" before
the cap was checked, and came back as a success with its output cut. The order of checks in a polling loop is part
of its meaning: every check that must hold for the final state goes before the exit.

## A sentence translated by its format (`game/app/text.gd`, `Text.sentence`)
The rules write English sentences from formats ("%s takes %d.") and keep them that way, because they are saved and
compared with reference results. To show one in Japanese, the format itself is the key: turned into a regular
expression (`%s` becomes `(.+?)`, `%d` becomes `(-?\d+)`), it matches the finished sentence and hands back the values,
which then fill the Japanese format. Formats are tried longest first, so "%s takes %d from %d bolts." wins over "%s
takes %d.". Japanese often wants the values in another order, so a translation can number its slots, `{2}に{1}`.

## C++ in WebAssembly, compiled before the game runs (`scripts/build-cpp.sh`, ADR-0046)
Python and JavaScript are interpreters, so a job can send them source. C++ has to be compiled, and a compiler in the
turn loop would make every preview wait, so every card is compiled ahead of time into one module and the job sends
only card ids. Two details made it work under wasmtime: exceptions need the new encoding of Wasm's exception-handling
proposal (`-fwasm-exceptions -mllvm -wasm-use-legacy-eh=false`, linked with libunwind), and a precompiled `.cwasm`
only runs with the settings it was compiled with, so `-W exceptions=y` is given both when it is compiled and when it
runs. `#line 1 "card.cpp"` keeps `__LINE__` (which the loop counter records) on the card's own numbering.

## Pure data in a state machine: Issues as a list of effects (ADR-0050)
Thirty events with different shapes (a heal, a card swap, a bet on reading code, a gift that pays two rooms later) share
one engine because each choice is only a list of small effects. An effect that cannot finish on its own (it needs the
player to pick a card) returns `true`, which means "I opened a stage and took the rest of the list with me"; the command
that answers the stage runs that rest. This is a continuation, written as plain data so it survives a save. The same
trick makes a deferred effect easy: `pending` is just an effect list with a countdown beside it.

## A formatter can change the meaning of code
`gdformat` rearranged a lambda inside a parenthesised `.filter(...).size()` chain into a layout Godot 4.7 refuses to parse
("Unindent doesn't match"), and every script that used the class failed with a confusing cascade. When many scripts fail
to resolve one class name, look for that class's own parse error first, and run `scripts/check.sh` after formatting.

## Two renderers, one GPU
A screenshot is drawn on the GPU, and so is an SDXL render. With ComfyUI at 100% a screenshot takes minutes or hangs.
Render the art and take the pictures one after the other, never at once.

## 2026-10-04 — Issue quizzes need the sandbox trace, not its work total

The Will It Halt Issue reads the executed card's trace to decide whether its program finished inside the budget.
`SpellRuns` keeps the numeric total in `work` and the ordered steps in `trace`; treating `work` as an array silently
made this path fail. Read `trace`, convert it through `ProgramRules.stages`, and keep the shared work total numeric.
End-to-end Issue flows now pass for Rubber Duck, Oracle Test Suite, Big-O Quiz and Will It Halt in Python, JavaScript
and C++.

## 2026-10-05 — Fullscreen is not one thing, and a frame cap has to fit the refresh rate

`WINDOW_MODE_FULLSCREEN` asks the window manager for its fullscreen state, which lets the compositor skip itself and
show the game straight; on a laptop where one GPU draws for a screen another drives, that path flashed garbage green
when the window lost focus. A borderless window the size of the screen looks the same and stays composited. Separately,
`Engine.max_fps` with vsync on only looks smooth when it is the refresh rate divided by a whole number: 90 on a 165 Hz
panel shows some frames for one refresh and some for two. `Settings.frame_cap` picks the largest such share that is 90
or less. See ADR-0051.

## 2026-10-05 — Some settings can only be set before the program starts

Godot picks the graphics device and the renderer once, from the command line, so a setting for them cannot take effect
while the game runs. The game saves the choice and starts itself again with the right flags (`OS.create_process` on
`OS.get_executable_path()`, with the original arguments), marking the second start so it cannot loop. Two guards matter:
`--gpu-index` past the last device quietly falls back to automatic, but an unknown `--rendering-method` aborts, so only
whitelisted names are passed; and a test, a tool or the editor must never relaunch, so those are recognised by their
arguments. See ADR-0052.

## 2026-10-05 — A laptop's two GPUs are a bug source, not just a speed knob

With the AMD chip driving the screen and the NVIDIA chip chosen to draw, every frame is copied between them, and that
copy was unstable while the window was behind another. Drawing on the chip that drives the screen (or OpenGL through
Mesa) was steady. Measure with a screenshot loop and a count of the odd pixels, unfocused, on each GPU: it showed the
difference where reading the code could not. And `ceili(NaN)` is the smallest integer, not zero: a refresh rate that
the platform cannot report may be 0, -1 or NaN, so test `value > 0.0` rather than `value <= 0.0`.

## 2026-10-05 — Stable cosmetic variation (`game/ui/card_wear.gd`, ADR-0013)

Card edge nicks are decoration, so each visible card instance gets a one-time seed inside the UI renderer. A card
moving or being hovered cannot advance the run's random stream or change its finish, and two copies of the same shard
can have different quality and irregular chip patterns.

## 2026-10-05 — Reward stages leave later rewards intact (`game/core/shardrun/shardrun_commands.gd`, ADR-0049)

Program rewards can contain several independent fields. The loot view shows relics before cards, and a skip command
clears only the selected reward field; the next stage is then built from the remaining state. A forced cursed relic is
already applied by the rules, so its “keep going” command only dismisses the presentation. This keeps UI sequencing
from quietly changing reward rules.

## 2026-10-05 — Keep card hover details when making the face clickable (`game/scenes/shardrun/room_panel.gd`)

`CardFace` already routes a click through its `pressed` callback and keeps its child art pass-through, so a reward can
select on the face without an invisible button stealing the hover that opens the code detail. A composed relic panel
needs its child controls to pass pointer input up to the panel before it can select the whole surface.

## 2026-10-05 — Only hide titles in the compressed spell row (`game/scenes/shardrun/card_face.gd`)

The same small card size is used for both the active spell and the held-card row, but only the spell slot compresses
names into jittery, unreadable text. `CardFace.spot.zone` distinguishes them, so hide only the name for `spell` and
leave names visible in `hold` and in the hand.

## 2026-10-05 — Swap an ending under the sigil veil (`game/scenes/shardrun/shardrun_screen.gd`)

Abandoning a run changes the current Shardrun state and shows its score; it does not load another scene. Reuse
`ArchivePassage` over the current screen and redraw at its opaque midpoint, while title returns use the same veil via
`Game.go(..., true)`. The player sees the same transition in both flows.

## 2026-10-05 — Let Rootglass's frame crop the card art (`game/scenes/shardrun/card_face.gd`)

The Rootglass SVG already has an opaque body with a transparent oval opening, so draw the card picture beneath that
frame instead of adding a second rectangular window. `TextureRect.STRETCH_KEEP_ASPECT_COVERED` fills the oval's bounds;
after review, scale the art to 45.6% of the opening and lift it by 6% of the opening's height plus 11 px. This leaves
more breathing room around each relic while the parchment plaque naturally covers the lower picture. Older frames keep
their original inset art. Reviewed reward and hand captures: `/tmp/rootward-pack-oval-art-polish.png` and
`/tmp/rootward-hand-oval-art-polish.png`.

## 2026-10-05 — Soften the card glow and finish script rewards

The Rootglass art window now has a cubic radial glow with the same 11 px lift as its picture, replacing the hard
concentric rings. Script rewards wait until relics, cards, caches and spells are resolved; the command rules enforce
that order, and opening a cache preserves a script for the final stage. The reward art opens its own `HoverInfo`, and
the fight belt slots grew from 56 to 62 px with tighter spacing. New square anime portraits for Mana, Anby, Vesper and
Emberfox were made with the built-in ChatGPT image generator and wired to fight portraits, the character carousel and
run summaries. The screenshot tool can capture the final script stage with `ROOTWARD_SHOT=script_reward`.

Reviewed: `/tmp/rootward-rootglass-gradient-smoothed.png`, `/tmp/rootward-script-reward-final.png`,
`/tmp/rootward-script-reward-tooltip.png`, `/tmp/rootward-script-belt-larger.png`,
`/tmp/rootward-anby-avatar-belt.png`, and `/tmp/rootward-mana-avatar-carousel.png`. `scripts/lint.sh` passes; no
automated tests were run.

## 2026-10-06 — Preserve source when a program bolt is a scheduler rest (ADR-0054)

A one-power neutral bolt might be a real attack or a `Task Scheduler` spacer, so power and element cannot say whether
it is safe for Handoff Ward to convert. Keep the scheduler's provenance as an explicit `idle` bit through program
normalization and the C++ bridge. The matching guard consumes that bit; this avoids guessing from a bolt's visible
shape and makes the two-card interaction work across languages.

The v0.2 balance-fix set adds ten program cards with separate generated icons and repairs the audited low-payoff
cards. `Equal Partition` uses an explicitly bounded word bitset, then a deterministic greedy split above 1,024 total
power; `Coin Change` uses the same fixed-sum boundary for its exact search. This keeps work estimates close to the
algorithms' actual bounded work, and the greedy fallback is explained on the card. The native build compiles 1,222
Program functions and 77 Spellforge functions. Reviewed the hover capture at `shots/balance-cards-hand-hover.png`.
Balance impact still needs playtesting.

## Finding the file a stack trace means (`game/sandbox/lanternroot/watch.js`)
QuickJS names every function built with `new Function` `<input>` in a stack trace, so a trace cannot say which of
the player's modules failed. Lanternroot's watch loads module number k with `k * 10000` blank lines in front of it:
line 7 of module 2 is reported as line 20009 (plus the 2 lines QuickJS's wrapper adds), and dividing by 10000 gives
the file back. Blank lines cost the parser almost nothing. When a tool hides information, sometimes you can encode it
in something the tool does keep.

## Output a killed program never sent (`game/sandbox/launch/launch.js`)
Standard output to a pipe is buffered: text waits in memory until the buffer fills or the program ends. A program
stopped by the time limit loses whatever was still waiting. The watch reports each test as it finishes and flushes
right away (`process.stdout.flush()`, which the launcher adds), so a test that never ends still leaves the ones
before it reported.

## Smooth glows (`game/scenes/lanternroot/town_painter.gd`)
A glow drawn as stacked translucent circles shows its rings as bands. One radial `GradientTexture2D` with an eased
falloff, made once and kept in a `static var`, is smooth at any size and can be tinted and stretched for every
lantern, firefly and gremlin eye.

## Keys a focused control takes first (`game/scenes/lanternroot/workbench.gd`)
Godot offers input to `_input` first, then to the focused Control (`_gui_input`), and only then to
`_unhandled_input`. A `CodeEdit` with focus takes Ctrl+Enter as "new line below", so the workbench's Run shortcut
lives in `_input`, and checks that the workbench is visible.

## Small capitals and code (`LanternWorkbench.prose`)
The interface font is Cinzel, which has only capitals: `loaves_for` in a sentence shows as LOAVES_FOR, and in code
case matters ("Dear Mabel," is not "DEAR MABEL,"). Anything that is code or a value goes through a RichTextLabel with
backtick spans in the code font, so the player sees exactly what their program produced.

## A token follows the layout, not the signal (`token_flight.gd`, `token_stream.gd`)
The code panel emits "this call started" before it scrolls to the call, so a token launched on that signal left from
where the line used to be. A flight also computed its positions through the overlay's transform, which had not settled
yet: the token was placed against a stale origin and ended off the top of the window. Two fixes made it work: wait for
the reveal to settle, and keep the flight top-level in global coordinates, so no parent's layout can move it.

## A shared English summary is one Japanese entry (`locales/ja/`)
Japanese text is keyed by the English exactly. A card and its refactor often share a summary, so they share one entry.
Changing the English of one of them moves that entry, and the other card is left without Japanese (a locale test caught
this twice in one pass). Two cards that come to read the same make a duplicate key, which the locale test rejects. When
a summary changes, check the entries of its refactor and its base as well.

## Smooth motion is a short peak, measured per frame (`pipeline/moves/clips/`)
The keys of a move were already smooth. The jerk was a speed spike: a snap whose ease front-loads its movement (expo_out)
packed into three frames, and a finger ramp that blended in over a quarter of a second. Measure each clip's summed bone
speed per frame in the live Blender, and the spike shows as a single peak (the worst frames of a clip are its first few).
Lengthen the ramp or soften the ease, keeping the release, and the peak falls while the timing stays.

## 2026-10-08 — Convert a global point through the parent, every frame (`game/scenes/shardrun/fight/legendary_cast.gd`, `game/scenes/shardrun/fight/black_hole_impact.gd`, `game/scenes/shardrun/fight/constellation_volley.gd`)

A point passed between nodes is global, and each node converts it into its own space every frame, with its parent's
transform. `LegendaryCast.global_of` uses the node's parent rather than the stage: the stage's shake moves its child
layers `_world` and `_fx` (`battle_stage.gd`, `shake`), so the stage's own transform misses the shake, and a bolt would
start a few pixels off. A black hole must not set its position from `to_local` on itself, because that measures from
where the node already is and moves it every frame, so `_follow` converts through the parent instead. The LEARN comment
in `black_hole_impact.gd` gives that reason; `black_hole_impact_test.gd` pins the outcome, that the hole stays on its
point under an offset, a scaled and a moving parent. A volley converts each target and origin every frame as well, since
the orrery turns and a parent may move during a flight; `constellation_volley_test.gd` checks that a moving parent still
aims at the global target. The carousel preview converts its card's centre with the card's own transform before it
places the hole (`game/scenes/title/look_art.gd`). Compare the token entry above, which keeps its flight top-level
instead.

## 2026-10-08 — A missing shader keeps the clock running (`game/scenes/shardrun/fight/black_hole_impact.gd`)

Without its shader, a black hole still runs its timeline and emits its signals, so a caller that awaits `landed()` never
hangs. Only the drawing is skipped: `_build` returns before it adds the screen copy and the quad, while the clock in
`advance` keeps going. A picture that fails to load should cost the picture and nothing else, which is the rule for
every picture, model and sound in this project. The LEARN comment in `black_hole_impact.gd` states the behaviour; no
test removes the shader to check it.

## 2026-10-08 — A BackBufferCopy's rect is in viewport coordinates (`game/scenes/shardrun/fight/black_hole_impact.gd`)

A `BackBufferCopy` copies the part of the screen its `rect` names, and that rect is read in viewport coordinates, not in
the copy's own space. The rect set when the node was built copied the wrong patch of screen, so the lens read as flat
grey. The fix sets the rect once the node is in the tree, and again every frame after that, as the node's global
transform applied to its copy area. A render showed the fault; the contract's Verification list does not name that
render. `black_hole_impact_test.gd` pins the rect to the quad's global rect, which is the viewport reading the fix
relies on, but a test cannot show what the engine reads.

## 2026-10-08 — A node's signal waits for the tree, and its release outlives the node (`game/scenes/shardrun/fight/black_hole_impact.gd`)

A black hole's clock runs only while the node is in the tree, so an impact is never announced for a node its parent does
not hold yet; `black_hole_impact_test.gd` checks that no signal comes before the node is in the tree. `landed()` returns
a signal on a `RefCounted` release, which outlives the node. The LEARN comment in `black_hole_impact.gd` gives the
engine reason: a node cannot emit its own signal once it is freed, and emitting one from inside the parent's removal
would run the waiters in the middle of that removal. The tests pin the outcome: the release fires when the node is freed
before its impact, and a waiter released by that removal may add a child to the parent. On an early removal the release
fires deferred, after the removal ends, which is what avoids the "Parent node is busy setting up children" error; the
contract's Verification checks that the error is absent from the log across a legendary cast. At the impact itself the
release fires at once. The button entry on `game/scenes/title/title.gd` is the same removal problem, seen from a click.

## 2026-10-08 — Drive a shader and its clock from one progress value (`game/scenes/shardrun/fight/black_hole.gdshader`, `game/scenes/shardrun/fight/black_hole_impact.gd`)

Every timed feature of the black hole is a formula of one `progress` uniform from 0 to 1; the style uniforms only choose
which features show. The shader never reads `TIME`, has no loops and makes at most one screen read (the lens), so the
same progress draws the same frame over the same background. The clock is `advance(delta)`, which `_process` calls each
frame with the scaled time, and a test may call it directly to step to any moment exactly;
`test_progress_drives_the_shader_uniform` checks the uniform. The LEARN comment in `black_hole_impact.gd` gives the
reason for a plain clock rather than a `Tween`; no test compares the two. The entry on `foundry_lights.gdshader`
explains why a setting must not drive `TIME`; this entry is about checking one frame.

## 2026-10-08 — Hold a frame by holding its clock (`game/scenes/title/look_art.gd`)

The carousel shows a black hole at 0.6 of its timeline. The timeline is advanced to that point in one step (`advance`),
and then its `time_scale` goes to 0, so the clock holds while the process keeps running. The lens copy refits every
frame and stays a true lens; `black_hole_impact_test.gd` checks that a frozen clock still follows its parent and refits
its copy. Stopping the process instead would leave the copy behind, as the LEARN comment in `look_art.gd` says, and the
shader reads only `progress`, so the held frame is the same every time.

## 2026-10-08 — Read a setting where the motion is drawn (`game/scenes/shardrun/fight/constellation_volley.gd`, `game/scenes/shardrun/fight/legendary_orrery.gd`)

The volley reads `Settings.reduced_motion` each time an effect starts and each time it is drawn, not once when a bolt
is added, so turning the setting on during a cast stops the sparks and blooms at once. An effect begun at full motion
that is no longer drawn ages out unseen. The trace keeps the length it was given, because a timeline cannot change
length mid-flight without jumping. The orrery takes the same approach: the circle sets its flare on every arrival
whatever the setting, and the frame that is drawn reads no flare under reduced motion. The state keeps the value, and
the drawing decides what to show.

## 2026-10-08 — Reduced motion keeps what tells you and drops the decoration (`game/scenes/shardrun/fight/constellation_volley.gd`, `game/scenes/shardrun/fight/black_hole_impact.gd`)

Under reduced motion the volley keeps its flights, its arrivals and the white flash of each star's ignition. It drops
the origin burst, the sparks, the convergence bloom and the growing ring around the ignition. A star's flare keeps a
glint that shrinks and fades where it stands, which still says the star flared. The black hole keeps its disc, its
photon ring, its impact flash and its features (digits, split, cells, scanlines), and drops the spin, the lensing, the
jets, the dispersal, the shock ring and the inflow arms. The inflow arms are not yet verified on screen. The rule is the
same in both: whatever tells you what happened stays, and only the motion goes.

## 2026-10-08 — Map a shape's position, not its shape (`game/scenes/shardrun/fight/legendary_orrery.gd`)

The orrery's orbits are narrowed and leaned back to read as a disc seen from the side. The planets and their glyphs are
placed through the same map, but they are drawn in unsquashed local space, so they keep their round shape while the
orbits they sit on are narrowed. The magic circle entry above ("A circle seen side-on is a transform, not a picture")
draws everything in disc space, because its rings should narrow with the disc. Here the planets must not, so transform
the position, and draw the shape in its own space. The LEARN comment in `legendary_orrery.gd` gives this; no test checks
the planets' shape.

## 2026-10-08 — A tiny polygon fails to triangulate (`game/scenes/shardrun/fight/constellation_volley.gd`)

A diamond a fraction of a pixel across makes Godot's polygon triangulation fail with "Invalid polygon data,
triangulation failed", and nobody could see it anyway. The volley skips any diamond under `MIN_DIAMOND_ACROSS` (0.5 px)
before it builds the polygon. The contract's Verification checks that this error is absent from the log across a
legendary cast, and `constellation_volley_test.gd` pins the skip. Check the size of a shape before handing it to a
polygon call, and skip what cannot be seen.

## 2026-10-08 — An effect ends at its longest fade (`game/scenes/shardrun/fight/constellation_volley.gd`)

A bolt's trail fades 0.25 s after the bolt lands, but the bolt is not finished then. The traced line and the last star
keep their own longer fades, so a rider is done only when the longest of them has ended. Freeing the node at the
landing would cut those fades short. An effect ends at the latest end of its parts, not at the end of its main motion.

## 2026-10-08 — Close says no bolt is coming, and does not free (`game/scenes/shardrun/fight/constellation_volley.gd`, `game/scenes/shardrun/fight/legendary_cast.gd`)

`close()` on a volley says that no more bolts are coming. It does not free the volley, because a bolt that waits
behind a falling blow can be added after the next cast has closed it, and that bolt must still fly. The volley frees
itself once its riders are done. A volley that has already freed itself takes no more riders: `add_rider` would land
the bolt at once, with a warning. So `LegendaryCast.ride` checks that the volley is valid and not queued for deletion,
and starts a new volley for a late bolt instead.

## 2026-10-08 — One effect per target, with slack for drift (`game/scenes/shardrun/fight/legendary_cast.gd`, `game/scenes/shardrun/fight/constellation_volley.gd`)

A foe gets one black hole per cast, keyed by the foe and not by the bolt, so one hole stands however many bolts land on
it. A volley blooms each target once, and it matches targets with four pixels of slack (`SAME_TARGET_PX`). The LEARN
comment in `constellation_volley.gd` gives the reason: a foe's point may drift a little between two adds. Within one
cast, though, `LegendaryCast.target_of` keeps each foe's point from its first launch, so the bolts of one cast share an
exact point and that drift does not reach the volley on this path. The slack is a margin, which
`constellation_volley_test.gd` pins (bolts aimed a few pixels apart share one bloom). Key a shared effect by the thing
it belongs to, and allow for drift when you compare positions.

## 2026-10-08 — State that closures share belongs to the owner (`game/scenes/shardrun/fight/legendary_cast.gd`)

Each bolt of a cast gets a closure that returns the cast's origin. The last star the cast saw is kept on the cast
rather than in a closure, so every bolt shares it. A volley can first read its origin after its circle has freed
itself, because a bolt waited behind a falling blow; it then gets the star the cast last saw, not the circle's centre.
A value that several closures must agree on belongs to an object that outlives all of them.

## 2026-10-08 — Lay out for the final count, not the count so far (`game/scenes/shardrun/fight/legendary_orrery.gd`)

The orrery spaces its planets for every shard in the plan, not only the shards that have arrived, so no planet moves as
shards come in. Arrivals come in plan order, so the last planet belongs to the last shard, which is the last to arrive.
A circle that never receives its last shard (a function that returned early, or a failed program) keeps that place,
though it is never drawn. A layout that counted only the arrivals would move every planet each time one came in. The
LEARN comment in `legendary_orrery.gd` gives this; no test checks that the planets stay still as shards arrive.

## 2026-10-08 — A hash's low bits need a finaliser (`game/scenes/shardrun/fight/legendary_look.gd`, `game/core/rng.gd`)

`Rng.hash_string` is FNV-1a: each UTF-16 code unit is XORed into the state, and the state is multiplied by an odd
prime. Multiplying by an odd number keeps the lowest bit, so the lowest bit of the hash depends only on the lowest
bits of the characters, and the seeds of consecutive bolts would alternate in any rule that reads bit 0. `rider_seed`
therefore runs the hash through `Rng.mix32`, which spreads every input bit across the output, and masks the result to
31 bits so the seed stays non-negative. Read a hash's low bits only after a finaliser.

## 2026-10-08 — Each rule takes its own bits of a seed (`game/scenes/shardrun/fight/legendary_look.gd`)

`bolt_style` reads two parts of one seed for two rules. The star count reads bit 2 (`(seed >> 2) & 1`), and the prism
rule reads bits 0 and 1 (`posmod(seed, 4) == 0`). A count that read bit 0 or bit 1 would give every prism bolt four
stars, since a prism bolt has both low bits at zero. A right shift moves bit 2 down to bit 0 for any sign, so `& 1` is
right for a negative seed too. Before a rule takes some bits of a seed, check which bits the other rules already read.

## 2026-10-08 — A merge keeps the old value unless it is told to overwrite (`game/scenes/shardrun/fight/legendary_look.gd`)

`Dictionary.merge` keeps the existing value for a key that both dictionaries have, unless it is called with `overwrite`
set to `true`; the LEARN comment in `legendary_look.gd` states that default. `impact_style` therefore merges each change
with `true`, and it applies the signature card last, so a signature card wins a clash with its role: quickselect keeps
its jets on under a guard, which would otherwise turn them off. `legendary_look_test.gd` checks that outcome. When two
sources set one key, the order of the calls decides the winner, so the order is part of the rule.

## 2026-10-08 — Check the fit before pushing values apart (`game/scenes/shardrun/fight/constellation_path.gd`)

The star places are pushed apart until neighbours differ by at least `MIN_GAP`. Pushing up can run past the top of the
range, and pulling down from the top then fixes that. Done in that order, it leaves every gap at least `MIN_GAP` and
keeps the places inside the range, but only when `(count - 1) * MIN_GAP` fits in the range. So the fit is checked first,
and a crowd that cannot fit is spaced evenly instead. A two-pass fix is correct only under a condition, so the condition
belongs in the code. `constellation_path_test.gd` pins both branches.

## 2026-10-08 — Clamp the segment index, so the end reads the last segment (`game/scenes/shardrun/fight/constellation_path.gd`)

`point_on` maps `p` from 0 to 1 across equal-time segments. At `p = 1` the index would name the segment after the last
one, so it is capped at the last segment (`mini(floori(along), segments - 1)`), and the weight becomes 1 at the final
point instead of reading past the end of the route. A route with N segments has N + 1 points, and its last point needs
the last segment, so the index is clamped rather than assumed to stay in range.

## 2026-10-08 — Find a bolt by its place, not by its value (`game/scenes/shardrun/fight/log_player.gd`)

The bolt's place in its cast comes from the loop index, not from `volley.find(hit)`. `find` returns the first match, as
the LEARN comment in `log_player.gd` says, so two identical bolts would find the same place and take the same path. No
test drives two identical bolts through `_launch`, so the reason rests on that comment. Use the position you already
have. A search answers only for the first of several equal values.

## 2026-10-08 — Take what you need before the await (`game/scenes/shardrun/fight/log_player.gd`)

A bolt that waits behind a falling blow is paused at an `await`, and the circle it was launched from can free itself
during that pause. So the cast, its circle, the bolt's origin and the foe's points (`target_point`, `foot_point`,
`sprite_width`) are read before the first `await`, and the bolt rides from the point it left, even if the foe's view has
freed. The cast is taken rather than its volley, because a volley is made lazily and can be freed and replaced during
the wait. State that lives on the cast, such as its heavy flag, is read after the await, because the bolt holds the
cast. `legendary_cast_test.gd` pins the outcome: a bolt whose circle frees during its wait rises from its final star,
and a bolt whose foe view frees during a falling blow still lands.

## 2026-10-08 — Tag the item, not its place in a list (`game/core/programs/program_landing.gd`)

A bolt's card and role ride on the bolt itself, in its `shape`, so every record of the bolt (a hit, a ward, an
overflow) names its card without a lookup. A bolt's index is a position, and relics and withdrawals move positions, so
an index can point at a different bolt by the time it is read. Carry an identity with the item it names, not with
where that item sits.

## 2026-10-08 — Capture the built-ins before the card runs (`game/sandbox/shardrun/spell_harness.js`, `game/sandbox/shardrun/spell_harness.py`, `game/sandbox/launch/launch.js`)

A card runs in the same interpreter as the harness, so it can replace a built-in that the harness calls afterwards. The
JavaScript harness takes `Reflect.apply` and the other functions it needs as constants before the card runs, and calls
them through a wrapper, because `call` is looked up on a function at call time and a card could rebind it. The Python
harness binds `dict = dict` and its other names at import: a bare name is looked up in the module's globals and then in
the builtins at each call, so a card that rebinds `builtins.dict` would otherwise change the harness's `dict(...)`. The
launcher captures 13 built-in functions and methods, and the `Error`, `Map` and `Set` constructors, in its closure at
start (16 references in all), so a program cannot change the line the launcher prints. The LEARN comments in the
harnesses and `launch.js` give these engine reasons; the rebinding cases in `program_tags_test.gd` pin that the output
does not change.

## 2026-10-08 — Syntax can call a method you did not write (`game/sandbox/shardrun/spell_harness.js`, `game/sandbox/launch/launch.js`)

Some syntax calls a method on an object with no visible call. `for...of` calls the array's `Symbol.iterator` and then
the iterator's `next`, and `value instanceof C` reads `C[Symbol.hasInstance]` when it runs. A card can replace any of
those on the built-ins it shares with the harness. So the JavaScript harness indexes its loops over the bolts it copied,
reading the length once before each loop, and the launcher calls the default `Symbol.hasInstance` itself, with the
constructor as receiver. Where the harness must trust a loop or a check, it writes the call out itself. The LEARN
comments in `spell_harness.js` and `launch.js` give the engine rule; the tests that replace the array iterator, its
`next` and the `instanceof` lookups (`program_tags_test.gd`) pin that the printed output and the tags do not change.

## 2026-10-08 — Read a card's result once, into a copy (`game/sandbox/shardrun/spell_harness.js`)

A card's return value is read once, into a JSON copy, and both the bill and the printed output come from that copy. A
`Proxy` can answer each read differently, for its length or for a slice, so a second read could bill fewer bolts than
the output holds; the LEARN comment in `spell_harness.js` gives this. `program_tags_test.gd` checks that a card whose
length changes between reads is billed for the bolts it returns. Measure and print from one snapshot, and never read a
value a card controls twice.

## 2026-10-08 — An import is not a step, so stamp its bolts before the next import runs (`game/sandbox/shardrun/spell_harness.py`, `game/sandbox/shardrun/spell_harness.js`, `game/sandbox/cpp/harness.cpp`)

An import is not a step of the program, so after a card the bolts an import hands back still belong to that card. Each
import's bolts are stamped before the next import runs. Whatever the first import wrote on a bolt is replaced, and the
second import sees the card's tags, as the C++ harness does. Before a card runs, its bolts are not yet its, so the
card is handed them as they came. Stamp a value when the step that produced it ends.

## 2026-10-08 — An unset optional is not an empty string (`game/sandbox/cpp/program.hpp`)

The C++ bolt's `card` and `role` fields are `std::optional<std::string>`. An unset optional means "no tag", which a
plain empty string cannot say, because a card with no role still stamps `""`. The LEARN comment in `program.hpp` gives
the reason, and `cpp_program_tags_test.gd` checks that a bolt no card returned has neither key. Use an optional where
absence and an empty value must mean different things, and test `has_value()` where the difference matters.

## 2026-10-08 — A test stands in for compiled code (`game/test/sandbox/cpp_program_tags_test.gd`)

C++ cards are compiled ahead of time, so a test cannot give a built card new code. The test sends a bolt that already
carries a card and a role, standing in for one a card returned, and checks that the stamp replaces both, whichever
card they came from. When the code under test cannot change from the test, change the input it receives instead.

## 2026-10-08 — Check a Variant's type and its key, not its truth (`game/core/cosmetic_rules.gd`)

In GDScript, `"yes"` and `1` are truthy, so a flag read from JSON passes a plain `if`. The type is tested before the
flag is trusted: a look counts as legendary only when its `legendary` value is a boolean that is true. And `get()`
returns `null` both for a missing key and for a key whose value is `null`, so `has()` decides whether a `draw` is
present. A `"draw": null` is then reported as an unknown draw, rather than read as no draw. Both GDScript facts are the
LEARN comments' (`cosmetic_rules.gd`, at the flag and the draw checks). `cosmetic_rules_test.gd` pins the `"yes"` flag
cases and the unknown-draw cases; no test sets `"draw": null`, so that last sentence is checked by reading the code
only.

## 2026-10-08 — A frozen object is its own capture (`game/sandbox/shardrun/spell_harness.js`)

The JavaScript harness freezes the job's input before any card runs (`deepFreeze(DATA)`), so the shard table, the
limits, the execution flag and the relic options cannot change. A frozen object needs no copy to be a capture: nothing
can change it, so the harness reads it where it is. A card's write to a property of the frozen input does not change it.
`program_tags_test.gd` (`test_a_card_that_rewrites_the_job_it_runs_in_changes_none_of_it`) pins that a card which
rewrites the job changes none of its output, in both languages. The LEARN comment in `spell_harness.js` states the rule.

## 2026-10-08 — Keep text for what is read again, and values for what is compared (`game/sandbox/shardrun/spell_harness.py`)

The Python harness reads its input once, at import. A dict the harness keeps can be changed by any card that reaches it
through `sys._getframe`, and then every later read sees the change. So it keeps JSON text for each shard, spell and rule
it reads again (`SHARD_TEXT`, `SPELL_TEXT`, `EXECUTION`) and parses a fresh copy each time, and plain values (numbers,
strings, tuples of pairs) for what it only compares (`LIMIT`, `SOURCE_POWER`, `STAMPS`). `DATA` is read only in the
block that copies it. `program_tags_test.gd` (`test_a_card_that_rewrites_the_job_it_runs_in_changes_none_of_it`) has a
Python card write into `DATA` through `sys._getframe`, and the output does not change. The LEARN comment in
`spell_harness.py` states the rule.

## 2026-10-08 — An exit is one the launcher made, not one that looks like it (`game/sandbox/launch/launch.js`)

The launcher ends a program with `process.exit`, which throws an exit object. A program can reach `Exit.prototype`
through any error's constructor, so a thrown look-alike with an exit code of 0 would pass an `instanceof` check and exit
0. The launcher therefore keeps each exit it makes in a `WeakSet` of its own closure, freezes it, and counts a thrown
object as an exit only if it is in that set. `program_tags_test.gd` (`test_only_the_launchers_own_exits_are_exits`)
throws a look-alike and a rewritten exit, and both end in a runtime error. The LEARN comment in `launch.js` states the
reason.


## 2026-10-10 — Measure at the player's screen before choosing a size (`game/scenes/overworld/pixel_view.gd`)

The first baseline was taken at 1920 x 1080 and showed a 4x town. The player plays fullscreen on a 2560 x 1440 laptop
panel, where the same town is 6x. Every comparison made from the first capture was wrong by one step. `xrandr` and the
saved settings (fullscreen, the screen index) gave the real size. The rule now: take the baseline and the review shots
at the size the player plays, with `SHOT_SIZE`, and choose a base from that display. A 512 x 288 base gives an exact 5x
at 2560 x 1440 and 3x at 1920 x 1080.

## 2026-10-10 — A float just under an exact fit rounds one step down (`pixel_view.gd`, `_fit`)

2560 / 512 is exactly 5, but a float a hair under 5 floors to 4, and the same error adds a whole art pixel to the world
size when it rounds up. The fit and the world are both computed with a 0.001 margin in the direction that keeps an exact
fit exact. The shot at 2560 x 1440 shows 5x, and the probe in the build printed the scale and the viewport size once to
check it.

## 2026-10-10 — One writer per file, or the lanes lose each other's edits (the Lanternroot build)

Two lanes ran at once: one regenerated `lanternroot.jsonc` whole from its generator, and the other edited the text fields
of the same file. Whichever wrote last would have erased the other. The run was stopped before any file changed, and the
text lane now runs after the map lane in the same lane. Lanes that share a file run in sequence; a lane that regenerates a
file owns it for the whole run.

## 2026-10-10 — Test every input a content file can read, in both languages (`town_things.gd`, `hooks.py`, `hooks.js`)

The starter code for the first two town things read `thing.keys` and `thing.text`, which the harness did not pass. The
thing tests gave the hook only a fields dictionary, so they passed while the first press failed. The fix passes the keys
and the text and adds cases in Python and JavaScript that read each of them back. The rule: a test that drives a hook
should give the hook every input the content can name, not only the ones the test happens to use.

## 2026-10-13 — A negative prompt can draw the thing it names next to the subject (`pipeline/animation/manifest.json`)

To remove the faint pink shadow under a character's boot, the negative prompt got "cast shadow, ground shadow, shadow
under feet". The model then drew a larger pink platform under both feet, which is worse than the sliver it was meant to
remove. The negative went back, and the one-pixel sliver is left. The rule: a negative term names a thing and puts it
in the model's attention, so it can appear where the term points. Remove an artefact in the post-processing (an alpha
cut, a largest-piece filter) or accept it, and test a negative change by looking at the render before trusting it.

## 2026-10-13 — One render, many pixel counts: the pixel count is the only variable (`pipeline/animation/base_sprites.py`)

The five ComfyUI sizes come from one cached render. The first asset renders, and the others read its cache through
`raw_from`, so a size comparison can't be confused by a different seed or prompt. The same rule applies to the Blender
models: the render is one size and the cut is the only step that changes. The test that picked the checkpoint was the
same idea: SDXL base with the pixel LoRA drew scenes and turnaround sheets for a single-character prompt, while the anime
checkpoint drew single figures. A pipeline default that works for props can fail for characters, so test the checkpoint
on the subject first.

## 2026-10-13 — A palette lock on the full palette snaps highlights to the wrong ramp (`base_sprites.py`, `manifest.json`)

The shared lock snaps every colour to its nearest palette colour, and the nearest one to a pale cyan highlight on teal
cloth is the water ramp. The shoulder came out blue. Both sources now lock to the character ramps only (skin, hair,
cloth, eyes, gold, steel), so highlights stay in the family of the cloth they sit on. The rule: a lock that is correct for
a whole town can be wrong for one character, so name the ramps a subject may use.

## 2026-10-13 — Lathe solids need poles to close, and open tubes do not (`pipeline/animation/blender_base.py`, `lathe`)

A solid of revolution closes at a pole (a ring of radius zero), so its ends are a fan of triangles. A sleeve or a hem is
an open tube: its ends are rings, and it needs no pole. Building both from one profile list keeps the body, the skirt and
the trims in one helper. Recalculating the normals after the faces are built keeps the shading right whatever order the
faces were added in. Hair is a sphere set back and up, not a dome: a dome sitting on the head left a flat helmet, and a
fringe placed in front of the forehead reads as a shelf, so the front edge of the sphere makes the hairline.

## 2026-10-13 — Restyle a turn of one model, not a prompt: four directions from one front drawing (`pipeline/animation/cast.py`, first tried in a sheet since replaced)

A sprite sheet needs the back and the side of a character the front render never showed. The obvious route is a text
prompt ("from behind"), but nothing here keeps a character the same across views: no image-edit model (Qwen Edit,
Kontext) and no IP-Adapter are installed, only the SDXL checkpoints, the pixel LoRA and an OpenPose ControlNet. So the
Blender model is turned to -90 and 180 degrees, and ComfyUI restyles each turn with img2img at denoise 0.7, with the same
checkpoint, LoRA and palette as the front. The silhouette and proportions come from the turn; the anime pixel look comes
from the checkpoint. In the test renders, 0.55 stayed closer to the Blender turn, and 0.7 gave clearer faces and hair, so
0.7 was kept. The start image has to be the turn's own size: the job covers the image to its size, and a square job would
crop the 2:3 turn at the head and feet.

## 2026-10-13 — An idle is one pixel of motion, and it is the cheapest animation there is (`generate.breathe`)

The idle frame is the stop frame with everything above the waist moved one pixel down, feet planted. The pipeline already
had `breathe` (for the battle sprites); it moves pixels that exist rather than redrawing, so every idle frame is exactly
the same design. The rule: start the idle with a motion that needs no new drawing, and add frames only when the still
frames have been judged.

## 2026-10-13 — Cut the camera's frame, not each figure's box (`pipeline/animation/cast.py`, `registered_cut`)

The first sheet fitted every frame to its own bounding box. That made each view fill its cell, so a front drawn with a
smaller head and a side view with lower hair came out at different scales, and the player saw the front as a different
person. The cast's frames are cut *registered*: one orthographic camera frames every turn of every character the same
way, and the whole camera frame goes down to the sprite frame. Nothing is cropped or fitted per frame. A figure's height
is then the model's height, and its feet land on the same row (46 of 48) in every view of every character. The rule:
when frames must agree, fix the camera and cut the same rectangle from each; never measure each frame to place it.

## 2026-10-13 — Hold a restyle to the shape it came from (`cast.py`, `pick` and `guarded`)

img2img at denoise 0.7 keeps a turn's composition but may grow hair or narrow a hem. Two cheap checks keep the
proportions: of the candidates, keep the one whose outline overlaps the turn's most (intersection over union; the
player's three views scored 0.90 to 0.91), and then cut the kept image back to the turn's outline grown by one sprite
pixel. The generator still draws everything inside the outline: the face, the folds, the light. The outline, and so the
proportions, stay the model's.

## 2026-10-13 — Key generated art by what it was made from (`OverworldArt.character`, `cast.json`)

A townsperson's sheet is drawn only while their look is the look it was made from. The index records that look, and the
game compares what the two looks *show*: unused parts and colours at their defaults are dropped before comparing.
Changing a look in the content without making a new sheet does not draw stale art; the person falls back to the parts they
were built from before. The same lookup gives the player the start look's sheet while that is the player's look. The rule:
when an asset is generated from data, store the data beside the asset and check it before use.

## 2026-10-13 — A back view needs hair on the back of the head (`blender_cast.py`, `_nape`)

The first cast's back views drew faces on the quartermaster and a bare skin oval on four others. The blockout was at
fault, not ComfyUI: the hair cap sat high on the head, so from behind the lower half of the head was a big skin-coloured
oval, and a hat that covered the crown left no hair at all. The restyle drew what it saw, a face. One ellipsoid over the
back of the head (inside the head from the front, so the front views did not change) fixed all five. The rule: when a
restyle invents something, look at what the blockout showed it before touching the prompt.

## 2026-10-13 — A cache must know the code that made it (`cast.py` `blockout_digest`, `world.py` `code_digest`)

The turns were cached by their spec, so changing the Blender code that draws them reused the old turns silently. Now the
spec carries a digest of the Blender scripts, and editing them renders again. The restyle cache already hashed its input
image, so only the turns that really changed went back through ComfyUI. The rule: a cache key covers everything the
output depends on, the code included.

## 2026-10-13 — One scale, written once (`OverworldScale`, `scale.jsonc`, ADR-0064)

Moving from 16 px to 40 px tiles touched three `const TILE := 16`, a 512 x 288 base, Hotaru's hover, a camera offset, a
shadow, an interior zoom and every picture's size. Now the tile, the view and the person frame live in `OverworldScale`
and, for the Python pipelines, in `scale.jsonc`, with a test that fails if they differ. Older art records the tile it was
drawn for (none means 16) and is enlarged on load, so the town stayed whole while each kind of art was remade. The rule:
a number many things depend on gets one home, and data made with it records the value it was made with.

## 2026-10-13 — The town's 3/4 view is a shear (`pipeline/world/blender_world.py`)

Top-down RPGs draw an object's height in full, its depth squashed, and the ground as if seen from straight above. No real
camera does that: a tilted orthographic camera foreshortens heights too and puts the ground at an angle. Lifting every
point of the model by `depth_scale * y` (a shear) and filming it straight on gives exactly the game's projection, with one
tile across always the same number of pixels. So a blockout's frame is known in tiles before it is rendered, and the cut
lands on the map's grid.

## 2026-10-13 — Solve the shape from the footprint (`world.py`, `building_depth`)

The maps give a building's whole picture area as its footprint. Instead of asking whoever writes a spec for the depth
and the roof height (two numbers that must add up), the pipeline solves the depth so the picture fills the footprint:
walls + depth * (1 + depth_scale / 2) = footprint height, with a roof as tall as the building is deep. The spec only says
how tall the walls are. Fewer free numbers means fewer ways for a smaller model to get a building wrong.

## 2026-10-13 — Repeating textures hide large shapes in a dither (`terrain.py`, `patches`)

At 40 px a grass tile has room for soft light patches, but a tile repeats, so any patch with an outline shows as a grid
across a field. Water with a dark swell looked like a line of footprints. The slow variation is now only a checkerboard
of the lighter shade where the noise is high: it brightens an area without drawing an edge the eye can follow from tile to
tile. Small details (tufts, pebbles, sparkles) can be crisp because there are many of them in different places.

## 2026-10-13 — Godot's JSON numbers are floats (`JsoncWriter.normalized`, ADR-0066)

`JSON.parse_string` returns every number as a float, so a map read and written back would turn `[13, 45]` into
`[13.0, 45.0]`. Lanternroot Studio's writer turns every whole float back into an int before it writes anything, and a
round-trip test proves that reading a map and writing it unchanged gives the same bytes. The same test found two
objects in the town's map wrapped over two lines by hand; the map was rewritten once in the canonical form (one object
to a line), with its data checked identical before and after. The rule: when a tool will write a file people also edit
by hand, fix the file's format first, test that a read and write changes nothing, then let the tool write.

## 2026-10-13 — An undo must restore order too (`StudioCommands`, ADR-0066)

Lanternroot Studio writes maps keeping each object's key order, so git shows exactly what changed. A command that
erases a field, undone by putting the field back, would put it at the end of the object: the data is equal, but the
file's line changes, and an edit that was undone still shows in git. The undo of an erase therefore remembers the
key's position and puts it back there; the tests compare the written text, not just the data. The same care keeps
session ids from being reused after an undone add. The rule: an inverse is exact only if it restores everything the
output depends on, and here the output is text, so order counts.

## 2026-10-13 — Index the picture as well as its footprint (`StudioPick`)

A tree can be picked through its crown, which reaches beyond the cells it stands on. Indexing footprints alone misses
that crown; scanning every sprite on every hover makes the mouse slower as the town grows. StudioPick now puts each
picture rectangle into the cells it covers, preserving drawing order, then checks alpha only among nearby candidates.
After warming image caches on the 1,586-object town, 6,066 picks measured p95 19 microseconds and maximum 34 microseconds.
Those are CPU measurements; they do not prove the renderer meets its separate frame budget.

## 2026-10-13 — A redirected save still needs isolated state (`StudioWork`, `OverworldScreen`)

Play draft used to redirect the store while sharing the normal character's state. Returning the store to its real folder
would then save the test's flags, lessons and position there. The overworld now snapshots its state, boots table and
related display state, plays a deep copy, and restores the original before restoring the writer's folder, including on
exit. A serial invalidates late boots callbacks. Tests check both real save bytes during draft play and exit-time state.

## 2026-10-13 — Rebase must persist both sides' identities (`StudioRebase`, `StudioFiles`)

Map objects have no permanent ids, so a three-way merge matches disk objects by persistent id where available, then
kind, art and cell, then nearest unmatched kind and art. Equally near matches are conflicts, including one disk object
equally near two base objects. The merged document and its new base share aligned session ids. Saving only the merged
ids lost that alignment when base_text was parsed again after restart; drafts now also keep base_sids. A regression test
rebases around an external insertion, restarts, and checks the diff still reports the intended move.

## 2026-10-13 — Publish needs a reviewed version and a complete backup (`StudioPublish`, `StudioFiles`)

Every changed map is checked against the entire draft world. All originals are backed up before the first write, and a
failed later write rolls earlier writes back without clearing drafts. Keep draft authorizes the exact disk hash shown
in its dialog; passive status checks use another service so they cannot silently authorize a newer version. Atomic
writes check the expected hash again after preparing the temporary file. A narrow race with an uncooperative external
writer between that check and rename remains; these are per-file atomic writes, not an operating-system transaction.
After Publish, clean visited sessions also reload from disk, so an old session cannot replace freshly reloaded content.

## 2026-10-13 — A popup's position belongs to its embedder (`StudioMode._world_input`, `StudioContextMenu`)

The window stretches its canvas (`canvas_items`, scale 0.88), and popups are embedded subwindows by default, so a
PopupMenu's position is in the root canvas's units, not window pixels. The right-click menu was placed with the
viewport's screen transform, which multiplies by the content scale: on a 2560 x 1440 window it opened about 17% further
from the corner than the cursor, well away from the object. `Control.get_screen_transform()` goes through
`Viewport.get_popup_base_transform()`, which is the identity while embedding and the window's position and stretch when
the popup is a native window, so it is right both ways (it is what Godot's own LineEdit menu does). A scene test right-
clicks under the stretched headless window and checks the menu's corner is the clicked point; the old line fails it by
hundreds of pixels. The same fact matters for tests: `get_tree().root.push_input(event, true)` forwards mouse events to
an embedded popup in its own coordinates, so a real row click can be simulated. Emitting the popup's `window_input`
signal does not do that; it only calls the signal's listeners, and PopupMenu never sees the event.

## 2026-10-13 — Measure a cache before writing it (`StudioThumbs`)

The spec planned catalog thumbnails cached on disk in `user://studio/thumbs/` by picture and file time. A probe timed
the work first: `Texture2D.get_image()` returns an uncompressed RGBA8 copy even headless, and cropping the first frame,
trimming to the used rectangle and scaling by a whole number took about 0.2 ms a picture, so all 65 placeable pictures
cost about 13 ms, made only when a card is first shown. Writing and reading back PNGs would cost more than that, add a
folder to keep in step with the art and a stale-cache bug to have. The thumbnails stay in memory for the run.

## 2026-10-13 — A STOP control under a ScrollContainer eats the wheel (`StudioCatalogCard`)

The catalog's cards sit in an HFlowContainer inside a ScrollContainer. With `MOUSE_FILTER_STOP` a card takes every
mouse event over it, the wheel included, so the list never scrolled while the pointer was on a card (which is almost
always). `MOUSE_FILTER_PASS` lets the card see hover and clicks and still hands the unhandled wheel up to the
ScrollContainer.

## 2026-10-13 — A workflow can quietly replace its input (`pipeline/music/comfy.py`, ADR-0067)

The ComfyUI music workflow has two YuE2 nodes: a planner that writes an ABC score from the style, and a music node that
performs an ABC. The pipeline sent our composed score along, but the graph wired the planner's ABC into the music node,
so every ComfyUI take was the planner's own tune in our style, and nothing failed. The only sign was in the
measurements: how closely each bar followed the score. The fix wires the score into the music node and drops the
planner, and the smoke take's adherence went to 0.946. When a tool takes an input you care about, measure that the
output followed it, not only that the call succeeded.

## 2026-10-13 — A gradient texture made inside `_draw` draws white once (`CharacterSelectLineup`)

The character screen's lantern pool and edge fades were `GradientTexture2D`s created in `_draw`. Such a texture fills
itself on the rendering thread after it is first used, so the first frame drew a solid white rectangle where the soft
glow should be. Building the glow as an `Image` and wrapping it in an `ImageTexture` once, outside `_draw`, gives the
right pixels from the first frame.

## 2026-10-13 — Measure the whole path of one edit (the Studio's placement lag)

The player felt a spike on every placement. Timing each stage on the real town (1,592 objects) found it in places
nobody would have guessed first: of about 830 ms per edit, 688 ms was `GroundLayer` baking every ground tile again,
although an edit never touches the ground; 260 ms more came 0.2 s later from the live check reviewing the whole world
on the main thread, and 23 ms 2 s later from the draft save. The fixes follow the measurements: the ground keeps its
bake when its rows are unchanged; the town and the pick index change only the nodes of the changed objects (found by
comparing the old and new docs by session id, so undo and rebase are covered), checked against a full rebuild after
every step in a test; the live check runs `StudioPublish.review` unchanged on a worker thread over a snapshot of the
sessions, dropping an answer older than the newest change; drafts are written on a thread; the diff skips objects that
compare equal as a whole; the draft's change count is written on the next frame; and opening a map builds its doc
once without drawing, so the first edit is as cheap as the rest. An edit now costs about 15 ms, the frames after it
under 9 ms. Snapshots can share the docs because a command never changes a doc in place: it works on a copy.

## 2026-10-13 — A placeholder is the old picture stretched, never a new picture (`OverworldArt.stand_ins`, `TownMapView`)

A thing dragged to a new size takes its remake's id at once (`barrel-2x1`), long before the world pipeline has drawn it.
Drawing a plain block would make the town unreadable while you work, and saving a stretched picture as art would break
the rule that pictures are never stretched. So the Studio registers each waiting remake as a stand-in (its source and
the footprint the source was drawn for), and `TownMapView` draws the source stretched to the new footprint, scaled by
the source's own art scale (the remake has no index entry yet, so asking for its own would enlarge it as old art). The
overlay hatches it in Edit, and reviews call it a warning. When a run reports the picture made, `OverworldArt.forget`
drops the stand-in and the cached index, and one full redraw shows the real picture without a restart. Diagonal hatch
lines are drawn with a negative width (the hairline primitive): a one-pixel polygon on a diagonal can vanish in the
low-resolution pixel viewport.

## 2026-10-14 — Repaint a dual grid by the ring round the change (`GroundLayer.repaint`)

The Land tab paints a few cells at a time, and the ground is baked into pictures. A dual-grid corner's tile depends
only on the four cells round it, so a changed cell changes the tiles of its four corners, and those cover half of every
cell round it. Painting again the changed cells and the ring round them (base tiles first, then every corner of those
cells) gives exactly what a whole bake gives: a corner on the ring's outside edge is drawn over the same tile, and the
ground's pixels are fully opaque or fully clear, so drawing it twice changes nothing. A test compares a repaint with a
whole bake byte for byte across pieces, map edges, water frames and a room. The bake is cut into 320 px pieces, so a
stroke uploads two or three small textures (`ImageTexture.update`) instead of the whole 3,240 x 2,280 picture. Two
traps on the way: `Color.TRANSPARENT` is white with no alpha, while a new `Image` is black with no alpha (both show
nothing, but the bytes differ); and most of a bake's cost was GDScript reading the four cells round each corner once per
ground and per frame. Reading them once per corner, painting the base once for every frame and copying base tiles
(`blit_rect`) instead of blending them took the town's whole bake from about 0.7 s to 0.23 s; a 5 x 5 stamp repaints in
about 1.5 ms.

## 2026-10-14 — A preview is a new Dictionary each step (`StudioLandTool`)

While a stroke is under way the town shows a preview map whose ground is painted, and the ground layer compares what it
shows with what it is asked to show. Packed arrays are copied on write, but a Dictionary is shared: had the tool painted
into the same preview Dictionary the ground layer already held, the two would always compare equal and nothing would be
repainted. Each step makes a shallow copy of the preview with a new ground array, so the layer keeps the old one to
compare with, and the real map is never touched until the stroke ends as one command.

## 2026-10-14 — A resize moves the doors that lead in from other maps (`StudioWork._follow`)

Growing a map on its left or top edge moves every cell, so a door in another map that arrives here would land in the
wrong place without a word (it is still on walkable grass). The resize command is a batch with `shift`, the amount the
cells moved, and its undo carries the opposite. Whenever such a batch is applied, undone or redone, the Studio moves the
other maps' doors into this one by the same amount, each as a change in that map's own draft. The links stay right in
every state of the history without one history having to reach into another.

## 2026-10-14 — `flock -o` when the locked command starts a server (`/tmp/rootward-gpu.lock`)

Several agents shared the GPU by wrapping their jobs in `flock /tmp/rootward-gpu.lock`. A `scripts/world.sh make`
finished, but the lock stayed held for 24 minutes and every other GPU job queued behind it: `comfy_start` launches
ComfyUI with `setsid nohup`, and the new process inherited the file descriptor that holds the lock, so the lock lived
as long as ComfyUI did. `flock -o` closes that descriptor before running the command; flock itself keeps the lock until
the command ends, and nothing the command starts can carry it off.

## 2026-10-14 — A sink is in the picture's own pixels (replacing an enlarged picture moves it)

The town's bridge pieces are anchored a row above where they lie and sunk 20 pixels, and the desk lantern raised 7.
Those numbers are in the picture's own pixels, and `TownMapView._standing` enlarges them with the picture: an old 16 px
picture is shown 2.5x, so its sink of 20 meant 50 world pixels. When the world pipeline's 40 px picture replaced it, the
same 20 meant 20, and the bridge sat most of a tile too far north while the lantern stood on the floor in front of the
desk. The fix was content (sink 50 and -36, through the Studio's Publish); the lesson is to look at every placement
that carries a sink when a picture of another scale replaces its art.

## 2026-10-14 — A file that is not there reads as "" (`StudioSession.create`, Make interior)

A room made in the Studio has no file until Publish. Publish's safety rests on one comparison: the hash of the text on
disk now against the hash of the text the draft began from, so that a file someone changed meanwhile is a conflict and
not overwritten. A new map fits the same rule without a special case: `StudioFiles.read_text` gives "" for a missing
file, so a new map's draft records the hash of "" as its base. While nobody has made the file, the disk still hashes to
that; if a file of that name appears, the hashes differ and Publish stops. The batch writer only has to skip the backup
(there is nothing to back up) and, when a later write fails, remove the file it made instead of restoring old text.

## 2026-10-14 — A Dictionary key named like a method is read with brackets (`StudioDebug`)

GDScript lets `data.key` read a Dictionary's key, which is handy for content (`thing.program`, `step.done`). But a
Dictionary has methods too, and since Godot 4.4 one of them is `set(key, value)`: `changes.set` is that method, a
Callable, not the key "set", so a `for flag in changes.set` loop never sees the flags. `get`, `has`, `size`, `keys`,
`values`, `clear`, `erase`, `merge` and `find_key` are taken the same way. Keys that may share a name with a method are
read as `changes["set"]`; the debug panel's flag events depended on it.

## 2026-10-14 — A reload that replaces a Dictionary leaves old references behind (`ThingHost.setup`)

The overworld keeps one catalog Dictionary that the Studio and the screen share, and reloading content clears it and
merges the new one in, so everyone who holds the catalog sees the new content. But `merge` puts new values under the
keys: `catalog.things` is a new Dictionary afterwards, and the things' runner had been given the old one in `setup`. It
went on running the code of the things as they were before the reload. A reload now hands the runner the new
`catalog.things`; anything that keeps a part of a shared Dictionary rather than the Dictionary itself has to be told
when that part is replaced.


### 2026-10-15 — Lanternroot catalog objects

Three Luna agents prepared 90 new placeable objects; 86 use Blender blockouts and ComfyUI restyles, four use
user-requested ChatGPT image generation. Specs, source images, prompts, metadata and rebuild instructions are
under `pipeline/world/expansion/` and `pipeline/world/objects/expand-*.jsonc`. The catalog grew from 82 to 172
entries, with new Animal care, Farm tools and Workstations subcategories.

A projected depth is not a map row: the world camera multiplies depth by 0.6, so an end-on wall needs 1/0.6
(about 1.667) tiles of model depth to join the next map cell. Horizontal/end-on/corner variants keep the same
height and are grouped by material. Solid courses in the blockout keep a low wall from becoming a doorway
in a restyle. Rugs and crops need explicit walkability and ground-layer metadata.

All 90 specs are current and palette-cut at 40 px tiles. Catalog and world-art checks: 7/7 passed. Grouped contact
sheets and three in-game category screenshots were inspected in `shots/studio/expansion-*`.


## The game the player builds (Concept/v0.4, ADR-0068)

**One job answers every question a part will ever be asked** (`PartsRuntime`, `Parts.domain`). The boots already
did it: every key on every tile in one sandbox job. A part's function is asked the same way about everything the game
could ask, all at once on a thread: every key for `shortcut`, every notch for `volume`, every minute for
`time_of_day`, every cell of the town for `place_of` (about 4,500 calls). The game then reads a dictionary and never
waits, and every answer is still the player's real code. Only what depends on the moment (the bag, the menu for the
town's current parts) is called live, at about 70 ms in Python and 11 ms in JavaScript. A job costs the same whether
it answers 1 call or 4,000: starting the interpreter is the expensive part.

**Facts beside flags** (`Parts.facts`, `Talk.holds`). A condition such as "Marta asks once you hold three cabbages"
needs a count, but conditions read flags. The town counts the bag itself (never with the player's code, which could
lie) and puts the counts beside the flags as `bag:cabbage`. The flags a talk hands back include those facts, so
`Parts.without_facts` strips them before anything is saved. A save that kept them would believe in cabbages long
eaten.

**Sorting by "name and id" glued together is not sorting by name, then id** (`StudioAssets.placeable`). "Fieldstone
wall expand-fieldstone_wall" and "Fieldstone wall (end on) expand-fieldstone_wall_v" compare at their 16th
character, where "(" comes before "e", so the longer name sorted first. Sorting by name and breaking ties by id puts
the shorter name first, which is what the catalog's filter did, and the two lists disagreed once the catalog gained
names that start other names. A compound key compares part by part, not as one string.

**A node has one parent** (`StudioConditionEditor.build`). The kind picker was put into a row, and then, for an "all"
condition, handed to another container: "Can't add child 'Kind' ... already has a parent", 180 orphaned rows in a test
run, and no failing assertion. `remove_child` first (and free the row left empty) and the errors and orphans go.


## Chapter 3 and the town in Japanese (ADR-0069, ADR-0070)

**A pure function's answer cannot show it is pure** (`tasks.py`, `ForgeJudges`). `forge(["wood", "iron"])` gives
"hammer" whether it sorted a copy or the list it was handed, so the answer alone cannot catch `.sort()`. The harness
already deep-copies each call's arguments; with `"args_after": true` it also hands back those copies as the function
left them, and the judge compares them with what went in. What a function does to its inputs is part of what it
does.

**An "or" from rows that share a flag** (`overworld.gd`, `BEATS`). Hotaru's beats are [condition, talk, told flag],
and a beat is skipped once its told flag is set. Two rows with the same talk and the same told flag therefore act as
one beat with two ways in: whichever condition holds first fires, and the talk's flag closes the other. That gave the
glow request a second way in without adding "any" to the condition language.

**Translate the template, then fill it** (`Tasks.advice`, `TaskWords`). "For the Esc key, your code gave nothing."
is not a key in any overlay: only "For {say}, your code gave {got}." is, and the case's description ("the Esc key") is
a key of its own. So the advice is translated while it still has its holes, and each piece is translated before it
goes in. The pieces then have to be shaped to fit, so a case description in Japanese is a noun phrase (Esc の キー),
never a clause ending in とき.

**`pkill -f` can match itself** (a slip while stopping a worker's queued job). The pattern was a path that also
appeared in the command line of the shell running `pkill`, so the shell killed itself (exit 144). Kill by PID, or
use a pattern only the target's command line contains.

## Japanese reading choices and town collision review (2026-10-16)

**A Label's source text is not its drawn translation.** Godot keeps the source key in `Label.text`; automatic
translation happens when it draws. Test the translation lookup and inspect a rendered screen instead of expecting
the property to become Japanese. Labels that were assigned already-translated prose need to rebuild that prose
from its original quest data when the reading preference changes.

**Reading style belongs in a text cache's identity.** Place captions depend on the player's program, locale and
reading preference. An asynchronous job captures that identity before it starts, so a result from the previous
preference cannot be mistaken for a result from the current one. Reviewed reading tables are cached by mode, and
phrase candidates are indexed by their first character rather than tried at every character of every sentence.

**A picture's rectangle is not its wall.** Roof margins and tree canopies need not block walking. Validated wall
rows and trunk/root cells let the same map builder serve play and Studio. Drawing order is separate again: moving
a building's sort anchor while compensating its art offset fixes the doorway without moving its picture.


### 2026-10-16 — A drag previews a command before it exists

Boundary pieces opt into drag placement through catalog orientation pairs. `StudioRow.oriented` chooses a picture
from the same start/end cells for both the ghost and the committed row, preserving the instance's properties. The
mouse press starts a preview; release sends the existing batch command, so undo removes the complete run. Variant
keys preserve a pending gesture. Thin art retains full-cell collision: visual thickness and navigation are separate
models, and independent wall edges would need rules for crossing between cells.

### 2026-10-16 — A character sheet can contain several aligned sheets

The creator's choices no longer need to be baked into one texture. `CharacterSheet` can keep a small sheet for each
part, all with the same frame, ground row, and facing layout. `Walker` draws those pieces as sibling sprites and changes
their order by facing. That makes a held staff pass behind the figure from the back, and gives the future inventory a
stable hand attachment to fill. Keep a flattened texture alongside the pieces for screens that still draw one image.

### 2026-10-16 — A walk cycle moves the limbs, not the whole sprite

The cast-style player art has separate arm and leg layers, but no authored movement frames. Two step poses can be
derived from those pixels: front and back views move opposite halves of the anatomy, and side views alternate the
visible leading and trailing limbs. Four synchronized poses add counter-swinging arms, a small body bob and hand-item
motion. `CharacterSheet` selects each pose and `Walker` cycles them across a tile, then stands on arrival. Clothing
follows the body bob; authored fabric motion remains future work.

### 2026-10-16 — A face belongs to one head layer

A generated head already contained eyes, so adding a second face layer copied the features twice and made the face look
hollow. The player head now takes its face from the reviewed cast sprite, and short hair is cut into a separate layer.
That sprite also used the same old brown ramps for fringe and iris pixels. The cut step uses nearby skin pixels to tell
eye shading from hair, then maps each to the selectable eye or hair ramp. Small highlights and a mouth finish the face.
Other generated parts still subtract higher-layer masks before export.

### 2026-10-17 — A movement clip has its own clock

The layered character experiment above was reverted after visual review. The replacement uses complete authored
64 x 96 frames, so a face, its hair and its clothes are always one drawing. A grid walk still moves one tile at a time,
but an eight-frame gait lasts longer than one tile. Restarting that animation on each tween repeats the same foot and
makes the character skate. `Walker` advances a separate clip clock across adjacent steps and allows a short arrival
grace before idle. Only a real stop resets the gait. Idle can assign a short duration to its blink independently of
its slower breathing frames.

### 2026-10-17 — Register frames without resizing every pose

Generated sprite sheets can vary their spacing even when the figure is consistent. `import_player_sheets.gd` slices
the fixed source grid, finds each figure, then uses one scale for all twelve frames in that directional sheet. The
head center fixes sideways drift and row 93 fixes the ground. Fitting each pose separately would stretch a bent knee
or a wider stride and make the head pulse. Sources and the registration report remain beside the playable review,
so corrections can be reproduced instead of hiding in an edited PNG.


### 2026-10-17 — Transparent margins are part of modular art

A fence rail must meet its neighbor at a known tile edge. Cropping each picture to its visible silhouette destroys
that registration, and fitting open and closed gates separately moves their posts. Registered sources preserve the
whole canvas through the palette cut. Ordered source frames share that canvas; a wide gate gets one wide frame
rather than repeated narrow doors. This also lets a program keep its existing state machine while its art improves.

### 2026-10-17 — Paint fence material and derive its shape

A four-bit neighbor mask selects one of sixteen timber pictures. The catalog owns those pictures and gate sockets;
the pure planner preserves existing instance fields and returns changes without applying them. Fit candidates,
then plan again from accepted cells, so rejected cells cannot leave dangling joins. Preview and commit read that
same plan. Dry-applying a move/delete/swap lets neighbor corrections join its existing undo transaction. Caching
unchanged preview inputs avoids copying the town's objects for every redraw. Latching the drag axis at the first
movement also prevents the whole row turning when a hand drifts across a diagonal.


### 2026-10-17 — A completion count is not a step index

When steps can finish in any order, two completed steps do not imply that step three is next. `Quests.next_step`
finds the first missing condition separately from `steps_done`, which counts every completed condition. Each log
checkmark and tracker pip also asks its own condition. Updating a later step must refresh the count and bar even
when the current instruction's ID has not changed.

### 2026-10-17 — Merge achievements from asynchronous work

A boots sandbox result can arrive while a conversation holds an older copy of the flags. Replacing all live flags
when that conversation ends erases the new evidence. Progress reports should add true achievements to the live state;
absence in a snapshot means it did not know yet, not that an achievement should be undone. `remembered` makes that
rule explicit, strips derived bag counts, and leaves deliberate developer flag replacement as a separate operation.
Boots milestones are likewise an additive patch after real execution, including on load, so valid saved programs
can repair a missing flag without running a tutorial again. An unrun draft is not evidence.

### 2026-10-17 — Grow one useful tool through the player's code

The basic quest card gives immediate instructions without showing a long list of future quests. Pip's existing
progress lesson unlocks a larger journal and drives its bars with the player's verified function. This makes the
coding task improve a familiar tool while keeping its initial form small. Both forms use the same quest data;
changing the presentation cannot invent or discard completion.

### 2026-10-17 — A walker's destination is ahead of its feet

`Walker.cell` changes when a step starts, before the position tween finishes. Gate occupancy uses both that
destination and the current foot tile: the former starts opening before contact, and the latter prevents closing
through someone still walking out. Combining all Walkers' cells also makes a wide gate wait for its last user.
This state belongs to rendering; a programmed gate's saved lock and collision still come from `TownThings`.
Registering all thirteen views of one native hinge model avoids resizing a door as it turns.

### 2026-10-17 — A reading edition is a complete translation

Kana does not encode meaning: 買った and 勝った sound the same. A short replacement table also leaves most of a
sentence in children's orthography, while replacing inside a mixed compound can damage text that was already
correct. Japanese entries now carry complete `to` and `kanji` editions. The English key selects the sentence in
context, before placeholders are filled. Code, names and inserted values never pass through an adult conversion.
Exact inline fallback mappings exclude ambiguous sources such as なまえ, which can mean a label or an input prompt.
Both editions are cached from the original catalog, so repeated switches do not transform an earlier result.

### 2026-10-17 — Preview a preference without committing unfinished creation

The creator keeps a staged reading choice and remembers the previous one. A switch rebuilds translated controls
from English while retaining the typed name, character model and programming style. Completion saves the choice
with the profile; cancellation restores the previous reading. The same saved field drives ordinary Settings, so
an initial accessibility choice does not become permanent. Corpus tests check complete edition coverage and the
format/code tokens, while scene tests exercise actual creation, cancellation and a later profile reload.

### 2026-10-18 — Keep the source shape while resizing a placement

An imported picture can be resized without changing its asset file. The placement keeps its native `art_size`, and
every renderer, ghost and preview uses the same size ratio. Door and collision masks need an original `art_shape`
too: repeatedly rounding an already rounded cell loses an asymmetric doorway or thickens a thin wall. Resampling
the baseline avoids that drift; conservative area coverage keeps small solid regions from disappearing. A manually
edited door records the dimensions it was edited at, independently of the picture/collision baseline.

### 2026-10-18 — Art feedback and art generation are different records

A quality flag belongs to an asset, across every map that uses it. It should survive map undo and Publish, retain
its prompt after review, and never delete placed instances. The separate review file therefore deduplicates by art
ID. Generation creates a new variant through the existing queue, where a blockout actually supports restyling.
Imported images only recut their source; saving a brief for later is more useful than presenting that recut as new
art. Prompts remain JSON data, while subprocess arguments contain only generated IDs and the existing fixed command.

### 2026-10-18 — Texture variety needs compatible edges

Changing a tile's tint preserves its repeated silhouette. Authored variants can change tiny plants, soil clods and
stones, while identical edge pixels and alpha masks keep neighbouring choices compatible. Cobble variants retain
the same joints; otherwise a new stone layout meets an old one abruptly at the tile edge. A hash of coordinates
and ground kind chooses a texture without consuming gameplay randomness or adding transient values to map files.
The same input therefore gives the same preview, final stroke, reload and undo. Twelve dual-grid surfaces also need
48 bits of corner masks: a 32-bit packed array silently loses later layers, so tests include every layer.

### 2026-10-18 — Choose an area before applying its destructive action

An empty-ground marquee is hard to use where trees cover the ground. A dedicated area tool can begin anywhere,
preview matching footprints and filter trees from other props before Delete is pressed. The area itself is a
preview; while dragging, editing shortcuts cannot act on the previous selection. Release creates the selection,
and the existing delete command removes it in one reversible history step. Stable session IDs and catalog category
metadata preserve ordinary selection and avoid guessing which art names mean a tree.

### 2026-10-19 — Match the material and blend in the renderer's texture phase

Identical outer pixels cannot hide a flat green center beside painted meadow turf. Empty variants need the same
source material, palette and detail density as their flowered neighbors. A shared textured collar then fades their
differences gradually. Dual-grid tiles shift the source by half a cell, so that collar must be built after the same
shift: the rendered seam otherwise cuts through the untouched source center. Dirt-path edge wear follows the actual
exposed mask boundary, leaving connected interiors unframed. Regression checks compare neighboring path borders
for all compatible corner masks and measure the green colors of empty and flowered meadow separately from petals.

### 2026-10-19 — World expansion changes a coordinate contract

The v0.35 Studio specifications distinguish enlarging a map, naming a district and creating a connected map.
Growing west/north shifts authored cells, incoming doors, quest pins, named rectangles and scheduled anchors;
moving the editor walker alone cannot preserve older character saves. The proposed implementation therefore plans
those reference changes together, records published coordinate revisions and migrates saved positions once on load.
Likewise, modular buildings need explicit ownership of generated room geometry while preserving furniture and floor
paint. These are design contracts in `Concept/v0.35/`, not claims that migration or modular construction is built.

### 2026-10-19 — A transaction hashes identity, not allocation history

Undoing an add removes its SID but leaves `next_sid` above it, so a later object cannot accidentally inherit a
cancelled object's identity. Including that high-water mark in a world transaction's document hash made valid
cross-map undo and restart restoration fail. The hash now covers authored text and live SIDs. Earlier draft
records are verified against their original allocator hashes before being restored with the new hashes; stale
objects still fail validation. Failure-injection tests check the documents, history and saved drafts together.

### 2026-10-19 — An invisible shelf should invalidate, then wait

Rebuilding the People shelf after every object edit cost about 16 ms even while Objects owned the workspace.
A hidden panel now advances its revision and rebuilds when opened; it does not create invisible cards on the edit's
frame. The roster also groups placements in one scan rather than rescanning every map for each person. A real-town
benchmark reduced median barrel placement from 34.18 to 16.55 ms and cottage placement from 39.01 to 18.66 ms.
These are headless command timings, not a promise of 60 fps. A regression opens the stale shelf and verifies that
its cards and authored locations catch up immediately.

### 2026-10-19 — A link preview keeps its source, even while looking elsewhere

A door link retains its original session, SID and object snapshot while the author visits destination maps.
Changing maps drops only the pending arrival/facing. Choosing a facing rechecks both the source snapshot and the
arrival through the same validator used by Publish. Source and arrival markers are presentation state, never map
objects. Deferred popup-hide callbacks carry a gesture epoch so an old popup cannot clear a newer choice.
Cancelling a provisional transition removes its history entry instead of offering a redo that could resurrect it.

### 2026-10-19 — Undoing a room link should keep the room usable

Make interior is one map command plus an entrance link. Undoing that command should remove the link while retaining
the new map and its furniture, so Reconnect and Locate belong on the room draft rather than on the discarded history
row. A unique return warp can identify its original unlinked building; an ambiguous match should only locate. Revert
is a separate destructive action, so it checks every outside entrance before deleting a new map and returns through
the room's saved exit if the source building has since been unlinked.

### 2026-10-19 — Building scale includes the approach path

At 40 px per tile, character-scale facades need explicit native frames, map footprints, doors and collision masks.
Enlarging a footprint can leave the doorway clear while nearby trees still isolate the approach from the town path;
check connectivity from the map start after moving props. Keep depth inside the approved camera by joining towers and
other tall forms to the roof ridge, so every facade shares one silhouette grammar.

### 2026-10-19 — More terrain layers need another mask plane

The signed 64-bit corner mask leaves the sign bit clear, so fifteen four-bit ground layers fit safely in one plane.
Eighteen paintable outdoor overlays split into two 15-layer planes; the same packing is used for full bakes and
incremental chunk repainting. Connected dirt, brick, stone and wood paths share the exposed-edge generator, which
keeps a three-cell-wide path unframed through its center. Palette-locked ImageGen swatches give each material a
distinct 40-pixel texture while preserving the existing renderer's deterministic variants and seam checks.

### 2026-10-19 — Chunking does not remove the full-map bake cost

`GroundLayer` draws the complete map image before splitting it into 320-pixel display chunks. The chunks keep the
renderer incremental, but the temporary source image still grows with the map's full pixel area. Map-size controls
therefore share a 128 × 128 tile ceiling instead of allowing unbounded growth. Dialog help also needs an explicit
minimum width: smart wrapping a content-sized label without one can make a compact popup taller than the screen.

### 2026-10-19 — Editor navigation needs identities and a history owner

A quest label can change with a draft or translation, so a person reference now carries its quest ID and step index
beside the displayed words. It is derived from giver IDs and dialogue flags, then opens the existing editor. Returning
to a person likewise resolves their map and person ID again instead of saving an object index. Navigation first
settles focused text; the header Undo button follows the same document as keyboard Undo. Otherwise a dialogue editor
can look correct while its global button undoes a hidden map edit. Entrance diagnostics keep exact source snapshots
and use shared link-state codes rather than decoding an English error message.

### 2026-10-19 — A workspace scope is separate from a search filter

Build reuses the same canonical entries and card component as Objects, with a caller scope intersected before user
filters. Reset, Recent and On this map therefore cannot escape construction. Separate panel instances preserve
browsing state; passive refresh must preserve scroll too, because a hidden refresh can otherwise erase it before the
panel opens. Tab routing also clears tools the destination does not offer, preventing a hidden tree-area filter from
capturing Build gestures. An explicitly typed empty history list keeps room removal safe while no session exists.
