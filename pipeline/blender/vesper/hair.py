"""Vesper's short purple bob as one signed distance field, made of locks.

A helmet that follows her skull blends into a flared curtain (the bob's sides and back), made a shell a finger thick
so the inside of the bob shows from below. Around her head the surface is divided into 23 locks: each bulges out
between sharp valleys and ends in its own point at the hem, so the toon outline and light read as anime strands.

The face window is cut along lock valleys: the five front locks are the bangs (they end at her brow), the locks either
side of them hang past her cheeks to the jaw and frame the face, and the rest make the bob.
"""

from __future__ import annotations

import numpy as np

from . import head as H
from .sdf import Field, Loft, smax, smin

# The curtain: the bob below the ears, flaring toward the hem (z, half width, front, back, centre y, exponent).
CURTAIN_KEYS = [
    (1.490, 0.086, 0.048, 0.104, 0.022, 2.1),
    (1.455, 0.110, 0.058, 0.120, 0.022, 2.1),
    (1.410, 0.124, 0.064, 0.121, 0.022, 2.2),
    (1.360, 0.136, 0.070, 0.117, 0.022, 2.2),
    (1.320, 0.147, 0.075, 0.113, 0.022, 2.2),
    (1.270, 0.158, 0.080, 0.112, 0.022, 2.2),
]
SHELL = 0.016
AXIS_Y = 0.022
LOCKS = 23
# The bangs are the front five locks: the window's sides lie in the valleys either side of them (lock coordinate
# +-2.5 from the centre of the front lock).
BANGS_HALF = 2.5
LOCK_BULGE = 0.0034


def _hash(i: np.ndarray, seed: float) -> np.ndarray:
    return np.modf(np.abs(np.sin(i * 12.9898 + seed * 78.233) * 43758.5453))[0]


def _angle(p: np.ndarray) -> np.ndarray:
    """Around her head from the front (0) through her left (+pi/2) to the back (+-pi)."""
    return np.arctan2(p[:, 0], -(p[:, 1] - AXIS_Y))


def lock_coordinate(p: np.ndarray) -> np.ndarray:
    """Which lock a point is in: the integer part numbers the lock (0 is front centre), .5 is its middle... shifted
    so that lock centres fall on integers and valleys on halves."""
    return _angle(p) * LOCKS / (2 * np.pi)


def _helmet_thickness(p: np.ndarray) -> np.ndarray:
    z, y, x = p[:, 2], p[:, 1], p[:, 0]
    crown = 0.003 * np.clip((z - 1.49) / 0.08, 0, 1)  # thin under the hat
    back = 0.005 * np.clip(y / 0.08, 0, 1)
    temples = 0.010 * np.exp(-(((z - 1.47) / 0.05) ** 2)) * np.clip(np.abs(x) / 0.08, 0, 1)
    return 0.015 + crown + back + temples


def _outer(skull, curtain, p: np.ndarray):
    base = smin(skull.eval(p) - _helmet_thickness(p), curtain.eval(p), 0.032)
    L = lock_coordinate(p)
    i = np.round(L)
    f = L - i  # -0.5 .. 0.5 across the lock, 0 at its middle
    # A lock bulges with a rounded crest and meets its neighbour in a sharp valley; some locks stand out more.
    crest = np.clip(1.0 - np.abs(2.0 * f), 0.0, 1.0) ** 0.55
    size = 0.65 + 0.35 * _hash(i, 1.0)
    fade = np.clip((p[:, 2] - 1.285) / 0.04, 0.35, 1.0)  # the tips thin toward their points
    return base - LOCK_BULGE * size * crest * fade, L, i, f


def hair() -> Field:
    skull = H.skull()
    curtain = Loft(CURTAIN_KEYS)

    def field(p: np.ndarray) -> np.ndarray:
        y, z = p[:, 1], p[:, 2]
        o, L, i, f = _outer(skull, curtain, p)
        d = np.maximum(o, -(o + SHELL))
        tri = 1.0 - np.abs(2.0 * f)  # 1 at a lock's middle, 0 in the valleys
        a = np.abs(L) / (LOCKS / 2.0)  # 0 at the front, 1 at the back
        # The hem: every lock ends in a point, the framing locks longest, the back a little shorter.
        length = 0.020 + 0.014 * _hash(i, 3.0)
        frame = np.exp(-(((np.abs(L) - 3.3) / 1.1) ** 2))
        hem = 1.318 + 0.010 * np.clip((a - 0.55) / 0.45, 0, 1) - 0.010 * frame - length * tri**1.15
        d = smax(d, hem - z, 0.002)
        # The bangs: the five front locks stop at her brow, each in a point; the centre strand hangs longest, between
        # her eyes, and the others fall unevenly, as the concept's fringe does.
        bang_len = np.interp(i, [-3, -2, -1, 0, 1, 2, 3], [0.010, 0.015, 0.027, 0.034, 0.020, 0.013, 0.010])
        bangs = 1.468 + 0.006 * (np.abs(L) / BANGS_HALF) ** 2 - bang_len * tri**1.1
        front = np.abs(L) - BANGS_HALF  # < 0 inside the bangs' span, measured in locks
        window = np.maximum(np.maximum(front * 0.012, z - bangs), y - 0.0)
        d = smax(d, -window, 0.0015)
        return d

    lo = np.array([-0.17, -0.14, 1.24])
    hi = np.array([0.17, 0.16, 1.63])
    return Field(field, lo, hi)


def inner_side(p: np.ndarray) -> np.ndarray:
    """True where a hair vertex lies on the shell's inner face (the underside of the bob)."""
    o = _outer(H.skull(), Loft(CURTAIN_KEYS), p)[0]
    return o < -SHELL * 0.5


# The hair's drawing: a UV map from the same lock coordinate the geometry uses (u runs round her head a lock at a
# time, v up), and a texture painted on it with ink lines down every valley, a few finer strand lines, a gradient from
# the crown to the tips, and a zigzag highlight band. The lines can't miss the valleys: both come from lock_coordinate.
UV_Z0, UV_Z1 = 1.26, 1.63
TEX_W, TEX_H = 2048, 1024


def hair_uv(p: np.ndarray) -> np.ndarray:
    u = (lock_coordinate(p) + LOCKS / 2.0) / LOCKS
    v = (p[:, 2] - UV_Z0) / (UV_Z1 - UV_Z0)
    return np.stack([u, v], axis=1)


def _mix(a, b, t):
    return a * (1 - t[..., None]) + b * t[..., None]


def hair_texture(base_hex: str, ink_hex: str, light_hex: str, dark_hex: str) -> np.ndarray:
    """The texture as an (H, W, 3) sRGB array, row 0 at the bottom (Blender's order)."""
    from .blend import hex_colour

    base, ink, light, dark = (np.array(hex_colour(h)) for h in (base_hex, ink_hex, light_hex, dark_hex))
    u = (np.arange(TEX_W) + 0.5) / TEX_W
    v = (np.arange(TEX_H) + 0.5) / TEX_H
    uu, vv = np.meshgrid(u, v)
    L = uu * LOCKS - LOCKS / 2.0
    i = np.round(L)
    f = L - i
    z = UV_Z0 + vv * (UV_Z1 - UV_Z0)
    # Crown lighter, tips darker, each lock a shade of its own.
    shade = np.clip((z - 1.30) / 0.22, 0, 1)
    col = _mix(dark, base, 0.55 + 0.45 * shade)
    col = col * (0.95 + 0.08 * _hash(i, 11.0))[..., None]
    # The highlight: a band across the upper bob, each lock's patch pointed at the bottom.
    band_top = 1.515 + 0.010 * _hash(i, 5.0)
    band_bot = 1.482 - 0.020 * (1 - np.abs(2 * f)) ** 1.5 - 0.008 * _hash(i, 6.0)
    edge = 0.0015
    hl = (
        np.clip((z - band_bot) / edge, 0, 1)
        * np.clip((band_top - z) / edge, 0, 1)
        * np.clip((0.40 - np.abs(f)) / 0.05, 0, 1)
    )
    col = _mix(col, light, 0.75 * hl)
    # Ink in every valley, fading out on the crown where the locks crowd together.
    fade = np.clip((1.585 - z) / 0.05, 0, 1)
    valley = np.clip((np.abs(f) - (0.5 - 0.040)) / 0.012, 0, 1) * fade
    col = _mix(col, ink, 0.9 * valley)
    # Finer strand lines on some locks, rising from the tips and stopping short of the crown.
    has = _hash(i, 9.0) > 0.35
    pos = 0.12 + 0.12 * _hash(i, 13.0)
    reach = 1.36 + 0.10 * _hash(i, 17.0)
    strand = np.clip((0.018 - np.abs(f - pos * np.sign(_hash(i, 21.0) - 0.5))) / 0.006, 0, 1)
    strand = strand * has * np.clip((reach - z) / 0.03, 0, 1)
    col = _mix(col, ink * 0.6 + base * 0.4, 0.55 * strand)
    return np.clip(col, 0, 1)
