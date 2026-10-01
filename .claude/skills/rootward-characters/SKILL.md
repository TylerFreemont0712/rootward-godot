---
name: rootward-characters
description: Rootward's character and animation pipeline - VRM anime skins (godot-vrm, MToon, spring bones), the shared move library keyed from readable poses in Blender (pipeline/moves, scripts/moves.sh), headless Blender 5.2 with the VRM add-on, retargeting through Godot's humanoid profile, and judging motion with sheets and reels. Use when making or changing a skin, a model, a rig, a clip, a spell animation or a pose, or anything under pipeline/blender, pipeline/moves or game/characters.
---

# Rootward characters and moves

Read first: `docs/decisions/ADR-0028-vrm-skins-and-a-shared-move-library.md`, `ADR-0029` (the anime look) and `pipeline/moves/README.md` (every
pose parameter, the clip format, the fantastical-motion checklist). Older routes and why they were dropped:
ADR-0005, ADR-0007, ADR-0008.

## The shape

- Skin = `game/characters/<id>/<id>.vrm` + `game/assets/portraits/<id>.png` + an entry in `Settings.CHARACTER_SKINS`,
  `ui/skin_selection.gd` and `run_summary.gd`. godot-vrm renames humanoid bones to `SkeletonProfileHumanoid` names
  on a `%GeneralSkeleton` and keeps MToon, springs and expressions (`happy`, `angry`, `sad`, `surprised`, `blink`...).
- Moves = `pipeline/moves/{poses.json,clips/*.json}` -> `scripts/moves.sh` -> `game/characters/moves/rootward.glb`
  (+ `moves.json`: length, loop, release, hand, release_point in hip heights, face). One library, every VRM skin.
- `StageCharacter` (game/characters/character.gd) plays either kind; `HeroView` frames, lights and times it.

## The anime look (ADR-0029)

- Shaders: `game/characters/anime_toon.gdshader`, `anime_face.gdshader`, `anime_outline.gdshader`,
  `anime_common.gdshaderinc`; unshaded, lit by `set_light_direction(HeroView.KEY_LIGHT)`.
- VRM: `AnimeSkin.restyle_vrm` (MToon -> anime); `ROOTWARD_STYLE=mtoon|anime|anime-ink` picks it for now.
- Any rig -> skin: `~/blender/blender --background <src.blend> --python pipeline/blender/normalize_rig.py -- <map.json>`
  writes glb + textures + `skin.json`; copy the `.import` retarget block from `game/characters/moves/rootward.glb.import`
  (skeleton path `PATH:Skin/Skeleton3D`, `fix_silhouette/enable` true for an A-pose).
- Look dev: `ROOTWARD_CHARACTER=<id> ROOTWARD_LOOK=full|face [ROOTWARD_CLIP=.. ROOTWARD_AT=..]
  scripts/screenshot.sh res://tools/skin_look.tscn shots/look/x.png 20`.
- Third-party models (e.g. the ZZZ fan rigs in `/data/Blender/ZZZ`) go ONLY under `game/characters/_local/` and
  `pipeline/local/` (git-ignored). Never commit or ship them; study them, then make our own assets.
- To dump any .blend shader as text: iterate `material.node_tree.nodes` / `links` (see ADR-0029's method).

## The motion dummy and lab (ADR-0030)

- Moves are judged on the **motion dummy** first (`game/characters/dummy/`, a normalised skin built by
  `~/blender/blender --background --python pipeline/blender/build_dummy.py` on the move library's own skeleton), then
  on skins. `scripts/moves.sh` sheets and reels use it by default; `scripts/motion-lab.sh` plays any clip live (slow
  motion, frame steps, limited/smooth, hand trails, the cast's circle and a volley).
- Casts end in their push: `<cast>-hold` loops it while the volley flies, `<cast>-end` lets go on `end_cast()`;
  `events.charge` ends the coil, the only part slowed to wait for a long circle.
- Clip tools against stiffness: `follow` springs (`"Hand": [7, 0.42]`), negative `lag` (hips lead), `wave` layers,
  and no dead holds (drift between two near poses).
- A pose from four sides at once: `ROOTWARD_CLIP=idle-breathe ROOTWARD_AT=0 scripts/screenshot.sh
  res://tools/pose_views.tscn shots/pose.png 20` (`ROOTWARD_REST=1`: the model as built, no clip, no IK).
- The cast's magic circle is `MagicCircle` (game/scenes/shardrun/fight/magic_circle.gd), in front of the palm;
  look-dev sheet: `scripts/screenshot.sh res://tools/magic_circle_sheet.tscn shots/circles.png 10`.

## Workflow for a new or changed clip

1. Edit poses/clips (numbers only; no bone axes). Remember: foes are on her LEFT and 35 degrees forward; a torso
   `turn` toward them swings the left arm back, so add the turn to the arm's `forward`.
2. `scripts/moves.sh` (unit tests, Blender build ~20 s, import, sheets `shots/moves/{cast,react,end}.png`).
3. Look at the sheets; the gold label is the release frame. For motion: `scripts/moves.sh --reel`, then pull frames
   with `ffmpeg -ss <t> -i shots/moves/reel.mp4 -vf "fps=6,scale=240:-1,tile=8x1" -frames:v 1 strip.png` and Read it.
4. In the fight: `ROOTWARD_SHOT=volley ROOTWARD_SHOT_SKIN=shibu ROOTWARD_SHOT_LANGUAGE=javascript
   scripts/screenshot.sh res://tools/shardrun_shot.tscn shots/x.png 60`.
5. `scripts/test.sh -a res://test/characters` (vrm_character_test.gd checks clips, loops, release timing and point).

## Verified facts and traps (Blender 5.2.2, Godot 4.7.2)

- Feet are planted by default (build: two-bone IK per frame; runtime: `LegPlanting` with `TwoBoneIK3D`). Keep
  `Hips.lift` <= 0 except in an unplanted window (`plant` in the clip). The Hips must stay disconnected (the build
  does it): Blender ignores a connected bone's location.
- Every clip starts and ends in the `stance` pose (the guard idle); the foot spots are taken from each clip's frame 0.
- A T-pose skin built on the move library's skeleton (the dummy) imports with `fix_silhouette` **off**, as
  `rootward.glb` does: on, it re-aims the VRoid feet and tips them toes-up. Only an A-pose rig needs it.
- The VRoid `Toes` bone sits at ankle height; the floor (the sole) is at 0.

- Blender: `--factory-startup` disables user extensions (VRM). The pipeline enables it with
  `addon_utils.enable("bl_ext.blender_org.vrm")`. VRM imports face -Y, her left +X, Z up, T-pose, quaternion bones;
  VRM 0 humanoid map: `armature.data.vrm_addon_extension.vrm0.humanoid.human_bones` (`.bone`, `.node.bone_name`).
- VRM 0 thumbs are one segment out: Proximal->Metacarpal, Intermediate->Proximal (Godot/VRM 1 names).
- Set `scene.render.fps` before keying: glTF export converts frames with it (24 default -> clips 1.25x slow).
- With an action assigned, `view_layer.update()` re-evaluates it and overwrites a hand-set pose; use `frame_set`.
- Godot AnimationLibrary import: `retarget/remove_tracks/except_bone_transform` must be **false** (true strips
  rotations). The `.import` in `game/characters/moves/` is the template; `humanoid_bone_map.tres` is identity.
- A SubViewport with `own_world_3d` has no light: MToon renders black unless the view adds one (HeroView._light).
- `bpy.ops.pose.apply_to_basis` and `anim.convert_legacy_action` both exist in 5.2 (the generic blender-* skills
  say the latter was removed; it was not).

## Tools installed

Blender extensions: VRM format, MMD Tools (Japanese anime motion files), Wiggle Bones (bone springs), Rigify.
Godot addons: `addons/vrm`, `addons/Godot-MToon-Shader` (V-Sekai, MIT). References in `pipeline/cache/reference/`:
CC0 VRoid samples (`scripts/fetch-moves-refs.sh`), Quaternius Universal Animation Library (CC0, 43 clips incl.
spell casts; UE mannequin names map one to one onto the profile), Bandai Namco dataset 2 (CC BY-NC, walks/waves).
General Blender API references: the user-level `blender-*` skills.
