# ADR-0029: the anime look (ZZZ-style shaders) and normalised skins

- Status: accepted as tooling; the game's default look is the player's choice (see "Open")
- Date: 2026-10-01
- Related: ADR-0028 (VRM skins and the move library)

## Context

The player liked the VRM skins' polish but wants "a little more anime style, like Zenless Zone Zero", and wants the
styling settled before more classes are made. They had fan rigs of ZZZ characters on disk (`/data/Blender/ZZZ`:
Anby, Miyabi and Nekomiya Mana, by @Crabnuts, shaders by Just_ScaasI; non-commercial, educational use). Those are
HoYoverse's characters: studying them is fine, shipping them is not.

Taking Anby's shader apart (its node graphs dumped from the .blend) showed what the look is made of:

1. A hard light/shade split (N·L over 0 to 0.25) whose shade is a **colour per material slot**, picked by a mask
   texture's red channel (warm rose on skin, slate on cloth), never a grey darkening.
2. The **face shaded by an SDF lightmap** against the head's facing, not by its normals: a drawn shadow that sweeps.
3. A **specular band** (N·H over 0.75 to 1) masked by the mask's blue channel, coloured per slot.
4. A **colour-grading LUT** read through Unity's LogC curve (the constants 0.048 / 0.386 give it away).
5. No outline or rim in this shader (in-game ZZZ draws both, thin).

## Decision

- **Our own shaders implement the technique** (committed): `anime_toon.gdshader` (slots or a painted shade map,
  specular, rim, LUT, flash), `anime_face.gdshader` (SDF lightmap, or flat for a painted face),
  `anime_outline.gdshader` (an inverted hull coloured from the surface), `anime_common.gdshaderinc` (LogC LUT).
  Unshaded: the stage hands in one light direction (`HeroView.KEY_LIGHT`), so every skin is lit alike.
- **Any VRM can wear them**: `AnimeSkin.restyle_vrm` converts MToon (its lit texture and its own painted shade
  texture), shares one material per source material, keeps soft-transparent eye layers in MToon.
  `ROOTWARD_STYLE=mtoon|anime|anime-ink` picks the look for now.
- **Any rigged model can become a skin**: `pipeline/blender/normalize_rig.py` builds a clean humanoid skeleton at the
  source's joints, folds every deform bone's weight onto it (twist bones into their limb, face bones into the head),
  keeps hair and cloth chains for spring bones, and writes a glTF, its textures and a `skin.json`. Godot imports it
  through the same humanoid profile (with "fix silhouette" for an A-pose), so the move library plays on it.
- **Reference skins stay local**: `game/characters/_local/` and `pipeline/local/` are git-ignored; the wardrobe lists
  them as "Local reference · not shipped". Anby is one (her map in `pipeline/local/anby/rig_map.json`).

## Consequences

- The shader closes much of the gap; the rest is **asset design**. Shibu in the anime shader looks cleaner but not
  ZZZ, because her textures are grungy paint. ZZZ-grade characters need flat, clean base colours, a painted shade
  per material (or a slot mask), a hair specular mask and an SDF face lightmap. None of those can be borrowed from
  the reference skins; they have to be ours.
- The rig normaliser merges twist bones, so forearms twist less smoothly than in the source rig; face bones are
  dropped for shape keys.
- A fan rip's quirks travel with it (Anby's skirt panels part at rest).

## Open (the player's call)

Which look is the default for the game (MToon, anime, anime with ink), how large the hero is drawn on the stage, and
how our own ZZZ-grade characters get made (see WIP.md).

## Amendment (2026-10-01): the 2XKO target, after Guilty Gear Xrd

The player set the target: the anime-styled League look of 2XKO (a 2D fighter of heavily cel-shaded 3D characters),
for characters, enemies and everything, animation included, with an Ahri-like character to find it. Its method is
Arc System Works' (GDC, "GuiltyGear Xrd's Art Style: the X Factor between 2D and 3D"): hard step shading with the
threshold, the light and the normals all under the artist's control; shade = base x a tint per material; inverted-hull
lines; limited animation (no interpolation, held poses, heavy scale animation, no simulation). Now:

- **Edited normals, automated** (`normalize_rig.py` `normals`): smoothed across neighbours, and the head's turned to an
  ellipsoid, so the face shades as one drawn shape.
- **A light per character** (`style.light`, in its own facing), tuned so its shadow shapes read from the stage camera;
  a skin's own `style` also sets its shade tint, edge, rim, ink width and tint, and `flatten` (dividing out a painted
  texture's baked lighting, for game textures made for another look).
- **Ink lines on every anime skin**, coloured from the surface.
- **Limited animation**: pose, leg IK and springs advance together at `LIMITED_FPS` (15) and hold between
  (`AnimationMixer` and `Skeleton3D` in manual mode); `ROOTWARD_LIMITED=0` plays smoothly for comparison.
- **MMD models convert directly** (`import.pmx`), so an Ahri model (a fan MMD conversion of Wild Rift's) became a local
  reference skin: nine tails, hair, ears, skirt and tassels on 19 spring chains. Local only, like Anby and Mana.


## Amendment (2026-10-01): limited animation is opt-in

The player found the 15-a-second limited animation choppy. Playback is smooth by default; `ROOTWARD_LIMITED=15` (or
`=style`, a skin's own rate) brings the limited look back (ADR-0031).
