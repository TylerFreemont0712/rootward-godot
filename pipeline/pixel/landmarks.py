"""Small deterministic corrections to ComfyUI landmarks whose story needs an exact read.

The Root Gate keeps its generated stone-and-root silhouette, but its entrance must look sealed until the later reveal.
This hard-pixel overlay closes the cave mouth on every local build while leaving the original render and cache intact.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

from pixelkit import Palette


def rootgate_lattice_clasp_v1(image: Image.Image, palette: Palette) -> Image.Image:
    """Add a compact seam and clasp to imagegen's crossed-root lattice without laying a broad stone panel over it."""
    image = image.convert("RGBA")
    if image.size != (96, 96):
        raise ValueError(f"Root Gate candidate correction requires 96x96, got {image.width}x{image.height}")

    ink = palette.resolve("ink")
    bronze = palette.resolve("wood.3")
    gold = palette.resolve("gold.2")
    seam = palette.resolve("glow.3")
    glint = palette.resolve("glow.1")
    draw = ImageDraw.Draw(image)
    # The short, two-pixel seam grows down from the root knot into the lower stone negative space.
    draw.line([(47, 62), (47, 74)], fill=ink, width=1)
    draw.line([(48, 62), (48, 74)], fill=seam, width=1)
    # A small square latch marks the crossing as a closure while keeping the generated lattice visible around it.
    draw.rectangle((45, 56, 51, 62), fill=ink)
    draw.rectangle((46, 57, 50, 61), fill=bronze)
    draw.rectangle((47, 58, 49, 60), fill=gold)
    draw.point((48, 58), fill=glint)
    return image


def seal_rootgate(path: Path, palette: Palette) -> None:
    """Draw a closed rooted stone face and a faint seam over the generated Root Gate opening."""
    image = Image.open(path).convert("RGBA")
    if image.size != (96, 96):
        raise ValueError(f"{path}: Root Gate art must be 96x96, got {image.width}x{image.height}")

    ink = palette.resolve("ink")
    stone = [palette.resolve(f"stone.{shade}") for shade in range(4)]
    wood = [palette.resolve(f"wood.{shade}") for shade in range(4)]
    glow = [palette.resolve(f"glow.{shade}") for shade in range(4)]
    draw = ImageDraw.Draw(image)

    # The arch is a shallow, readable stone frame. The face fills the old negative space completely, so it can no
    # longer read as a cave even at the town's small logical resolution.
    draw.polygon(
        [
            (28, 88), (28, 59), (30, 52), (34, 46), (39, 42), (45, 39),
            (51, 39), (57, 42), (62, 46), (66, 52), (68, 59), (68, 88),
        ],
        fill=ink,
    )
    draw.polygon(
        [(31, 86), (31, 59), (33, 53), (37, 47), (42, 43), (48, 41), (54, 43), (59, 47), (63, 53), (65, 59), (65, 86)],
        fill=stone[2],
    )
    draw.polygon(
        [(34, 85), (34, 59), (36, 53), (40, 48), (44, 45), (48, 44), (52, 45), (56, 48), (60, 53), (62, 59), (62, 85)],
        fill=stone[3],
    )

    # Block seams and a few upper-left glints keep the sealed face in the same cool stone family as its arch.
    draw.line([(34, 57), (39, 56), (43, 57)], fill=stone[1], width=1)
    draw.line([(53, 57), (58, 56), (62, 58)], fill=stone[2], width=1)
    draw.line([(34, 68), (41, 67)], fill=stone[2], width=1)
    draw.line([(55, 67), (62, 68)], fill=stone[1], width=1)
    draw.line([(37, 52), (41, 48), (46, 46)], fill=stone[1], width=1)
    draw.line([(63, 60), (63, 70)], fill=stone[3], width=1)
    draw.line([(35, 83), (61, 83)], fill=stone[1], width=1)
    draw.rectangle((34, 86, 62, 88), fill=stone[2], outline=ink)
    draw.line([(35, 86), (61, 86)], fill=stone[1], width=1)

    # A hairline amber seam says there is light behind the seal without showing an opening or the chamber beyond.
    draw.line([(48, 47), (48, 53)], fill=glow[3], width=1)
    draw.line([(48, 64), (48, 84)], fill=glow[3], width=1)
    for point in ((48, 51), (48, 82)):
        draw.point(point, fill=glow[2])

    # One old root runs across the threshold and branches into the arch. Three nested strokes make a bark edge,
    # midtone and upper-left highlight at integer pixels, with no soft alpha or generated texture.
    roots = [
        [(25, 60), (32, 58), (38, 59), (44, 57), (49, 59), (56, 57), (64, 59), (71, 56)],
        [(38, 59), (38, 54), (42, 50)],
        [(49, 59), (50, 54), (53, 51)],
        [(56, 58), (57, 63), (63, 67)],
        [(44, 58), (43, 63), (38, 67)],
    ]
    for branch in roots:
        draw.line(branch, fill=wood[3], width=6)
        draw.line(branch, fill=wood[2], width=3)
    draw.line([(27, 58), (33, 57), (38, 58), (44, 56)], fill=wood[1], width=1)
    draw.line([(49, 58), (50, 53), (52, 51)], fill=wood[1], width=1)
    draw.line([(57, 62), (61, 66)], fill=wood[1], width=1)

    # The root knot is the seal's focal point. A tiny warm clasp keeps the seam visible where the roots meet.
    draw.rectangle((46, 56, 50, 61), fill=wood[3], outline=ink)
    draw.point((47, 57), fill=glow[3])
    draw.point((48, 58), fill=glow[2])

    image.save(path, optimize=True)
