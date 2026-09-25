"""Vesper's head: a lofted skull with a small anime nose and ears, and the concept's face drawn onto it.

The face (eyes, brows' ends, nose dot, mouth, blush) is the head sheet's own drawing, lifted onto a clean skin-coloured
texture and projected straight from the front: on a face this flat the projection barely stretches, and it keeps the
exact eyes of the concept. Everything outside the features is plain skin, so the sides and back of the head (under the
hair) take the skin tone without smearing.
"""

from __future__ import annotations

from pathlib import Path

import bpy
import numpy as np

from . import anatomy as A
from .sdf import Ellipsoid, Loft, Mirror, RoundCone, SUnion, frame

# (z, half width, front depth, back depth, centre y, exponent): chin to crown. Measured on the head sheet (front and
# profile) at 0.475 mm per pixel, with the nose softened: the drawing's profile nose would stand 4 cm proud in 3D.
HEAD_KEYS = [
    (1.3345, 0.004, 0.006, 0.006, -0.068, 2.0),
    (1.340, 0.016, 0.014, 0.012, -0.066, 2.0),
    (1.348, 0.028, 0.024, 0.024, -0.058, 2.1),
    (1.357, 0.040, 0.038, 0.040, -0.046, 2.1),
    (1.366, 0.050, 0.051, 0.054, -0.034, 2.2),
    (1.376, 0.058, 0.064, 0.066, -0.021, 2.2),
    (1.391, 0.066, 0.078, 0.078, -0.009, 2.3),
    (1.406, 0.072, 0.082, 0.085, 0.000, 2.3),
    (1.421, 0.077, 0.084, 0.089, 0.006, 2.3),
    (1.441, 0.080, 0.085, 0.091, 0.010, 2.3),
    (1.466, 0.083, 0.089, 0.093, 0.012, 2.25),
    (1.496, 0.0805, 0.088, 0.091, 0.012, 2.2),
    (1.503, 0.0790, 0.086, 0.089, 0.012, 2.2),
]

HEAD_SHEET = "Concept/vesper-star-script-witch/reference/head-front-left-profile.png"
# Where the head sheet's front face sits: its eye line and midline, and its scale (eyes 84 mm apart, 177 px).
SHEET_EYE = (438.5, 419.0)
SHEET_M_PER_PX = 0.084 / 177.0
# The face texture covers a 20 cm square of the front view.
FACE_X0, FACE_Z0, FACE_SIZE, FACE_PX = -0.10, 1.33, 0.20, 1024


# The cranium's dome above the brow is an ellipsoid (a loft closing to a point is a poor distance field, and the hair
# is an offset of this surface).
CRANIUM = ((0.0, 0.013, 1.470), (0.083, 0.090, 0.111))


def skull() -> SUnion:
    loft = Loft(HEAD_KEYS)
    cranium = Ellipsoid(*CRANIUM)
    nose = RoundCone((0.0, -0.079, 1.421), (0.0, -0.0935, 1.401), 0.0035, 0.0048)
    nose_wing = Ellipsoid((0.0, -0.084, 1.401), (0.011, 0.007, 0.006))
    # The ear lies flat against the head: thin across, tilted back a little at the top.
    ear = Ellipsoid((0.078, 0.042, 1.434), (0.017, 0.0085, 0.030), frame([0.0, 0.26, 0.97], [1.0, 0.0, 0.0]))
    return SUnion([SUnion([loft, cranium], 0.012), nose, nose_wing, ear, Mirror(ear)], 0.006)


def head(neck_bottom: float = 1.285) -> SUnion:
    neck = RoundCone((0.0, 0.019, neck_bottom), (0.0, 0.022, 1.40), 0.0335, 0.030)
    return SUnion([skull(), neck], 0.018)


def face_uv(verts: np.ndarray) -> np.ndarray:
    """The front projection: x across, z up, into the face texture's square."""
    u = (verts[:, 0] - FACE_X0) / FACE_SIZE
    v = (verts[:, 2] - FACE_Z0) / FACE_SIZE
    return np.stack([u, v], axis=1)


def _image_array(path: Path) -> np.ndarray:
    img = bpy.data.images.load(str(path), check_existing=True)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    # Blender stores rows bottom-up; flip so row 0 is the top, as in the sheet's pixel coordinates.
    return px.reshape(h, w, 4)[::-1].copy()


def _ellipse(xx, yy, cx, cy, rx, ry, feather):
    r = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    return np.clip((1.0 - r) * min(rx, ry) / feather, 0.0, 1.0)


def _rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, (g - b) / d % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6.0
    s = d / (mx + 1e-6)
    return h, s, mx


def face_texture(root: Path, out: Path) -> tuple[bpy.types.Image, tuple[float, float, float]]:
    """The face texture: the sheet's eyes, nose, mouth and blush on flat skin, 1024 px over 20 cm."""
    sheet = _image_array(root / HEAD_SHEET)
    H, W = sheet.shape[:2]
    # Sample: pixel (i, j) of the texture (row 0 at the top) is model (x, z), which is sheet (px, py).
    n = FACE_PX
    xs = FACE_X0 + (np.arange(n) + 0.5) / n * FACE_SIZE
    zs = FACE_Z0 + FACE_SIZE - (np.arange(n) + 0.5) / n * FACE_SIZE
    px = SHEET_EYE[0] + xs / SHEET_M_PER_PX
    py = SHEET_EYE[1] + (A.EYE_Z - zs) / SHEET_M_PER_PX
    xx, yy = np.meshgrid(px, py)
    rgb = _bilinear(sheet[..., :3], xx, yy)
    # Skin: the cheek between eye and mouth, away from the blush.
    skin = np.median(sheet[470:500, 400:420, :3].reshape(-1, 3), axis=0)
    # The features to keep, as soft masks in sheet pixels.
    keep = np.zeros_like(xx)
    for cx in (350.0, 527.0):
        keep = np.maximum(keep, _ellipse(xx, yy, cx, 413.0, 88.0, 52.0, 6.0))
    keep = np.maximum(keep, _ellipse(xx, yy, 440.0, 468.0, 18.0, 16.0, 5.0))
    keep = np.maximum(keep, _ellipse(xx, yy, 442.0, 538.0, 56.0, 16.0, 5.0))
    blush = np.maximum(
        _ellipse(xx, yy, 300.0, 478.0, 70.0, 34.0, 30.0), _ellipse(xx, yy, 580.0, 478.0, 70.0, 34.0, 30.0)
    )
    # Inside the eye masks, strands of the bangs and side locks are hair, not eye: purple, fairly bright, saturated,
    # and outside the irises.
    h, s, v = _rgb_to_hsv(rgb)
    irises = np.maximum(
        _ellipse(xx, yy, 356.0, 425.0, 30.0, 36.0, 3.0), _ellipse(xx, yy, 522.0, 425.0, 30.0, 36.0, 3.0)
    )
    hair = (h > 0.70) & (h < 0.86) & (s > 0.30) & (v > 0.42) & (irises < 0.5)
    keep = np.where(hair, 0.0, keep)
    # Blush is the drawing's pink over skin: keep it where the drawing is bright and unlined (no hair, no ink).
    keep = np.maximum(keep, blush * ((v > 0.72) & (s < 0.38)))
    out_rgb = skin[None, None, :] * (1 - keep[..., None]) + rgb * keep[..., None]
    img = bpy.data.images.get("VesperFace") or bpy.data.images.new("VesperFace", n, n, alpha=False)
    img.scale(n, n)
    rgba = np.concatenate([out_rgb, np.ones((n, n, 1))], axis=-1)[::-1].astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    out.parent.mkdir(parents=True, exist_ok=True)
    img.filepath_raw = str(out)
    img.file_format = "PNG"
    img.save()
    return img, tuple(float(c) for c in skin)


def _bilinear(img: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    H, W = img.shape[:2]
    x = np.clip(x, 0, W - 1.001)
    y = np.clip(y, 0, H - 1.001)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    a = img[y0, x0] * (1 - fx) + img[y0, x0 + 1] * fx
    b = img[y0 + 1, x0] * (1 - fx) + img[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


# The face's normals are bent toward those of an ellipsoid round the head (the usual anime-model trick): the toon light
# then falls across the face in one clean curve, with no shadow from the nose or the cheek.
FACE_ELLIPSOID = ((0.0, 0.028, 1.452), (0.16, 0.10, 0.16))


def face_normals(verts: np.ndarray, normals: np.ndarray) -> np.ndarray:
    c, r = (np.asarray(x) for x in FACE_ELLIPSOID)
    g = (verts - c) / (r * r)
    g /= np.linalg.norm(g, axis=1, keepdims=True)
    # Full strength on the face (front, between chin and brow), none at the back and the neck.
    front = np.clip((-verts[:, 1] + 0.0) / 0.05, 0.0, 1.0)
    height = np.clip((verts[:, 2] - (A.CHIN_Z - 0.004)) / 0.02, 0.0, 1.0)
    w = (front * height * 0.9)[:, None]
    n = normals * (1 - w) + g * w
    return n / np.linalg.norm(n, axis=1, keepdims=True)
