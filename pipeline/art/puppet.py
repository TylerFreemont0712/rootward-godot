"""Draw a character frame by frame from the pose skeleton, instead of asking a diffusion model to redraw it.

Why this exists. A sprite sheet rendered by a diffusion model is twenty independent drawings that happen to share a
prompt: the coat is a slightly different coat in every cell, the silhouette breathes, and no two frames agree on where
the hand is. That is invisible in a contact sheet and impossible to miss at twelve frames a second. A puppet is the
other half of the trade. One description of the character -- proportions, colors, cloth -- is posed by the same
`poses.Pose` skeleton the ControlNet sheets use, so every frame is the same character by construction, the registration
is exact because the origin never moves, and the animation can have as many frames as the timing wants. It also knows
where the hand is in every frame, which is what lets a spell leave exactly where the sprite throws it
(`CAST_RIG` in apps/client/src/shardrun/skins.ts).

What it gives up is rendered detail: this is shape and palette work, not painting. It is drawn flat and large, shaded by
one light pass, then handed to the same pixel-art post-process as every diffusion render (`post_pose_strip` in
generate.py), so it lands in the game's palette with the game's outline.

Preview a sheet:  $PY pipeline/art/puppet.py prism-rig 1536 1536 /tmp/prism.png
"""

from __future__ import annotations

import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import poses
from poses import (
    L_ANKLE, L_ELBOW, L_HIP, L_KNEE, L_SHOULDER, L_WRIST, NECK, NOSE,
    R_ANKLE, R_EAR, R_ELBOW, R_EYE, R_HIP, R_KNEE, R_SHOULDER, R_WRIST,
)

Point = tuple[float, float]
Color = tuple[int, int, int]

# The figure is drawn this many times larger than it is wanted, so every edge is an average of many samples rather than
# a staircase. The pixel steps come later, from the palette and the downscale, where they are chosen on purpose.
SUPERSAMPLE = 6


def hex_rgb(value: str) -> Color:
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


def mix(a: Color, b: Color, t: float) -> Color:
    return (round(a[0] + (b[0] - a[0]) * t), round(a[1] + (b[1] - a[1]) * t), round(a[2] + (b[2] - a[2]) * t))


class Skin:
    """A character's colors and build. A new skin is this and nothing else: the rig, the poses and the timing are shared.

    `build` is in figure units, where 1.0 is the skeleton's full height, so changing the head size or the coat's hem
    reshapes the character without touching a single pose.
    """

    def __init__(self, *, colors: dict[str, str], build: dict[str, float] | None = None) -> None:
        self.c = {name: hex_rgb(value) for name, value in colors.items()}
        self.build = {
            "head_rx": 0.094, "head_ry": 0.114, "hair": 1.3,
            "coat_hem": 0.80, "coat_flare": 0.19, "shoulder": 0.115,
            "scarf": 1.0, "sleeve": 0.062, "boot": 0.072,
            **(build or {}),
        }

    def far(self, name: str) -> Color:
        """The same material on the side away from the viewer: pushed toward the shadow so the near limb reads in front."""
        return mix(self.c[name], self.c["shadow"], 0.28)


PRISM_ETCHER = Skin(
    colors={
        "shadow": "#191230",
        "hair": "#d9d0f0", "hair_dark": "#a696ca", "hair_light": "#f2ecff",
        "skin": "#f4d6bd", "skin_dark": "#d2a78c",
        "coat": "#2f3766", "coat_dark": "#1d2245", "coat_light": "#4a548c",
        "lining": "#b8324a", "lining_light": "#e0566c",
        "gold": "#e9c469", "gold_dark": "#a9813a",
        "leather": "#191d33", "leather_light": "#2d3352",
        "trouser": "#242a4a",
        "crystal": "#a855f7", "crystal_light": "#d8b4fe",
        "eye": "#f0a83c", "lens": "#fbf2e2",
        "sash": "#7c3aed", "sash_light": "#a78bfa",
    },
)


class Pen:
    """Drawing in figure units. `at` turns a skeleton point into a canvas pixel; everything else is built from that."""

    def __init__(self, draw: ImageDraw.ImageDraw, origin: Point, size: float) -> None:
        self.draw = draw
        self.ox, self.oy = origin
        self.size = size

    def at(self, p: Point) -> tuple[float, float]:
        return (self.ox + p[0] * self.size, self.oy + p[1] * self.size)

    def blob(self, center: Point, rx: float, ry: float, color: Color) -> None:
        x, y = self.at(center)
        rx, ry = rx * self.size, ry * self.size
        self.draw.ellipse((x - rx, y - ry, x + rx, y + ry), fill=color)

    def poly(self, points: list[Point], color: Color) -> None:
        self.draw.polygon([self.at(p) for p in points], fill=color)

    def limb(self, a: Point, b: Point, w0: float, w1: float, color: Color, *, cap: float = 1.0) -> None:
        """A bone as a tapered capsule: a quad along it, a round cap at each end so joints never show a corner.

        `cap=0` leaves the caps off, which is what a short band wants: at a band's proportions a round cap is wider
        than the band is long, and a cuff becomes a bangle."""
        (x0, y0), (x1, y1) = self.at(a), self.at(b)
        angle = math.atan2(y1 - y0, x1 - x0)
        nx, ny = -math.sin(angle), math.cos(angle)
        r0, r1 = w0 * self.size / 2, w1 * self.size / 2
        self.draw.polygon(
            [(x0 + nx * r0, y0 + ny * r0), (x1 + nx * r1, y1 + ny * r1),
             (x1 - nx * r1, y1 - ny * r1), (x0 - nx * r0, y0 - ny * r0)],
            fill=color,
        )
        for (x, y), r in (((x0, y0), r0 * cap), ((x1, y1), r1 * cap)):
            self.draw.ellipse((x - r, y - r, x + r, y + r), fill=color)

    def ribbon(self, points: list[Point], widths: list[float], color: Color) -> None:
        """A strip of cloth through a polyline, its width given per point: a scarf, a coat tail, a sleeve's fall."""
        for i in range(len(points) - 1):
            self.limb(points[i], points[i + 1], widths[i], widths[i + 1], color)

    def ring(self, center: Point, rx: float, ry: float, width: float, color: Color) -> None:
        x, y = self.at(center)
        rx, ry, w = rx * self.size, ry * self.size, max(1.0, width * self.size)
        self.draw.ellipse((x - rx, y - ry, x + rx, y + ry), outline=color, width=round(w))


# ---------------------------------------------------------------------------------------------------------------------
# The character


def head_center(pose: poses.Pose) -> Point:
    """Between the ear and the nose, lifted: the skeleton marks a face, and the skull sits above and behind it."""
    (nx, ny), (ex, ey) = pose[NOSE], pose[R_EAR]
    return (nx * 0.42 + ex * 0.58, (ny + ey) / 2 - 0.016)


def hip_mid(pose: poses.Pose) -> Point:
    (rx, ry), (lx, ly) = pose[R_HIP], pose[L_HIP]
    return ((rx + lx) / 2, (ry + ly) / 2)


def curve(a: Point, b: Point, bend: Point, steps: int) -> list[Point]:
    """A quadratic bend from a to b through the control point `bend`: cloth hangs on curves, not on straight lines."""
    out = []
    for i in range(steps + 1):
        t = i / steps
        u = 1 - t
        out.append((u * u * a[0] + 2 * u * t * bend[0] + t * t * b[0],
                    u * u * a[1] + 2 * u * t * bend[1] + t * t * b[1]))
    return out


def clamp_drift(drift: Point, limit: float = 0.04) -> Point:
    """Cloth trails the body, but only so far. Between two frames of a fast throw the neck can jump a tenth of the
    figure's height, and unclamped that flings a scarf clean off the character."""
    length = math.hypot(drift[0], drift[1])
    if length <= limit:
        return drift
    return (drift[0] * limit / length, drift[1] * limit / length)


def draw_leg(pen: Pen, skin: Skin, hip: Point, knee: Point, ankle: Point, *, near: bool) -> None:
    trouser = skin.c["trouser"] if near else skin.far("trouser")
    leather = skin.c["leather"] if near else skin.far("leather")
    b = skin.build
    pen.limb(hip, knee, 0.078, 0.060, trouser)
    pen.limb(knee, ankle, 0.060, 0.052, trouser)
    # A heavy boot whose toe reaches forward of the ankle. At this size the feet carry the whole stance, so they are
    # drawn a size up from anatomy: a small foot reads as a figure about to fall over.
    heel = (ankle[0] - 0.016, ankle[1] - 0.004)
    toe = (ankle[0] + b["boot"], ankle[1] - 0.002)
    pen.limb((ankle[0] - 0.008, ankle[1] - 0.072), heel, 0.070, 0.066, leather)
    pen.limb(heel, toe, 0.062, 0.044, leather)
    pen.limb((ankle[0] - 0.006, ankle[1] - 0.070), (ankle[0] + 0.026, ankle[1] - 0.070), 0.026, 0.022, skin.c["gold_dark"] if near else skin.far("gold_dark"), cap=0.0)
    pen.limb((heel[0] - 0.012, ankle[1] + 0.012), (toe[0] - 0.004, toe[1] + 0.012), 0.022, 0.018, skin.c["shadow"])


def draw_arm(pen: Pen, skin: Skin, shoulder: Point, elbow: Point, wrist: Point, *, near: bool, drift: Point) -> None:
    coat = skin.c["coat"] if near else skin.far("coat")
    coat_dark = skin.c["coat_dark"] if near else skin.far("coat_dark")
    lining = skin.c["lining"] if near else skin.far("lining")
    gold = skin.c["gold"] if near else skin.far("gold")
    glove = skin.c["leather"] if near else skin.far("leather")
    b = skin.build
    pen.limb(shoulder, elbow, 0.078, 0.064, coat)
    # The sleeve runs to a bell that starts short of the wrist and whose hem lags the hand. A wide sleeve is the
    # largest moving shape on a caster, and letting it arrive a frame late is most of what gives a throw weight.
    span = (wrist[0] - elbow[0], wrist[1] - elbow[1])
    cuff = (elbow[0] + span[0] * 0.62, elbow[1] + span[1] * 0.62)
    hem = (elbow[0] + span[0] * 0.98 - drift[0] * 1.4, elbow[1] + span[1] * 0.98 - drift[1] * 1.0 + 0.008)
    pen.limb(elbow, cuff, 0.064, 0.058, coat)
    pen.limb(cuff, hem, 0.058, b["sleeve"] * 1.45, coat)
    pen.limb(((cuff[0] + hem[0]) / 2, (cuff[1] + hem[1]) / 2), hem, 0.026, b["sleeve"] * 1.05, lining)
    run = max(1e-4, math.hypot(span[0], span[1]))
    edge = (hem[0] - span[0] / run * 0.014, hem[1] - span[1] / run * 0.014)
    pen.limb(edge, hem, b["sleeve"] * 1.42, b["sleeve"] * 1.46, gold, cap=0.0)
    reach = math.atan2(wrist[1] - elbow[1], wrist[0] - elbow[0])
    palm = (wrist[0] + math.cos(reach) * 0.008, wrist[1] + math.sin(reach) * 0.008)
    pen.limb(hem, palm, 0.038, 0.034, coat_dark)
    pen.blob(palm, 0.025, 0.025, glove)
    # Fingers opened toward the spell rather than closed in a fist: the far hand is the casting one, and it is where
    # every effect is anchored, so it is the one that must not be a mitten.
    for offset, length in ((-0.5, 0.028), (-0.16, 0.034), (0.2, 0.029)):
        tip = (palm[0] + math.cos(reach + offset) * length, palm[1] + math.sin(reach + offset) * length)
        pen.limb(palm, tip, 0.018, 0.011, glove)


def draw_coat_tail(pen: Pen, skin: Skin, pose: poses.Pose, drift: Point) -> None:
    """The back of the coat, drawn before the body so it reads as behind it: it hangs from the hips and swings late."""
    hips = hip_mid(pose)
    b = skin.build
    end = (hips[0] - 0.20 - drift[0] * 2.2, b["coat_hem"] + 0.015 - drift[1] * 1.2)
    spine = curve((hips[0] - 0.02, hips[1] - 0.04), end, (hips[0] - 0.15, hips[1] + 0.17), 6)
    pen.ribbon(spine, [0.175, 0.185, 0.185, 0.170, 0.145, 0.115, 0.085], skin.c["lining"])
    pen.ribbon([(x + 0.004, y - 0.014) for x, y in spine], [0.150, 0.158, 0.156, 0.142, 0.120, 0.094, 0.068], skin.c["coat_dark"])


def draw_coat(pen: Pen, skin: Skin, pose: poses.Pose, drift: Point) -> None:
    """The body of the coat: shoulders to a flaring hem, a lining showing at the hem and the chest, gold at the closure."""
    b = skin.build
    neck, hips = pose[NECK], hip_mid(pose)
    hem_y = b["coat_hem"]
    front = hips[0] + b["coat_flare"] * 0.66 + drift[0] * 1.4
    back = hips[0] - b["coat_flare"] * 0.80 - drift[0] * 1.0
    shoulder = b["shoulder"]
    # The crimson underside, a fraction larger, so the flaring hem shows its lining the way a real coat does.
    pen.poly(
        [(neck[0] - shoulder, neck[1] + 0.03), (neck[0] + shoulder * 0.94, neck[1] + 0.03),
         (hips[0] + 0.125, hips[1]), (front + 0.012, hem_y + 0.022), (hips[0] + 0.02, hem_y + 0.042),
         (back - 0.012, hem_y + 0.016), (hips[0] - 0.125, hips[1])],
        skin.c["lining"],
    )
    pen.poly(
        [(neck[0] - shoulder, neck[1] + 0.03), (neck[0] + shoulder * 0.94, neck[1] + 0.03),
         (hips[0] + 0.12, hips[1]), (front, hem_y), (hips[0] + 0.02, hem_y + 0.020),
         (back, hem_y - 0.004), (hips[0] - 0.12, hips[1])],
        skin.c["coat"],
    )
    # The closure: a lining panel down the chest with gold studs on it, instead of one long stripe that reads as a zip.
    chest = [(neck[0] + shoulder * 0.34, neck[1] + 0.045), (hips[0] + 0.055, hips[1] + 0.015)]
    pen.ribbon(chest, [0.072, 0.050], skin.c["lining"])
    for t in (0.18, 0.52, 0.86):
        pen.blob((chest[0][0] + (chest[1][0] - chest[0][0]) * t, chest[0][1] + (chest[1][1] - chest[0][1]) * t), 0.013, 0.013, skin.c["gold"])
    # A belt across the waist, and the crystal the character etches with hanging from it.
    pen.limb((hips[0] - 0.085, hips[1] - 0.006), (hips[0] + 0.095, hips[1] - 0.012), 0.046, 0.040, skin.c["leather"])
    pen.limb((hips[0] + 0.012, hips[1] - 0.010), (hips[0] + 0.058, hips[1] - 0.012), 0.034, 0.030, skin.c["gold"], cap=0.0)
    pen.limb((hips[0] + 0.090, hips[1] + 0.010), (hips[0] + 0.096, hips[1] + 0.052), 0.010, 0.008, skin.c["gold_dark"])
    pen.blob((hips[0] + 0.098, hips[1] + 0.076), 0.021, 0.030, skin.c["crystal"])
    pen.blob((hips[0] + 0.093, hips[1] + 0.066), 0.009, 0.013, skin.c["crystal_light"])


def draw_collar(pen: Pen, skin: Skin, pose: poses.Pose) -> None:
    """The high collar, drawn after the head so it stands in front of the jaw."""
    neck = pose[NECK]
    pen.limb((neck[0] - 0.058, neck[1] + 0.004), (neck[0] + 0.068, neck[1] - 0.014), 0.072, 0.058, skin.c["coat_light"])
    pen.limb((neck[0] + 0.014, neck[1] - 0.014), (neck[0] + 0.074, neck[1] - 0.022), 0.046, 0.032, skin.c["lining"])


def draw_scarf(pen: Pen, skin: Skin, pose: poses.Pose, drift: Point, phase: float) -> None:
    """A scarf hanging behind the shoulder. It lags the body and ripples, which is what makes a held pose look alive."""
    neck = pose[NECK]
    b = skin.build
    length = 0.34 * b["scarf"]
    points, widths = [], []
    for i in range(8):
        t = i / 7
        wave = math.sin(phase + t * 3.4) * 0.022 * t
        # Back quickly, then falling: a ribbon leaves the shoulder along the body's own line and only then gives in to
        # gravity, which is what stops it reading as a straight rod pinned to the back.
        points.append((
            neck[0] - 0.03 - length * (0.95 * t - 0.28 * t * t) - drift[0] * 3.0 * t * t,
            neck[1] - 0.05 + length * (1.35 * t * t + 0.12 * t) - drift[1] * 1.6 * t + wave,
        ))
        widths.append(0.068 * (1 - t) ** 0.55 + 0.013)
    pen.ribbon(points, widths, skin.c["sash"])
    pen.ribbon([(x + 0.006, y - 0.008) for x, y in points], [w * 0.42 for w in widths], skin.c["sash_light"])


def draw_head(pen: Pen, skin: Skin, pose: poses.Pose, drift: Point, phase: float) -> None:
    """A chibi head in three layers: the hair behind, the face, and the hair that falls in front of it.

    The order matters more than the shapes. Drawn the other way round the fringe swallows the face, and at 144 pixels
    a character without a visible face is a coloured shape rather than someone casting a spell.
    """
    b = skin.build
    c = head_center(pose)
    rx, ry = b["head_rx"], b["head_ry"]
    lag = (-drift[0] * 1.8, -drift[1] * 0.9)
    # 1. The mass of hair behind the skull, and the strands that hang off it.
    pen.blob((c[0] - rx * 0.44 + lag[0] * 0.4, c[1] + ry * 0.02), rx * 0.96, ry * 0.99, skin.c["hair_dark"])
    for k, (dx, dy, r) in enumerate(((-0.86, 0.62, 0.46), (-0.98, 1.02, 0.36), (-0.70, 1.30, 0.27))):
        sway = lag[0] * (0.7 + k * 0.6) + math.sin(phase + k * 1.3) * 0.005
        pen.blob((c[0] + rx * dx + sway, c[1] + ry * dy), rx * r, ry * r * 0.95, skin.c["hair_dark"])
    # 2. The face fills the front of the head: everything the hair does not cover is skin, not a circle inside a wig.
    face = (c[0] + rx * 0.26, c[1] + ry * 0.10)
    pen.blob(face, rx * 0.86, ry * 0.92, skin.c["skin"])
    pen.blob((face[0] - rx * 0.30, face[1] + ry * 0.18), rx * 0.70, ry * 0.80, skin.c["skin_dark"])
    pen.blob((face[0] - rx * 0.16, face[1] + ry * 0.04), rx * 0.78, ry * 0.86, skin.c["skin"])
    # 3. The hair cap over the crown, with a fringe that stops above the eye and a strand falling past the cheek.
    pen.blob((c[0] - rx * 0.02, c[1] - ry * 0.50), rx * 1.04, ry * 0.68, skin.c["hair"])
    for dx, tip, w in ((-0.62, -0.30, 0.058), (0.0, 0.34, 0.052), (0.55, 0.86, 0.042), (0.92, 1.04, 0.028)):
        pen.limb((c[0] + rx * dx, c[1] - ry * 0.78), (c[0] + rx * tip, c[1] - ry * 0.10), 0.066, w, skin.c["hair"])
    pen.limb((c[0] - rx * 0.80, c[1] - ry * 0.44), (c[0] - rx * 0.94 + lag[0], c[1] + ry * 0.78), 0.058, 0.038, skin.c["hair"])
    # The ahoge: two joined strands, so it curls instead of standing up like a wire.
    top = (c[0] - rx * 0.12, c[1] - ry * 1.00)
    mid = (top[0] - 0.020 + lag[0] * 1.4, top[1] - 0.034 + math.sin(phase) * 0.005)
    pen.limb(top, mid, 0.022, 0.013, skin.c["hair"])
    pen.limb(mid, (mid[0] + 0.026, mid[1] - 0.014), 0.013, 0.007, skin.c["hair_light"])
    # 4. The portrait's round gold glasses, an amber eye behind them, and a small mouth.
    eye = (c[0] + rx * 0.52, c[1] + ry * 0.12)
    pen.blob(eye, rx * 0.34, ry * 0.31, skin.c["lens"])
    pen.blob((eye[0] + rx * 0.02, eye[1] + ry * 0.02), rx * 0.15, ry * 0.17, skin.c["eye"])
    pen.blob((eye[0] + rx * 0.10, eye[1] - ry * 0.10), rx * 0.07, ry * 0.07, skin.c["hair_light"])
    pen.ring(eye, rx * 0.35, ry * 0.32, 0.011, skin.c["gold"])
    pen.limb((eye[0] + rx * 0.38, eye[1] - ry * 0.02), (eye[0] + rx * 0.66, eye[1] - ry * 0.10), 0.012, 0.009, skin.c["gold"])
    pen.limb((eye[0] - rx * 0.40, eye[1] - ry * 0.04), (c[0] - rx * 0.50, c[1] - ry * 0.06), 0.012, 0.009, skin.c["gold_dark"])
    pen.limb((eye[0] + rx * 0.14, eye[1] + ry * 0.60), (eye[0] + rx * 0.36, eye[1] + ry * 0.58), 0.014, 0.010, skin.c["skin_dark"])
    # The neck, joining the jaw to the collar that is drawn over it next.
    pen.limb((c[0] + rx * 0.14, c[1] + ry * 0.86), (pose[NECK][0], pose[NECK][1] + 0.01), 0.052, 0.058, skin.c["skin_dark"])


def draw_figure(pose: poses.Pose, previous: poses.Pose | None, skin: Skin, phase: float, canvas: Image.Image, origin: Point, size: float) -> None:
    """One frame, back to front. `previous` gives the cloth something to lag behind; `phase` keeps the idle alive."""
    pen = Pen(ImageDraw.Draw(canvas), origin, size)
    raw = (0.0, 0.0) if previous is None else (pose[NECK][0] - previous[NECK][0], pose[NECK][1] - previous[NECK][1])
    drift = clamp_drift(raw)
    draw_scarf(pen, skin, pose, drift, phase)
    draw_coat_tail(pen, skin, pose, drift)
    draw_arm(pen, skin, pose[L_SHOULDER], pose[L_ELBOW], pose[L_WRIST], near=False, drift=drift)
    draw_leg(pen, skin, pose[L_HIP], pose[L_KNEE], pose[L_ANKLE], near=False)
    draw_leg(pen, skin, pose[R_HIP], pose[R_KNEE], pose[R_ANKLE], near=True)
    draw_coat(pen, skin, pose, drift)
    draw_head(pen, skin, pose, drift, phase)
    draw_collar(pen, skin, pose)
    draw_arm(pen, skin, pose[R_SHOULDER], pose[R_ELBOW], pose[R_WRIST], near=True, drift=drift)


# ---------------------------------------------------------------------------------------------------------------------
# Light


def shade(cell: Image.Image) -> Image.Image:
    """One light pass over a flat drawing: a key light from above and in front, and a rim where the body faces it.

    LEARN: the surface normal of a flat shape can be read off its own silhouette. Blurring the alpha mask turns the
    hard edge into a ramp, and the gradient of that ramp points out of the body, so the same picture that says where
    the character is also says which way each edge is facing.
    """
    rgba = np.asarray(cell, dtype=np.float32) / 255
    alpha = rgba[..., 3]
    soft = np.asarray(Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(cell.width / 34)), dtype=np.float32) / 255
    gy, gx = np.gradient(soft)
    length = np.hypot(gx, gy)
    facing = np.where(length > 1e-4, (-gx * 0.62 + gy * 0.78) / np.maximum(length, 1e-4), 0.0)
    height = np.linspace(1.0, 0.0, cell.height, dtype=np.float32)[:, None]
    light = 0.86 + 0.20 * height + 0.34 * np.clip(facing, 0, 1) * np.clip(1 - soft * 1.25, 0, 1)
    light -= 0.26 * np.clip(-facing, 0, 1) * np.clip(1 - soft * 1.25, 0, 1)
    out = np.clip(rgba[..., :3] * light[..., None], 0, 1)
    return Image.fromarray((np.dstack([out, alpha]) * 255).astype(np.uint8), "RGBA")


# ---------------------------------------------------------------------------------------------------------------------
# Sheets


def prism_cells() -> list[tuple[poses.Pose, poses.Pose | None, float]]:
    """The Prism Etcher's twenty cells, in the order `poses.prism_sheet` lays them out."""
    flow = poses.sample_flow(poses.prism_cast_keys(), poses.PRISM_CAST_FRAMES, poses.PRISM_CAST_TIMING)
    cells: list[tuple[poses.Pose, poses.Pose | None, float]] = []
    for index, pose in enumerate(flow):
        # The frame before it in the flow is what the cloth is trailing; the first frame is at rest.
        cells.append((pose, flow[index - 1] if index > 0 else None, index * 0.62))
    for index, pose in enumerate(poses.prism_hold_poses()):
        cells.append((pose, None, index * 1.4))
    return cells


SHEETS = {"prism-rig": (prism_cells, PRISM_ETCHER, 5, 4, 0.78, -0.06)}


def sheet(name: str, width: int, height: int) -> Image.Image:
    """A grid of drawn cells, laid out exactly as `poses.sheet` lays out its skeletons, so the two are interchangeable."""
    if name not in SHEETS:
        raise ValueError(f"unknown puppet sheet {name!r}; known: {', '.join(SHEETS)}")
    cells_of, skin, columns, rows, figure, shift = SHEETS[name]
    cells = cells_of()
    image = Image.new("RGBA", (width * SUPERSAMPLE, height * SUPERSAMPLE), (0, 0, 0, 0))
    cell_w, cell_h = width * SUPERSAMPLE / columns, height * SUPERSAMPLE / rows
    size = cell_h * figure
    for index, (pose, previous, phase) in enumerate(cells):
        r, c = divmod(index, columns)
        ox = cell_w * (c + 0.5) + shift * size
        oy = cell_h * (r + 1) - cell_h * (1 - figure) * 0.4 - size
        frame = Image.new("RGBA", (round(cell_w), round(cell_h)), (0, 0, 0, 0))
        draw_figure(pose, previous, skin, phase, frame, (ox - cell_w * c, oy - cell_h * r), size)
        image.alpha_composite(shade(frame), (round(cell_w * c), round(cell_h * r)))
    return image.resize((width, height), Image.Resampling.LANCZOS)


def cell(name: str, index: int, px: int) -> Image.Image:
    """One cell on its own, at any size: the preview for working on the character rather than on the animation."""
    cells_of, skin, _, _, figure, _ = SHEETS[name]
    pose, previous, phase = cells_of()[index]
    image = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    size = px * figure
    draw_figure(pose, previous, skin, phase, image, (px * 0.46, px * (1 - figure) * 0.6), size)
    return shade(image)


# ---------------------------------------------------------------------------------------------------------------------
# The hand track


def hand_track(name: str, width: int, height: int, frame: tuple[int, int], count: int) -> dict[str, list[tuple[float, float]]]:
    """Where each hand is in the first `count` frames, in the coordinates the effects canvas uses.

    Two tracks, because the cast uses two hands: `focus` is the near hand, which holds the gathering spell out in front
    while the body coils, and `hand` is the far one, which is drawn back behind the shoulder and then thrown at the
    foe. Anchoring the gathering glyph to the near hand and the launch to the far one is what keeps the effect on the
    character instead of drifting off behind them.

    The client anchors a spell to the hand, and until now that was one constant offset guessed for one pose, so a
    bolt left the chest on half the frames. The puppet knows the answer exactly, and this repeats the registration
    `post_pose_strip` does (one crop box, one scale, feet on the bottom row) to say it in the strip's own frame.
    Printed by `puppet.py hands prism-rig`, and pasted into CAST_RIG in apps/client/src/shardrun/skins.ts.
    """
    cells_of, skin, columns, rows, figure, shift = SHEETS[name]
    cells = cells_of()
    frame_w, frame_h = frame
    pad = 1
    cell_w, cell_h = width * SUPERSAMPLE / columns, height * SUPERSAMPLE / rows
    size = cell_h * figure
    boxes, wrists = [], []
    for index, (pose, previous, phase) in enumerate(cells):
        canvas = Image.new("RGBA", (round(cell_w), round(cell_h)), (0, 0, 0, 0))
        origin = (cell_w * 0.5 + shift * size, cell_h - cell_h * (1 - figure) * 0.4 - size)
        draw_figure(pose, previous, skin, phase, canvas, origin, size)
        alpha = np.asarray(canvas, dtype=np.uint8)[..., 3] > 127
        ys, xs = np.nonzero(alpha)
        boxes.append((int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1))
        wrists.append(tuple(
            (origin[0] + pose[joint][0] * size, origin[1] + pose[joint][1] * size) for joint in (L_WRIST, R_WRIST)
        ))
    # The sheet is drawn supersampled and then resized whole, so every box shrinks by the same factor and the union
    # box, the scale and the anchor are the same numbers the strip's own registration arrives at.
    k = 1 / SUPERSAMPLE
    left = min(b[0] for b in boxes) * k
    right = max(b[1] for b in boxes) * k
    tallest = max(b[3] - b[2] for b in boxes) * k
    scale = min((frame_w - 2 * pad) / (right - left), (frame_h - 2 * pad) / tallest)
    tracks: dict[str, list[tuple[float, float]]] = {"hand": [], "focus": []}
    for (x0, x1, y0, y1), joints in zip(boxes, wrists):
        width_px = round((right - left) * scale)
        height_px = round((y1 - y0) * k * scale)
        for key, (wx, wy) in zip(("hand", "focus"), joints):
            ox = (frame_w - width_px) // 2 + (wx * k - left) * scale
            oy = frame_h - pad - height_px + (wy * k - y0 * k) * scale
            tracks[key].append((round((ox - frame_w / 2) / frame_w, 4), round((frame_h - oy) / frame_h, 4)))
    return {key: value[:count] for key, value in tracks.items()}


if __name__ == "__main__":
    if sys.argv[1] == "hands":
        for key, track in hand_track(sys.argv[2], 1536, 1536, (152, 144), int(sys.argv[3])).items():
            print(f"{key}: [" + ", ".join(f"[{x}, {y}]" for x, y in track) + "]")
    elif sys.argv[1] == "cell":
        cell(sys.argv[2], int(sys.argv[3]), int(sys.argv[4])).save(sys.argv[5])
    else:
        sheet(sys.argv[1], int(sys.argv[2]), int(sys.argv[3])).save(sys.argv[4])
