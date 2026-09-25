"""Vesper's colours, picked from the canonical front sheet (sRGB)."""

from __future__ import annotations

from .blend import hex_colour

PALETTE = {
    "skin": "#fde0d1",
    "hair": "#9a5fc0",
    "hair_inner": "#63408f",
    "tights": "#3a2a31",
    "collar": "#1e1d2e",
    "tunic": "#127484",
    "tunic_seam": "#0d3f55",
    "gold": "#f0b85e",
    "shorts": "#222849",
    "belt": "#6b3f2c",
    "mantle": "#62234c",
    "mantle_lining": "#43183a",
    "hat": "#1f3160",
    "hat_under": "#7a2d5c",
    "hat_band": "#4e3340",
    "glove": "#2b1f27",
    "glove_lining": "#25305e",
    "boot": "#6a3b27",
    "boot_sole": "#1f1826",
    "boot_cuff": "#25305e",
    "boot_cuff_lining": "#3b2c49",
    "strap": "#4f2c20",
    "book": "#1f2c58",
    "pages": "#efe3c8",
    "emblem_dark": "#3a1430",
}


def colour(name: str):
    return hex_colour(PALETTE[name])
