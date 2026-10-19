# What could ship, and what could not

Rootward is an in-house project, so nothing here blocks anything today. This page is for the day the game might go
public or commercial: what is clearly ours or free to ship, what needs a credit, and what must be checked or replaced
first. Written 2026-10-09; keep it current when an asset source is added (CLAUDE.md asks for it). "Verify" means the
licence was not read in full for this page; read it before relying on it.

## Ours, free to ship

- Hand-placed pixel art: `pipeline/pixel/sprites/*.sprite` and what they build (characters, Hotaru, small props).
- Blender-built characters: `pipeline/animation/blender_base.py` and its models in `Concept/v0.3/animation/models/`, and
  the cast's blockouts (`pipeline/animation/blender_cast.py`), made from primitives in code with no imported 3D asset
  (2026-10-13). The cast's finished sheets are ComfyUI restyles of these, so they are listed below. The same holds
  for the world pipeline's blockouts (`pipeline/world/blender_world.py`, built from the specs in
  `pipeline/world/objects/`, ADR-0064).
- Code-made art: ground tiles (`pipeline/pixel/terrain.py`), puppet sheets (`pipeline/art/puppet.py`), effects drawn
  in code (spell circles, bolts, impacts).
- Hinged gate sheets (2026-10-17): nine designs with thirteen poses, built from native vector geometry by
  `game/tools/build_gate_art.gd`. Source PNGs and endpoint SVGs: `Concept/v0.3/Update/gate-swing/`. These replace
  the earlier five imagegen-derived gate sheets and four expanded gate blockouts; existing fences still use their
  previously recorded sources.
- All code, content, dialogue and text.

## Free with a credit or a licence file

- **Kenney packs** (`pipeline/sources/vendor/kenney-*`): CC0, no credit required (a credit is polite).
- **OpenGameArt sounds** (`pipeline/sources/vendor/oga-*`, `ccby-oga`): mixed CC0, CC-BY and OGA-BY. CC-BY and
  OGA-BY need the author credited. Verify each file's licence in its folder before shipping.
- **Fonts** (`game/ui/fonts/`): Alegreya, Cinzel, Exo 2 and Lora under the SIL Open Font License (OFL files beside
  them); IBM Plex Mono is OFL too (verify its licence file is shipped).

## Check before shipping (AI-generated)

Everything made with ComfyUI or the music models. The usual position is that a model's licence governs use, and
generated images may not be protectable as your own work in some countries. Read each licence before going public:

- **Pictures:** `novaAnimeXL_ilV190` (an Illustrious XL merge; its licence is on its model page, verify),
  `sd_xl_base_1.0` (CreativeML Open RAIL++-M: commercial use allowed within its use restrictions), the Pixel Art XL
  LoRA (verify), RMBG background removal (verify). This covers the overworld's buildings, trees and props
  (`pipeline/pixel/manifest.json`), the townspeople's portraits (`game/assets/overworld/portraits/`), card art,
  creatures, backdrops, the old sprite sheets, the animation candidates (`pipeline/animation/manifest.json`,
  `Concept/v0.3/animation/comfy-*.png`) and the overworld cast's sprite sheets (`game/assets/overworld/cast/`, from
  `pipeline/animation/cast.json`), which use the same checkpoint and LoRA, and the world's objects
  (`game/assets/overworld/world/`, ADR-0064): ComfyUI restyles of code-made blockouts, and re-cuts of the overworld's
  earlier ComfyUI renders.
- **Terrain from ChatGPT Image Generation** (2026-10-19): `art-source/lanternroot-pathways-imagegen-2026-10-19.png`
  and `art-source/lanternroot-fantasy-ground-imagegen-2026-10-19.png` supply the brick, stone, timber and woodland
  materials integrated by `pipeline/pixel/terrain.py`. The raw sources and exact prompts are kept in
  `Concept/v0.3/Update/art-source/land-variants-imagegen-2026-10-19.md`; runtime atlas cuts use the shared palette.
- **Player animation and commander replacement** (2026-10-17): the player explicitly requested ChatGPT image
  generation for the higher-quality characters. Built-in OpenAI imagegen produced the selected directional sources
  for `game/assets/overworld/player/male.png`, `female.png` and the replacement `cast/sergeant.png`, using the
  project's existing cast and sergeant portrait as references. Sources and complete prompts are preserved under
  `Concept/v0.3/animation/player/`; `game/tools/import_player_sheets.gd` registers them into game sheets.
- **Town art polish** (2026-10-17): built-in OpenAI imagegen produced replacement Lantern Tree, Root Gate and
  wooden fence/gate source artwork, following the player's quality request. Complete prompts, selected sources and
  previous art are in `Concept/v0.3/Update/town-polish/`. Registered posts, rails, sixteen connection shapes and wide gate frames reuse the authored
  timber (including the additional vertical-face source); the world pipeline cuts and palette-locks all 23 final assets in `assets/overworld/world/`.
- **Five buildings from ChatGPT image generation** (OpenAI): the archive, smithy, hall, workshop and Root Gate
  pictures were cut from approved sources in `Concept/v0.3/Update/art-source/*chatgpt-imagegen*` (2026-10-09 and 10),
  and `game/assets/overworld/world/` re-cuts them at 40 px (2026-10-13). OpenAI's terms give the output to the user
  (verify), but they are outside the free-and-local rule for production art: remake them as world-pipeline blockouts
  before anything ships.
- **Lanternroot catalog expansion** (2026-10-15): 86 new `expand-*` objects use the existing ComfyUI world
  pipeline and its models. Four additional objects (bakery, greenhouse, fountain, roofed noticeboard) use
  ChatGPT image generation, explicitly requested by the player for this batch. Original images and complete
  prompts are preserved in `pipeline/world/expansion/imagegen/` and `imagegen-sources.json`. All 90 game pictures
  are cut by the world pipeline at 40 px tiles; see `pipeline/world/expansion/README.md` for provenance.
- **v0.4's item icons and props** (2026-10-15): sixteen bag icons (`item-*`), the music box and Pell's map table,
  made locally by the same world pipeline (Blender blockouts from `pipeline/world/objects/item-*.jsonc`,
  `music-box.jsonc` and `map-table.jsonc`, then the ComfyUI restyle above, cut at 40 px). Same licence notes as the
  world's objects.
- **Music and sound:** YuE, ACE-Step, Stable Audio Open 1.0 and Stable Audio 3 (each with its own licence; Stability
  AI's community licence has a revenue limit and terms; verify all four).
  YuE2 is used twice for the same scores (ADR-0067): the GGUF weights through `yue2.cpp` and the ComfyUI
  `yue2_MusicGen` workflow's checkpoint (`yue2-comfy-...` takes); both are CC BY-NC 4.0, non-commercial.
- **3D:** TRELLIS (verify) and anything imported through the Blender MCP from Sketchfab or Poly Pizza (licence per
  model; Poly Haven is CC0).

## Do not ship as is

- **Characters from existing games or shows.** A model or portrait of someone else's character cannot ship, however
  it was made. `game/assets/portraits/anby.png` (the player's uncommitted file) looks like Anby from Zenless Zone Zero;
  if it is, it and any skin of her stay private. Check `mana.png` and the VRM skins the same way.
- **VRM models:** each `.vrm` carries its own licence in its metadata (who may use it, whether commercially, whether it
  may be modified). Read each one before a skin ships.
- **Mana Seed** art is not used and must not be: its licence forbids use alongside generative AI.
