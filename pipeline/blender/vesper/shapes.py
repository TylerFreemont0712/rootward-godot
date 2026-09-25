"""Flat emblems (the four-point star-rune, diamonds, crescents, rings) as 2D distance functions, and the two ways they
become solids: pressed out as a badge with a bevel, or laid on a garment's surface as a raised appliqué."""

from __future__ import annotations

import numpy as np

from .sdf import Field, Node, _v, smax


def star4(q: np.ndarray, rx: float, ry_up: float, ry_down: float, waist: float) -> np.ndarray:
    """A four-point star: points at +-rx across and ry_up / ry_down vertically, concave sides pinched to `waist`.

    q is (N, 2). The star is the union of two thin diamonds (lozenges) with slightly concave sides; close to exact near
    its outline, which is all that matters for a badge.
    """
    x, y = np.abs(q[:, 0]), q[:, 1]
    ry = np.where(y >= 0, ry_up, ry_down)
    y = np.abs(y)
    # Horizontal lozenge: tips at (rx, 0), half height `waist` at x = 0; vertical lozenge the same way round.
    h = _lozenge(x, y, rx, waist)
    v = _lozenge(y, x, ry, waist)
    return np.minimum(h, v)


def _lozenge(a: np.ndarray, b: np.ndarray, length: float, half_width: float) -> np.ndarray:
    """Distance to a diamond with tips at a = +-length and its widest (half_width) at a = 0."""
    h = np.hypot(half_width, length)
    n0, n1 = half_width / h, length / h
    return a * n0 + b * n1 - length * n0


def diamond(q: np.ndarray, rx: float, ry: float) -> np.ndarray:
    return _lozenge(np.abs(q[:, 1]), np.abs(q[:, 0]), ry, rx)


def crescent(q: np.ndarray, r_out: float, r_in: float, shift: float) -> np.ndarray:
    """A crescent opening toward +x: a disc with a smaller disc, shifted along +x, taken out."""
    d_out = np.hypot(q[:, 0], q[:, 1]) - r_out
    d_in = np.hypot(q[:, 0] - shift, q[:, 1]) - r_in
    return np.maximum(d_out, -d_in)


def ring(q: np.ndarray, r: float, w: float) -> np.ndarray:
    return np.abs(np.hypot(q[:, 0], q[:, 1]) - r) - w


class Badge(Node):
    """A flat shape pressed into a solid `depth` thick with a rounded edge, placed at `centre` facing `normal` with its
    2D y axis along `up`."""

    def __init__(self, shape2d, centre, normal, up, depth: float, bevel: float, extent: float):
        self.shape2d = shape2d
        self.c = _v(centre)
        n = _v(normal) / np.linalg.norm(normal)
        u = _v(up) - n * np.dot(up, n)
        u /= np.linalg.norm(u)
        self.axes = np.stack([np.cross(u, n), u, n], axis=1)
        self.depth, self.bevel, self.extent = depth, bevel, extent

    def eval(self, p):
        q = (p - self.c) @ self.axes
        d2 = self.shape2d(q[:, :2]) + self.bevel
        dz = np.abs(q[:, 2]) - self.depth / 2 + self.bevel
        outside = np.hypot(np.maximum(d2, 0), np.maximum(dz, 0))
        return outside + np.minimum(np.maximum(d2, dz), 0) - self.bevel

    def bounds(self):
        e = self.extent + self.depth
        return self.c - e, self.c + e


def applique(surface: Node, shape2d, centre, normal, up, lift: float, thickness: float, extent: float) -> Field:
    """A flat shape laid onto `surface` (a distance field): a skin `thickness` thick riding `lift` above the surface,
    cut to the shape as seen along `normal`. For the star on the tunic, the diamonds on the mantle."""
    c = _v(centre)
    n = _v(normal) / np.linalg.norm(normal)
    u = _v(up) - n * np.dot(up, n)
    u /= np.linalg.norm(u)
    axes = np.stack([np.cross(u, n), u, n], axis=1)

    def fn(p):
        q = (p - c) @ axes
        d_surf = np.abs(surface.eval(p) - lift) - thickness / 2
        return smax(d_surf, shape2d(q[:, :2]), 0.0006)

    return Field(fn, c - extent, c + extent)
