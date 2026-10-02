# ADR-0037: A cosmetic loadout, one figure height, and a rehearsal at fight scale

Accepted 2026-10-02.

## Context

The player wants as much customisation as possible on what is seen most: the moves and the spells, not only the
skin. A cast had one look: the snap or the push, the codex circle, the lance (an orb when strong) and blocks of
code falling on each foe. The player asked for the spell to be split into the circle the caster writes, the bolts
thrown at the foes, and the heavy blow that falls on them, and for three or four new animations in the game's
theme. They also found the 3D skins drawn larger than Vesper in a fight and not the same size as each other
(their models measure 1.39 to 1.75 m and all shared one 2.4 m camera; Vesper's view was a smaller share of the
arena than theirs), and the Character room not showing a skin, its circles and its spells as a fight does.

## Decision

- **One figure height.** Every skin's view takes `HeroView.VIEW_SHARE` of the arena, and its figure (head, hair, hat
  or ears to soles) is fitted to `FIGURE_SHARE` of it, which is Vesper's height as drawn before. A 3D skin's height is
  measured from its meshes in the rest pose (`StageCharacter.stature`) and its orthographic camera is sized to it; a
  drawn skin's is measured from its idle's first frame (`SpriteCharacter.stature`) and its frames are drawn at the
  fill that makes it so. Circles, the ward, the ground sigil and the shard flourish are sized by the figure
  (`figure_height`, `circle_radius`), so they keep their size against any skin. A cast that ends on the floor stands
  its circle on the floor.
- **A loadout of six slots** (`content/cosmetics.jsonc`): `idle`, `cast_light`, `cast_heavy`, `circle`, `bolt` and
  `impact`, each a list of options whose first is the default (the look the game had). `CosmeticRules` (pure) fills a
  saved loadout's missing or unknown choices with defaults and picks a move's clip, falling back to the skin's own
  when it cannot play it (Vesper's drawn clips, Emberfox's own). The loadout is saved in `settings.json` and with the
  profile (`profile.loadout`, beside `avatar`). Names and notes are content, translated through the Japanese overlay.
- **What each slot changes in a fight**: the idle a 3D skin returns to (`StageCharacter.idle_clip`), the clip played
  for a light or a heavy cast (any clip with a release is a cast; a heavy one may bring `-hold` and `-end`), the
  MagicCircle style (`codex`, `rootglass`, `clockwork`, `constellation`, drawn by `CircleStyles` on the same disc,
  timing and runes), the bolt's sheet, strong sheet and path (`arc`, `straight`, `spiral`), and the sheet a heavy
  cast's first blow on each foe arrives as (`hit-heavy`, `hit-starfall`, `hit-roots`, `hit-pillar`).
- **New assets**: four moves built by the move pipeline on CC0 capture (Lantern Bearer on `Idle_Torch_Loop`, Rune
  Trace keyed over the idle, Skyward Call over the simple spell, Root Seal on `Fixing_Kneeling` with the feet
  unplanted while kneeling), and four code-drawn spell sheets (`bolt-thorn` and the three impacts), each impact on
  the falling code's ground line and beat so it shares its sound.
- **The rehearsal is a fight stage.** The practice ring is a real `BattleStage` with `local_clock` on: its waits poll
  a clock of its own, its effects take a `time_scale`, its tweens are tracked and given its tempo (or a
  `custom_step` for a frame step), and the skin's pose is stepped by hand at a scaled time. A test cast is a made-up
  log played by the fight's own `LogPlayer` against practice wisps of 999 health that are made whole after each
  cast. Its shape is wider than square (sizes come from its height, as in a fight) and it spreads its foes further.
  `Engine.time_scale` stays untouched; hit-stop is skipped on a rehearsal stage.
- **Carousels**: Moves (idle, light, heavy) and Spells (circle, bolt, impact) each show a slot as a wheel like the
  skins'. The centre card plays its preview live (the circle written by MagicCircle, a bolt's or an impact's sheet;
  a move's picture of the motion dummy from `tools/move_thumbs`), and browsing tries the option on the practice ring
  at once and shows it off. Only *Wear this* saves it. Options a skin cannot play are marked "3D skins".

## Consequences

Customisation is data: a new option is a line of JSONC (and its sheet, clip or style); a new circle style is a
drawing in `CircleStyles`. The fight is unchanged when nothing is worn. The rehearsal now shows exactly the fight's
proportions, but its arena is narrower than a fight's, so foes stand closer than they would; foes' own small tweens
(recoil, lunge) run at real time in slow motion. The zoom and contrast options of ADR-0036 are replaced by the arena
backdrop toggle and floor/height guides, since a zoomed skin would no longer be at fight scale.

Writing the tests exposed two older suites saving the player's real `user://settings.json` (booting points saving
there; choosing a profile saves): they now save into their test folders.
