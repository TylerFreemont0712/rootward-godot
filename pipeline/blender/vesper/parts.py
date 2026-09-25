"""Every piece of Vesper that is meshed from a distance field: what it is made of, how fine, which object it joins and
which colours it takes. The build meshes each part (caching the result), smooths away the voxel steps, reduces it to a
game budget and gives its faces their materials.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable

import numpy as np

from . import body, book, boots, clothes, cloth, gloves, hair, hands, hat, head, mantle


@dataclass
class Part:
    name: str
    make: Callable
    voxel: float
    obj: str
    # One material, or a labeller: vertices -> index into `materials`.
    materials: list[str]
    label: Callable[[np.ndarray], np.ndarray] | None = None
    tris: int = 10000  # triangle budget after decimation
    smooth: int = 3  # smoothing passes against the voxel steps
    extra: dict = field(default_factory=dict)
    # Cloth: a Sheet factory. The part is then meshed as one sheet and thickened (see cloth.py); `materials` lists the
    # outer slots, then the lining's, then the edge's.
    sheet: Callable | None = None


def _body_label(v: np.ndarray) -> np.ndarray:
    # Her legs are in dark tights from the crotch down; everything above is skin (and mostly under clothes).
    return (v[:, 2] < 0.84).astype(int)


def _hair_label(v: np.ndarray) -> np.ndarray:
    return hair.inner_side(v).astype(int)


PARTS: list[Part] = [
    Part("body", lambda: body.body()["whole"], 0.0022, "Body", ["skin", "tights"], _body_label, tris=40000),
    Part("head", lambda: head.head(), 0.0009, "Body", ["face"], tris=24000, extra={"face": True}),
    Part("hand_l", lambda: hands.hands()["left"], 0.0006, "Body", ["skin"], tris=9000),
    Part("hand_r", lambda: hands.hands()["right"], 0.0006, "Body", ["skin"], tris=9000),
    Part("hair", lambda: hair.hair(), 0.0009, "Hair", ["hair", "hair_inner"], _hair_label, tris=50000, smooth=6),
    Part(
        "collar",
        None,
        0.0009,
        "Clothes",
        ["collar", "collar", "collar"],
        tris=5000,
        smooth=2,
        sheet=clothes.collar_sheet,
    ),
    Part(
        "tunic",
        None,
        0.0012,
        "Clothes",
        ["tunic", "gold", "tunic", "gold", "gold"],
        tris=20000,
        smooth=2,
        sheet=clothes.tunic_sheet,
    ),
    Part(
        "shorts",
        None,
        0.0012,
        "Clothes",
        ["shorts", "gold", "shorts", "gold", "gold"],
        tris=10000,
        smooth=2,
        sheet=clothes.shorts_sheet,
    ),
    Part("tunic_gold", lambda: clothes.tunic()["gold"], 0.0007, "Clothes", ["gold"], tris=3500, smooth=1),
    Part("tunic_seams", lambda: clothes.tunic()["seams"], 0.0007, "Clothes", ["tunic_seam"], tris=2500, smooth=1),
    Part("shorts_gold", lambda: clothes.shorts_tabs(), 0.0007, "Clothes", ["gold"], tris=800, smooth=1),
    Part("belt", lambda: clothes.belt()["strap"], 0.0010, "Clothes", ["belt"], tris=4000),
    Part("belt_gold", lambda: clothes.belt()["gold"], 0.0006, "Clothes", ["gold"], tris=1500, smooth=1),
]

for _s in ("l", "r"):
    PARTS += [
        Part(
            f"glove_cuff_{_s}",
            None,
            0.0006,
            "Clothes",
            ["glove", "gold", "glove_lining", "gold", "gold"],
            tris=3500,
            smooth=1,
            sheet=lambda s=_s: gloves.cuff_sheets()[s],
        ),
        Part(
            f"boot_cuff_{_s}",
            None,
            0.0008,
            "Clothes",
            ["boot_cuff", "gold", "boot_cuff_lining", "gold", "gold"],
            tris=5000,
            smooth=1,
            sheet=lambda s=_s: boots.cuff_sheet() if s == "l" else cloth.mirrored(boots.cuff_sheet()),
        ),
        Part(f"glove_{_s}", lambda s=_s: gloves.gloves()[f"leather_{s}"], 0.0007, "Clothes", ["glove"], tris=9000),
        Part(
            f"glove_gold_{_s}",
            lambda s=_s: gloves.gloves()[f"gold_{s}"],
            0.0006,
            "Clothes",
            ["gold"],
            tris=3000,
            smooth=1,
        ),
        Part(f"boot_{_s}", lambda s=_s: boots.boots()[f"leather_{s}"], 0.0012, "Clothes", ["boot"], tris=10000),
        Part(
            f"boot_sole_{_s}",
            lambda s=_s: boots.boots()[f"sole_{s}"],
            0.0010,
            "Clothes",
            ["boot_sole"],
            tris=2500,
            smooth=1,
        ),
        Part(
            f"boot_gold_{_s}", lambda s=_s: boots.boots()[f"gold_{s}"], 0.0007, "Clothes", ["gold"], tris=5000, smooth=1
        ),
        Part(f"boot_strap_{_s}", lambda s=_s: boots.boots()[f"strap_{s}"], 0.0008, "Clothes", ["strap"], tris=2000),
    ]

PARTS += [
    Part(
        "mantle",
        None,
        0.0011,
        "Mantle",
        ["mantle", "gold", "mantle_lining", "gold", "gold"],
        tris=26000,
        smooth=3,
        sheet=mantle.drape_sheet,
    ),
    Part(
        "hood",
        None,
        0.0011,
        "Mantle",
        ["mantle", "mantle_lining", "mantle"],
        tris=6000,
        smooth=3,
        sheet=mantle.hood_sheet,
    ),
    Part("cowl", lambda: mantle.cowl(), 0.0009, "Mantle", ["mantle"], tris=6000, smooth=3),
    Part("cowl_trim", lambda: mantle.cowl_trim(), 0.0008, "Mantle", ["gold"], tris=2500),
    Part("clasp", lambda: mantle.clasp(), 0.0005, "Mantle", ["gold"], tris=2500, smooth=1),
    Part("ribbon", lambda: mantle.ribbon()["cloth"], 0.0007, "Mantle", ["mantle"], tris=2000),
    Part("ribbon_trim", lambda: mantle.ribbon()["trim"], 0.0007, "Mantle", ["gold"], tris=2000),
    Part("mantle_gold", lambda: mantle.emblems()["gold"], 0.0006, "Mantle", ["gold"], tris=3000, smooth=1),
    Part("mantle_dark", lambda: mantle.emblems()["dark"], 0.0006, "Mantle", ["emblem_dark"], tris=1200, smooth=1),
    Part("hat_felt", lambda: hat.hat()["felt"], 0.0012, "Hat", ["hat"], tris=16000),
    Part("hat_brim", None, 0.0012, "Hat", ["hat", "hat_under", "hat"], tris=12000, smooth=2, sheet=hat.brim_sheet),
    Part("hat_band", lambda: hat.hat()["band"], 0.0009, "Hat", ["hat_band"], tris=4000),
    Part("hat_gold", lambda: hat.hat()["gold"], 0.0008, "Hat", ["gold"], tris=3000),
    Part("hat_ornaments", lambda: hat.hat()["ornaments"], 0.0006, "Hat", ["gold"], tris=3000, smooth=1),
    Part("book_cover", lambda: book.parts()["cover"], 0.0007, "Book", ["book"], tris=2500, smooth=1),
    Part("book_pages", lambda: book.parts()["pages"], 0.0007, "Book", ["pages"], tris=1500, smooth=1),
    Part("book_gold", lambda: book.parts()["gold"], 0.0005, "Book", ["gold"], tris=3000, smooth=1),
    Part("book_strap", lambda: book.parts()["strap"], 0.0006, "Book", ["strap"], tris=1200, smooth=1),
]


def by_name() -> dict[str, Part]:
    return {p.name: p for p in PARTS}
