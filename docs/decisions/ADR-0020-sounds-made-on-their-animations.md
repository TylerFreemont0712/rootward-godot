# ADR-0020: sounds made on their animations

- Status: accepted
- Date: 2026-09-28
- Related: ADR-0014 (spell animations drawn as motion), ADR-0019 (the soundtrack)

## Context

The player: "The hit markers, and general sfx also have quite a few issues with not matching the animation", then
"rather than timing, the sound doesn't sound like it fits the animation or action that it's connected to a lot of the
time". The audit (docs/SOUND_DESIGN.md) found generic fantasy combat sounds (stone, leather, a fireball, a knife, a
book) under pictures of code-magic (lines of light, runes, brackets, hex tiles, glass splinters, blocks of code), and a
hit sound chosen by a rule that disagreed with the rule choosing its picture.

## Decision

- **A sound belongs to its animation.** `spells.json` names each animation's sound; `SpellAnim.play` starts it with
  the first frame and adds an element's layer at the impact. The log player sounds only what has no animation.
- **Each sound is a timeline** in `pipeline/audio/manifest.json` (style `timeline`): layers at the animation's own
  milliseconds (its `beats`), from CC0 recordings and from ingredients made in `pipeline/audio/synth.py` (glass
  shimmers and rune ticks in D, bracket clacks, suction, sub booms, the ward's hum, clocks, a glitch, a gulp).
- **Several takes** of a sound heard many times (`variants`); `Sound.play` picks one.
- **Checked by picture**: `beats.py` draws every take against its beats; the loudest moment of each lands on its
  animation's blow (hit-compile 195 ms against 192, the heavy blow 900 against 896).
- **Cues stand in for the music** (`Sound.cue`): the music fades, the fanfare plays, the next screen's music waits.

## Consequences

- No GPU is needed for the sound effects; a recipe edit re-renders in seconds.
- Nobody in the loop can hear; the player's ear decides what to change, and each change is a line of a recipe.
