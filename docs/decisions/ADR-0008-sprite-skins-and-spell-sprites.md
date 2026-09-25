# ADR-0008: sprite skins from a video model, and spell sprites from the concept boards

- Status: accepted (a first test run: Vesper's idle and one cast, and ten spell sprites). Supersedes ADR-0007 for
  Vesper's look in the game.
- Date: 2026-09-25
- Related: ADR-0005 (one pipeline into Godot), ADR-0007 (Vesper modelled in code); in the old repository, ADR-0029
  (the sprite pipeline) and ADR-0030 (mage casts)

## Context

Vesper's modelled 3D version (ADR-0007) is clean but, in the player's words, "doesn't have the anime quality I was
hoping for". They asked for a simpler Vesper made with ComfyUI as a sprite sheet ("general anime style, a little more
depth; not high detail, but smooth animation"), an idle and a cast as a first test, spell sprites drawn from the new
concept boards (`Concept/spellAnimations/`) to replace the line-art effects, and all of it in the game, to see how far a
simple ComfyUI setup goes. The look they are after is Zenless Zone Zero's, with fewer frames.

The old game already solved smooth sprite animation on this machine (its ADR-0029, measured over four failed
approaches): a video model draws a whole clip at once, steered by an OpenPose skeleton per frame, dressed by one
reference drawing, with its first and last frames pinned to that drawing. Its rig was one chibi skeleton.

## Decision

- **Port the old pipeline, not rewrite it** (`pipeline/sprites/`, `scripts/sprites.sh`): the same Wan 2.1 VACE 1.3B
  graph and the same three small ComfyUI nodes, with a `urllib` client so it runs in the pipeline's own environment.
  The old repository is only read.
- **A skin brings its own rig.** `skins/<id>/rig.json` and `animations.json` sit beside `skin.json`. Vesper's is a
  small, cute witch about three and three-quarter heads tall, turned three-quarters toward the foes, hands empty (a held
  prop moves with whichever hand the skeleton moves near it, the old game's lesson), on the old game's proven 640x560
  canvas. A first Vesper six and a half heads tall was scrapped: at that size the 1.3B model softened her face and lost
  her capelet mid-strike (it billowed into a long cape or vanished), and the player preferred a simpler, cuter figure.
- **Drawn keys in the middle of a clip** (`keypose`, a clip's `drawn`): besides its two ends, a clip can pin a frame to
  a drawing of the character in that frame's pose, made like the reference. The video model then passes through her
  real costume at the big moment of a move, as an animator's keys hold a drawing while the in-betweens are filled.
- **The reference is drawn from words on the rest skeleton** (NovaAnimeXL with the OpenPose ControlNet), picked from
  candidates, and must sit on the skeleton: the animation depends on the drawing and the bones agreeing.
- **Clips as before**: pinned to the reference at both ends, feet pinned to the ground line in the build, the cast
  doubled with RIFE in-betweens. The build writes WebP grids and `clips.json` (frames, rate, loop, release frame,
  the hand's position per frame) into `game/assets/sprites/<id>/`.
- **In the game, a sprite skin is a `SpriteCharacter`**: `HeroView` builds one when the skin has a `clips.json`,
  otherwise the 3D `StageCharacter`. A clip a skin was not drawn with plays a stand-in (a heavy cast as the light one,
  a guard as the idle), and a cast's wind-up is played in exactly the 380 ms the stage waits before it launches the
  bolts, which then leave from the drawn palm (the hand track), not from a fixed point.
- **Spell sprites from the boards** (`pipeline/sprites/fx.py`, `fx.json`): each effect is a quadrant of a board,
  cleaned to light on black, redrawn by NovaAnimeXL img2img, and made a glow sprite whose alpha is its brightness.
  In the game one sprite is animated many ways by one shader (`spell_sprite.gdshader`: a noise dissolve with a burning
  edge, a clockwise reveal with a pen tip, a wobble, a shimmer) plus code-drawn layers (a contact flash, a shockwave
  ring) and sparkle particles: a burst pops, spreads and burns out from its core, a seal is drawn in and burns away, a
  ward gathers out of noise and crumbles, a bolt trails a stream of glints. The older line art stays as the fallback
  when a sprite is missing.

## Consequences

- A new clip for a sprite skin is keys in its `animations.json` and about five minutes of GPU; a new skin is a
  `skin.json`, a rig, and a picked reference.
- The fidelity is the 1.3B model's: faces soften in fast motion and fine detail shimmers a little; it is not Zenless
  Zone Zero. The next steps toward that look are a character LoRA (identity in every frame), a larger video model on a
  rented GPU, or a real toon-shaded 3D model with authored animation.
- Sprite skins and 3D skins sit side by side in the wardrobe; nothing about a fight depends on which one is chosen.
