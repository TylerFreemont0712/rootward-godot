# ADR-0071: Complete player sheets with authored movement

Accepted 2026-10-17. Builds on ADR-0064's 40 px world and 64 x 96 people; supersedes the temporary player rollback
described in ADR-0065.

## Context

The layered prototype produced overlapping faces and hair and unreliable walking. The temporary rollback restored a
single sprite, but its 25 x 35 art did not match the townspeople. The player requested complete higher-quality sheets
with walking and idle in four directions, then limited appearance selection to male or female until a later pass.
The commander also needed to resemble the existing portrait.

## Decision

- The player has two complete sheets, `game/assets/overworld/player/male.png` and `female.png`. Every frame contains
  the entire figure, including its face, hair and clothes. There is one runtime sprite per character.
- `player.json` declares 64 x 96 frames, ground row 93, four directional rows, four idle columns and eight walk
  columns. Clips support explicit frame durations or a frame rate. Idle includes a short blink; walking runs at 12 fps
  after the player's pacing feedback, with 0.22-second tile travel.
- `OverworldArt.player_character` selects these sheets independently of the legacy NPC part composer. Old saved
  appearance dictionaries resolve to male without changing their other progress. Missing art uses the native-size
  plain-figure fallback. The player never uses the retired 25 x 35 parts or the old cast `player.png`.
- Creation asks for a name, male or female, and the existing Builder/Scribe play style. Appearance saves only
  `{"model": "male"}` or `{"model": "female"}`. Colour, part and accessory controls are removed.
- The movement clip has its own clock, carried across consecutive grid steps. A tile arrival does not restart the
  gait or insert a standing frame. Stopping settles into idle; reduced motion freezes the idle frame.
- Artwork comes from built-in OpenAI image generation, authorized by the player. Sources, selected prompts and a
  playable review are in `Concept/v0.3/animation/player/`. `game/tools/import_player_sheets.gd` registers the frames
  from `pipeline/animation/player_sources.json`, using one scale per directional source and a fixed head center and
  ground row. Frame poses retain their relative sizes. The source manifest records any direction corrections.
- Sergeant Brisk is the commander used for this pass: the replacement follows the portrait's silver swept hair,
  narrow face and steel armor. The portrait stays the reference. `authored_sheet` in the cast configuration protects
  the replacement from older cached restyles; the source importer rebuilds it.

## Alternatives

- Reusing the old cast player's two poses lacks authored limb movement.
- Returning to the layer prototype would repeat its unresolved face and motion problems.
- Keeping legacy appearance controls would promise combinations for which no matching animation exists.

## Consequences

Customization can return once complete, aligned art is available. Current inventory items do not change the player's
appearance. NPCs keep their existing exact cast sheets and legacy fallback. The new clip layout is reusable for future
authored NPC animations without adding runtime body layers.
