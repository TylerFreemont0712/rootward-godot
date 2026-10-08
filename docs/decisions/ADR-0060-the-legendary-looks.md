# ADR-0060: The legendary looks: an orrery circle, constellation bolts and a black-hole impact

Accepted 2026-10-08. Applies to the worn circle, bolt and impact (ADR-0037, ADR-0039, ADR-0044, ADR-0057 and
ADR-0058), and the program run's bolts (ADR-0012).

## Context

A cast is drawn by three of the six worn slots: the circle, the bolt and the impact (ADR-0037). The first version of
the legendary looks drew sprite sheets and is retired. The second gave each bolt a patterned route. The player wanted a
spectacle when a spell is actually cast: four or five star points per bolt, placed at random, a slightly different
path for every bolt, every bolt converging on one point of the foe, and a turning orrery that the bolts leave from.
The new looks sit beside the existing ones, which keep working unchanged.

## Decision

- The circle option `legendary-orrery` (style `orrery`) draws one planet per shard on a turning orrery. Its final star,
  the planet of the shard that arrived last, is where the cast's bolts start.
  `MagicCircle.final_node_global()` gives that point in global coordinates.
- The bolt option `legendary-constellation` (`draw: "constellation"`) is one volley per cast: a `ConstellationVolley`
  with one rider per bolt. Each rider has its own seeded route of four or five stars (five for the signature cards
  radix-sort, quickselect and memo-ward), seeded by the cast's serial, the hit's index and the card id. Each bolt has
  its own path, and the same bolt looks the same every time. Every route converges on one point of its foe. A legendary ward rides at 0.6 of the bolt's flight, as an ordinary ward does.
- The impact option `legendary-singularity` (`draw: "black-hole"`) is a shader on the foe's point. `LegendaryCast`
  opens one hole per foe per cast: the first non-critical landing on that foe opens it, and a critical one does not.
- The catalogue names each renderer with `draw`, so no sprite sheet is needed. An unknown `draw` is reported by
  `CosmeticRules.check`, and the look is then held to its sheet fields.
- A program bolt carries the card and the role that returned it. The harness stamps both after the card has run, in
  Python, JavaScript and C++, so a card cannot choose its look through the values it returns.
- Reduced motion (`Settings.reduced_motion`) drops rings, bursts and sparks. The trace shortens to 0.12 s, and the hole
  takes 0.6 s, without spin, lensing, jets, dispersal, the shock ring or the inflow arms. A star's flare keeps a glint that shrinks and fades.
  The inflow arms are not yet verified on screen.
- Both harnesses bill from one copy made before any card-controlled value is read again, and the launcher captures its
  built-ins at start. The harness's open limits are recorded and not closed. A card can replace some of the harness's names
  for its own job (JavaScript's `counts`, `tagged` and `loop`; Python's locals through `sys._getframe`), hide
  measured work by switching off its tracer or shadowing its loop counter, and a later card can print a forged result line. Closing them is a
  policy or architecture choice for the player (docs/LEGENDARY_LOOKS.md, Decisions).

## Alternatives considered

- Sprite sheets (version 1, retired). The sheets were a recolour of the existing glyph swarm. They are archived in the
  session scratchpad, not in git.
- A patterned route for each bolt (version 2, retired). The star points were patterned, where the player wanted them
  placed at random.
- Stamping the tags in card code (rejected). Each card could then choose its own look.

## Consequences

- Measured on 2026-10-08 with `wc -l`: `log_player.gd` is 793 lines, under the 800-line `max-file-lines` limit in
  `.gdlintrc`. The legendary helpers live in `LegendaryCast` (187 lines). The volley (`constellation_volley.gd`, 691
  lines) and the orrery (`legendary_orrery.gd`, 566 lines) are the largest new files.
- New harness rule: loops over a card's bolts run over copies or lists the harness built, never over the card's objects.
  JavaScript indexes them, with the length read once before each loop, and never uses `for...of`, because the iterator
  protocol is a built-in a card can replace. Python iterates the harness's lists, and C++ keeps range-for loops over the
  harness's own `Bolts`. The launcher captures its 13 built-in functions and methods, and the `Error`, `Map` and `Set`
  constructors, in its closure before the player's code runs.
- The stamp is written only for program runs, so Spellforge, the card run and the reference fixtures are unchanged by
  design (docs/LEGENDARY_LOOKS.md, Program tags).
- Known limit: a bolt that waits past the 8 s landing cap after its volley has freed can start a second volley and bloom
  its foe again. It is rare, and it changes only the bloom.
- Japanese names and notes are in `game/content/packs/core/locales/ja/cosmetics.jsonc`.
- Open decisions for the player: the three harness limits; reduced motion for ordinary hits, since the existing blows
  and `SpellAnim` do not read the setting; four or five stars per bolt; whether the looks are always available or
  unlocked; and a bespoke cast sound (the hole uses `sfx-hit-heavy`; a new cue would go through
  `pipeline/audio/manifest.json`).
- This record runs none of the tests, lint, validation, locale check or screenshots. They are listed in
  docs/LEGENDARY_LOOKS.md (Verification).
