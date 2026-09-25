"""Which parts of her body are hidden for good under her clothes (torso under the tunic, hips under the shorts, hands
in the gloves, calves in the boots, neck in the collar). The build deletes them once the weights are made: nobody sees
them, and skin that isn't there can't poke through cloth when a joint bends.

Each test keeps a margin, so the cut edge always stays tucked under the garment's own edge.
"""

from __future__ import annotations

import numpy as np

from . import boots, clothes, hands
from .sdf import Mirror, Offset


def covered(v: np.ndarray) -> np.ndarray:
    x, y, z = v[:, 0], v[:, 1], v[:, 2]
    hidden = np.zeros(len(v), dtype=bool)
    # Under the tunic: well inside its outer face, between its hem and the collar.
    tunic = clothes.tunic_surface()
    band = (z > clothes.tunic_hem(v) + 0.012) & (z < 1.275)
    # The shoulders stay: raised arms must not open a gap at the armpit.
    shoulder = (z > 1.15) & (np.abs(x) > 0.105)
    hidden |= band & ~shoulder & (tunic.eval(v) < -0.004)
    # Under the shorts: hips and the tops of the thighs, above their hems (the hands hang beside, not inside).
    hidden |= (z > 0.803) & (z < 0.95) & (np.abs(x) < 0.21)
    # Inside the gloves.
    glove_l = Offset(hands.hand_left(finger_upto=0.58, thumb_upto=1.55), 0.0013)
    for g in (glove_l, Mirror(glove_l)):
        near = (z < 0.95) & (np.abs(x) > 0.25)
        idx = np.nonzero(near)[0]
        if len(idx):
            hidden[idx] |= g.eval(v[idx]) < -0.0007
    # Inside the boots, below the shaft's top.
    boot = boots.boot_upper()
    for b in (boot, Mirror(boot)):
        low = np.nonzero(z < boots.TOP_Z - 0.012)[0]
        hidden[low] |= b.eval(v[low]) < -0.0025
    # Inside the collar.
    neck_r = np.hypot(x, y - 0.019)
    hidden |= (z > 1.270) & (z < 1.318) & (neck_r < 0.040)
    return hidden
