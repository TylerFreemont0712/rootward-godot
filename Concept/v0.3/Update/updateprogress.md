# Lanternroot update progress — 2026-10-10

## Goal

Continue the interrupted Lanternroot polish: make the town feel open at the wider camera distance, correct walkability
and sprite layering, improve the fit and depth of overworld art, and keep source methods attached to every new asset.
Preserve unrelated in-progress workspace changes.

## Completed

- Reworked `game/content/packs/core/overworld/maps/lanternroot.jsonc` as a 56×40 town. The lesson/save spawn at
  (37, 2) is clear after moving the blocking oak to (20, 2). The cabbage fence and crops move south one row; a gate at
  (13, 34) and path spur connect the home-side nook to the southern meadow. The player starts facing into town.
- Added `draw_layer: "ground"` for the Home rug and doormat, town steps and footbridge. `TownMapView` draws these above
  terrain but below walkers. The same layer now keeps five passable tufts and two mushroom clumps beneath walkers; the
  strict map schema only accepts the supported `ground` layer.
- Set the outdoor logical view to 480×270 at 1920×1080 (twice the former width and height) with integer 4× pixel
  scaling. Interior maps use a 2× camera zoom to preserve their earlier framing.
- Compacted the pause menu with shorter rows, narrower columns, a smaller portrait and tighter spacing.
- Added the opt-in imagegen candidate promotion path. The validator restricts candidates to the candidates directory
  and checks dimensions, palette and hard alpha; an optional named Root Gate correction is separately linted.
- Promoted Root Gate imagegen candidate 3, created by ChatGPT Image Generation and processed through
  `pipeline/pixel/imagegen_candidate.py`. Two art reviews found that its central seam and latch read as a sealed
  entrance. The 1920×1080 town capture at [`2026-10-10-rootgate-imagegen-v3-town.png`](../../../shots/overworld/2026-10-10-rootgate-imagegen-v3-town.png)
  confirms the seam and canopy remain clear at runtime scale. Its original source and the superseded ComfyUI fallback
  are recorded in [`artchecklist.md`](artchecklist.md).
- Added depth to the hand-authored Home bookshelf and desk in `pipeline/pixel/sprites/props.sprite`. The shelf has a
  projecting cap, beveled rails, thicker shelf boards and contact feet; the desk has a thicker top, apron, drawer knob,
  longer legs and a small floor-contact shadow. The in-game result is shown in
  [`2026-10-10-home-furniture-depth.png`](../../../shots/overworld/2026-10-10-home-furniture-depth.png). A review
  found the existing bed and chair already read clearly at this scale. Source method and processing are listed in
  [`artchecklist.md`](artchecklist.md).
- Rebuilt the townspeople as authored 20×28 character parts instead of enlarging the former 16×24 frames. Sixteen
  assembled residents now have distinct full designs; 14 hairstyles and seven headpieces gained crown silhouettes
  and highlights, with small face and clothing details. Movement and collision stay on the 16×16 tile grid. The
  gameplay-scale town, native-scale cast and Home rug are captured in
  [`2026-10-10-town-20x28-final.png`](../../../shots/overworld/2026-10-10-town-20x28-final.png),
  [`2026-10-10-townsfolk-20x28-scale1.png`](../../../shots/overworld/2026-10-10-townsfolk-20x28-scale1.png) and
  [`2026-10-10-home-20x28-rug.png`](../../../shots/overworld/2026-10-10-home-20x28-rug.png).
- Captured the compact menu with the taller portrait at
  [`2026-10-10-town-menu-20x28.png`](../../../shots/overworld/2026-10-10-town-menu-20x28.png); the portrait and rows
  remain within the panel at 1920×1080.
- Reviewed four building replacements in town at 4× and selected the hall, archive, smithy and workshop. The hall now
  reads as a broad civic landmark without the previous top-cropped, overly tall feel; the archive and smithy match
  their 7×6 and 7×5 footprints, and the workshop is one coherent facade instead of two joined structures. The
  workshop interaction moved to its nearest centered tile `[3,4]`. The review captures are
  [`hall`](../../../shots/overworld/2026-10-10-building-hall-review.png),
  [`archive`](../../../shots/overworld/2026-10-10-building-archive-review.png),
  [`smithy`](../../../shots/overworld/2026-10-10-building-smithy-review.png) and
  [`workshop`](../../../shots/overworld/2026-10-10-building-workshop-review.png). Original sources, processing and
  the previous runtime PNG fallbacks are recorded in [`artchecklist.md`](artchecklist.md).
- Refined the hand-authored woodpile cut ends with warm wood colors and varied growth rings. The 32×16 silhouette
  remains compact; the 4× town capture is [`2026-10-10-woodpile-depth.png`](../../../shots/overworld/2026-10-10-woodpile-depth.png).

## Remaining note

- The workshop is six tiles wide, so its centered doorway falls between columns 2 and 3. The nearest interaction cell
  is `[3,4]`; a player at that cell stands 8 logical pixels right of the door center. The 4× approach capture still
  reads naturally. Revisit the art offset only if playtesting makes that half-tile difference distracting.

## Verification

- `pipeline/.venv/bin/python pipeline/pixel/build.py` promoted the four selected building candidates and Root Gate v3,
  rebuilt 52 character parts, 39 props, 17 portraits, terrain and Hotaru, and finished with `lint: clean`.
- `pipeline/.venv/bin/python -m unittest discover pipeline/pixel` passed all 20 tests.
- `scripts/test.sh -a res://test/content/overworld_content_test.gd` passed all 9 content cases, including the updated
  workshop door cell and all map bounds/starts.
- SHA-256 checks confirmed the installed hall, archive, smithy and workshop PNGs exactly match their selected candidates.
- The bookshelf, desk and woodpile targeted prop builds passed pixel lint; `git diff --check` also passed.
- Godot parsing previously passed for `overworld.gd`, `pixel_view.gd` and `pause_menu.gd`. The captures in
  `shots/overworld/` cover the town square, compact menu, Home rug, guild hall approach, Root Gate, town cast and
  updated Home furniture.
- The wider town captures naturally crop peripheral scenery as the camera follows the player; the dedicated guild-hall
  and Root Gate views show those assets at approach scale.
- ComfyUI could not reach the NVIDIA driver earlier in this pass, so new building work uses the documented ChatGPT
  Image Generation candidate path where appropriate. No Blender session was run.
- The worktree contains unrelated existing changes. Do not stage or revert them as part of this pass.

## Next handoff

No blocking work remains. Keep intentional eaves, chimneys, shrine finial, Root Gate roots and Lantern Tree canopy
overhangs as documented. A later art pass can use this folder to record any newly found in-game issue and its source
method.
