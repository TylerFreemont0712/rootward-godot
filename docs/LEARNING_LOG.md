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
