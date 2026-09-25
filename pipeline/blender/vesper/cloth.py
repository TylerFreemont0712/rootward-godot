"""Cloth as one sheet with a thickness, not as a thin closed shell.

A garment is its outer face (a distance field, negative inside) cut by a few boundaries (a hem, an opening). The
build meshes the solid those make, deletes the flat caps the cuts leave (keeping only faces on the outer face),
paints trim bands on the sheet as materials, reduces it, and only then gives it its thickness (`blend.thicken`):
the inside becomes the lining, the edge the piping. Two walls made that way can never cross, however far the sheet
is reduced; two walls meshed separately a few millimetres apart do.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Callable

import numpy as np

from .sdf import Field, smax


# LEARN: meshing both walls of a thin shell and reducing them lets the walls cross; one face thickened afterwards cannot
# (docs/LEARNING_LOG.md, "Cloth has one face and a thickness").
@dataclass
class Sheet:
    surface: Callable[[np.ndarray], np.ndarray]  # the outer face: negative inside
    cuts: list[Callable[[np.ndarray], np.ndarray]]  # each negative where the cloth is
    lo: np.ndarray
    hi: np.ndarray
    thickness: float
    # Trim bands: (material slot, field negative inside the band), checked in order; slot 0 elsewhere.
    bands: list[tuple[int, Callable[[np.ndarray], np.ndarray]]] = ()
    slots: int = 1  # material slots on the outer face; the lining uses slots..2*slots-1, the edge slot 2*slots

    def solid(self) -> Field:
        def fn(p):
            d = self.surface(p)
            for c in self.cuts:
                d = smax(d, c(p), 0.0008)
            return d

        return Field(fn, self.lo, self.hi)

    def keep(self, centres: np.ndarray) -> np.ndarray:
        """Faces of the outer face (not of a cut's cap): nearer the surface than to any cut, and inside every cut."""
        s = np.abs(self.surface(centres))
        ok = np.ones(len(centres), dtype=bool)
        for c in self.cuts:
            cv = c(centres)
            ok &= s < np.abs(cv)
        return ok

    def label(self, centres: np.ndarray) -> np.ndarray:
        out = np.zeros(len(centres), dtype=np.int32)
        done = np.zeros(len(centres), dtype=bool)
        for slot, band in self.bands:
            inside = (band(centres) < 0) & ~done
            out[inside] = slot
            done |= inside
        return out


def mirrored(sh: Sheet) -> Sheet:
    """The same sheet on her other side (x mirrored)."""
    flip = np.array([-1.0, 1.0, 1.0])
    lo, hi = sh.lo * flip, sh.hi * flip
    return Sheet(
        surface=lambda p: sh.surface(p * flip),
        cuts=[(lambda c: lambda p: c(p * flip))(c) for c in sh.cuts],
        lo=np.minimum(lo, hi),
        hi=np.maximum(lo, hi),
        thickness=sh.thickness,
        bands=[(slot, (lambda b: lambda p: b(p * flip))(b)) for slot, b in sh.bands],
        slots=sh.slots,
    )
