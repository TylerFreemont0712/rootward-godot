# Legendary looks: the Orrery's bolts and a black-hole impact

Version 3.5, 2026-10-08. Version 3.5 records the hardening pass over 3.4: the reduced-motion flare glint, the inflow arms not
yet verified on screen, the constellation ward's flight, the harness's billing and captured built-ins, the cast's fields, the
file's length, and the loop rule. Version 3.4 recorded the decisions from the v3.3 review: the orrery's fallback origin,
reduced motion for rings and arms, the landing names, the heavy cast's first bolt, and the harness's open limits. Version 2 gave each bolt its own patterned route. The player wanted: four or five star points per
bolt, placed at random; a slightly different path for every bolt; every bolt converging on one point of the foe; and a
spectacle when the spell is actually cast. Version 3 built that. Versions 3.1 to 3.3 record the decisions from review and
evidence: the coordinate convention, the effects layer, the cast serial, the captured built-ins, the seed bit, the landing
signal, the draw order, and reduced motion. Version 1 (sprite sheets) is retired, and archived in the session scratchpad,
not in git. The set sits beside the existing looks, which keep working unchanged.

## The three options

Each is appended to its slot, never first (the first option is the default), and carries `"legendary": true`.

| Slot | Option id | English name | Japanese name | Fields |
|---|---|---|---|---|
| circle | `legendary-orrery` | Orrery of the Codex | コードの天球儀 | `style: "orrery"` |
| bolt | `legendary-constellation` | Constellation Bolt | 星座の光条 | `draw: "constellation"` |
| impact | `legendary-singularity` | Singularity Burst | 特異点の爆発 | `draw: "black-hole"` |

Notes (English, then Japanese in `locales/ja/cosmetics.jsonc`):
- Orrery: "A rotating orrery: one planet for each shard, marked with its role. Each arrival links a planet into a constellation." / 回転する天球儀。シャードごとに惑星が一つ現れ、役割の印を帯びる。到着するたびに星座につながる。
- Constellation: "A line of light that hops from star to star on its way to the foe. It starts at the orrery's last star, and follows that star as the orrery turns." / 敵へ向かう途中で星から星へ跳ぶ光の線。天球儀の最後の星から放たれ、その星の回転に従う。
- Singularity: "A black hole that opens on the foe, bent into prismatic light: it collapses, flashes, and throws out jets." / 敵の上に開く、虹色に曲がった光のブラックホール。収縮し、閃き、噴流を放つ。

**Name colour:** a legendary option's name (carousel title and wardrobe name) uses `UiTheme.LEGENDARY_NAME = Color("#ff6ec7")`, hot magenta.

**Gating:** none. The three are always available.

## The catalogue says how a look is drawn

A bolt or an impact option names its renderer with `draw`, and needs no sheet:
- A bolt with `"draw": "constellation"` needs no `sprite`, `strong` or `path`. The known bolt draws are `BOLT_DRAWS = ["constellation"]`. Ordinary bolts keep `sprite`, `strong` and `path`.
- An impact with `"draw": "black-hole"` needs no `sprite`. The known impact draws are `IMPACT_DRAWS = ["black-hole"]`.
- An unknown `draw` is reported by `CosmeticRules.check`, and the look is then held to its sheet fields, as an ordinary look is.
- `CENTRED_STYLES` includes `orrery`, so the orrery is drawn on the circle's centre.

## Styles by role and cast (pure: LegendaryLook)

`game/scenes/shardrun/fight/legendary_look.gd` (`class_name LegendaryLook`, static functions only, no nodes):
- `unit(seed: int, k: int) -> float`: a hash in [0, 1), from `Rng.imul`, `Rng.mix32` and `& 0xFFFFFFFF`. The same inputs give the same value.
- `rider_seed(cast_serial: int, index: int, card: String) -> int`: a 31-bit FNV-1a hash of the cast's serial, the hit's index and the card id, finished by `Rng.mix32`. The finaliser matters: plain FNV-1a's lowest bit is the parity of its input, so consecutive bolts would alternate. Each bolt of one cast gets its own seed, so each bolt has its own path, and the same bolt looks the same every time.
- `is_signature(card: String) -> bool`: true for `radix-sort`, `quickselect` and `memo-ward`.
- `spread_of(role: String) -> float`: how far a role's stars may stray from the line, as a fraction of its length. strike 0.24, guard 0.14, source 0.30, shape 0.22, order 0.12, import 0.26, anything else 0.20.
- `bolt_style(role: String, card: String, seed: int, element_colour: Color) -> Dictionary`, with keys:
  - `count`: the star points the bolt hits. 5 for a signature card; otherwise `4 + ((seed >> 2) & 1)`, so 4 or 5. Prism reads the low two bits of the seed (`seed % 4 == 0`), so bit 2 is free, and a prism bolt can have five stars.
  - `spread`: `spread_of(role)`.
  - `prism`: true for a signature card, and for one bolt in four (`seed % 4 == 0`). A prism bolt's line is coloured through the palette along its length.
  - `colour`: the role's tint (strike `#ff9a3c`, guard `#5ff2d0`, source `#9dff5c`, shape `#b98cff`, order `#6fd6ff`, import `#ffe066`), else `element_colour`. A prism bolt's core is `LegendaryLook.PRISM_CORE` (`#fff6e0`).
- `impact_style(role: String, card: String) -> Dictionary`, with keys `bands`, `spin`, `tilt`, `jets`, `lens`, `hue`, `photon_sides`, `arms`, `scanlines`, `digits`, `split`, `cells`, `rings`. Base values: bands 6, spin 0.6, tilt 0.45, jets true, lens 0.6, hue 0, photon_sides 0, arms 0, scanlines false, digits 0, split false, cells false, rings 1.
  - strike: tilt 0.6, bands 4, lens 0.9, hue 0.04.
  - guard: rings 3, jets false, bands 3, lens 1.0, hue 0.5 (a shield).
  - source: arms 4, bands 8, spin 1.0, jets false, lens 0.4, hue 0.3.
  - shape: photon_sides 6, jets false, bands 6, lens 0.5, hue 0.7.
  - order: scanlines true, bands 12, jets false, lens 0.3, hue 0.55.
  - import: arms 2, rings 2, lens 0.5, hue 0.15.
  - Signature: radix-sort `digits` 10; quickselect `split` true and jets true; memo-ward `cells` true and rings 2.

## Coordinates, and where the effects live

- **Every legendary position passed between nodes is a global point.** Each consumer converts it into its own space, each frame,
  with its parent's transform: the impact for `at`. The volley converts its origins and targets with `to_local`, which is its own
  transform, and so its parent's space, since the volley is added at the parent's origin. Nothing passes a point in another
  node's space. The conversion is not `stage.to_global`: `BattleStage` is a Control whose shake offsets live in its `_world` and
  `_fx` children, so the node that draws decides.
- **The volley and the black hole are children of the fight's effects layer**, `BattleStage.fx_layer()`, not of the stage. The
  fight's time scale (`BattleStage._keep_time`) reaches them through a `time_scale` property, as it reaches a SpellAnim.
- **Draw order.** The volley draws above the black hole: the volley's `z_index` is 2, the hole's is 1. So the convergence bloom
  is not hidden under the hole's disc.
- Tests for both nodes parent them at an offset (not the origin), so a missing conversion fails a test.

## The constellation bolt: a volley of riders

Files: `constellation_path.gd` (`class_name ConstellationPath`, pure geometry) and `constellation_volley.gd` (`class_name
ConstellationVolley`, a Node2D that owns the riders, their timing, their drawing and their arrivals).

**Geometry** (`ConstellationPath`, static, pure):
- `stars(seed: int, count: int, spread: float) -> PackedVector2Array`: `count` star parameters, each `Vector2(t, s)`.
  - `t`: `count` values from `unit(seed, k)` scaled into [0.12, 0.88], sorted ascending, and pushed apart so that neighbours
    differ by at least 0.06. If they cannot, they are spaced evenly.
  - `s`: a signed lateral offset, `(unit(seed, count + k) * 2 - 1) * spread * (1 - 0.6 * t)`, as a fraction of the line's
    length. The factor narrows the route as it nears the foe, so every route converges on the target.
- `route(origin: Vector2, target: Vector2, stars: PackedVector2Array) -> PackedVector2Array`: the origin, then each star at
  `origin.lerp(target, t) + normal * s * length`, then the target. `normal` is the unit perpendicular to `target - origin`
  (`Vector2.RIGHT` when the length is 0). The route has `count + 2` points.
- `point_on(route: PackedVector2Array, p: float) -> Vector2`: `p` in 0..1 across equal-time segments. Star k (1-based) is reached
  at `p = k / (count + 1)`.

**One volley per cast.**
- `ConstellationVolley.start(parent: Node, origin: Callable) -> ConstellationVolley`: `origin` returns the orrery's final star in
  global coordinates. It is called once per frame, and every rider's route is rebuilt from it, so the constellation turns with
  the orrery. `parent` is the fight's effects layer.
- `add_rider(target: Vector2, look: Dictionary, ms: float, arrive: Callable) -> void`: `target` is global. `look` holds `role`,
  `card`, `index`, `cast_serial` and `element_colour`, and `power`. The rider's seed is `LegendaryLook.rider_seed(cast_serial, index,
  card)`, its style is `bolt_style`, and its stars are `ConstellationPath.stars(seed, style.count, style.spread)`.
- `close() -> void`: no new cast is coming. The volley frees itself once its riders are done.
- Lifetime: `LegendaryCast.ride` makes a cast's volley at its first legendary bolt (LogPlayer calls it), and keeps it open while the cast runs. A rider may join at
  any time while the volley is open, including a bolt that waits behind a falling blow. A cast's volley is closed when
  the next cast starts, or when the log ends (`_legendary.close()` in `log_player.gd`); it frees itself once its riders are done. A target blooms once per volley.
- **Known limit.** A bolt that waits past the 8 s cap (`LANDING_CAP_MS`) after its volley has freed starts a new volley for its cast,
  which can bloom a foe a second time. It is rare, and it changes only the bloom.

**Timeline**, from a rider's add time:
- **Trace**, 0.32 s (0.12 s reduced). The route is drawn out from the origin by a bright pen. Star k ignites as the pen reaches
  `p = k / (count + 1)`: it scales in over 0.12 s with a white flash and a ring. The head is hidden during the trace.
- **Flight**: `clamp(ms / 1000, 0.12, 1.4)` seconds. The fight's own flight times are kept, so missiles, lances and seekers keep
  their different speeds. The head starts at the origin and moves along `point_on(route, p)`. Each star flares again as the head
  passes it: a ring that grows and fades, a four-point glint, and six sparks, over 0.35 s.
  A legendary ward rides at `flight * 0.6`, as an ordinary ward does (`log_player.gd`, `_launch`); `legendary_cast_test.gd` checks it.
- **Arrival**: `arrive.call()` runs once. The rider is done after its longest fade: the traced line fades 0.6 s after the head
  passes, and the stars are kept for 0.8 s.
- **Origin burst**: each rider bursts at the origin when it is added, a ring and eight sparks, 0.3 s. The first rider of a volley
  also draws a larger flare on the orrery's final star.
- **Convergence bloom**: when the last rider aimed at a target lands, the volley draws a ring and twelve sparks at that point,
  0.4 s. A target blooms once per volley.

**Drawing.** The traced constellation line, the trail as three strokes over each other (wide and faint behind, narrow and bright
ahead, with a white-hot core), the head's glint, the stars as diamonds, and the sparks. A diamond is drawn only when it is at
least 0.5 px across. A prism rider colours each part of its line by its place along the route, the hue cycling with time. A
tinted rider uses its `colour`. Power 12 or more widens lines by 1.6. The glow is an additive material. Only draw calls are used.
The volley's `time_scale` multiplies its clock.

**Reduced motion** (`Settings.reduced_motion`): the trace takes 0.12 s. There are no origin bursts, no sparks, no convergence
bloom, no ignition ring, and prism colours do not cycle. A star's flare keeps a glint that shrinks and fades where it stands, without the growing ring or the
sparks; no test pins the shrink or the fade. The flights and arrivals stay.

## The black-hole impact

Files: `black_hole_impact.gd` (`class_name BlackHoleImpact`, a Node2D) and `black_hole.gdshader`.

`BlackHoleImpact.play(parent, at, radius, look) -> BlackHoleImpact`, with `at` global and `look` holding `role` and `card`. Its disc
is `radius` (120 px for a blow, 150 px for a heavy cast's first blow). Its quad is **5.0 radii** across, so the shock ring and the
jets have room. The lensing copy covers the quad, in viewport coordinates, and refits every frame.

**Measure in disc radii.** The black core (the event horizon) is 0.42 of the disc radius. The shock ring reaches 2.4 radii and the
jets 1.9 radii, measured from the disc's centre. Checks compare these ratios to the black core on screen, not absolute pixels: the
fight's own scale is not known to a screenshot. (The v3.2 evidence measured a ring of about 5.7 black-core radii and jets of about
4.5, which matches 2.4 / 0.42 and 1.9 / 0.42.)

- Signals: `impact` (once, at `p = 0.25` of the timeline, the instant the blow lands). `finished` (at the end, when it frees
  itself). Nothing is emitted before the node is in the tree.
- **`landed()`** returns a signal that fires when the impact lands or when the node is freed before that, whichever comes first. A
  caller awaits it right after `play()`. It is a release, not the `impact` signal, so an early removal never emits `impact` from inside
  the parent's removal. After the impact, `BlackHoleImpact.landed_of(hole)` (a static coroutine, as `SpellAnim.landed_of` is) returns at once. On an early
  removal the release fires deferred, after the removal ends, so a waiter can add nodes to the parent without the busy-parent
  error. At the impact it fires at once.
- `time_scale`: the node's clock multiplies by it, as a SpellAnim's does.
- Timeline: 1.2 seconds. Reduced motion: 0.6 seconds, with the impact at 0.15 s.
- Phases, on `progress` p in 0..1: inflow 0 to 0.3 (streaks spiral in along the arms, fading out between 0.2 and 0.3; not yet verified on screen); collapse 0.08 to 0.25 (the
  horizon opens over this span, and the prismatic photon ring and the banded accretion disc brighten); impact at 0.25 (a white flash, a
  shock ring from 0.45 to 2.4 radii, the lensing pinch at its strongest); jets 0.25 to 0.6 (two prismatic beams, up and down, 1.9
  radii long); dispersal 0.4 to 1.0 (prismatic shards leave the ring and fade).
- Variant features come from `impact_style`: scanlines, digits, split (a beam through the disc at impact), cells (the ring cracks into
  eight arcs at impact), rings, photon_sides, arms.
- **Reduced motion** sets the shader's `reduced` uniform. It drops the spin, the lensing, the jets, the dispersal, the shock ring and
  the inflow arms. It keeps the disc, the photon ring, the impact flash, and the features digits, split, cells and scanlines. The
  inflow arms are not yet verified on screen: a test pins the `arms` uniform to 0 and reads the shader's gate as text, but no
  screenshot has shown the arms, full or reduced.
- Shader uniforms (names fixed): `progress`, `radius_uv`, `bands`, `spin`, `tilt`, `jets`, `lens`, `hue`, `photon_sides`, `arms`,
  `scanlines`, `digits`, `split`, `cells`, `rings`, `reduced`, `screen_tex`.
- Colour: the cosine palette `a + b * cos(2 pi (t + d))` with `d = (0, 1/3, 2/3)`, offset by `hue`. The hottest part of the photon ring is white.
- `z_index` is 1 (the volley's is 2).

**One black hole per foe per cast**, decided by `LegendaryCast` (below): the first non-critical landing on each foe in a cast opens
it, at that foe's convergence point. A critical landing plays `hit-critical` on the sprite path and does not open it, so the first
non-critical landing after it does. Later landings on that foe in the same cast play the ordinary blow, `blow_sheet(element)`.

## The orrery's final star (unchanged)

- `LegendaryOrrery.planet_positions(time, radius, count) -> PackedVector2Array`: each shard's planet, in the circle's local space.
  `draw` uses the same function, so the drawn planets and the bolts' origins cannot disagree.
- `LegendaryOrrery.final_node(time, radius, count) -> Vector2`: the last planet, the shard that arrived last. `Vector2.ZERO` with no shards.
- `MagicCircle.final_node_global() -> Vector2`: the final node in global coordinates, using the clock and `radius * swell` that
  `_draw` uses. With no shards, the circle's centre. Used only when the circle's style is `orrery`. If the circle has freed before the volley reads its origin, the origin is the last final star the cast read (seeded at its first launch), not the circle's centre.

## Fight wiring (WIRING)

Legendary bolts do not go through `BattleStage.fly`, which stays for ordinary bolts.
- `BattleStage` provides `fx_layer() -> Control` and `next_cast_serial() -> int`. The serial belongs to the fight, not to a
  LogPlayer: a LogPlayer is made per command, so a counter on it would repeat seeds across the fight's casts.
- `LegendaryCast` (`legendary_cast.gd`, `class_name LegendaryCast`, RefCounted): the pure decisions and the per-cast state. It holds
  the cast's serial, whether it is heavy, each foe's falling blow (`crashed`), its volley, the origin it last read
  (`last_origin`), a snapshot of each foe's target point taken at the cast's first launch to that foe, and the set of foes
  already opened. It decides the origin (the final star when the circle is an orrery, else the launch point converted with the
  launch node's own transform), the target (the snapshot for a foe, the hero's body point for a ward), and whether a landing opens the
  hole. The legendary helpers live there, out of `log_player.gd`.
- **The launch point is captured before the first await.** A bolt that waits behind a falling blow must not read its circle after
  that await, because the circle can have freed itself by then. The foe is the same: its points (`target_point`,
  `foot_point`, `sprite_width`) are read before the first await, so a bolt flies to the point it launched with, even if the
  foe's view frees during a falling blow.
- `log_player.gd` must stay under 800 lines, the lint limit. It is 793 lines now (measured with `wc -l` on 2026-10-08). The 760 target of earlier versions is dropped.
- `_launch(hit, flight, volley, index)`, when the worn bolt's `draw` is `constellation`, calls `LegendaryCast.ride`, which makes the cast's volley on its first legendary bolt (and a new
  one for a late bolt once the last has freed), and the bolt joins it with
  `add_rider(target, look, flight, _land.bind(hit, volley, cast))`. Targets are global.
- **A heavy cast's falling first blow on a foe is a blow, not a bolt.** With a sprite impact, the hit lands as the falling blow, so no rider is added for it. With a black hole there is no falling blow: the foe's first bolt is a rider, and it lands as the 150 px hole.
- `LegendaryCast.ride` takes the cast's serial, volley and origin before any await, so a bolt that waited behind a falling blow joins the cast it was launched in, from the point it was launched from.
- `_land(hit, volley, cast, crashed := false)`: the hole opens as `LegendaryCast` decides, and its release is awaited as a sprite's
  impact was. A legendary impact's hole plays `sfx-hit-heavy`.
- Fast stage: legendary bolts land at once, with no volley and no hole. Non-legendary bolts are unchanged.
- The "Parent node is busy setting up children" error is fixed at its cause: a release that fires during a removal is deferred.

## Carousel previews (LOOK)

- A sprite-less legendary look shows a still preview on its card: a bolt's route of stars, or a black hole at progress 0.6.
- A preview's black hole keeps processing with its `time_scale` at 0, so it keeps refitting its copy and stays a true lens. It is
  placed at the card's global centre, and it is rebuilt when the card moves, because the impact stays on its global point.
- Previews are children of their card, so freeing the card frees them.

## Program tags

- A program bolt carries `card` and `role`. They travel from the sandbox harness to the fight hit: `ProgramRules.normalize`
  keeps both, and `ProgramLanding` puts both on the bolt's `shape`, so a hit has `hit.card` and `hit.role`.
- The harness writes the tags, not the card. Python, JavaScript and C++ each stamp a bolt with the card that returned it, after
  that card has run, overwriting any `card` or `role` key the card's own code returned. A bolt takes the tags of the last card that
  returned it. A bolt no card returned has none. Before-imports are not stamped.
- **Captured names.** Every built-in or library function the harness calls after a card returns is captured when the harness starts,
  and loops over bolts follow the loop rule below. That covers
  the stamp, the serialisation, the array and dict operations on bolts, and the arithmetic the relics do on a bolt's power. The
  launcher (`game/sandbox/launch/launch.js`) captures 13 built-in functions and methods, and the `Error`, `Map` and `Set` constructors, in its closure at start (16
  references in all), so a card cannot change the printed line. Its exits are frozen and kept in a `WeakSet` of its own, so a
  thrown look-alike is not an exit.
- **What remains open.** A card can still:
  - change a built-in's behaviour for its own job, for example by defining `Object.prototype.toJSON` or setting `Symbol.species` on an
    array constructor, so its output changes (no test here exercises this);
  - rebind a global name of the harness, such as its stamp function (in JavaScript `counts`, `tagged` and `loop`, for one), or
    reach the harness's locals through `sys._getframe` (Python);
  - swap Python's `json` encoder.
  These changes are confined to the job. A turn's programs share one job (`spell_runs.gd`), so a card in one spell can change another
  spell's output in the same turn. Closing this fully means freezing the prototypes after the harness's setup, or giving each program its
  own process. Neither is done (see Decisions).
- **Input at start (v3.5).** JavaScript freezes the job's input (`DATA`) before any card runs, so the shard table, the limits, the
  execution flag and the relic options cannot change. Python copies the shard table as text, and the limits, the execution flag
  and the relic values as plain values, at start; it parses shards and the execution rules afresh from that text.
- **Loops (v3.5).** JavaScript and Python loops over bolts run over copies or lists the harness built, never over a card's
  objects. JavaScript indexes them and never uses `for...of`, because the iterator protocol is a built-in a card can replace.
  C++ keeps range-for loops over the harness's own `Bolts`. The rule is about card objects, not the harness's own lists.
- `normalize` validates them: `role` must be one of `ProgramSchemas.ROLES`, else `""`; `card` must be a card id (lower-case
  letters, digits and hyphens), else `""`.
- The stamp is written only for program runs, the path that sets `execution`. Spellforge, the card run and the reference fixtures do
  not change.
- Tag the bolt, not its index: `shape.bolt` indexes the landing list, which withdrawals and relics change.
- **Billing and results (v3.5).** Billing counts a card's returned bolts from one copy, made before any card-controlled value is read
  again, so a card cannot report a different length to the billing. Three limits remain, and each is a decision (see Decisions): the
  card runs in the harness's own scope, so it can replace some of the harness's names for its job (in JavaScript `counts`,
  `tagged` and `loop`; in Python the harness's locals, through `sys._getframe`). Replacing the job's input changes nothing, since
  JavaScript freezes it and Python reads it only at start. A card can
  hide its measured work by switching off its own tracer (`sys.settrace(None)`) or by shadowing its loop counter (`__loop`),
  which bills 1 for the work, and 26 shipped
  content files use measured work; and a later card can print a forged result line for an earlier spell, which `read_runs` accepts
  because it keeps the last line. One process per program closes the forged lines, and freezing the JavaScript names closes that
  part of the first. Neither closes the hidden counts: a card can switch off its own tracer in its own process, and Python's
  `sys._getframe` reaches the harness's frames in any scope.

## Tests (each lane's own)

- Styles: `unit` is in [0, 1) and deterministic; `rider_seed` differs by index and by card, and matches its pinned values; `bolt_style`
  gives 4 or 5 stars (5 for signature cards), the spread for each role, and the prism rule; a non-signature prism bolt can have five
  stars; `impact_style` gives each role and signature card its features.
- Geometry: `stars` gives `count` parameters, sorted, within [0.12, 0.88], neighbours at least 0.06 apart (or evenly spaced),
  deterministic, and different for different seeds; the lateral offset shrinks towards the target; `route` starts at the origin,
  ends at the target and has `count + 2` points; `point_on` is continuous and reaches star k at `k / (count + 1)`.
- Volley: parented at an offset, with a stub origin and a target in global coordinates: the head ends on the target, so the
  conversion is right; each rider's `arrive` runs once; the origin is called more than once; each star flares once in flight; the head is
  hidden during the trace and starts at the origin; the bloom runs once per target per volley; `close` frees the volley once its riders
  are done; the flight is `clamp(ms / 1000, 0.12, 1.4)`; two riders of one cast have different routes; reduced motion adds no sparks,
  origin burst or bloom; a diamond under 0.5 px is not drawn; `time_scale` 0 freezes it; the volley's `z_index` is above the hole's.
- `LegendaryCast`: one hole per foe per cast; a critical does not open it; the next non-critical landing does; a ward never opens it;
  the snapshot holds when the foe moves; the origin falls back to the launch point converted with its own transform; the serial comes
  from the stage, so two LogPlayers in one fight give different serials; a late rider joins its own cast's volley; a constellation ward flies at 0.6 of the bolt's flight; a bolt whose foe view frees
  during a falling blow still lands; the launch point is
  captured before the first await.
- Impact: parented at an offset, `at` global; `impact` fires once at 0.25 of the duration; `landed()` fires at the impact or on an early
  removal, whichever comes first; `landed_of` returns at once after the impact; the node frees itself; the reduced timeline is 0.6 s, with
  no ring, spin, jets, lens or dispersal; the uniforms match `impact_style`; the quad is 5.0 radii; `time_scale` scales its clock.
- Orrery: `final_node` is the position `draw` uses for the last planet; with no shards it is the centre.
- Carousel: a sprite-less legendary look yields a preview node that is still processing with `time_scale` 0 and refits its copy; the
  preview is freed with its card.
- Catalogue: `draw` values are known; the three legendary options pass `check`; each has Japanese names and notes.
- Tags: in Python, JavaScript and C++; a card's returned values cannot choose its look; a card that rebinds the built-ins the harness
  captured cannot change its own tags or a relic's effect; loops over bolts run over the harness's lists; Spellforge's output and the fixtures are unchanged.

## Verification

- Full suite (`scripts/test.sh`), lint (`scripts/lint.sh`, including `max-file-lines` at 800), `scripts/validate.sh` (the harness changed),
  `scripts/locale.sh ja --missing` for the new strings, and the fixtures (no change). The C++ runtime is rebuilt with `scripts/build-cpp.sh`.
  The known failures are the two that predate this work: the loot-screen layout test, and the program upgrades test for ten cards.
- Screenshots, each looked at, in `shots/legendary/`: the cast (the origin burst, the trace, the stars igniting); the flight and the
  convergence on one point, with the convergence bloom visible above the black hole; the head at the start of a flight (no snap back);
  two casts of one fight with different routes; three bolts of one role with different routes; the origin at two orbit phases; a
  reduced-motion pair (no ring, burst, sparks or bloom, and the disc and flash kept); the carousel's two legendary previews and their magenta
  names, with ordinary names in amber. Ring and jet lengths are checked as ratios to the black core.
- The inflow arms have no screenshot yet, so they are not verified on screen (see Reduced motion).
- The "Parent node is busy setting up children" and "Invalid polygon data" errors are absent from the log across a legendary cast.
- The earlier lint failure, the doc comment at `game/core/programs/program_rules.gd:498`, stays fixed.

## Decisions for the player

- Harness, from the v3.3 review: (1) the harness's scope (wrap it in one function, so a card cannot replace its JavaScript globals; Python's `sys._getframe` reaches its frames in any scope); (2) measured
  work that a card hides (bill tampered runs at the cap, or fail them); (3) forged result lines (one process per program); each is a
  change of policy or architecture, and none is made yet.
- Reduced motion for ordinary hits: the game's own blow sheets (`hit-*`) draw rings and sparks, and `SpellAnim` does not read
  `Settings.reduced_motion`. The legendary looks follow the setting; the existing blows do not. Extending it is a game-wide change.

- Stars per bolt: four or five, five for a signature card. Say if you want more.
- Gating: are the legendary looks always available, or unlocked by something in play?
- Sound: the hole uses `sfx-hit-heavy`, and the cast uses the existing sounds. A bespoke cast cue would go through `pipeline/audio/manifest.json`.
- The harness: freeze the built-in prototypes after the harness's setup (this stops a card from monkeypatching them, and changes what card
  code can do), give each program its own process (the complete fix, and the slowest), or accept the job-level limit as it stands.

## Research notes

A web-research pass ran before version 1 (standard search, eight queries). Its sources were read as search excerpts, not
opened in full, so treat each as a lead.

- Prismatic hue: a cosine palette, a + b * cos(2 pi (c t + d)), from Inigo Quilez's palette article
  (iquilezles.org/articles/palettes). A hue stored in an 8-bit channel is blended by linear filtering, so keep hues away from the 0/1 wrap.
- Lens and shockwave: `hint_screen_texture` with `SCREEN_UV`, per the Godot 4.4 screen-reading shader tutorial. Each screen
  read copies the framebuffer; a BackBufferCopy in rect mode limits the copy (the Godot 4.2 class reference). Only what is
  drawn beneath the lens is bent.
- Additive glow from draw calls: a CanvasItemMaterial with the add blend mode (the Godot 4.2 class reference). Stacked
  additive discs clip to white, so keep each ring's alpha low.
- Orrery: orbit tilt by a y-scaled transform, and a back and front split so a planet hides the far arc. Sources: an
  open-source orrery project (github.com/taliaduckie/orrery) and a write-up of Outer Wilds' Ship Log as a node-and-line graph
  (archania.org).
- Flashing: WCAG 2.3.1 limits flashing to three per second (W3C, cited from memory). The flashes here are single flares, not
  strobes, and reduced motion removes the sparks.
