# VesperV2.0

Separate selectable skin id: `vesper-v2`. Original Vesper remains available. Finished assets are in
`game/assets/sprites/vesper-v2/`, with transparent **640 × 560** cells and eight columns in lossless WebP.
Her nose and gaze face the enemies on screen right. The full wardrobe portrait remains the copied Vesper portrait.

## Current touch-up

The built-in ChatGPT imagegen tool supplied the portrait-inspired anime artwork and the corrected poses.
`imagegen/touch-up/` stores the new sheets and the exact prompts:

- `neutral.png`: the approved neutral model used as the identity, proportion and palette reference.
- `hurt.png` / `hurt.txt`: redrawn from the neutral model, rather than the previous hurt sheet with its enlarged head.
  Recoil is conveyed mainly through shoulders, a hand and expression; the torso and legs retain the base proportions.
- `cast-start.png` / `cast-start.txt`: forward casting poses using the neutral model's navy/plum, purple and teal colors.
- `cast-anticipation.png` / `.txt`: two additional belt/chest poses of the correct casting arm. These replace the
  arm-switching candidates in the larger sheet. `cast-start-arm-fix.txt` records the earlier attempted correction.
- `idle-rest.png`, `idle-inhale-1.png`, `idle-inhale-2.png`: three frames from the beginning of the approved breathing
  pass, reused for a much smaller breathing arc. No full sway, long blink or large skirt movement remains.
  `idle-breathe.png` / `.txt` preserve an attempted redraw; the finished idle uses the three restrained frames above.
- `*-matte.png`: the existing toon matte workflow's cleaned transparent cutouts. Candidate sheets are retained
  for comparison and are not used by the current build.

The importer registers each drawing by its hat/head component, excluding a raised hand. It holds the head scale
at 208 pixels, preserves the upper 180 pixels and normalizes the torso/leg region to the common figure height.
This corrects proportions instead of enlarging the whole sprite when a torso is compressed. Boots share a fixed
baseline. All clips start and finish in the same neutral pose.

Casting includes neutral, belt, chest, cheek, half extension, release and hold; recovery follows the same path
in reverse. This keeps one arm and one palette throughout, with no skipped anticipation or recovery stage.
The installed RIFE v4.26 model provides the intermediate frames. The existing toon matte restores clean alpha.

| Clip | Frames | Rate | Behavior |
| --- | ---: | ---: | --- |
| Breathing | 64 | 24 fps | Restrained 2.67-second loop, using only the first quarter of the original inhale |
| Casting | 57 | 64 fps after release | Release at 380 ms; full clip about 0.96 seconds |
| Hurt | 29 | 24 fps | Consistent head/body proportions, compact recoil and recovery |

Palm coordinates and cast phases are updated for the new sequence. Spell effects retain Vesper's theme and
the stage's release timing remains 380 ms.

## Rebuild

Run from the repository root, with ComfyUI on port 8188:

```sh
pipeline/.venv/bin/python pipeline/sprites/interpolate_imagegen.py --matte-sources cast-start hurt cast-anticipation
godot --headless --path . --script pipeline/sprites/import_imagegen_hq.gd
pipeline/.venv/bin/python pipeline/sprites/interpolate_imagegen.py
godot --headless --path . --script pipeline/sprites/import_imagegen_hq.gd -- --finish
godot --headless --path game --editor --import --quit
```

Selected keys, interpolated sheets and individual finished frames are cached in
`pipeline/cache/sprites/vesper-v2/touch-up/`. `--inspect` on the Godot importer creates transparent pose contact
sheets for visual review. The original high quality generation sources and prompts remain in
`imagegen/high-quality/`; first polish sources remain in `imagegen/`. Their caches remain in
`pipeline/cache/sprites/vesper-v2/high-quality/` and `pass-1/`.

Open `preview.html` for synchronized animation playback with pause, speed and frame controls. It compares the
touch-up with the previous VesperV2.0 by default, using locally preserved assets in
`pipeline/cache/sprites/vesper-v2/before-touch-up/`. Select Original Vesper for the original skin; that also serves
as the fallback when the previous revision's cache is unavailable. `preview-manifests.js` is regenerated when
packing so each version plays with its actual frame dimensions and timing.

The copied ComfyUI rig and animation definitions are retained for later experiments. The generic builder uses
its own cache; use the commands above for this artwork revision.
