# ADR-0014: spell animations drawn as motion

- Status: accepted
- Date: 2026-09-26
- Related: ADR-0008 (spell sprites from the concept boards), ADR-0009 (spells that differ), ADR-0013 (the card table)

## Context

The player, after the card table: "for fighting, the lighting is way too bright, like seizure levels... get rid of the
lightning style of effects entirely as they are a little too .png like instead of being an actual animation. I'd love if
you could actually start working on the spell animation next, using the pipeline to create more custom spell animations
than what is in the concept folder, instead creating more unique and game theme fitting animation styles that create a
more punchy (but not just bright) animation style."

The effects of ADR-0008 are pictures redrawn from the concept boards and moved by one shader (dissolve, reveal, wobble);
their motion is the shader's, not the effect's. Heavy casts called an element's strike down from the sky with an impact
frame and a flash of the whole stage.

## Decision

- **The strikes, impact frames and whole-stage flashes are gone** (ADR-0013's amendment), and the remaining hit and
  cast flashes are softer.
- **Spell animations are drawn as motion, in the pipeline** (`pipeline/sprites/spells.py`, `spells.json`,
  `scripts/sprites.sh spells`). Each is a small program over time t: brackets slam shut and the blow lands on a frame
  of its own, splinters fly out fast and slow down, a ring races out and thins, runes scatter and drift. The runes are
  the code panel's own futhark (RuneCode), so the spells cast the letters the program is written in. Frames are drawn
  three times larger and shrunk, with a bloom from a blur of the light, into a lossless PNG sheet and a JSON of facts
  (frames, fps, anchor, the moment of impact). No GPU is needed; a sheet redraws in about a second.
- **Two channels, coloured in the game.** A sheet's red channel is light and its green channel is shade.
  `spell_anim.gdshader` colours light through a ramp (dark, mid, hot) whose hot end is a pale tint of the colour, never
  white, and uses shade to darken what lies behind, in one premultiplied-alpha pass. One sheet serves every element
  (none, fire, frost, spark) and the ward, the foes and the race; the punch comes from contrast and timing, not light.
- **The first set**: `cast-sigil` (the file runs: a circle draws itself, runes take their places, brackets snap shut,
  it gathers and lets go), `glyph-bolt` (a comet of runes, flown along an arc and turned to its heading),
  `hit-compile` (brackets slam on the target, then a star, a thinning ring, splinters and runes), `hit-heavy` (a heavy
  cast's first blow on each foe: blocks of code fall on it one after another and crash), `ward-hex` (hex tiles lock into
  a shield), `shatter` (a foe cracks and flies apart), `claw` (a foe's blow on the Maintainer: dark cuts with bright
  edges) and `tempo` (a foe beats the Program: a clock's hand sweeps round).
- **Punch is timed.** `SpellAnim` emits `impact` on its blow's frame; a hit's recoil, number and a short hit-stop
  (30 ms, 80 ms for a heavy crash) wait for it, and a hit-stop freezes every animation on the stage with it. A missing
  sheet falls back to the ADR-0008 effects.

## Consequences

- The old spell sprites stay as fallbacks and for Spellforge's tools; the strike sprites are deleted.
- A painted pass over the drawn motion (the video model repainting the frames, as the sprite skins are drawn) is
  possible on top of this, per animation, if a flat drawn look ever feels too plain; the timing would stay the code's.

## Amended (2026-09-26, after play)

- Slower, to be seen: about half as long again throughout. The heavy blow is three blocks, each drawn in the air above
  the foe, hanging a beat, then dropped (about six frames of fall with a streak) and broken apart where it lands; the
  bolts after it at the same foe wait for it, so the hits land in the order the log gives them.
- The bracket slam shows its brackets before they close, and throws fewer splinters and runes.
