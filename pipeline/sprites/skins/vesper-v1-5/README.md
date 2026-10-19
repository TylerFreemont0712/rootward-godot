# Vesper 1.5

Selectable skin id: `vesper-v1-5`. This is a repair copy of original **Vesper**, independent of VesperV2.0.
Original Vesper and VesperV2.0 remain available. Runtime sheets are in `game/assets/sprites/vesper-v1-5/`.

## Preserved

- Original 400 × 350 cells, eight columns, frame counts, FPS, loop/return settings, cast release frame, phases,
  hand tracks, effect colors, figure scale, baseline and center.
- Original navy hat, gold band/crescent, purple blunt bob, plum capelet, teal dress, tights and brown boots.
- `idle-breathe.webp` and `profile.png` are copied byte for byte. The wardrobe portrait is a copy of Vesper's.
- All frame cells outside the repair ranges below retain the original artwork. No whole-clip redraw or new poses.

## Repairs

Frame numbers are zero based and match the preview slider.

| Animation | Frames repaired | Visible defect |
| --- | --- | --- |
| Cast | 14–19 | Smeared raised hand, face/hat and doubled contours |
| Cast | 20–25 | Hat ornament changes/duplicates, wrong boots and malformed fingers |
| Cast | 40–46 | Smeared or doubled hands during return to neutral |
| Hurt | 2–18 | Extra elongated forearms, missing/warped short capelet, clipped hat and smeared transitions |

The built-in ChatGPT imagegen tool edited five damaged key poses, using the original frames and neutral sprite
as references. The exact inputs, outputs and prompts are in `repairs/`:

- `cast-016-original.png` → `cast-016-edited.png`; `cast-016-prompt.txt` and `cast-016-hat-prompt.txt`.
- `cast-020-original.png` → `cast-020-edited.png`; `cast-020-prompt.txt`.
- `hurt-003-original.png` → `hurt-003-edited.png`; `hurt-003-prompt.txt`.
- `hurt-008-original.png` → `hurt-008-edited.png`; `hurt-008-prompt.txt`.
- `hurt-017-original.png` → `hurt-017-edited.png`; `hurt-017-prompt.txt`.

The packer scales these single-frame edits to the original figure height and aligns them by the boots, retaining
the existing pose placement. A small margin repairs the clipped hat. RIFE interpolates between repaired keys and
healthy original neighboring frames. Only damaged frame cells are replaced; all healthy frames remain original.
The last cast return span reuses healthy original casting poses in reverse order, avoiding the original smeared
hands and the artifacts introduced by interpolating that return. It needs no generated key pose.

`repairs/changed-frames.json` records the exact replaced cells. The animations retain 32 idle, 49 cast and 21 hurt
frames. This replaces 36 of the 102 animation frames; 66 retain their original artwork.

## Rebuild and review

Run from the repository root with ComfyUI on port 8188:

```sh
godot --headless --path . --script pipeline/sprites/repair_vesper.gd
pipeline/.venv/bin/python pipeline/sprites/repair_vesper.py
godot --headless --path . --script pipeline/sprites/repair_vesper.gd -- --finish
godot --headless --path game --editor --import --quit
```

The existing RIFE/toon-matte workflow restores clean alpha after interpolation. Prepared repair keys, finished
interpolation and individual frames are cached under `pipeline/cache/sprites/vesper-v1-5/`.

Open `preview.html` for synchronized original/repair playback at the same timing, with pause, speed and frame
controls. Its frame label indicates whether a frame was repaired or retained. The preview manifest is generated
by the final packing step. The repaired skin is available in the wardrobe, Artificer class and profile avatar picker.
