# Lanternroot art checklist

Art changed or prepared during the 2026-10-09 and 2026-10-10 Lanternroot updates is listed here so source and treatment stay attached to the image.
For each future art change, add the asset path, creation method, source references or prompt, any palette/size cleanup,
and its acceptance status.

## This update

| Art/output | Created by / source method | Processing | Status |
|---|---|---|---|
| `game/assets/overworld/buildings/rootgate.png` (preserved fallback) | Original ComfyUI Root Gate render from the manifest/cache (`ow-landmark-rootgate`; seed, pick and prompt remain in `pipeline/pixel/manifest.json`) | When no imagegen override is approved, `pipeline/pixel/build.py` applies the deterministic Pillow face overlay in `pipeline/pixel/landmarks.py`. The original cached render and this fallback treatment remain available. | Not the current runtime image; candidate v3 is selected below. |
| `Concept/v0.3/Update/art-source/rootgate-chatgpt-imagegen-2026-10-09.png` | ChatGPT Image Generation, first pass, using the current Root Gate, Home and Archive as visual references; requested a sealed root-and-stone threshold in the existing pixel style. | Original 1254×1254 transparent PNG retained unchanged. | Source for review candidate 1; not a runtime asset. |
| `Concept/v0.3/Update/art-source/rootgate-chatgpt-imagegen-2026-10-09b.png` | ChatGPT Image Generation, revision of candidate 1 with the current Root Gate as a style reference; prompt emphasized a brighter one-pixel seam, broader pixel clusters and fewer small details. | Original 1254×1254 transparent PNG retained unchanged. | Source for review candidate 2; not a runtime asset. |
| `pipeline/pixel/candidates/ow-landmark-rootgate-imagegen.png` | ChatGPT Image Generation candidate 1, from the source above. | `pipeline/pixel/imagegen_candidate.py` resolves `ow-landmark-rootgate` in the manifest and calls `pipeline/art/generate.py` sprite processing: crop/fit to 96×96, quantize to 26 colors, hard alpha, ink outline, then lock to `pipeline/pixel/palette.json`. | Review-only. Pixel lint passes; its center seam loses too much contrast at target size. |
| `pipeline/pixel/candidates/ow-landmark-rootgate-chatgpt-v2.png` | ChatGPT Image Generation candidate 2, from the `...2026-10-09b.png` source above. | Same manifest-driven processing through `imagegen_candidate.py`; 96×96, 26 colors, hard alpha, outline and shared palette lock. | Review-only. Pixel lint passes; the brighter seam survives better, but requires an in-game scale review before acceptance. |
| `Concept/v0.3/Update/art-source/rootgate-chatgpt-imagegen-2026-10-09c.png` | ChatGPT Image Generation revision c. | Original 1254×1254 transparent PNG retained unchanged. | Source for review candidate 3. |
| `pipeline/pixel/candidates/ow-landmark-rootgate-chatgpt-v3.png` | ChatGPT Image Generation candidate 3, from the source above. | `pipeline/pixel/imagegen_candidate.py` applies the manifest-driven 96×96 processing: 26 colors, hard alpha, ink outline and shared palette lock. | Approved by Rootward art review on 2026-10-09 and confirmed in town at 4× on 2026-10-10 (`shots/overworld/2026-10-10-rootgate-imagegen-v3-town.png`). Selected in the manifest and rebuilt to the runtime image; no additional clasp correction is set because v3 already has a clear seam and latch. |
| `game/assets/overworld/characters/*.png` | Authored pixel-art edits by the visual-review agent on 2026-10-10 in `pipeline/pixel/sprites/*.sprite`; no imagegen or ComfyUI source. | Rebuilt by `pipeline/pixel/build.py` / `pixelkit` at native 20×28 character-part scale with the shared palette and hard alpha; the sprites are not resampled. Movement and collision remain 16×16 tiles. | Sixteen complete townspeople; 20 pixel pipeline tests pass. Reviewed at gameplay scale in `shots/overworld/2026-10-10-town-20x28-final.png` and native scale in `shots/overworld/2026-10-10-townsfolk-20x28-scale1.png`. |
| `game/assets/overworld/props/bookshelf.png` | Hand-authored pixel-art edit by Codex on 2026-10-10 in `pipeline/pixel/sprites/props.sprite`; no imagegen or ComfyUI source. | `build_props(Palette.load())` in `pipeline/pixel/build.py` rebuilt the 32×32 sprite with the shared palette and hard alpha. The edit adds a projecting cap, inset side rails, three thicker shelf boards, feet and floor-contact pixels. | Reviewed in the 1920×1080 home capture `shots/overworld/2026-10-10-home-furniture-depth.png`; `pipeline/pixel/build.py --lint` passes. |
| `game/assets/overworld/props/desk.png` | Hand-authored pixel-art edit by Codex on 2026-10-10 in `pipeline/pixel/sprites/props.sprite`; no imagegen or ComfyUI source. | `build_props(Palette.load())` rebuilt the 32×24 sprite with the shared palette and hard alpha. The edit clarifies the tabletop plane and underside, adds an apron/drawer and small steel knob, and extends the legs to floor contact with a compact shadow. | Reviewed beside the updated bookshelf in `shots/overworld/2026-10-10-home-furniture-depth.png`; `pipeline/pixel/build.py --lint` passes. |
| `game/assets/overworld/props/woodpile.png` | Hand-authored pixel-art refinement by Codex on 2026-10-10 in `pipeline/pixel/sprites/props.sprite`; no imagegen or ComfyUI source. | Targeted `build_props(Palette.load())` rebuilt the native 32×16 sprite with the shared palette and hard alpha. The staggered pile silhouette stays intact; cut-face colors now use the wood ramp with nested growth-ring pixels instead of the dirt ramp. | Reviewed at 4× in the town capture `shots/overworld/2026-10-10-woodpile-depth.png`; the capture was made while building-fit candidates were temporarily active. `pipeline/pixel/build.py --lint` passes. |
| `game/assets/overworld/props/*.png` | Hand-authored props in `pipeline/pixel/sprites/props.sprite`. | Rebuilt by `pipeline/pixel/build.py` / `pixelkit`, using declared frame sizes and the shared palette. | Generated outputs; source edits are retained in `props.sprite`. |
| `game/assets/overworld/tiles/terrain.png` | Procedural pixel art in `pipeline/pixel/terrain.py`. | Rebuilt by `pipeline/pixel/build.py`; dual-grid layout and palette are checked by pixel lint. | Generated output; source is `terrain.py`. |
| 18 outdoor overlays in `game/assets/overworld/tiles/terrain.png` | ChatGPT Image Generation source atlases for brick, stone and wood paths plus root floor, fern moss and glow moss; prompts in `art-source/land-variants-imagegen-2026-10-19.md`. | `pipeline/pixel/terrain.py` reduces each swatch to 40×40, locks its material palette, and builds stable variants with connected exposed-edge masks. | Rebuilt and palette-linted; source images are retained in `art-source/`. |

## 2026-10-13: the animation base (candidates, not runtime assets)

Candidates for animating the character at larger sizes (`Concept/v0.3/animation/README.md`, `pipeline/animation/`). None is
in `game/assets/`; the player chooses one before anything is wired in.

| Art/output | Created by / source method | Processing | Status |
|---|---|---|---|
| `Concept/v0.3/animation/comfy-32x48.png`, `comfy-40x60.png`, `comfy-48x72.png`, `comfy-64x96.png`, `comfy-80x120.png` | ComfyUI, one render from the `anim-character` style in `pipeline/animation/manifest.json`: `novaAnimeXL_ilV190` with `pixel-art-xl-v1.1` LoRA (strength 1.0), 1024 px, 28 steps, cfg 5.5, euler ancestral, seed from the asset id (`anim-comfy-32x48`), BiRefNet background removal. The other four cut the same cached render (`raw_from`). | `pipeline/art/generate.py` sprite post: crop, box-filter fit to each size, largest piece kept, alpha cut 0.75, 32 colours, ink outline, lock to `palette.json` on the character ramps. | Candidate. Checked at 2x to 6x in `sheet.png`. The one-pixel shadow sliver under the right boot is left in. |
| `Concept/v0.3/animation/blender-32x48.png`, `blender-48x72.png`, `blender-64x96.png` | Blender 5.2 (headless, Cycles CPU, orthographic front view) of the model built in code by `pipeline/animation/blender_base.py` at detail low, standard and detailed. No imported or generated 3D assets. | Rendered 800 x 1200 with a transparent background, then the same cut as the ComfyUI set. | Candidate. |
| `Concept/v0.3/animation/models/anim-blender-*.blend` | The three models above, saved from `blender_base.py`. | None. Each part is a named object. | Candidate models for posing and rendering frame by frame. |
| `Concept/v0.3/animation/sheet.png` | `scripts/animation.sh sheet` over the eight sprites above. | None. | Review sheet only. |
| `Concept/v0.3/animation/views/`, `sheets/` (removed) | The first sprite sheet: a ComfyUI text-to-image front with restyled Blender turns for back and side. | Superseded the same day. | Rejected by the player: the front's proportions did not match the other views. The files were deleted; the cast below replaces them. |
| `game/assets/overworld/cast/<id>.png` (16 townspeople and `player`, the start look) and `cast.json` | `pipeline/animation/cast.py` (ADR-0063): a Blender blockout on one shared body per look (`blender_cast.py`), turned to front, left and back; ComfyUI img2img at denoise 0.7 (`novaAnimeXL_ilV190` + `pixel-art-xl-v1.1`, two candidates per view, seeds from `cast-<id>-<view>`), prompts from `cast.json`. | The candidate whose outline best matches the turn (IoU) is kept and held to the turn's outline; a registered cut of the whole camera frame to 32 x 48, shared colours, ink outline, lock to the character's ramps. Right mirrored from left; idle by `generate.breathe`. | Shipped game assets (drawn by `OverworldArt.character`; parts are the fallback). Picks and scores in `Concept/v0.3/animation/cast/picks.json`; reviews in `Concept/v0.3/animation/cast/`. |

## Existing art provenance

The current building and tree family is represented in `pipeline/pixel/manifest.json`; its entries hold ComfyUI prompts,
fixed seeds, selected candidate indices, output sizes and palette-lock settings. This update did not regenerate those
building PNGs through ComfyUI. The NVIDIA driver was unavailable, so the offline source build and the approved
ChatGPT-candidate route were used instead. Do not attribute the other already-present PNGs to this pass.

Portrait PNGs copied from `Concept/v0.3/Townspeople/` retain their source files there; their original creation method
was not recorded in this handoff. Record it only when that source history is confirmed.

## Approved imagegen promotion

Imagegen candidates stay review-only under `pipeline/pixel/candidates/`. After town-scale review and explicit approval,
set the matching manifest asset's `approved_imagegen_candidate` to an object containing the candidate `path`, original
`source`, processing `method`, and dated `approval`; the build checks the candidate path, declared sprite dimensions,
shared palette, and hard alpha before copying it to the manifest output. An optional named `correction` is applied by
`pipeline/pixel/landmarks.py` and linted again before promotion; `rootgate_lattice_clasp_v1` adds a compact clasp and seam
to the imagegen lattice without the full face overlay. Run `scripts/pixel.sh` to build and promote.
To withdraw an override, set the field to `null`, retain the candidate and provenance, then run
`scripts/pixel.sh --comfy '<asset-id>'` to regenerate the normal ComfyUI output. Do not use `--comfy` while an override is
set, because the approved candidate is applied after generation. Keep provenance and review outcome in this checklist.

For the Root Gate, the manifest points to candidate 3 with its original source, processing method and dated art-review
approval. Candidate 1 and 2 remain review-only. The `rootgate_lattice_clasp_v1` preview was applied to temporary copies
of candidates 2 and 3 only; it passes palette/alpha lint but should not be layered over v3 because v3 already has a clear
seam and latch.

## Building fit studies — 2026-10-10

The town screenshot and map audit found the guild hall too tall for its 9×8 footprint, with the archive and smithy also
overhanging their footprints. The current workshop art read as two attached buildings. These ChatGPT Image Generation
studies were reviewed in-world at 4× and selected for the building fit pass. Prior runtime PNGs are preserved as
rollback references in `art-source/`; the original imagegen source PNGs remain unchanged there too.

| Candidate/source | Creation direction | Processing and fit review | Status |
|---|---|---|---|
| `pipeline/pixel/candidates/ow-building-hall-chatgpt-v2.png` from `Concept/v0.3/Update/art-source/guildhall-chatgpt-imagegen-2026-10-10b.png` | ChatGPT Image Generation using the existing hall, home and archive as style references; broad two-story guild hall, plum roof, compact central clock gable, centered door, no tower. | `pipeline/pixel/imagegen_candidate.py --asset-id ow-building-hall` uses the manifest's 144×128 target (the 9×8 map footprint), 30 colors, hard alpha, ink outline and `pipeline/pixel/palette.json` lock. Opaque bounds are `(0,18)-(143,127)`; the entrance aligns with `[4,7]`. | Approved after 4× town review; selected at `game/assets/overworld/buildings/hall.png`. The view is [`2026-10-10-building-hall-review.png`](../../../shots/overworld/2026-10-10-building-hall-review.png). The separate `ow-building-hall-chatgpt-wide-study.png` leaves 41 transparent top rows and was retained only as a too-squat comparison. |
| `pipeline/pixel/candidates/ow-building-archive-chatgpt-v1.png` from `Concept/v0.3/Update/art-source/building-archive-chatgpt-imagegen-2026-10-10.png` | ChatGPT Image Generation using the current archive, hall and home as references; broad stone-and-timber archive, blue slate roof, restrained dormers, open-book crest and centered arched entrance. | Manifest target is 112×96 to match the 7×6 footprint. The processor applies crop/fit, bottom-center anchoring, 28-color quantization, hard alpha, ink outline and shared-palette lock. Opaque bounds are `(0,24)-(111,95)`; the entrance aligns with `[3,5]`. | Approved after 4× town review; selected at `game/assets/overworld/buildings/archive.png`. See [`2026-10-10-building-archive-review.png`](../../../shots/overworld/2026-10-10-building-archive-review.png). |
| `pipeline/pixel/candidates/ow-building-smithy-chatgpt-v1.png` from `Concept/v0.3/Update/art-source/building-smithy-chatgpt-imagegen-2026-10-10.png` | ChatGPT Image Generation using the smithy, hall and archive as references; broad low forge with stone and timber walls, integrated compact chimney, warm forge bay, small anvil and centered door. | Manifest target is 112×80 to match the 7×5 footprint. The processor applies crop/fit, bottom-center anchoring, key-light cleanup, largest-component retention, 28-color quantization, hard alpha, outline and shared-palette lock. Opaque bounds are `(0,19)-(111,79)`; the entrance aligns with `[3,4]`. | Approved after 4× town review; selected at `game/assets/overworld/buildings/smithy.png`. See [`2026-10-10-building-smithy-review.png`](../../../shots/overworld/2026-10-10-building-smithy-review.png). |
| `pipeline/pixel/candidates/ow-building-workshop-chatgpt-v1.png` from `Concept/v0.3/Update/art-source/building-workshop-chatgpt-imagegen-2026-10-10.png` | ChatGPT Image Generation using the current workshop, hall and smithy as references; one broad teal-roofed tinker's facade with a gear gable, compact telescope, workbench windows and a centered door, with no detached second structure. | Manifest target is 96×80 to match the 6×5 footprint. The processor applies crop/fit, bottom-center anchoring, 26-color quantization, hard alpha, ink outline and shared-palette lock. The door center is x=48, between tile columns 2 and 3; the map interaction uses nearest-center cell `[3,4]` (x=56), 8px from the sprite center. | Approved after 4× town review; selected at `game/assets/overworld/buildings/workshop.png`. See [`2026-10-10-building-workshop-review.png`](../../../shots/overworld/2026-10-10-building-workshop-review.png). |

The manifest now records the selected candidate, original source, processing method and dated approval for all four
buildings. Their pre-imagegen runtime PNGs are retained as `pre-imagegen-{hall,archive,smithy,workshop}-runtime-2026-10-10.png`
in `art-source/`. Candidate generation is reproducible with
`pipeline/.venv/bin/python pipeline/pixel/imagegen_candidate.py <source.png> --asset-id <manifest-id>
--out pipeline/pixel/candidates/<candidate.png>`.

Other silhouettes were kept after the fit/door audit: cottage (+8px each axis), home, inn and shrine (+16px each), Root Gate
(+16px each) and Lantern Tree (+32px each) deliberately let eaves, chimneys, lantern finials, roots or canopy extend beyond
their walk footprints. Their entrances/trunk centers align with the declared cells. The shop's 16px roof/awning overhang is
also kept as storefront trim. No other building was resized in this pass. The staged hall source `...10-10a.png` and hall
candidate `...v1.png` are byte-identical duplicates of the selected `...10-10b.png` source and `...v2.png` output; they are
not counted as independent studies.


## Town overhaul, 2026-10-10 (Concept/v0.3/09-lanternroot-town-overhaul.md)

Every picture and sprite made in this pass. Source method and status are per row; nothing here is approved by the player
yet unless the status says so. Pictures come from ComfyUI (SDXL with the pixel-art LoRA, palette-locked, `pipeline/art/generate.py`)
or from hand-placed `.sprite` text (`pipeline/pixel/sprites/`). The sheets are in `shots/pixel/overhaul/`.

### ComfyUI pictures (manifest picks are the approval)

| Asset | Source method | Seed, candidates, pick | Processing | Status |
|---|---|---|---|---|
| `buildings/inn.png` | ComfyUI, ow-building style, re-rendered with the new prompt | 4301, 2, pick 0 | 96 x 96 (6 x 6 footprint), 26 colours, palette lock | In the game; the bowl sign reads weakly at 1x |
| `buildings/shop.png` | ComfyUI, re-rendered | 4314, 2, pick 0 | 96 x 96 | In the game; **the door sits off the centre tile**: recheck in the town shot |
| `buildings/shrine.png` | ComfyUI, re-rendered | 4315, 2, pick 1 | 96 x 96 | In the game; a pagoda, narrower than its footprint |
| `buildings/cottage-pell.png` | ComfyUI, new id | 4361, 2, pick 1 | 80 x 80 (5 x 5 footprint) | In the game; a single house, red roof |
| `buildings/cottage-seren.png` | ComfyUI, new id | 4362, 2, pick 0 | 80 x 80 | In the game; a single house, cream roof |
| `buildings/cottage-hollis.png` | ComfyUI, new id | 4363, 2, pick 0 | 80 x 80 | In the game |
| `buildings/lanterntree.png` | ComfyUI, post changed only (no render) | 4322, 2, pick 1 | 144 x 144; colours 24; wood, leaf, grass, thatch, glow, firefly, stone locked | In the game; overhangs its 5 x 4 trunk footprint by design |
| `props/well.png`, `props/stall.png`, `props/laundry.png` | ComfyUI, post changed only | 4201, 4204, 4343; pick 1 | colours and lock ramps changed | In the game |
| `props/oak.png`, `props/oak2.png` | ComfyUI, post changed only | 4205; picks 1 and 0 | colours 20; lock ramps | In the game |
| `props/haycart.png` | ComfyUI, new cached render added | 4342, 2, pick 1 | 32 x 32 | Written to the game; not placed on the map yet |
| `props/pine.png` | ComfyUI, new cached render added | 4331, 2, pick 1 | 32 x 64 | Written to the game; **weak** (a squat bush): not placed |
| `props/gate-garden` (candidate only) | ComfyUI, new id | 4352, 2, pick 1 | 32 x 32 | **Rejected**: both candidates are near-opaque squares with no walkway. The hand-placed gate is used instead. Not written to the game |

Approved and unchanged: the hall, archive, smithy, workshop and Root Gate v3 (ChatGPT candidates, see the sections above).

Renders went through `pipeline/cache/art`, which is a **symlink into `~/personal-project/ProgramMe/assets/.art-cache`**.
The new cache folders therefore live in the old repo's cache directory. Decide whether the link should stay.

### Hand-placed sprites (25 x 35 characters, outdoor props)

| Asset | Source method | Status |
|---|---|---|
| `characters/*.png` (body, 12 outfits, 33 hair/hat/face parts) | Hand-drawn text in `pipeline/pixel/sprites/{body,outfits,hair,hats,faces}.sprite` at 25 x 35, redrawn from the 20 x 28 layouts; not resampled | In the game after the 25 x 35 landing (`characters.py`, `overworld_art.gd`, walker anchor). Spiky hair follows the four-tuft sketch. Known weak spots: buns read as ears from the front; curly's back is rough; the hood from behind is bag-shaped |
| `props/*.png` outdoor props (fence, fence_v, fencepost, gate, lamppost, barrel, flowerpot, tombstone, crate, sack, sign, mailbox, signpost, banner, tuft, step, lilypad, mushrooms, rock, reeds, bench) | Hand-drawn in `pipeline/pixel/sprites/props.sprite`, 16 px footprints; standing props rise by 1.25 | In the game. `stonewall` is kept for the Old Stones garden; the map does not place it yet. Rock is 16 x 20 (the table said 16 x 16) |
| `items.sprite` (staff, book, lantern, flower, wand, watering) | Hand-drawn, re-anchored to the 25 x 35 body | In the game after the landing |

## Main home replacement, 2026-10-16

| Art/output | Source method | Processing | Status |
|---|---|---|---|
| `Concept/v0.3/Update/art-source/building-home-chatgpt-imagegen-2026-10-16.png` | ChatGPT Image Generation edit using the prior home sprite as the style/composition reference. The prompt requested a broad, low, front-facing inhabited cottage with a centered door, warm windows, timber and plaster walls, a slate-moss roof, and no detached props. | Original 1268×1241 transparent PNG retained. `pipeline/world/objects/home.jsonc` references it; `scripts/world.sh cut --only home` scales it into the 6×6/240×240 frame, applies the world palette and hard alpha, and writes the runtime sprite plus footprint review. | Review shows 94% base coverage (up from 82%). In-game front-door and behind-roof screenshots reviewed after y-sort correction; see `shots/town-collision-home-final.png` and `shots/town-collision-home-behind.png`. |

## Lantern shrine replacement, 2026-10-16

- **Source:** `art-source/building-shrine-chatgpt-imagegen-2026-10-16.png` (ChatGPT Image Generation; transparent, pixel-art shrine with a broad red roof and centered entrance).
- **Integration:** `pipeline/world/objects/shrine.jsonc` now points to the source and the world cut produces a 240×240 sprite at the existing 6×6 footprint.
- **Review:** the pipeline review cut fills 92% of the base footprint (previous asset: 45%); the entrance stays centered and the eaves fill the visual scale of neighboring buildings.
- **Collision:** map uses rows 3–5 for the lower wall/body; the upper roof remains walkable and y-sortable.

## Meadow and connected paths, 2026-10-19

- **ChatGPT Image Generation sources:** `art-source/lanternroot-meadow-flowerless-chatgpt-imagegen-2026-10-19.png`
  edits the original meadow atlas to remove flowers while preserving its grass material. Three cells replace the
  flat procedural empty variants. `art-source/lanternroot-path-continuous-chatgpt-imagegen-2026-10-19.png` provides
  one uninterrupted dirt material in the earth atlas's style. Raw sources and exact prompts are recorded in
  [land-joins-imagegen-2026-10-19.md](art-source/land-joins-imagegen-2026-10-19.md).
- **Integration:** 40 px shared-palette cuts, gradual common texture collars at actual dual-grid seams, and weathered
  path margins only at exposed boundaries. The existing sixteen masks automatically select sides, corners, ends,
  junctions and filled centers. Eight stable texture variants remain available per surface.
- **Review:** native wide and close-up screenshots at `shots/land-joins-2026-10-19.png` and
  `shots/land-joins-close-2026-10-19.png`; build lint clean, nine terrain tests and twelve GroundLayer cases pass.

## Woodland ground atlas, 2026-10-19

- **Source:** three ChatGPT Image Generation 4×4 variation sheets, each with four distinct layouts per row: `art-source/lanternroot-ground-variants-nature-chatgpt-imagegen-2026-10-19.png` (grass, dry grass, forest floor, moss), `art-source/lanternroot-ground-variants-earth-chatgpt-imagegen-2026-10-19.png` (flowers, soil, furrows, path), and `art-source/lanternroot-ground-variants-stone-water-chatgpt-imagegen-2026-10-19.png` (sand, gravel, broken cobble, water). `art-source/lanternroot-meadow-variants-chatgpt-imagegen-2026-10-19.png` remains the dedicated 4×2 sheet of eight distinct meadow flower layouts. The earlier `lanternroot-land-atlas-chatgpt-imagegen-2026-10-19b.png` is retained as the initial broad study.
- **Integration:** `pipeline/pixel/terrain.py` downsamples the swatches to 40px tiles, locks each surface to its shared palette ramps and reconciles wrapped/shared borders. Meadow keeps eight separate authored compositions; every other outdoor surface uses four authored patterns plus seeded surface marks for eight stable variants. Dry grass, water and all loose grounds now vary; cobble gains small seeded chips and cracks at random interior points. The existing dual-grid code still generates all sixteen transition shapes per overlay; water retains three ripple frames. `GroundLayer` hashes surface and map position to pick variants consistently.
- **Review:** `scripts/pixel.sh --only terrain` reports `terrain built; lint: clean`. Studio preview: `shots/land-variety/imagegen-land-surfaces-2026-10-19c.png`; the eight-by-thirteen tile contact sheet is `shots/land-variety/ground-variants-2026-10-19.png`, and the meadow patterns are enlarged at `shots/land-variety/meadow-variants-2026-10-19.png`.
- **Prompt direction:** “Production pixel-art tileset atlas for a cozy woodland-fantasy RPG; exact 4×4 equal square swatches; top-down, seamless edges; deliberately large readable pixel clusters at 40×40, low detail density and broad natural shapes. Distinct cells for grass, meadow, dry grass, woodland litter, moss, flowers, packed path, garden soil, furrows, sand, gravel, cobble, pond water, leaf litter, stepping stones and violets; warm upper-left light and a cohesive plum-outline palette.”
- **Meadow prompt:** “Exact 4×2 seamless top-down meadow tile atlas with a calm shared green base and similar simple outer edges. Make the eight centers different: scattered white/yellow daisies, a curving white/pink band, two asymmetric clusters, violet/clover corners, a broken yellow diagonal, three flower islands, one broad irregular patch with grass gaps, and mostly grass with a few larger flowers/herbs. Readable pixel clusters at 40×40; no scenery, props, characters or perspective.”
- **Variation atlas prompts:** all three requested exact 4×4 top-down rows, with four distinct but edge-compatible patterns per ground. The first grouped calm grass, straw tufts, forest leaf litter and moss clusters; the second grouped wildflowers, garden soil, horizontal seed furrows and packed path; the third grouped pale wind-rippled sand, loose gravel, fitted cobbles with randomly placed chips/cracks, and pond water with different ripple and glint patterns. Each prompt specified broad readable clusters at 40×40 and excluded scenery, props, characters and perspective.
