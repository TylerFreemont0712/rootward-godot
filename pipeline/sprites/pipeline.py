#!/usr/bin/env python3
"""The sprite pipeline: a reference drawing per skin, one animated sprite sheet per clip, built for the stage (ADR-0008).

  setup       check that ComfyUI has every model and node the graphs need
  poses       write the skeleton sheets that drive each clip, to look at before spending GPU time
  reference   draw the skin in its rig's rest pose; --candidates N renders options, --pick I keeps one
  keypose     draw the skin on one frame of a clip, to pin as a key in its middle (`drawn`)
  profile     the portrait for the wardrobe: the reference's head and shoulders repainted in more detail
  animate     render clips as sprite sheets, one ComfyUI run each, in dependency order (--draft: 8 fast steps)
  build       cut the sheets into what the game loads: one grid per clip plus clips.json, in game/assets/sprites/
  preview     a contact sheet and an HTML page that plays every clip at game speed

Ported from the old game's pipeline (ProgramMe, ADR-0029 to ADR-0030 there), where it was measured: a character stays
one character and moves smoothly only when every frame of a clip is drawn *together* by a model that knows frames
follow one another. A video model (Wan 2.1 VACE 1.3B) draws the whole clip as one piece of motion, takes the pose from
the rig's skeletons, the look from the reference, and pins the first and last frames to the reference itself, so every
clip leaves from and returns to the same drawing.

  scripts/sprites.sh setup
  scripts/sprites.sh reference vesper --candidates 4      then  --pick 2
  scripts/sprites.sh animate vesper                       every clip; or name some
  scripts/sprites.sh build vesper && scripts/sprites.sh preview vesper
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import rig as rigmod  # noqa: E402
from comfy import Comfy, Graph  # noqa: E402

REPO = HERE.parents[1]
SKINS = HERE / "skins"
OUT = REPO / "game" / "assets" / "sprites"
CACHE = REPO / "pipeline" / "cache" / "sprites"

HF = "https://huggingface.co"
MODELS = {
    "checkpoints": {"novaAnimeXL_ilV190.safetensors": "https://civitai.com/models/376130 (Nova Anime XL, IL v19.0)"},
    "loras": {
        "DetialN_XL.safetensors": "(already installed; any SDXL detail LoRA works, or set its strength to 0)",
        "Wan21_CausVid_bidirect2_T2V_1_3B_lora_rank32.safetensors":
            f"{HF}/Kijai/WanVideo_comfy/resolve/main/Wan21_CausVid_bidirect2_T2V_1_3B_lora_rank32.safetensors",
    },
    "controlnet": {"noobai-openpose-sdxl-fp16.safetensors": "https://civitai.com/models/962537 (NoobAI openpose)"},
    "diffusion_models": {
        "wan2.1_vace_1.3B_fp16.safetensors":
            f"{HF}/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_vace_1.3B_fp16.safetensors",
    },
    "text_encoders": {
        "umt5_xxl_fp8_e4m3fn_scaled.safetensors":
            f"{HF}/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors",
    },
    "vae": {
        "wan_2.1_vae.safetensors": f"{HF}/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors",
    },
    # The finishing stages (ADR-0031): sharper, larger frames, and in-betweens for fast clips.
    "upscale_models": {
        "RealESRGAN_x4plus_anime_6B.pth":
            "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth",
    },
    "frame_interpolation": {
        "rife_v4.26.safetensors": f"{HF}/Comfy-Org/frame_interpolation/resolve/main/frame_interpolation/rife_v4.26.safetensors",
    },
}
NODES = ["RootwardPoseSheetToFrames", "RootwardVaceKeyframes", "RootwardFramesToSheet", "BiRefNetRMBG", "WanVaceToVideo",
         "ImageUpscaleWithModel", "FrameInterpolate"]

# What every skin's prompts share. A skin can override any of these in its `style`.
STYLE = {
    "prefix": "masterpiece, best quality, clean anime style, full body chibi character, ",
    "suffix": (", three-quarter view, body turned toward the right, facing the viewer, standing, flat cel shading, "
               "clean outline, plain white background, no shadow"),
    "negative": ("worst quality, low quality, blurry, text, watermark, signature, cropped, realistic, multiple views, "
                 "sprite sheet, grid, border, extra limbs, extra arms, background scenery, floor, ground shadow, "
                 "gradient background, back view, side view, profile"),
    "motion_suffix": (", anime cel animation, clean line art, smooth motion, plain white background, static camera, "
                      "full body always in frame"),
    "motion_negative": ("camera movement, zoom, pan, cut, flicker, color shift, morphing, blurry, deformed hands, extra "
                        "limbs, extra fingers, text, watermark, background scenery, floor, shadow, low quality, "
                        "still image, static frame, magic effects, light burst, lightning, sparkles, glow, beams, energy, particles, flash"),
}
COLUMNS = 8


# --- skins ------------------------------------------------------------------------------------------------------------


def load_skin(skin_id: str) -> dict:
    path = SKINS / skin_id / "skin.json"
    if not path.exists():
        raise SystemExit(f"no skin at {path}")
    skin = json.loads(path.read_text())
    if skin.get("pipeline") != "sprites":
        raise SystemExit(f"{skin_id} is not a sprite-pipeline skin (its skin.json has no \"pipeline\": \"sprites\")")
    return skin


def style(skin: dict, key: str) -> str:
    return skin.get("style", {}).get(key, STYLE[key])


def clip_specs(skin: dict) -> dict[str, dict]:
    """The rig's animations, with this skin's per-clip overrides (its own motion text, a seed) laid over them."""
    animations = rigmod.load_animations(skin["id"])["clips"]
    wanted = skin.get("clips", {})
    skip = set(skin.get("skip", []))
    return {name: {**spec, **wanted.get(name, {})} for name, spec in animations.items() if name not in skip}


def cache(skin_id: str, *parts: str) -> Path:
    path = CACHE.joinpath(skin_id, *parts)
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def canvas(skin_id: str) -> tuple[int, int]:
    width, height = rigmod.load_rig(skin_id)["canvas"]
    return int(width), int(height)


def reference_image(skin_id: str, scale: float = 1) -> Image.Image:
    path = SKINS / skin_id / "reference.png"
    if not path.exists():
        raise SystemExit(f"{skin_id} has no reference.png yet: run `reference {skin_id}` and then `--pick`")
    width, height = canvas(skin_id)
    return Image.open(path).convert("RGB").resize((round(width * scale), round(height * scale)), Image.LANCZOS)


# --- setup ------------------------------------------------------------------------------------------------------------


def setup(comfy: Comfy) -> None:
    node = HERE / "comfy_nodes" / "rootward_sprites" / "__init__.py"
    print(f"the Rootward nodes come from {node}; ComfyUI runs its copy in custom_nodes/rootward_sprites")
    if not comfy.alive():
        raise SystemExit(f"ComfyUI is not answering at {comfy.url}; start it (see CLAUDE.md) and run setup again")
    missing = 0
    for folder, files in MODELS.items():
        have = set(comfy.models(folder))
        for name, source in files.items():
            ok = name in have
            missing += not ok
            print(f"  {'ok     ' if ok else 'MISSING'} {folder}/{name}" + ("" if ok else f"\n          {source}"))
    for node in NODES:
        ok = comfy.has_node(node)
        missing += not ok
        print(f"  {'ok     ' if ok else 'MISSING'} node {node}")
    print("ready" if missing == 0 else f"{missing} missing; download into ComfyUI/models/<folder>/ and restart ComfyUI")


# --- poses ------------------------------------------------------------------------------------------------------------

def blend_pose(a: dict, b: dict, w: float) -> dict:
    """a toward b by w. A point only one side has (a far ear the head hides) is taken as it is."""
    out = {}
    for key in set(a) | set(b):
        if key in a and key in b:
            out[key] = (a[key][0] + (b[key][0] - a[key][0]) * w, a[key][1] + (b[key][1] - a[key][1]) * w)
        else:
            out[key] = a.get(key, b.get(key))
    return out


def clip_poses(skin_id: str, name: str, specs: dict[str, dict], rig: dict, library: dict) -> list[dict]:
    """Every frame's skeleton for a clip, from its keys, eased into its anchors over `ease` frames at each pinned end
    (so the skeleton and the pinned picture agree, and the model is never asked to reconcile two bodies)."""
    spec = specs[name]
    poses = rigmod.spec_poses(spec, rig, library)
    ease = int(spec.get("ease", 0))
    if ease:
        anchors = spec.get("anchors", {})
        for end in ("first", "last"):
            anchor = anchors.get(end)
            if anchor is None:
                continue
            target = rigmod.rest_pose(rig) if anchor == "reference" else clip_poses(
                skin_id, anchor.partition(":")[0], specs, rig, library)[-1]
            for step in range(min(ease, len(poses) // 2)):
                index = step if end == "first" else len(poses) - 1 - step
                u = step / ease
                keep = u * u * (3 - 2 * u)  # smoothstep: the pinned pose exactly at the end, the keys by `ease`
                poses[index] = blend_pose(target, poses[index], keep)
    return poses


def control_sheet(poses: list[dict], rig: dict) -> Image.Image:
    """What the video model is steered by: the skeletons, one per frame, in a grid."""
    return rigmod.pose_sheet(poses, rig, COLUMNS)


def resolved(spec: dict, poses: list[dict]) -> dict:
    """A clip spec with `release: "auto"` filled in from its skeleton: the frame a hand reaches furthest toward the foe,
    that hand (or both, when they reach together), and phases around it."""
    if spec.get("release") != "auto":
        return spec
    reach = []
    for pose in poses:
        neck = pose["neck"][0]
        reach.append((pose["l_wrist"][0] - neck, pose["r_wrist"][0] - neck))
    best = max(range(len(poses)), key=lambda i: max(reach[i]))
    far, near = reach[best]
    hand = "both" if abs(far - near) < 0.06 else ("far" if far > near else "near")
    n = max(1, len(poses) - 1)
    release = best / n
    return {**spec, "release": release, "hand": hand, "phases": {
        "anticipate": [0.0, max(0.0, release - 0.06)],
        "release": [max(0.0, release - 0.04), min(1.0, release + 0.22)],
        "recover": [min(1.0, release + 0.24), 1.0],
    }}



def poses(skin_id: str, names: list[str] | None) -> None:
    skin = load_skin(skin_id)
    rig = rigmod.load_rig(skin_id)
    library = rigmod.load_animations(skin_id)
    for name, spec in clip_specs(skin).items():
        if names and name not in names:
            continue
        sheet = control_sheet(clip_poses(skin_id, name, clip_specs(skin), rig, library), rig)
        path = cache(skin_id, "poses", f"{name}.png")
        sheet.resize((sheet.width // 4, sheet.height // 4)).save(path)
        print(f"{name}: {spec['frames']} frames -> {path}")


# --- reference --------------------------------------------------------------------------------------------------------


def figure_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    """The character's box: alpha where there is some, else everything that is not near-white."""
    rgba = np.asarray(image.convert("RGBA")).astype(np.int16)
    if (rgba[..., 3] < 250).any():
        solid = rgba[..., 3] > 32
    else:
        solid = (255 - rgba[..., :3]).max(axis=-1) > 24
    ys, xs = np.nonzero(solid)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def placed_source(skin: dict, width: int, height: int, image: Image.Image | None = None) -> Image.Image:
    """The skin's existing art (or `image`), scaled and placed where the rig's rest figure stands, on white."""
    spec = skin["reference"]
    image = (image or Image.open(SKINS / skin["id"] / spec["source"])).convert("RGBA")
    if "cell" in spec and "source" in spec:
        columns, rows = spec.get("grid", [1, 1])
        cw, ch = image.width // columns, image.height // rows
        row, column = divmod(int(spec["cell"]), columns)
        image = image.crop((column * cw, row * ch, (column + 1) * cw, (row + 1) * ch))
    if (np.asarray(image)[..., 3] == 255).all():
        # An opaque picture: treat near-white as background so the figure can be measured and moved.
        rgb = np.asarray(image)[..., :3].astype(np.int16)
        alpha = np.where((255 - rgb).max(axis=-1) > 24, 255, 0).astype(np.uint8)
        image.putalpha(Image.fromarray(alpha))
    left, top, right, bottom = figure_bbox(image)
    figure = image.crop((left, top, right, bottom))
    rig = rigmod.load_rig(skin["id"])
    scale = rig["figure"] * height * spec.get("scale", 1.0) / figure.height
    figure = figure.resize((max(1, round(figure.width * scale)), max(1, round(figure.height * scale))), Image.LANCZOS)
    # Centre on the alpha's weight rather than the box, so an outstretched arm does not drag the body sideways.
    weights = np.asarray(figure)[..., 3].astype(np.float64).sum(axis=0)
    middle = float((weights * np.arange(figure.width)).sum() / max(1.0, weights.sum()))
    x = round(rig["center"] * width - middle + spec.get("shift", 0.0) * rig["figure"] * height)
    y = round(rig["feet"] * height - figure.height)
    out = Image.new("RGBA", (width, height), (255, 255, 255, 255))
    out.alpha_composite(figure, (x, max(0, y)))
    return out.convert("RGB")


def reference(skin_id: str, comfy: Comfy, candidates: int, pick: int | None) -> None:
    skin = load_skin(skin_id)
    folder = cache(skin_id, "reference", "x").parent
    if pick is not None:
        chosen = folder / f"candidate-{pick}.png"
        if not chosen.exists():
            raise SystemExit(f"no candidate {pick} in {folder}")
        spec = skin.get("reference", {})
        if "source" in spec or not spec.get("place", True):
            # The ControlNet already stood the figure on the rest skeleton: keep the drawing where it is.
            shutil.copy(chosen, SKINS / skin_id / "reference.png")
        else:
            # Drawn from words alone, the figure comes out whatever size the model liked: the Foxfire Miko filled the
            # canvas top to bottom, about a fifth bigger than the skeleton, so every spell left from beside her drawn
            # hand instead of from it (ADR-0030). Put the drawing where the rig's figure stands, as source art is.
            # `reference.scale` sizes the whole silhouette (ears and tail count), 1.0 being the rig's figure height.
            shutil.copy(chosen, SKINS / skin_id / "reference-drawn.png")
            big = Image.open(chosen)
            placed_source(skin, big.width, big.height, big).save(SKINS / skin_id / "reference.png")
        print(f"kept candidate {pick} as {SKINS / skin_id / 'reference.png'}")
        return
    spec = skin.get("reference", {})
    width, height = canvas(skin_id)
    scale = float(spec.get("scale_up", 2))
    big = (round(width * scale / 8) * 8, round(height * scale / 8) * 8)
    rig = rigmod.load_rig(skin_id)
    pose = rigmod.draw_pose(rigmod.rest_pose(rig), rig, *big)
    graph = Graph("reference")
    graph.set("rw:pose", image=comfy.upload(pose, f"{skin_id}-rest-pose.png"))
    graph.set("rw:positive", text=style(skin, "prefix") + skin["character"] + style(skin, "suffix"))
    graph.set("rw:negative", text=style(skin, "negative"))
    graph.set("rw:control", strength=float(spec.get("control", 1.0)), end_percent=float(spec.get("control_end", 0.85)))
    graph.set("rw:detail", strength_model=float(spec.get("detail", 0.6)), strength_clip=float(spec.get("detail", 0.6)))
    graph.set("rw:empty", width=big[0], height=big[1])
    graph.set("rw:source-size", width=big[0], height=big[1])
    graph.set("rw:sampler", steps=int(spec.get("steps", 30)), cfg=float(spec.get("cfg", 5.5)))
    if "source" in spec:
        source = placed_source(skin, *big)
        source.save(folder / "source-placed.png")
        graph.set("rw:source", image=comfy.upload(source, f"{skin_id}-source.png"))
        graph.set("rw:sampler", denoise=float(spec.get("denoise", 0.65)))
        graph.remove("rw:empty")
    else:
        graph.link("rw:sampler", "latent_image", "rw:empty")
        graph.set("rw:sampler", denoise=1.0)
        graph.remove("rw:source", "rw:source-size", "rw:encode")
    graph.remove("rw:save")
    seed = int(spec.get("seed", 1000))
    shots = []
    for index in range(candidates):
        graph.set("rw:sampler", seed=seed + index)
        graph.set("rw:save-clean", filename_prefix=f"rootward/{skin_id}/reference-{index}")
        started = time.monotonic()
        image = comfy.run(graph)["rw:save-clean"][0].convert("RGB")
        image.save(folder / f"candidate-{index}.png")
        shots.append(image)
        print(f"candidate {index} (seed {seed + index}) in {time.monotonic() - started:.0f}s")
    thumb = 360
    sheet = Image.new("RGB", (thumb * len(shots), round(thumb * big[1] / big[0]) + 24), "white")
    draw = ImageDraw.Draw(sheet)
    for index, shot in enumerate(shots):
        sheet.paste(shot.resize((thumb, round(thumb * big[1] / big[0]))), (index * thumb, 24))
        draw.text((index * thumb + 6, 4), f"candidate {index}", fill="black")
    sheet.save(folder / "candidates.png")
    print(f"compare {folder / 'candidates.png'}, then: reference {skin_id} --pick <n>")


# --- profile --------------------------------------------------------------------------------------------------------

PORTRAIT = (", upper body portrait, looking at the viewer, highly detailed face, detailed eyes with highlights, detailed "
            "hair strands, intricate embroidery, soft rim lighting, painterly anime illustration, crisp line art")


def portrait_crop(skin_id: str, size: int) -> Image.Image:
    """The reference's head and shoulders, square, upscaled: what the portrait pass redraws in more detail."""
    ref = reference_image(skin_id, 2)
    left, top, right, bottom = figure_bbox(ref)
    rgba = np.asarray(ref.convert("RGB")).astype(np.int16)
    solid = (255 - rgba).max(axis=-1) > 24
    # Centre on the head: the middle of the figure across its top fifth, not across the whole body.
    band = solid[top : top + (bottom - top) // 5]
    cols = np.nonzero(band.any(axis=0))[0]
    middle = (int(cols[0]) + int(cols[-1])) // 2 if len(cols) else (left + right) // 2
    side = round((bottom - top) * 0.62)
    box = (middle - side // 2, top - side // 20, middle + side - side // 2, top - side // 20 + side)
    canvas = Image.new("RGB", (box[2] - box[0], box[3] - box[1]), "white")
    canvas.paste(ref.crop((max(0, box[0]), max(0, box[1]), box[2], box[3])), (max(0, -box[0]), max(0, -box[1])))
    return canvas.resize((size, size), Image.LANCZOS)


def profile(skin_id: str, comfy: Comfy, candidates: int, pick: int | None) -> None:
    """A portrait a notch above the sprite (the player, 2026-09-24): the reference's head and shoulders, repainted at
    1024 with the detail LoRA, so the picture beside the spells is the same character drawn with more care."""
    skin = load_skin(skin_id)
    folder = cache(skin_id, "profile", "x").parent
    if pick is not None:
        chosen = folder / f"candidate-{pick}.png"
        if not chosen.exists():
            raise SystemExit(f"no candidate {pick} in {folder}")
        shutil.copy(chosen, SKINS / skin_id / "profile.png")
        print(f"kept candidate {pick} as {SKINS / skin_id / 'profile.png'}")
        return
    spec = skin.get("portrait", {})
    source = portrait_crop(skin_id, 1024)
    source.save(folder / "source.png")
    graph = Graph("profile")
    graph.set("rw:source", image=comfy.upload(source, f"{skin_id}-portrait-source.png"))
    graph.set("rw:positive", text=style(skin, "prefix").replace("full body chibi character, ", "")
              + skin["character"] + spec.get("prompt", PORTRAIT))
    # A portrait is allowed the light and shading a sprite is kept flat for; flat colour is what it must not be.
    negative = style(skin, "negative").replace(", sparkles", "").replace(", glow", "").replace(", light rays", "")
    graph.set("rw:negative", text=negative + ", flat color, flat shading, simple shading, full body")
    graph.set("rw:sampler", denoise=float(spec.get("denoise", 0.5)), steps=int(spec.get("steps", 32)))
    graph.set("rw:detail", strength_model=float(spec.get("detail", 0.9)), strength_clip=float(spec.get("detail", 0.9)))
    seed = int(spec.get("seed", 9000))
    shots = []
    for index in range(candidates):
        graph.set("rw:sampler", seed=seed + index)
        graph.set("rw:save", filename_prefix=f"rootward/{skin_id}/profile-{index}")
        image = comfy.run(graph)["rw:save"][0].convert("RGBA")
        image.save(folder / f"candidate-{index}.png")
        shots.append(image)
        print(f"candidate {index} (seed {seed + index})", flush=True)
    thumb = 320
    sheet = Image.new("RGBA", (thumb * (len(shots) + 1), thumb + 24), (40, 40, 48, 255))
    draw = ImageDraw.Draw(sheet)
    sheet.paste(source.resize((thumb, thumb)), (0, 24))
    draw.text((6, 4), "source (sprite reference)", fill="white")
    for index, shot in enumerate(shots):
        small = shot.resize((thumb, thumb))
        sheet.alpha_composite(small, ((index + 1) * thumb, 24))
        draw.text(((index + 1) * thumb + 6, 4), f"candidate {index}", fill="white")
    sheet.save(folder / "candidates.png")
    print(f"compare {folder / 'candidates.png'}, then: profile {skin_id} --pick <n>")


# --- animate ----------------------------------------------------------------------------------------------------------


def anchor_image(skin_id: str, anchor: str, specs: dict[str, dict], draft: bool = False) -> Image.Image:
    if anchor == "reference":
        return reference_image(skin_id)
    clip, _, which = anchor.partition(":")
    if which != "last" or clip not in specs:
        raise SystemExit(f"cannot read anchor {anchor!r}: use 'reference' or '<clip>:last'")
    raw = CACHE / skin_id / "raw" / f"{clip}.png"
    # A draft chains through other drafts where they exist, so a re-keyed windup is what a drafted cast starts from.
    drafted = CACHE / skin_id / "drafts" / "raw" / f"{clip}.png"
    if draft and drafted.exists():
        raw = drafted
    if not raw.exists():
        raise SystemExit(f"anchor {anchor!r} needs {clip} rendered first")
    return frames_of(Image.open(raw), int(specs[clip]["frames"]))[-1].convert("RGB")


def order(names: list[str], specs: dict[str, dict]) -> list[str]:
    """Clips whose anchors come from other clips render after them."""
    done: list[str] = []

    def visit(name: str, trail: tuple[str, ...]) -> None:
        if name in done:
            return
        if name in trail:
            raise SystemExit(f"anchor cycle: {' -> '.join((*trail, name))}")
        for anchor in specs[name].get("anchors", {}).values():
            if anchor != "reference":
                visit(anchor.partition(":")[0], (*trail, name))
        done.append(name)

    for name in names:
        visit(name, ())
    return done


def pinned_control(
    skin_id: str, name: str, spec: dict, specs: dict[str, dict], rig: dict, library: dict, draft: bool
) -> tuple[Image.Image, Image.Image]:
    """The control video and its mask, as two sheets: every frame a skeleton to follow (mask white, "draw here"), except
    the pinned ones, which hold a real picture (mask black, "these pixels are the answer").

    The ends are pinned to their anchors (the reference, or another clip's last frame). A clip can also pin drawn key
    poses in its middle (`drawn`: frame -> picture), the way an animator draws the keys and leaves the in-betweens: the
    video model keeps the character's costume through a big move when it passes through a drawing of it."""
    width, height = canvas(skin_id)
    control = control_sheet(clip_poses(skin_id, name, specs, rig, library), rig)
    mask = Image.new("RGB", control.size, "white")
    frames = int(spec["frames"])
    pins: dict[int, Image.Image] = {}
    anchors = spec.get("anchors", {})
    if "first" in anchors:
        pins[0] = anchor_image(skin_id, anchors["first"], specs, draft)
    if "last" in anchors:
        pins[frames - 1] = anchor_image(skin_id, anchors["last"], specs, draft)
    for index, path in spec.get("drawn", {}).items():
        pins[int(index)] = Image.open(SKINS / skin_id / path).convert("RGB")
    black = Image.new("RGB", (width, height), "black")
    for index, picture in pins.items():
        row, column = divmod(index, COLUMNS)
        control.paste(picture.resize((width, height), Image.LANCZOS), (column * width, row * height))
        mask.paste(black, (column * width, row * height))
    return control, mask


def keypose(skin_id: str, clip: str, frame: int, comfy: Comfy, candidates: int, pick: int | None) -> None:
    """Draw the character on one frame's skeleton of a clip, like the reference is drawn on the rest pose, to pin as a
    key in that clip (its `drawn`). --pick keeps a candidate as skins/<id>/keys/<clip>-<frame>.png."""
    skin = load_skin(skin_id)
    specs = clip_specs(skin)
    rig = rigmod.load_rig(skin_id)
    folder = cache(skin_id, "keys", "x").parent
    if pick is not None:
        chosen = folder / f"{clip}-{frame}-candidate-{pick}.png"
        target = SKINS / skin_id / "keys" / f"{clip}-{frame}.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(chosen, target)
        print(f"kept {chosen.name} as {target}; pin it with \"drawn\": {{\"{frame}\": \"keys/{target.name}\"}}")
        return
    pose = clip_poses(skin_id, clip, specs, rig, rigmod.load_animations(skin_id))[frame]
    spec = skin.get("reference", {})
    width, height = canvas(skin_id)
    scale = float(spec.get("scale_up", 2))
    big = (round(width * scale / 8) * 8, round(height * scale / 8) * 8)
    # Drawn on the whole canvas, a pose that leaves most of it empty came back with a second girl in the space. The
    # key is drawn in a window around the skeleton instead (as wide as tall, which is the figure's natural frame), then
    # pasted back where the window was, on white, so the pinned frame still lines up with the clip's other frames.
    xs = [rigmod.to_canvas(p, rig, *big)[0] for p in pose.values()]
    middle = (min(xs) + max(xs)) / 2
    window_w = min(big[0], round(big[1] * 0.92 / 64) * 64)
    x0 = int(max(0, min(big[0] - window_w, round(middle - window_w / 2))))
    skeleton = rigmod.draw_pose(pose, rig, *big).crop((x0, 0, x0 + window_w, big[1]))
    character = skin["character"]
    if "key_expression" in specs[clip]:
        character = character.replace("small smile", specs[clip]["key_expression"])
    graph = Graph("reference")
    graph.set("rw:pose", image=comfy.upload(skeleton, f"{skin_id}-{clip}-{frame}-pose.png"))
    graph.set("rw:positive", text=style(skin, "prefix") + "solo, " + character + ", " + specs[clip].get("key_prompt", "")
              + style(skin, "suffix"))
    graph.set("rw:negative", text=style(skin, "negative"))
    graph.set("rw:control", strength=float(spec.get("control", 1.0)), end_percent=float(spec.get("control_end", 0.85)))
    graph.set("rw:detail", strength_model=float(spec.get("detail", 0.6)), strength_clip=float(spec.get("detail", 0.6)))
    graph.set("rw:empty", width=window_w, height=big[1])
    graph.set("rw:sampler", steps=int(spec.get("steps", 30)), cfg=float(spec.get("cfg", 5.5)), denoise=1.0)
    graph.link("rw:sampler", "latent_image", "rw:empty")
    graph.remove("rw:source", "rw:source-size", "rw:encode", "rw:save")
    seed = int(spec.get("seed", 1000))
    shots = []
    for index in range(candidates):
        graph.set("rw:sampler", seed=seed + index)
        graph.set("rw:save-clean", filename_prefix=f"rootward/{skin_id}/{clip}-{frame}-{index}")
        drawn = comfy.run(graph)["rw:save-clean"][0].convert("RGB")
        image = Image.new("RGB", big, "white")
        image.paste(drawn, (x0, 0))
        image.save(folder / f"{clip}-{frame}-candidate-{index}.png")
        shots.append(image)
        print(f"candidate {index} (seed {seed + index})", flush=True)
    thumb = 300
    tall = round(thumb * big[1] / big[0])
    sheet = Image.new("RGB", (thumb * (len(shots) + 1), tall + 24), "white")
    draw = ImageDraw.Draw(sheet)
    sheet.paste(reference_image(skin_id).resize((thumb, tall)), (0, 24))
    draw.text((6, 4), "reference", fill="black")
    for index, shot in enumerate(shots):
        sheet.paste(shot.resize((thumb, tall)), ((index + 1) * thumb, 24))
        draw.text(((index + 1) * thumb + 6, 4), f"candidate {index}", fill="black")
    sheet.save(folder / f"{clip}-{frame}-candidates.png")
    print(f"compare {folder / f'{clip}-{frame}-candidates.png'}, then: keypose {skin_id} {clip} {frame} --pick <n>")


def clip_seed(skin: dict, name: str, spec: dict) -> int:
    if "seed" in spec:
        return int(spec["seed"])
    # A stable per-clip offset, so re-rendering one clip does not change another's.
    offset = int(hashlib.sha1(name.encode()).hexdigest()[:6], 16) % 10000
    return int(skin.get("animate", {}).get("seed", 7000)) + offset


def animate(
    skin_id: str, comfy: Comfy, names: list[str] | None, force: bool, deps: bool, draft: bool = False,
    seed_override: int | None = None,
) -> None:
    """Render clips. A draft runs the 8-step CausVid sampler into `drafts/`, leaving the shipped renders alone, to see
    whether a re-keyed motion reads before spending the full render on it (about a third of the time)."""
    skin = load_skin(skin_id)
    specs = clip_specs(skin)
    unknown = [n for n in names or [] if n not in specs]
    if unknown:
        raise SystemExit(f"unknown clips {unknown}; known: {', '.join(specs)}")
    wanted = names or list(specs)
    queue = order(wanted, specs) if deps or not names else wanted
    rig = rigmod.load_rig(skin_id)
    library = rigmod.load_animations(skin_id)
    width, height = canvas(skin_id)
    settings = dict(skin.get("animate", {}))
    if draft:
        settings.update({"speed": 0.7, "steps": 8, "cfg": 1.0})
    folder = ("drafts", "sheets") if draft else ("sheets",)
    raw_folder = ("drafts", "raw") if draft else ("raw",)
    reference = reference_image(skin_id)
    reference_name = comfy.upload(reference, f"{skin_id}-reference.png")
    for name in queue:
        spec = specs[name]
        sheet_path = cache(skin_id, *folder, f"{name}.png")
        if sheet_path.exists() and not force and name not in (names or []):
            print(f"{name}: already rendered (pass --force to redo)")
            continue
        frames = int(spec["frames"])
        if (frames - 1) % 4:
            raise SystemExit(f"{name}: frames must be 4n+1 for the video model, not {frames}")
        graph = Graph("animate_keys")
        control, mask = pinned_control(skin_id, name, spec, specs, rig, library, draft)
        graph.set("rw:poses", image=comfy.upload(control, f"{skin_id}-{name}-poses.png"))
        graph.set("rw:mask-sheet", image=comfy.upload(mask, f"{skin_id}-{name}-mask.png"))
        graph.set("rw:frames", columns=COLUMNS, frames=frames)
        graph.set("rw:mask-frames", columns=COLUMNS, frames=frames)
        graph.set("rw:reference", image=reference_name)
        anchors = spec.get("anchors", {})
        motion = spec.get("motion", "")
        graph.set("rw:positive", text=f"{skin['character']}, {motion}{style(skin, 'motion_suffix')}")
        graph.set("rw:negative", text=style(skin, "motion_negative"))
        # A clip can ask for a gentler hand than the skin's default: a collapse is far from anything the model has seen,
        # and a hard-steered unusual skeleton comes back with its bones drawn in.
        strength = float(spec.get("strength", settings.get("strength", 1.0)))
        graph.set("rw:vace", width=width, height=height, length=frames, strength=strength)
        seed = clip_seed(skin, name, spec) if seed_override is None else seed_override
        speed = float(settings.get("speed", 0.0))
        graph.set("rw:speed", strength_model=speed)
        graph.set(
            "rw:sampler",
            seed=seed,
            steps=int(settings.get("steps", 8 if speed > 0 else 24)),
            cfg=float(settings.get("cfg", 1.0 if speed > 0 else 5.0)),
        )
        graph.set("rw:shift", shift=float(settings.get("shift", 8.0)))
        graph.set("rw:sheet", columns=COLUMNS)
        graph.set("rw:raw-sheet", columns=COLUMNS)
        graph.set("rw:save", filename_prefix=f"rootward/{skin_id}/{name}")
        graph.set("rw:save-raw", filename_prefix=f"rootward/{skin_id}/{name}-raw")
        print(f"{name}: {frames} frames, seed {seed} ...", flush=True)
        started = time.monotonic()
        out = comfy.run(graph)
        out["rw:save"][0].save(sheet_path)
        out["rw:save-raw"][0].convert("RGB").save(cache(skin_id, *raw_folder, f"{name}.png"))
        if draft:
            # Keep every draft by its seed too, so several can be compared side by side.
            out["rw:save"][0].save(cache(skin_id, "drafts", "by-seed", f"{name}-{seed}.png"))
        upscale = float(settings.get("upscale", 1.0)) if not draft else 1.0
        interpolate = int(spec.get("interpolate", 1)) if not draft else 1
        if upscale > 1.0 or interpolate > 1:
            finish(comfy, skin_id, name, frames, upscale, interpolate, width, height,
                   cache(skin_id, *raw_folder, f"{name}.png"), sheet_path)
        cache(skin_id, "drafts" if draft else "renders", f"{name}.json").write_text(json.dumps({
            "seed": seed, "frames": frames, "seconds": round(time.monotonic() - started),
            "interpolate": int(spec.get("interpolate", 1)) if not draft else 1,
            "upscale": float(settings.get("upscale", 1.0)) if not draft else 1.0,
            "settings": settings, "anchors": anchors, "motion": motion,
            "rendered": time.strftime("%Y-%m-%dT%H:%M:%S"),
        }, indent=2) + "\n")
        print(f"{name}: done in {time.monotonic() - started:.0f}s -> {sheet_path}", flush=True)


def finish(comfy: Comfy, skin_id: str, name: str, frames: int, upscale: float, interpolate: int, width: int, height: int,
           raw_path: Path, sheet_path: Path) -> None:
    """Higher fidelity after the video model (ADR-0031): Real-ESRGAN redraws the clip's frames at 4x, scaled to `upscale`
    times the canvas, then RIFE adds in-between frames and the matte is cut again on the finished frames.

    The upscale runs eight frames at a time. Run on a whole 41-frame clip inside the animation graph, it held every
    4x frame at once on top of the cached video models, and the kernel killed ComfyUI at 26.6 GB. The raw sheet stays at
    canvas size and frame count, because other clips' anchors are read from it."""
    raw = frames_of(Image.open(raw_path), frames)
    size = (round(width * upscale), round(height * upscale))
    if upscale > 1.0:
        finished: list[Image.Image] = []
        for start in range(0, len(raw), COLUMNS):
            chunk = raw[start:start + COLUMNS]
            graph = Graph("upscale")
            graph.set("rw:frames-in", image=comfy.upload(grid(chunk), f"{skin_id}-{name}-up{start}.png"))
            graph.set("rw:cut", columns=COLUMNS, frames=len(chunk))
            graph.set("rw:downscale", width=size[0], height=size[1])
            graph.set("rw:save", filename_prefix=f"rootward/{skin_id}/{name}-up")
            finished += frames_of(comfy.run(graph)["rw:save"][0].convert("RGB"), len(chunk))
    else:
        finished = raw
    graph = Graph("finish")
    graph.set("rw:frames-in", image=comfy.upload(grid(finished), f"{skin_id}-{name}-finish.png"))
    graph.set("rw:cut", columns=COLUMNS, frames=len(finished))
    if interpolate > 1:
        graph.set("rw:interp", multiplier=interpolate)
    else:
        graph.link("rw:matte", "image", "rw:cut")
        graph.remove("rw:interp-model", "rw:interp")
    graph.set("rw:save", filename_prefix=f"rootward/{skin_id}/{name}-finished")
    comfy.run(graph)["rw:save"][0].save(sheet_path)
    print(f"{name}: finished at {size[0]}x{size[1]}, {(frames - 1) * interpolate + 1} frames", flush=True)


def grid(frames: list[Image.Image]) -> Image.Image:
    """Frames laid out as a sheet of COLUMNS, the way the Rootward nodes cut them."""
    columns = min(COLUMNS, len(frames))
    rows = -(-len(frames) // columns)
    w, h = frames[0].size
    sheet = Image.new(frames[0].mode, (columns * w, rows * h))
    for index, frame in enumerate(frames):
        sheet.paste(frame, ((index % columns) * w, (index // columns) * h))
    return sheet


# --- build ------------------------------------------------------------------------------------------------------------


def frames_of(sheet: Image.Image, count: int) -> list[Image.Image]:
    """A grid sheet's frames. The cell size is read from the sheet, so an upscaled sheet cuts as easily as a raw one."""
    columns = min(COLUMNS, count)
    rows = -(-count // columns)
    width, height = sheet.width // columns, sheet.height // rows
    return [
        sheet.crop(((i % COLUMNS) * width, (i // COLUMNS) * height, (i % COLUMNS + 1) * width, (i // COLUMNS + 1) * height))
        for i in range(count)
    ]


def clean_alpha(frame: Image.Image, floor: int, ceil: int) -> Image.Image:
    """Level the matte so the body is fully opaque and the background fully gone; keep the soft edge between."""
    rgba = np.asarray(frame.convert("RGBA")).astype(np.float32)
    alpha = np.clip((rgba[..., 3] - floor) / max(1, ceil - floor), 0.0, 1.0)
    rgba[..., 3] = alpha * 255.0
    return Image.fromarray(rgba.round().astype(np.uint8), "RGBA")


def lowest_row(frame: Image.Image) -> int | None:
    alpha = np.asarray(frame)[..., 3] > 128
    rows = np.nonzero(alpha.any(axis=1))[0]
    return int(rows[-1]) if len(rows) else None


def ground(frames: list[Image.Image], feet: int, reach: int = 40) -> tuple[list[Image.Image], int]:
    """Put every frame's lowest opaque row on the rig's ground line.

    The video model keeps a character's shape well and its *position* less well: across a slow idle it can lift the
    whole figure a dozen pixels, feet and all, which reads as floating. Every clip here keeps its feet on the floor
    (even the death ends kneeling), so the soles are the one thing that must not move. A shift larger than `reach` is
    left alone, because that is a matte failure to fix, not drift to hide."""
    out: list[Image.Image] = []
    worst = 0
    for frame in frames:
        low = lowest_row(frame)
        shift = 0 if low is None else feet - low
        if abs(shift) > reach:
            shift = 0
        worst = max(worst, abs(shift))
        if shift:
            moved = Image.new("RGBA", frame.size, (0, 0, 0, 0))
            moved.paste(frame, (0, shift))
            frame = moved
        out.append(frame)
    return out, worst


def shipped_indices(spec: dict, frames: int | None = None) -> list[int]:
    """A loop pinned to one picture at both ends draws that picture twice; playing both would stall on the seam."""
    frames = int(spec["frames"]) if frames is None else frames
    anchors = spec.get("anchors", {})
    closes = spec.get("loop") and anchors.get("first") is not None and anchors.get("first") == anchors.get("last")
    return list(range(frames - 1 if closes else frames))


def build(skin_id: str) -> dict:
    skin = load_skin(skin_id)
    specs = clip_specs(skin)
    rig = rigmod.load_rig(skin_id)
    library = rigmod.load_animations(skin_id)
    width, height = canvas(skin_id)
    ship_w, ship_h = skin.get("ship", {}).get("frame", [400, 350])
    matte = skin.get("matte", {})
    out_dir = OUT / skin_id
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_clips: dict[str, dict] = {}
    fallbacks: dict[str, str] = {}
    # Where the reference drawing's soles are: the ground line every frame is pinned to, and the stage's baseline.
    soles = figure_bbox(reference_image(skin_id))[3] - 1
    for name, spec in specs.items():
        sheet_path = CACHE / skin_id / "sheets" / f"{name}.png"
        if not sheet_path.exists():
            if spec.get("fallback"):
                fallbacks[name] = spec["fallback"]
            print(f"{name}: not rendered yet, skipped")
            continue
        render_path = CACHE / skin_id / "renders" / f"{name}.json"
        render = json.loads(render_path.read_text()) if render_path.exists() else {}
        multiplier = int(render.get("interpolate", 1))
        # RIFE puts multiplier - 1 frames between each rendered pair: (n - 1) * m + 1 in all.
        total = (int(spec["frames"]) - 1) * multiplier + 1
        drawn = frames_of(Image.open(sheet_path), total)
        keep = shipped_indices(spec, total)
        cell_h = drawn[0].height
        cleaned = [clean_alpha(drawn[i], int(matte.get("alphaFloor", 8)), int(matte.get("alphaCeil", 235))) for i in keep]
        if spec.get("grounded", True):
            cleaned, drift = ground(cleaned, round((soles + 1) * cell_h / height) - 1, reach=round(40 * cell_h / height))
            if drift:
                print(f"{name}: feet pinned to the ground line (they drifted up to {drift}px)")
        frames = [frame.resize((ship_w, ship_h), Image.LANCZOS) for frame in cleaned]
        columns = min(COLUMNS, len(frames))
        rows = -(-len(frames) // columns)
        grid = Image.new("RGBA", (columns * ship_w, rows * ship_h), (0, 0, 0, 0))
        for index, frame in enumerate(frames):
            grid.paste(frame, ((index % columns) * ship_w, (index // columns) * ship_h))
        # LEARN: lossy WebP keeps alpha and is about a quarter of the PNG; at quality 90 the loss is below what the
        # stage's own resampling blurs away, and a skin is eleven sheets of this.
        grid.save(out_dir / f"{name}.webp", quality=90, method=6, alpha_quality=90)
        count = len(frames)
        last = count - 1

        poses = clip_poses(skin_id, name, specs, rig, library)
        spec = resolved(spec, poses)

        def at(fraction: float) -> int:
            return max(0, min(last, round(fraction * (total - 1))))

        entry: dict = {"frames": count, "columns": columns, "fps": float(spec["fps"]) * multiplier,
                       "loop": bool(spec.get("loop"))}
        for key in ("after", "hold", "blend", "idleAfterMs", "bakedFx"):
            if key in spec:
                entry[key] = spec[key]
        if "phases" in spec:
            entry["phases"] = {phase: [at(a), at(b)] for phase, (a, b) in spec["phases"].items()}
        if "release" in spec:
            entry["releaseFrame"] = at(float(spec["release"]))
        which = spec.get("hand", "far")
        sides = ["r", "l"] if which == "both" else [rigmod.SIDES[which]]
        hand = []
        for shipped in keep:
            # A shipped frame between two rendered ones (RIFE) takes its hand from between their two skeletons.
            where = shipped / multiplier
            low = min(int(where), len(poses) - 1)
            pose = blend_pose(poses[low], poses[min(low + 1, len(poses) - 1)], where - low)
            # The palm when the clip drew hands (the middle finger's knuckle), else the wrist; "both" is the point
            # between the two, where a two-handed cast gathers.
            points = [pose.get(f"{side}_hand9", pose[f"{side}_wrist"]) for side in sides]
            middle = (sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points))
            x, y = rigmod.to_canvas(middle, rig, width, height)
            # Measured up from the bottom of the frame, which is where the stage stands the sprite (its placement's y is
            # the box's foot). It was measured from the rig's feet line, 4.5% higher, so spells left below the hand.
            hand.append([round((x - width / 2) / width, 4), round((height - y) / height, 4)])
        entry["hand"] = hand
        manifest_clips[name] = entry
        print(f"{name}: {count} frames, {columns}x{rows} grid -> {out_dir / f'{name}.webp'}")
    profile = SKINS / skin_id / skin.get("profile", "profile.png")
    if profile.exists():
        size = int(skin.get("profileSize", 512))
        Image.open(profile).convert("RGBA").resize((size, size), Image.LANCZOS).save(out_dir / "profile.png", optimize=True)
    else:
        # A skin always has a profile beside its spells: the reference's head and shoulders stand in.
        ref = reference_image(skin_id, 2)
        left, top, right, bottom = figure_bbox(ref)
        side = round((bottom - top) * 0.55)
        middle = (left + right) // 2
        ref.crop((middle - side // 2, top, middle + side // 2, top + side)).resize((512, 512), Image.LANCZOS).save(
            out_dir / "profile.png", optimize=True
        )
    manifest = {
        "id": skin_id,
        "name": skin["name"],
        "accent": skin["accent"],
        "frame": {"width": ship_w, "height": ship_h},
        "format": "webp",
        "baseline": round((soles + 1) / height, 4),
        "center": rig["center"],
        "figure": rig["figure"],
        "clips": manifest_clips,
        "fallbacks": fallbacks,
    }
    if "fx" in skin:
        manifest["fx"] = skin["fx"]
    if "casts" in skin:
        # The skin names its own casts (ADR-0030); a name with no rendered clip would leave a spell with no motion.
        casts = skin["casts"]
        missing = [n for n in [*casts["light"], casts["heavy"]] if n not in manifest_clips and n not in fallbacks]
        if missing:
            print(f"warning: casts {missing} are not rendered yet; those spells will play no cast")
        manifest["casts"] = casts
    (out_dir / "clips.json").write_text(compact_json(manifest) + "\n")
    print(f"wrote {out_dir / 'clips.json'} with {len(manifest_clips)} clips")
    return manifest


def compact_json(value: object) -> str:
    """Indented JSON with every short list on one line, so a hand track is a column of pairs rather than a scroll."""
    import re

    text = json.dumps(value, indent=2)
    return re.sub(r"\[\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]", r"[\1, \2]", text)


# --- preview ----------------------------------------------------------------------------------------------------------


def preview(skin_id: str) -> None:
    """A contact sheet (8 frames of every clip) and a page that plays the built clips at their real frame rates."""
    manifest = json.loads((OUT / skin_id / "clips.json").read_text())
    fw, fh = manifest["frame"]["width"], manifest["frame"]["height"]
    thumb_w, thumb_h = fw // 2, fh // 2
    names = list(manifest["clips"])
    sheet = Image.new("RGB", (thumb_w * 8 + 120, thumb_h * len(names)), (40, 40, 48))
    draw = ImageDraw.Draw(sheet)
    for row, name in enumerate(names):
        clip = manifest["clips"][name]
        grid = Image.open(OUT / skin_id / f"{name}.{manifest.get('format', 'png')}")
        draw.text((6, row * thumb_h + 6), name, fill="white")
        for slot in range(8):
            index = round(slot * (clip["frames"] - 1) / 7)
            column, line = index % clip["columns"], index // clip["columns"]
            frame = grid.crop((column * fw, line * fh, (column + 1) * fw, (line + 1) * fh)).resize((thumb_w, thumb_h))
            sheet.paste(frame, (120 + slot * thumb_w, row * thumb_h), frame)
    contact = cache(skin_id, "contact.png")
    sheet.save(contact)
    rows = "\n".join(
        f'<figure><div class="clip" data-clip="{n}"></div><figcaption>{n} &middot; {c["frames"]}f @ {c["fps"]}fps'
        f'{" loop" if c["loop"] else ""}</figcaption></figure>'
        for n, c in manifest["clips"].items()
    )
    page = f"""<!doctype html><meta charset="utf-8"><title>{manifest['name']} clips</title>
<style>body{{background:#20202a;color:#ddd;font:14px system-ui;display:flex;flex-wrap:wrap;gap:12px;padding:12px}}
figure{{margin:0;background:#2c2c38;padding:8px;border-radius:8px}}
.clip{{width:{fw}px;height:{fh}px;background-repeat:no-repeat}}</style>
{rows}
<script>
const manifest = {json.dumps(manifest)};
const base = {json.dumps(str((OUT / skin_id).resolve()))};
for (const el of document.querySelectorAll('.clip')) {{
  const c = manifest.clips[el.dataset.clip], rows = Math.ceil(c.frames / c.columns);
  el.style.backgroundImage = `url("file://${{base}}/${{el.dataset.clip}}.${{manifest.format || 'png'}}")`;
  el.style.backgroundSize = `${{c.columns * 100}}% ${{rows * 100}}%`;
  let i = 0;
  setInterval(() => {{
    i = (i + 1) % (c.frames + (c.loop ? 0 : 8));
    const f = Math.min(i, c.frames - 1), col = f % c.columns, row = Math.floor(f / c.columns);
    el.style.backgroundPosition = `${{c.columns > 1 ? col / (c.columns - 1) * 100 : 0}}% ${{rows > 1 ? row / (rows - 1) * 100 : 0}}%`;
  }}, 1000 / c.fps);
}}
</script>"""
    html = cache(skin_id, "clips.html")
    html.write_text(page)
    print(f"contact sheet {contact}\nplay every clip: {html}")


# --- cli --------------------------------------------------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--comfy", default="http://127.0.0.1:8188")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("setup")
    p = sub.add_parser("poses")
    p.add_argument("skin")
    p.add_argument("clips", nargs="*")
    p = sub.add_parser("reference")
    p.add_argument("skin")
    p.add_argument("--candidates", type=int, default=4)
    p.add_argument("--pick", type=int)
    p = sub.add_parser("keypose")
    p.add_argument("skin")
    p.add_argument("clip")
    p.add_argument("frame", type=int)
    p.add_argument("--candidates", type=int, default=4)
    p.add_argument("--pick", type=int)
    p = sub.add_parser("profile")
    p.add_argument("skin")
    p.add_argument("--candidates", type=int, default=4)
    p.add_argument("--pick", type=int)
    p = sub.add_parser("animate")
    p.add_argument("skin")
    p.add_argument("clips", nargs="*")
    p.add_argument("--force", action="store_true", help="re-render dependencies that already have a sheet")
    p.add_argument("--deps", action="store_true", help="also render the clips a named clip is anchored to")
    p.add_argument("--draft", action="store_true", help="8-step sampler into drafts/, leaving shipped renders alone")
    p.add_argument("--seed", type=int, help="render with this seed instead of the clip's own")
    p = sub.add_parser("build")
    p.add_argument("skin")
    p = sub.add_parser("preview")
    p.add_argument("skin")
    args = parser.parse_args()
    comfy = Comfy(args.comfy)
    if args.command == "setup":
        setup(comfy)
    elif args.command == "poses":
        poses(args.skin, args.clips or None)
    elif args.command == "reference":
        reference(args.skin, comfy, args.candidates, args.pick)
    elif args.command == "keypose":
        keypose(args.skin, args.clip, args.frame, comfy, args.candidates, args.pick)
    elif args.command == "profile":
        profile(args.skin, comfy, args.candidates, args.pick)
    elif args.command == "animate":
        animate(args.skin, comfy, args.clips or None, args.force, args.deps, args.draft, args.seed)
    elif args.command == "build":
        build(args.skin)
    elif args.command == "preview":
        preview(args.skin)


if __name__ == "__main__":
    main()
