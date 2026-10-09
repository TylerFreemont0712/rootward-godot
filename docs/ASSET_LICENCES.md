# What could ship, and what could not

Rootward is an in-house project, so nothing here blocks anything today. This page is for the day the game might go
public or commercial: what is clearly ours or free to ship, what needs a credit, and what must be checked or replaced
first. Written 2026-10-09; keep it current when an asset source is added (CLAUDE.md asks for it). "Verify" means the
licence was not read in full for this page; read it before relying on it.

## Ours, free to ship

- Hand-placed pixel art: `pipeline/pixel/sprites/*.sprite` and what they build (characters, Hotaru, small props).
- Code-made art: ground tiles (`pipeline/pixel/terrain.py`), puppet sheets (`pipeline/art/puppet.py`), effects drawn
  in code (spell circles, bolts, impacts).
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
  creatures, backdrops and the old sprite sheets.
- **Music and sound:** YuE, ACE-Step, Stable Audio Open 1.0 and Stable Audio 3 (each with its own licence; Stability
  AI's community licence has a revenue limit and terms; verify all four).
- **3D:** TRELLIS (verify) and anything imported through the Blender MCP from Sketchfab or Poly Pizza (licence per
  model; Poly Haven is CC0).

## Do not ship as is

- **Characters from existing games or shows.** A model or portrait of someone else's character cannot ship, however
  it was made. `game/assets/portraits/anby.png` (the player's uncommitted file) looks like Anby from Zenless Zone Zero;
  if it is, it and any skin of her stay private. Check `mana.png` and the VRM skins the same way.
- **VRM models:** each `.vrm` carries its own licence in its metadata (who may use it, whether commercially, whether it
  may be modified). Read each one before a skin ships.
- **Mana Seed** art is not used and must not be: its licence forbids use alongside generative AI.
