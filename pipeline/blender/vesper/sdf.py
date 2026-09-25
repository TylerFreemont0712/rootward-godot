"""Signed distance fields in numpy, meshed through OpenVDB (bundled with Blender).

A shape is a tree of nodes. Every node answers `eval(p)` for an (N, 3) array of points (metres, Blender axes: x to the
character's left, y back, z up) and `bounds()`, an axis-aligned box that holds its surface. `mesh(node, voxel)` samples
the field only in blocks near the surface, hands the narrow band to OpenVDB and returns a quad mesh.

Distances are only approximate for some nodes (the lofts, ellipsoids); what matters is that the zero set is right and
the field grows at roughly one metre per metre near it, so smooth blends have a predictable width.
"""

from __future__ import annotations

import math

import numpy as np

BIG = np.float32(1e3)


def _v(x) -> np.ndarray:
    return np.asarray(x, dtype=np.float64)


def normalize(v) -> np.ndarray:
    v = _v(v)
    return v / np.linalg.norm(v)


def frame(forward, up_hint) -> np.ndarray:
    """A rotation matrix whose columns are (x, y, z) local axes: z along `forward`, y toward `up_hint`."""
    z = normalize(forward)
    x = np.cross(_v(up_hint), z)
    x = x / np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], axis=1)


def rotation(axis, degrees: float) -> np.ndarray:
    axis = normalize(axis)
    a = math.radians(degrees)
    c, s = math.cos(a), math.sin(a)
    x, y, z = axis
    return np.array(
        [
            [c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
            [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
            [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)],
        ]
    )


def smin(a: np.ndarray, b: np.ndarray, k: float) -> np.ndarray:
    # LEARN: the union of two shapes is min(a, b); this polynomial smooth minimum rounds the crease over a width k, so
    # an arm grows out of a shoulder with no seam (see docs/LEARNING_LOG.md, "Shapes as distance functions").
    if k <= 0:
        return np.minimum(a, b)
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a: np.ndarray, b: np.ndarray, k: float) -> np.ndarray:
    return -smin(-a, -b, k)


def smoothstep(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Node:
    def eval(self, p: np.ndarray) -> np.ndarray:
        raise NotImplementedError

    def bounds(self) -> tuple[np.ndarray, np.ndarray]:
        raise NotImplementedError

    # Culling: a node whose box is farther than `margin` from the block contributes nothing there.
    def near(self, lo: np.ndarray, hi: np.ndarray, margin: float) -> bool:
        blo, bhi = self.bounds()
        return bool(np.all(blo - margin <= hi) and np.all(bhi + margin >= lo))

    def eval_block(self, p: np.ndarray, lo: np.ndarray, hi: np.ndarray, margin: float) -> np.ndarray:
        return self.eval(p)


class RoundCone(Node):
    """A capsule whose radius runs from ra at a to rb at b (Inigo Quilez's exact round cone)."""

    def __init__(self, a, b, ra: float, rb: float):
        self.a, self.b, self.ra, self.rb = _v(a), _v(b), float(ra), float(rb)

    def eval(self, p):
        ba = self.b - self.a
        l2 = float(ba @ ba)
        rr = self.ra - self.rb
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = p - self.a
        y = pa @ ba
        z = y - l2
        q = pa * l2 - np.outer(y, ba)
        x2 = np.einsum("ij,ij->i", q, q)
        y2 = y * y * l2
        z2 = z * z * l2
        k = math.copysign(1.0, rr) * rr * rr * x2
        d_b = np.sqrt(x2 + z2) * il2 - self.rb
        d_a = np.sqrt(x2 + y2) * il2 - self.ra
        d_s = (np.sqrt(x2 * a2 * il2) + y * rr) * il2 - self.ra
        return np.where(np.sign(z) * a2 * z2 > k, d_b, np.where(np.sign(y) * a2 * y2 < k, d_a, d_s))

    def bounds(self):
        return np.minimum(self.a - self.ra, self.b - self.rb), np.maximum(self.a + self.ra, self.b + self.rb)


class Ellipsoid(Node):
    """An ellipsoid with semi-axes `radii` along the columns of `rot` (Quilez's bound)."""

    def __init__(self, c, radii, rot=None):
        self.c = _v(c)
        self.r = _v(radii)
        self.rot = np.eye(3) if rot is None else _v(rot)

    def eval(self, p):
        q = (p - self.c) @ self.rot
        k0 = np.linalg.norm(q / self.r, axis=1)
        k1 = np.linalg.norm(q / (self.r * self.r), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

    def bounds(self):
        ext = np.abs(self.rot) @ self.r
        return self.c - ext, self.c + ext


class RoundBox(Node):
    def __init__(self, c, half, radius: float, rot=None):
        self.c, self.half, self.radius = _v(c), _v(half), float(radius)
        self.rot = np.eye(3) if rot is None else _v(rot)

    def eval(self, p):
        q = np.abs((p - self.c) @ self.rot) - self.half + self.radius
        outside = np.linalg.norm(np.maximum(q, 0.0), axis=1)
        inside = np.minimum(np.max(q, axis=1), 0.0)
        return outside + inside - self.radius

    def bounds(self):
        ext = np.abs(self.rot) @ self.half
        return self.c - ext, self.c + ext


class Field(Node):
    """Any function of the points, with a box that holds its surface."""

    def __init__(self, fn, lo, hi):
        self.fn, self.lo, self.hi = fn, _v(lo), _v(hi)

    def eval(self, p):
        return self.fn(p)

    def bounds(self):
        return self.lo, self.hi


class Loft(Node):
    """A body built from horizontal cross-sections, the way a tailor measures one.

    `keys` are rows (z, half_width, front_depth, back_depth, centre_y, exponent). A section is a superellipse centred at
    (centre_x, centre_y) whose front half (toward -y) reaches front_depth and back half back_depth; the exponent is 2
    for an ellipse and higher for a boxier section. Rows are interpolated with a monotone cubic, so the outline stays
    smooth. Below the first row and above the last there is nothing.
    """

    def __init__(self, keys, centre_x: float = 0.0, steps: int = 2000):
        keys = np.asarray(sorted(keys), dtype=np.float64)
        self.z0, self.z1 = float(keys[0, 0]), float(keys[-1, 0])
        self.zs = np.linspace(self.z0, self.z1, steps)
        self.table = np.stack([_pchip(keys[:, 0], keys[:, i], self.zs) for i in range(1, 6)], axis=1)
        # How fast the width, depths and centre change with height: the surface's slope, for the distance.
        self.slope = np.gradient(self.table, self.zs, axis=0)
        self.cx = centre_x
        self.dz = (self.z1 - self.z0) / (steps - 1)

    def params(self, z: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        t = np.clip((z - self.z0) / self.dz, 0, len(self.zs) - 1.001)
        i = t.astype(np.int64)
        f = (t - i)[:, None]
        return self.table[i] * (1 - f) + self.table[i + 1] * f, self.slope[i] * (1 - f) + self.slope[i + 1] * f

    def eval(self, p):
        z = p[:, 2]
        (a, bf, bb, yc, n), (da, dbf, dbb, dyc, _) = (q.T for q in self.params(z))
        a = np.maximum(a, 1e-4)
        dy = p[:, 1] - yc
        front = dy < 0
        b = np.maximum(np.where(front, bf, bb), 1e-4)
        db = np.where(front, dbf, dbb)
        u = np.abs(p[:, 0] - self.cx) / a + 1e-9
        v = np.abs(dy) / b + 1e-9
        r = (u**n + v**n) ** (1.0 / n)
        k = r ** (1 - n)
        gx = k * u ** (n - 1) / a
        gy = k * v ** (n - 1) / b
        # r also changes with height, through a(z), b(z) and the centre yc(z): its z derivative tilts the gradient,
        # so the distance is right over a sloping crown or chin as well as on the upright sides.
        gz = -k * (u**n * da / a + v**n * db / b + v ** (n - 1) * np.sign(dy) * dyc / b)
        # The linear estimate only holds near the surface; far out, a steep end (a dome closing) would drive it to
        # zero. Capping the tilt at 60 degrees keeps it a distance everywhere.
        gxy2 = gx * gx + gy * gy
        g = np.sqrt(gxy2 + np.minimum(gz * gz, 3.0 * gxy2))
        d2 = (r - 1.0) / np.maximum(g, 1e-6)
        # Beyond the ends: distance to the end cap, rounded into the side distance.
        dz = np.maximum(self.z0 - z, z - self.z1)
        return np.where(dz > 0, np.sqrt(np.maximum(d2, 0) ** 2 + dz**2), d2)

    def bounds(self):
        t = self.table
        w = float(t[:, 0].max())
        lo = np.array([self.cx - w, float((t[:, 3] - t[:, 1]).min()), self.z0])
        hi = np.array([self.cx + w, float((t[:, 3] + t[:, 2]).max()), self.z1])
        return lo, hi


def _pchip(x: np.ndarray, y: np.ndarray, xs: np.ndarray) -> np.ndarray:
    """Monotone cubic (Fritsch-Carlson) interpolation: smooth, and never overshoots the keys."""
    h = np.diff(x)
    delta = np.diff(y) / h
    m = np.zeros_like(y)
    for i in range(1, len(y) - 1):
        if delta[i - 1] * delta[i] > 0:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])
    m[0], m[-1] = delta[0], delta[-1]
    i = np.clip(np.searchsorted(x, xs) - 1, 0, len(h) - 1)
    t = (xs - x[i]) / h[i]
    h00 = 2 * t**3 - 3 * t**2 + 1
    h10 = t**3 - 2 * t**2 + t
    h01 = -2 * t**3 + 3 * t**2
    h11 = t**3 - t**2
    return h00 * y[i] + h10 * h[i] * m[i] + h01 * y[i + 1] + h11 * h[i] * m[i + 1]


class SUnion(Node):
    """Children blended one after another with a smooth minimum of width k (k = 0 is a plain union)."""

    def __init__(self, children, k: float = 0.0):
        self.children = [c for c in children if c is not None]
        self.k = float(k)

    def eval(self, p):
        d = self.children[0].eval(p)
        for c in self.children[1:]:
            d = smin(d, c.eval(p), self.k)
        return d

    def eval_block(self, p, lo, hi, margin):
        d = None
        for c in self.children:
            if not c.near(lo, hi, margin + self.k):
                continue
            e = c.eval_block(p, lo, hi, margin + self.k)
            d = e if d is None else smin(d, e, self.k)
        return np.full(len(p), BIG) if d is None else d

    def bounds(self):
        los, his = zip(*(c.bounds() for c in self.children))
        return np.min(los, axis=0), np.max(his, axis=0)


def Union(children) -> SUnion:
    return SUnion(children, 0.0)


class Subtract(Node):
    """`base` with `cut` carved out, blended over k."""

    def __init__(self, base: Node, cut: Node, k: float = 0.0):
        self.base, self.cut, self.k = base, cut, float(k)

    def eval(self, p):
        return smax(self.base.eval(p), -self.cut.eval(p), self.k)

    def eval_block(self, p, lo, hi, margin):
        d = self.base.eval_block(p, lo, hi, margin)
        if self.cut.near(lo, hi, margin + self.k):
            d = smax(d, -self.cut.eval_block(p, lo, hi, margin + self.k), self.k)
        return d

    def bounds(self):
        return self.base.bounds()


class Offset(Node):
    """The surface pushed out by `amount` (in by a negative amount)."""

    def __init__(self, child: Node, amount: float):
        self.child, self.amount = child, float(amount)

    def eval(self, p):
        return self.child.eval(p) - self.amount

    def eval_block(self, p, lo, hi, margin):
        return self.child.eval_block(p, lo, hi, margin + abs(self.amount)) - self.amount

    def near(self, lo, hi, margin):
        return self.child.near(lo, hi, margin + abs(self.amount))

    def bounds(self):
        lo, hi = self.child.bounds()
        return lo - max(self.amount, 0), hi + max(self.amount, 0)


class Mirror(Node):
    """The child reflected across x = 0 (the character's left side becomes her right)."""

    def __init__(self, child: Node):
        self.child = child
        self.flip = np.array([-1.0, 1.0, 1.0])

    def eval(self, p):
        return self.child.eval(p * self.flip)

    def eval_block(self, p, lo, hi, margin):
        mlo, mhi = lo * self.flip, hi * self.flip
        return self.child.eval_block(p * self.flip, np.minimum(mlo, mhi), np.maximum(mlo, mhi), margin)

    def near(self, lo, hi, margin):
        mlo, mhi = lo * self.flip, hi * self.flip
        return self.child.near(np.minimum(mlo, mhi), np.maximum(mlo, mhi), margin)

    def bounds(self):
        lo, hi = self.child.bounds()
        lo, hi = lo * self.flip, hi * self.flip
        return np.minimum(lo, hi), np.maximum(lo, hi)


def mesh(node: Node, voxel: float, band_voxels: float = 3.0, block: int = 40, pad: float = 0.01):
    """Sample `node` near its surface on a grid of `voxel` metres and return (verts, quads) from OpenVDB."""
    import openvdb as vdb

    lo, hi = node.bounds()
    lo = lo - pad
    hi = hi + pad
    dims = np.ceil((hi - lo) / voxel).astype(int) + 1
    band = band_voxels * voxel
    grid = vdb.FloatGrid(float(band))
    grid.gridClass = vdb.GridClass.LEVEL_SET
    half_diag = 0.5 * math.sqrt(3) * block * voxel
    nb = np.ceil(dims / block).astype(int)
    evaluated = 0
    # Coarse pass: the field at every block's centre decides whether the surface can be inside it.
    centres = []
    for bi in range(nb[0]):
        for bj in range(nb[1]):
            for bk in range(nb[2]):
                centres.append((bi, bj, bk))
    centres = np.array(centres)
    cpos = lo + (centres * block + block / 2.0) * voxel
    dc = np.empty(len(centres))
    for s in range(0, len(centres), 4096):
        dc[s : s + 4096] = node.eval(cpos[s : s + 4096])
    ax = np.arange(block)
    for (bi, bj, bk), d0 in zip(centres, dc):
        if abs(d0) > 1.6 * half_diag + band:
            continue
        i0, j0, k0 = bi * block, bj * block, bk * block
        ii, jj, kk = np.meshgrid(ax + i0, ax + j0, ax + k0, indexing="ij")
        p = lo + np.stack([ii.ravel(), jj.ravel(), kk.ravel()], axis=1) * voxel
        blo, bhi = p.min(axis=0), p.max(axis=0)
        d = node.eval_block(p, blo, bhi, band + 2 * voxel)
        d = np.clip(d, -band, band).astype(np.float32).reshape(block, block, block)
        grid.copyFromArray(d, ijk=(int(i0), int(j0), int(k0)), tolerance=0.0)
        evaluated += 1
    grid.signedFloodFill()
    pts, quads = grid.convertToQuads(isovalue=0.0)
    verts = lo + pts.astype(np.float64) * voxel
    quads = quads.astype(np.int64)
    if signed_volume(verts, quads) < 0:
        quads = quads[:, ::-1]
    return verts, quads, evaluated


def signed_volume(verts: np.ndarray, quads: np.ndarray) -> float:
    a, b, c, d = (verts[quads[:, i]] for i in range(4))
    return float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() + np.einsum("ij,ij->i", a, np.cross(c, d)).sum()) / 6.0


def gradient(node: Node, p, h: float = 1e-4) -> np.ndarray:
    """The field's unit gradient (the surface normal) at one point, by central differences."""
    p = _v(p)
    e = np.eye(3) * h
    pts = np.concatenate([p + e, p - e])
    d = node.eval(pts)
    g = (d[:3] - d[3:]) / (2 * h)
    return g / np.linalg.norm(g)


def surface_point(node: Node, origin, direction, far: float = 0.6, steps: int = 60) -> np.ndarray:
    """Where the ray from `origin` (inside) along `direction` leaves the shape: bisection on the field's sign."""
    o, d = _v(origin), normalize(direction)
    ts = np.linspace(0.0, far, 400)
    vals = node.eval(o + np.outer(ts, d))
    i = int(np.argmax(vals > 0))
    lo, hi = ts[max(i - 1, 0)], ts[i]
    for _ in range(steps):
        mid = 0.5 * (lo + hi)
        if node.eval((o + d * mid)[None])[0] > 0:
            hi = mid
        else:
            lo = mid
    return o + d * 0.5 * (lo + hi)


class Transformed(Node):
    """A child built in its own frame: `axes` columns are its x, y, z in the world, `origin` its origin."""

    def __init__(self, child: Node, origin, axes):
        self.child, self.o, self.axes = child, _v(origin), _v(axes)

    def eval(self, p):
        return self.child.eval((p - self.o) @ self.axes)

    def bounds(self):
        lo, hi = self.child.bounds()
        corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
        w = corners @ self.axes.T + self.o
        return w.min(axis=0), w.max(axis=0)
