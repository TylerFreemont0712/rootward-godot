# ADR-0036: A fitting room with a local rehearsal clock, and Cinzel by default

Accepted 2026-10-02.

## Context

The player chose Cinzel as the game's default, asked for smaller paradigm lettering and a wider Settings shade,
and wanted a softer start to the magic-circle passage. Character should become a room for browsing skins and
checking actual animation clips and spell circles, useful both to players and while developing the moves.

## Decision

- Cinzel is the default for new and legacy preferences. Keep `default` as the original IBM Plex Mono/VT323 choice
  so existing ids remain valid. A `font_revision` distinguishes the former default from an explicit Original
  selection saved after this change; that explicit choice survives subsequent loads. Preserve other chosen
  candidates and the monospaced code role. Invalid or missing font ids resolve to Cinzel.
- Reduce paradigm offer names (35 → 32), complexity lettering (52 → 47) and descriptions (16 → 14). The run's
  paradigm header becomes 24 pixels, from 26. This is a typography adjustment, with no run layout/rule redesign.
- Extend the Settings reading shade beyond both edges of the preferences area, with a narrower feather and
  higher opacity, keeping sliders, values and Back over a dark reading surface.
- Run the existing detailed passage on one 1.12-second sine in/out tween, with one opaque midpoint crossing.
  Fade in faint mist and the circle gently at the opening. Do not stop/restart the progress curve at midpoint.
  The title still warms the shader, freezes input immediately and constructs the destination under the veil.
- Character inhabits a generated root-and-brass fitting room, with a compact left-hand class list, right-hand wardrobe/rehearsal tabs and
  an open central practice stage. Reuse the safe room handoff, Back/Escape and reduced-motion behavior. Artificer
  remains the only class; class membership is explicit. The planned roster from SHARDRUN_DESIGN has small vector symbols and disabled
  future-class entries, with an availability tooltip.
- Skins is the first/default right-hand tab. Browse the existing shipped/local skin catalogue through the original
  sliding portrait carousel, its smaller/dimmed neighboring cards, Previous/Next, card clicks and mouse wheel. An explicit
  `Use this skin` saves equipment/profile appearance; previewing never does, including clicks on the central card. `HeroView.preview_skin` selects a
  rehearsal renderer without mutating Settings. Normal battle skin selection remains unchanged.
- Render the actual SpriteCharacter or StageCharacter and expose native clips, rather than drawing placeholder
  animation samples. Motion, Spells and View follow Skins. Motion offers play/pause, four local speeds, looping, 30-fps frame stepping and scrubbing.
  Spells offers each skin's available casts, all four existing circle tiers, four elements, circle-only testing,
  optional circles and shared playback controls. View offers zoom, floor guides, a contrast backdrop and angles
  for 3D models; painted skins retain their drawn viewpoint. Cast tests emit harmless practice bolts.
- Rehearsal uses a local clock, never `Engine.time_scale`. Pause disables the actor subtree. The room drives the
  real MagicCircle manually with scaled delta, including its formation, turning, particles and closing; practice
  bolts and pulses use that same clock. Seeking samples a pose directly without blending from the model's rest
  pose. Switching skins clears transient effects and begins paused on an applied idle pose.

## Consequences and validation

This is a cosmetic rehearsal, with no sandbox execution, battle damage, spell loadout changes or new classes.
Existing production moves and circle drawing stay authoritative; only the rehearsal's harmless volley is local.
A missing painting has a solid room fallback, and missing skin models retain HeroView's existing fallback.
Artwork prompt, generation provenance and SHA-256 are in `finalMenuConcept/character/` (built-in imagegen).

Tests cover equipment isolation for all four shipped skins, native clip discovery, local speed/pause/stepping,
real circles, six harmless pulses, effect cleanup, 3D seeking, existing skin persistence, room handoffs and focus,
English/Japanese geometry, and the versioned font migration. Screenshots cover Motion, Spells, the 3D dummy,
Japanese at 1280×720, Settings audio controls, Cinzel paradigm offers and the passage. The full game suite passed
295 tests in 47 suites, with no errors/failures/orphans; the rendered walkthrough passed 185 actual mouse clicks.
Final focused checks passed all 24 cases after the paused-pose fix. All scripts pass the engine parse check;
changed scripts pass lint and formatting. Repository lint retains the unrelated archive_panel.gd:130
line-length violation.


### Carousel layout refinement

The initial fitting room replaced the old portrait wheel with a single portrait on the left. The player asked to
retain that carousel and put skin browsing in the first tab on the right. Reuse SkinSelectionPanel's wheel/card
arrangement inside a scaled wrapper; preserve the wheel nodes when a new rehearsal actor emits skin_ready so
in-progress card glides are not replaced by a fresh panel. The left column now contains class names and compact
symbols only. Class symbols are deterministic SVGs in the existing menu icon style, with no new raster generation.
Tests cover retained wheel identity during a turn, selection markers, larger central cards, preview-only card
clicks, disabled future classes and returning to the Skins tab. English and 1280×720 Japanese captures review the
roster and carousel; the Spells capture reviews the wider rehearsal controls.

Carousel refinement validation: all 296 tests in 47 suites passed, with no test errors/failures/orphans; the
rendered walkthrough passed 187 actual mouse clicks. All four changed scripts pass lint/format. The existing
archive_panel.gd:130 repository lint violation and intermittent engine exit resource warnings remain.
