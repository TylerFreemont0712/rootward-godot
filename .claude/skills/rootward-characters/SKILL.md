---
name: rootward-characters
description: Rootward's character and animation pipeline - VRM anime skins (godot-vrm, MToon, spring bones), the shared move library keyed from readable poses in Blender (pipeline/moves, scripts/moves.sh), headless Blender 5.2 with the VRM add-on, retargeting through Godot's humanoid profile, and judging motion with sheets and reels. Use when making or changing a skin, a model, a rig, a clip, a spell animation or a pose, or anything under pipeline/blender, pipeline/moves or game/characters.
---

# Rootward characters and moves

Read first: `docs/decisions/ADR-0028-vrm-skins-and-a-shared-move-library.md` and `pipeline/moves/README.md` (every
pose parameter, the clip format, the fantastical-motion checklist). Older routes and why they were dropped:
ADR-0005, ADR-0007, ADR-0008.

## The shape

- Skin = `game/characters/<id>/<id>.vrm` + `game/assets/portraits/<id>.png` + an entry in `Settings.CHARACTER_SKINS`,
  `ui/skin_selection.gd` and `run_summary.gd`. godot-vrm renames humanoid bones to `SkeletonProfileHumanoid` names
  on a `%GeneralSkeleton` and keeps MToon, springs and expressions (`happy`, `angry`, `sad`, `surprised`, `blink`...).
- Moves = `pipeline/moves/{poses.json,clips/*.json}` -> `scripts/moves.sh` -> `game/characters/moves/rootward.glb`
  (+ `moves.json`: length, loop, release, hand, release_point in hip heights, face). One library, every VRM skin.
- `StageCharacter` (game/characters/character.gd) plays either kind; `HeroView` frames, lights and times it.

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
