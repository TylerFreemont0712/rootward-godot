# ADR-0063: Lanternroot's cast as ComfyUI sprite sheets, from one shared Blender body

Accepted 2026-10-13. Builds on ADR-0061 (the overworld and its parts) and ADR-0062 (25 x 35 characters).

## Context

The overworld's characters were 25 x 35 sprites stacked from hand-placed parts. The player wanted more detail and
animation, and chose ComfyUI's anime pixel look over a Blender look (`Concept/v0.3/animation/`). A first sheet took its
front view from a ComfyUI text-to-image render and its back and side from restyled Blender turns. The player rejected the
front: its proportions did not match the other three views. They asked for every view to share one set of proportions,
a pipeline set up properly, and sheets for the whole cast. For now a sheet needs up, down, left and right, standing still
(stop) and idling.

Nothing installed keeps one character the same across views by itself: no image-edit model and no IP-Adapter, only the
SDXL checkpoints, the Pixel Art XL LoRA and an OpenPose ControlNet.

## Decision

- **One body, built in code.** `pipeline/animation/blender_cast.py` builds every character on the same body (legs, arms,
  head, face) and adds blockout shapes for its parts: six outfits, six hair styles, six hats, three faces and three
  items, which is every part the cast wears. A part with no blockout is an error. Colours come from the look's palette
  ramps, so the blockout is already in the character's colours.
- **Turns, then a restyle.** Blender renders each character from the front (0 degrees), the left (-90) and the back
  (180) through one orthographic camera, 3.0 units tall with the ground at a fixed row. ComfyUI restyles each turn by
  img2img at denoise 0.7 (Nova Anime XL with the Pixel Art XL LoRA), with a prompt built from the look's parts and a
  one-line description of the person from their portrait. Right is left, mirrored.
- **Proportions are held, not hoped for.** Of two candidates per view, the one whose outline overlaps the turn's most
  (IoU) is kept, and its outline is cut back to the turn's, grown by 24 render pixels (one sprite pixel at 32 x 48). The
  sprite cut is *registered*: the whole camera frame goes down to the sprite frame, with no crop or fit per frame. So
  every view and every character keeps the model's scale, and the feet sit on the same row (46 of 48).
- **The sheet.** Two columns (stop, idle) by four rows (down, up, left, right), 32 x 48 frames in the game. Idle is the
  stop frame with the body settled one pixel (`generate.breathe`), so it is the same drawing. The frames are locked to
  the character's own ramps in `palette.json`. Larger cuts (48 x 72, 64 x 96) are made for review.
- **Keyed by look, with parts as the fallback.** `game/assets/overworld/cast/cast.json` records the look each sheet was
  made from. `OverworldArt.character(look)` draws a cast sheet when one was made for that exact look; any other look is
  built from parts as before. Looks match by what they show: an unused part and a colour at its default are not
  differences. A townsperson whose look changes falls back to parts until `scripts/cast.sh` makes a new sheet, so no
  stale art is ever drawn. The player gets the start look's sheet while their look is the start look.
- **The walker reads the layout.** `CharacterSheet` holds a sheet's frame, ground row, rows and columns. `Walker` draws
  either layout. Standing still on a sheet with an idle frame it breathes (1.6 s, the last 40 % settled), each figure
  from a phase set by where it stands. A step shows the idle frame, so a walk bobs.
- **Data and stages.** `pipeline/animation/cast.json` holds the camera, views, layout, the restyle and the prompt words.
  The cast is the townsfolk in the content plus the player's start look. The stages are `scripts/cast.sh turns` (Blender,
  ComfyUI down), `restyle` (ComfyUI), `sheets` (no GPU) and `check`. Each stage is cached; a changed look or prompt
  renders again by itself.

## Alternatives

- **Text-to-image per view.** Rejected: the first sheet showed a front whose head, body and hem differed from its side
  and back.
- **Blender only.** Rejected by the player: flatter and more toy-like than ComfyUI.
- **Fitting each frame to its own bounding box.** Rejected: it stretches every view to the cell, so a hat or a lower
  head changes the scale, and the feet move between frames.
- **A true right view instead of a mirror.** Possible later: a held item swaps hands in the mirror. It is one more turn
  and restyle per character.

## Consequences

- Sixteen townspeople and the player's start look have sheets. The parts system, the character creator and its
  previews are unchanged.
- A player who changes their look in the creator is drawn from parts (the old style) until a sheet is made for that look.
  A sheet for any look can be added to `cast.json` and made with `scripts/cast.sh`. Whether the creator should change is
  the player's call.
- The 32 x 48 frame stood about 39 pixels tall in the 16 px world, against 33 before. ADR-0064 moved the world to 40 px
  tiles: the sheets are now cut at the person frame of `scale.jsonc`, 64 x 96, about two tiles tall.
- Measured on the 8 GB laptop GPU (2026-10-13): about 17 s of Blender per character for its three turns, and about 80 s
  of ComfyUI per view (two candidates), so about 4 minutes per character; all seventeen take a little over an hour.
- The first back views drew faces: the blockout's hair left the back of the head bare. Every hair style now has a nape
  (`blender_cast.py`), and the turns' cache includes a digest of the Blender code.
- Open: walking frames, a true right view, the creator.
