#!/usr/bin/env python3
"""Spell animations (ADR-0014): the motion designed here, frame by frame, then (optionally) painted by the video model.

  scripts/sprites.sh spells                  draw every animation in spells.json into game/assets/fx/spells
  scripts/sprites.sh spells --only 'hit-*'   ids, or prefixes ending in *
  scripts/sprites.sh spells --sheet          also write a contact sheet of every animation to the cache

A spell animation is not a picture that fades: it is timing. Brackets slam shut and the blow lands on a frame of its own;
shards fly out fast and slow down; a ring races out and thins; runes (the same futhark the code panel writes with) scatter
and drift. So each animation is a small program over time t in 0..1, drawn on black as two channels:

  R  light: how bright the effect is there. The game colours it through the element's ramp (dark, mid, hot), whose
     hottest colour is a pale tint, never white, so a big hit is vivid rather than blinding.
  G  shade: how much it darkens what is behind it (a cut's dark core, the ground under a crash). Light alone only ever
     brightens; shade is what makes a blow read as heavy on a bright arena.

Frames are drawn four times larger and shrunk, with a bloom added from a blur of the light. The sheet is a PNG grid
(lossless, so the two channels stay apart) with a JSON of its facts beside it.
"""

from __future__ import annotations

import argparse
import json
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
OUT = REPO / "game" / "assets" / "fx" / "spells"
CACHE = REPO / "pipeline" / "cache" / "sprites" / "spells"
SUPER = 3

# The runes of the code panel (game/ui/code/rune_code.gd), as strokes in a unit cell: the spells cast the same letters
# the code is written in.
RUNES: list[list[list[tuple[float, float]]]] = [
    [[(0.3, 0), (0.3, 1)], [(0.3, 0.1), (0.8, 0.35)], [(0.3, 0.4), (0.8, 0.65)]],
    [[(0.25, 1), (0.25, 0), (0.75, 0.3), (0.75, 1)]],
    [[(0.3, 0), (0.3, 1)], [(0.3, 0.25), (0.75, 0.5), (0.3, 0.75)]],
    [[(0.3, 0), (0.3, 1)], [(0.3, 0), (0.75, 0.25)], [(0.3, 0.3), (0.75, 0.55)]],
    [[(0.3, 1), (0.3, 0), (0.75, 0.25), (0.3, 0.5)], [(0.3, 0.5), (0.8, 1)]],
    [[(0.7, 0.1), (0.3, 0.5), (0.7, 0.9)]],
    [[(0.2, 0.1), (0.8, 0.9)], [(0.8, 0.1), (0.2, 0.9)]],
    [[(0.25, 0), (0.25, 1)], [(0.75, 0), (0.75, 1)], [(0.25, 0.35), (0.75, 0.65)]],
    [[(0.5, 0), (0.5, 1)], [(0.25, 0.35), (0.75, 0.65)]],
    [[(0.75, 0.2), (0.5, 0), (0.5, 1), (0.25, 0.8)]],
    [[(0.5, 0), (0.5, 1)], [(0.2, 0.05), (0.5, 0.4), (0.8, 0.05)]],
    [[(0.7, 0.05), (0.3, 0.35), (0.7, 0.65), (0.3, 0.95)]],
    [[(0.5, 0), (0.5, 1)], [(0.2, 0.35), (0.5, 0), (0.8, 0.35)]],
    [[(0.2, 1), (0.2, 0), (0.8, 0.5)], [(0.8, 1), (0.8, 0), (0.2, 0.5)]],
    [[(0.5, 0.15), (0.8, 0.5), (0.5, 0.85), (0.2, 0.5), (0.5, 0.15)]],
]


# ---------------------------------------------------------------------------------------------------------------------
# Timing


def clamp(x: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, x))


def span(t: float, start: float, end: float) -> float:
    """Where t is between start and end, as 0..1."""
    return clamp((t - start) / max(1e-6, end - start))


def out(x: float, power: float = 3.0) -> float:
    """Fast, then slowing: things thrown."""
    return 1.0 - (1.0 - clamp(x)) ** power


def into(x: float, power: float = 3.0) -> float:
    """Slow, then fast: things falling, things slamming shut."""
    return clamp(x) ** power


def overshoot(x: float, amount: float = 1.7) -> float:
    """Past the mark and back: things locking into place."""
    x = clamp(x) - 1.0
    return 1.0 + x * x * ((amount + 1.0) * x + amount)


def fade(t: float, start: float, end: float) -> float:
    return 1.0 - span(t, start, end)


# ---------------------------------------------------------------------------------------------------------------------
# Drawing


class Frame:
    """One frame, drawn larger than it will be shown: light and shade as 8-bit layers, summed as they are drawn."""

    def __init__(self, width: int, height: int):
        self.w, self.h = width * SUPER, height * SUPER
        self.light = np.zeros((self.h, self.w), np.float32)
        self.shade = np.zeros((self.h, self.w), np.float32)

    def _layer(self) -> tuple[Image.Image, ImageDraw.ImageDraw]:
        image = Image.new("L", (self.w, self.h), 0)
        return image, ImageDraw.Draw(image)

    def _add(self, image: Image.Image, value: float, shade: bool, blur: float = 0.0) -> None:
        if blur > 0:
            image = image.filter(ImageFilter.GaussianBlur(blur * SUPER))
        target = self.shade if shade else self.light
        target += np.asarray(image, np.float32) / 255.0 * value

    def _p(self, point: tuple[float, float]) -> tuple[float, float]:
        return (point[0] * SUPER, point[1] * SUPER)

    def lines(self, points: list[tuple[float, float]], width: float, value: float, shade: bool = False, blur: float = 0.0) -> None:
        if value <= 0.001 or len(points) < 2:
            return
        image, draw = self._layer()
        draw.line([self._p(p) for p in points], fill=255, width=max(1, round(width * SUPER)), joint="curve")
        self._add(image, value, shade, blur)

    def polygon(self, points: list[tuple[float, float]], value: float, shade: bool = False, blur: float = 0.0) -> None:
        if value <= 0.001:
            return
        image, draw = self._layer()
        draw.polygon([self._p(p) for p in points], fill=255)
        self._add(image, value, shade, blur)

    def disc(self, centre: tuple[float, float], radius: float, value: float, shade: bool = False, blur: float = 0.0) -> None:
        if value <= 0.001 or radius <= 0:
            return
        image, draw = self._layer()
        x, y = self._p(centre)
        r = radius * SUPER
        draw.ellipse((x - r, y - r, x + r, y + r), fill=255)
        self._add(image, value, shade, blur)

    def ellipse(self, centre: tuple[float, float], rx: float, ry: float, width: float, value: float, shade: bool = False, blur: float = 0.0) -> None:
        if value <= 0.001 or rx <= 0 or ry <= 0:
            return
        image, draw = self._layer()
        x, y = self._p(centre)
        draw.ellipse((x - rx * SUPER, y - ry * SUPER, x + rx * SUPER, y + ry * SUPER), outline=255, width=max(1, round(width * SUPER)))
        self._add(image, value, shade, blur)

    def arc(self, centre: tuple[float, float], radius: float, start: float, end: float, width: float, value: float, blur: float = 0.0) -> None:
        """An arc from `start` to `end` degrees (clockwise from east)."""
        if value <= 0.001 or radius <= 0 or end <= start:
            return
        image, draw = self._layer()
        x, y = self._p(centre)
        r = radius * SUPER
        draw.arc((x - r, y - r, x + r, y + r), start, end, fill=255, width=max(1, round(width * SUPER)))
        self._add(image, value, False, blur)

    def rune(self, index: int, centre: tuple[float, float], size: float, angle: float, width: float, value: float, blur: float = 0.0) -> None:
        """One of the code panel's runes, `size` tall, turned by `angle` degrees."""
        if value <= 0.001:
            return
        image, draw = self._layer()
        cos, sin = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        for stroke in RUNES[index % len(RUNES)]:
            points = []
            for u, v in stroke:
                dx, dy = (u - 0.5) * size * 0.62, (v - 0.5) * size
                points.append(self._p((centre[0] + dx * cos - dy * sin, centre[1] + dx * sin + dy * cos)))
            draw.line(points, fill=255, width=max(1, round(width * SUPER)), joint="curve")
        self._add(image, value, False, blur)

    def finish(self, width: int, height: int, bloom: float) -> np.ndarray:
        """The frame at its size: light (with its bloom) in R, shade in G, as 0..255."""
        light = np.clip(self.light, 0, 1.4)
        shade = np.clip(self.shade, 0, 1)
        small_light = np.asarray(Image.fromarray(np.clip(light / 1.4 * 255, 0, 255).astype(np.uint8)).resize((width, height), Image.Resampling.LANCZOS), np.float32) / 255 * 1.4
        small_shade = np.asarray(Image.fromarray((shade * 255).astype(np.uint8)).resize((width, height), Image.Resampling.LANCZOS), np.float32) / 255
        if bloom > 0:
            halo = np.asarray(Image.fromarray(np.clip(small_light / 1.4 * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(width * 0.035)), np.float32) / 255 * 1.4
            small_light = small_light + halo * bloom
        rgb = np.zeros((height, width, 3), np.uint8)
        rgb[..., 0] = np.clip(small_light, 0, 1) * 255
        rgb[..., 1] = np.clip(small_shade, 0, 1) * 255
        return rgb


def rotate(point: tuple[float, float], angle: float) -> tuple[float, float]:
    cos, sin = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    return (point[0] * cos - point[1] * sin, point[0] * sin + point[1] * cos)


def shard(centre: tuple[float, float], size: float, angle: float, stretch: float = 1.0) -> list[tuple[float, float]]:
    """A splinter: a thin, sharp quadrilateral pointing along `angle`."""
    shape = [(size * stretch, 0), (0, size * 0.28), (-size * 0.45, 0), (0, -size * 0.28)]
    return [(centre[0] + p[0], centre[1] + p[1]) for p in (rotate(q, angle) for q in shape)]


def hexagon(centre: tuple[float, float], radius: float) -> list[tuple[float, float]]:
    return [(centre[0] + radius * math.cos(math.radians(60 * i + 30)), centre[1] + radius * math.sin(math.radians(60 * i + 30))) for i in range(7)]


# ---------------------------------------------------------------------------------------------------------------------
# Motions: each draws frame `f` at time t (0..1) on a canvas of `w` x `h`.


def cast_sigil(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """The Program runs: a circle draws itself, runes take their places around it, two brackets snap shut on either
    side, and it all pulls into a point and lets go."""
    cx, cy = w / 2, h / 2
    gather = into(span(t, 0.62, 0.86), 2.0)
    radius = w * 0.4 * (1.0 - 0.82 * gather)
    alive = fade(t, 0.86, 0.96)
    draw_on = out(span(t, 0.0, 0.36))
    turn = t * 140
    f.ellipse((cx, cy), radius * 1.02, radius * 1.02, 10, 0.35 * alive, shade=True, blur=6)
    f.arc((cx, cy), radius, -90 + turn, -90 + turn + 360 * draw_on, 4.5, 0.95 * alive)
    f.arc((cx, cy), radius, -90 + turn, -90 + turn + 360 * draw_on, 12, 0.25 * alive, blur=4)
    for i in range(16):
        # Motes drawn in along a spiral while the circle gathers its power.
        pull = span(t, 0.3 + i * 0.012, 0.8)
        if 0 < pull < 1:
            angle = math.radians(i * 67 + pull * 240)
            reach = w * (0.5 - 0.46 * into(pull, 1.6))
            f.disc((cx + reach * math.cos(angle), cy + reach * math.sin(angle)), 2.6, 0.9 * (1 - pull * 0.5), blur=1)
    f.arc((cx, cy), radius * 0.86, 90 - turn * 1.6, 90 - turn * 1.6 + 300 * out(span(t, 0.1, 0.45)), 1.6, 0.6 * alive)
    for i in range(12):
        shown = span(t, 0.08 + i * 0.025, 0.14 + i * 0.025)
        angle = i * 30 + turn * 0.6
        at = (cx + radius * 0.72 * math.cos(math.radians(angle)), cy + radius * 0.72 * math.sin(math.radians(angle)))
        f.rune(i, at, w * 0.075 * (1 - 0.4 * gather), angle + 90, 2.4, 1.0 * shown * alive)
    snap = overshoot(span(t, 0.28, 0.42), 2.2)
    for side in (-1, 1):
        x = cx + side * (w * 0.62 - (w * 0.62 - radius * 1.14) * snap)
        arm = h * 0.2 * (1 - 0.5 * gather)
        f.lines([(x + side * -w * 0.06, cy - arm), (x, cy - arm), (x, cy + arm), (x + side * -w * 0.06, cy + arm)], 5, 0.9 * span(t, 0.26, 0.3) * alive)
    f.disc((cx, cy), w * 0.035 * (1 + 0.3 * math.sin(t * 40)), 0.7 * alive, blur=2)
    release = span(t, 0.84, 1.0)
    if release > 0:
        f.disc((cx, cy), w * (0.05 + 0.25 * out(release)), 0.6 * (1 - release), blur=4)
        f.ellipse((cx, cy), w * (0.08 + 0.4 * out(release)), w * (0.08 + 0.4 * out(release)), 3 * (1 - release) + 0.5, 0.9 * (1 - release))


def glyph_bolt(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A bolt in flight, heading right: a hot head, streaks behind it, and runes circling it and peeling off. It loops."""
    cx, cy = w * 0.64, h / 2
    phase = t * 2 * math.pi
    for i in range(4):
        length = w * (0.26 + 0.1 * math.sin(phase * 2 + i))
        offset = (i - 1.5) * h * 0.045
        f.lines([(cx - length, cy + offset * 1.4), (cx - w * 0.04, cy + offset * 0.4)], 3 - i * 0.4, 0.4 - i * 0.07, blur=1)
    f.polygon([(cx + w * 0.17, cy), (cx - w * 0.02, cy - h * 0.12), (cx - w * 0.14, cy), (cx - w * 0.02, cy + h * 0.12)], 0.95, blur=1.5)
    f.disc((cx + w * 0.03, cy), w * 0.05, 1.0, blur=1)
    f.disc((cx + w * 0.02, cy), w * 0.1, 0.35, blur=6)
    for i in range(5):
        around = phase + i * 2 * math.pi / 5
        trail = (i * 0.2 + t) % 1.0
        x = cx - w * 0.05 - trail * w * 0.34
        y = cy + math.sin(around) * h * (0.14 + trail * 0.08)
        f.rune(i * 3 + 1, (x, y), h * 0.12 * (1 - trail * 0.5), math.degrees(around), 1.8, 0.75 * (1 - trail))


def hit_compile(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A bolt lands: two brackets slam shut on the target, and at the moment they meet it breaks open: a sharp star, a
    ring racing out and thinning, splinters flung out and slowing, runes scattered."""
    cx, cy = w / 2, h / 2
    contact = 0.18
    # The brackets show where they will close before they slam, so the eye catches the blow coming.
    slam = into(span(t, 0.05, contact), 2.4)
    if t < contact + 0.1:
        for side in (-1, 1):
            x = cx + side * (w * 0.46 - w * 0.34 * slam)
            arm = h * 0.16
            seen = span(t, 0.0, 0.05) * fade(t, contact, contact + 0.1)
            f.lines([(x + side * w * 0.05, cy - arm), (x, cy - arm), (x, cy + arm), (x + side * w * 0.05, cy + arm)], 6, 0.9 * seen)
    after = span(t, contact, 1.0)
    if t >= contact:
        f.disc((cx, cy), w * 0.16 * (1 - out(after, 2)), 0.9 * fade(t, contact, contact + 0.18), shade=True, blur=4)
        star = fade(t, contact, contact + 0.14)
        for i in range(8):
            angle = i * 45 + 22.5 * (i % 2)
            reach = w * (0.28 if i % 2 == 0 else 0.16) * (0.4 + 0.6 * out(span(t, contact, contact + 0.06)))
            tip = (cx + reach * math.cos(math.radians(angle)), cy + reach * math.sin(math.radians(angle)))
            f.lines([(cx, cy), tip], 5 * star, 0.9 * star)
        f.disc((cx, cy), w * 0.06 * star, 0.7 * star, blur=2)
        ring = w * (0.08 + 0.4 * out(after, 3))
        f.ellipse((cx, cy), ring, ring, 9 * (1 - after) + 1, 0.9 * fade(t, contact, 0.8))
        f.ellipse((cx, cy), ring * 0.9, ring * 0.9, 10 * (1 - after), 0.45 * fade(t, contact, 0.7), shade=True, blur=3)
        for i in range(10):
            angle = rng.uniform(0, 360)
            speed = rng.uniform(0.25, 0.48)
            reach = w * speed * out(after, 3)
            at = (cx + reach * math.cos(math.radians(angle)), cy + reach * math.sin(math.radians(angle)))
            size = w * rng.uniform(0.03, 0.06)
            f.polygon(shard(at, size, angle, 1.0 + 2.0 * (1 - after)), 0.9 * fade(t, 0.35, 0.9))
        for i in range(6):
            angle = i * 60 + 20
            reach = w * 0.2 * out(after, 2) + w * 0.06
            at = (cx + reach * math.cos(math.radians(angle)), cy + reach * math.sin(math.radians(angle)) - h * 0.1 * after)
            f.rune(i + 4, at, h * 0.06, angle * 2 * after, 1.6, 0.7 * fade(t, 0.4, 0.95))


def hit_heavy(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A heavy blow: three blocks of code, each drawn in the air above the target, hanging there a beat, then dropped;
    the last and largest is the blow. Each breaks apart where it lands, throwing splinters and a ring of dust. Its
    ground is at 88% of the height."""
    ground = h * 0.88
    cx = w / 2
    blocks = [
        {"x": -0.2, "appear": 0.0, "fall": 0.12, "land": 0.24, "size": 0.2, "rune": 3},
        {"x": 0.2, "appear": 0.1, "fall": 0.24, "land": 0.36, "size": 0.2, "rune": 7},
        {"x": 0.0, "appear": 0.2, "fall": 0.42, "land": 0.56, "size": 0.32, "rune": 11},
    ]
    for index, block in enumerate(blocks):
        big = index == len(blocks) - 1
        bw, bh = w * block["size"], w * block["size"] * 0.66
        x = cx + block["x"] * w
        top = h * 0.14 + bh / 2
        if t < block["land"]:
            shown = span(t, block["appear"], block["appear"] + 0.07)
            if shown <= 0:
                continue
            fall = span(t, block["fall"], block["land"])
            bob = math.sin(t * 40 + index) * h * 0.006 * (1 - fall)
            y = top + bob + (ground - bh / 2 - top) * into(fall, 2.4)
            if fall > 0:
                # The streak it leaves as it drops.
                f.lines([(x, y - bh / 2 - h * 0.3 * fall), (x, y - bh / 2)], bw * 0.55, 0.28 * fall, blur=5)
                for side in (-0.32, 0.32):
                    f.lines([(x + side * bw, y - bh / 2 - h * 0.22 * fall), (x + side * bw, y - bh / 2)], 2, 0.5 * fall)
            corners = [(x - bw / 2, y - bh / 2), (x + bw / 2, y - bh / 2), (x + bw / 2, y + bh / 2), (x - bw / 2, y + bh / 2)]
            f.polygon(corners, 0.45 * shown, shade=True)
            # Its outline draws itself round, then holds.
            perimeter = corners + [corners[0]]
            drawn = max(2, round(1 + 4 * shown))
            f.lines(perimeter[:drawn], 3.4 if big else 2.8, 0.9 * min(1.0, shown * 1.5))
            f.rune(block["rune"], (x, y), bh * 0.66, 0, 2.6 if big else 2.2, 0.95 * span(t, block["appear"] + 0.03, block["appear"] + 0.08))
            continue
        after = span(t, block["land"], block["land"] + (0.44 if big else 0.28))
        if after >= 1:
            continue
        spread = w * (0.48 if big else 0.24) * out(after, 3)
        f.ellipse((x, ground), spread, spread * 0.2, 7 * (1 - after) + 1, 0.9 * (1 - after))
        f.ellipse((x, ground), spread * 0.85, spread * 0.17, 14, 0.55 * (1 - after), shade=True, blur=4)
        # The block breaks into pieces, flung up and out and falling back.
        for k in range(7 if big else 4):
            angle = -90 + (k - (3 if big else 1.5)) * (22 if big else 30) + rng.uniform(-8, 8)
            reach = h * (0.28 if big else 0.16) * out(after, 2)
            drop = h * 0.3 * after * after
            at = (x + reach * math.cos(math.radians(angle)), ground - bh * 0.3 + reach * math.sin(math.radians(angle)) + drop)
            f.polygon(shard(at, w * (0.045 if big else 0.032), angle + after * 200, 1.5), 0.85 * (1 - after))
        f.disc((x, ground - bh * 0.25), w * (0.09 if big else 0.06) * (1 - after), 0.6 * (1 - span(after, 0, 0.25)), blur=3)
        for k in range(5 if big else 3):
            rise = out(after, 2)
            sx = x + (k - (2 if big else 1)) * w * 0.05
            f.lines([(sx, ground - h * 0.06 - h * 0.3 * rise), (sx, ground - h * 0.06 - h * 0.2 * rise)], 2.2, 0.75 * (1 - after))


def ward_hex(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A ward: hexagonal tiles fly in and lock into a shield, a pulse runs across it, and it holds, then breaks up."""
    cx, cy = w / 2, h / 2
    r = w * 0.085
    cells = [(0, 0)] + [(1.75 * r * math.cos(math.radians(60 * i)), 1.75 * r * math.sin(math.radians(60 * i))) for i in range(6)]
    cells += [(0, -3.5 * r), (0, 3.5 * r), (-3.0 * r, -1.75 * r), (3.0 * r, -1.75 * r), (-3.0 * r, 1.75 * r), (3.0 * r, 1.75 * r)]
    leave = span(t, 0.78, 1.0)
    for index, (dx, dy) in enumerate(cells):
        arrive = span(t, 0.02 + index * 0.025, 0.2 + index * 0.025)
        away = rng.uniform(0, 360)
        from_x, from_y = dx + w * 0.6 * math.cos(math.radians(away)), dy + h * 0.6 * math.sin(math.radians(away))
        k = out(arrive, 3)
        x = cx + from_x + (dx - from_x) * k
        y = cy + from_y + (dy - from_y) * k
        size = r * 0.92 * overshoot(arrive, 1.4) * (1 - 0.6 * into(leave))
        pulse = math.exp(-((dx / w + 0.5 - span(t, 0.42, 0.62) * 1.6 + 0.3) ** 2) / 0.004)
        glow = (0.55 + 0.45 * pulse) * (1 - leave) * clamp(arrive * 3)
        f.polygon(hexagon((x, y), size), 0.12 * glow)
        f.lines(hexagon((x, y), size), 2.4, glow)
        if leave > 0:
            drift = h * 0.2 * leave
            f.rune(index, (x, y - drift), size * 0.8, leave * 90, 1.6, 0.5 * (1 - leave))


def shatter(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A foe breaks: cracks run out from its middle, then it flies apart, the pieces tumbling down and runes rising."""
    cx, cy = w / 2, h / 2
    crack = out(span(t, 0.0, 0.26), 2)
    cracks = []
    for i in range(7):
        angle = i * (360 / 7) + rng.uniform(-15, 15)
        points = [(cx, cy)]
        for step in range(1, 6):
            reach = w * 0.4 * step / 5 * crack
            jag = rng.uniform(-12, 12)
            points.append((cx + reach * math.cos(math.radians(angle + jag)), cy + reach * math.sin(math.radians(angle + jag))))
        cracks.append(points)
    if t < 0.36:
        for points in cracks:
            f.lines(points, 3, 0.95 * fade(t, 0.3, 0.36))
            f.lines(points, 8, 0.4, shade=True, blur=2)
    burst = span(t, 0.3, 1.0)
    if burst > 0:
        f.disc((cx, cy), w * 0.12 * (1 - out(burst)), 0.8 * fade(t, 0.3, 0.42), blur=4)
        for i in range(18):
            angle = rng.uniform(0, 360)
            speed = rng.uniform(0.2, 0.46)
            reach = w * speed * out(burst, 2.4)
            fall = h * 0.4 * burst * burst
            at = (cx + reach * math.cos(math.radians(angle)), cy + reach * math.sin(math.radians(angle)) + fall)
            size = w * rng.uniform(0.03, 0.07)
            spin = angle + burst * rng.uniform(-400, 400)
            f.polygon(shard(at, size, spin, 1.2), 0.8 * fade(t, 0.55, 1.0))
        for i in range(6):
            at = (cx + (i - 2.5) * w * 0.1, cy - h * 0.45 * out(burst, 1.6) + rng.uniform(-10, 10))
            f.rune(i * 2, at, h * 0.07, 0, 1.6, 0.7 * fade(t, 0.6, 1.0) * span(t, 0.32, 0.4))


def claw(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A foe's blow on the Maintainer: three slashes torn across in quick succession, each a dark cut with bright
    edges, lingering a moment and closing."""
    for i in range(3):
        start = i * 0.07
        draw = out(span(t, start, start + 0.12), 2)
        close = span(t, 0.45, 1.0)
        if draw <= 0 or close >= 1:
            continue
        offset = (i - 1) * w * 0.14
        points = []
        steps = 16
        for s in range(steps + 1):
            u = s / steps * draw
            x = w * 0.18 + u * w * 0.64 + offset
            y = h * 0.2 + u * h * 0.6 - math.sin(u * math.pi) * h * 0.08
            points.append((x, y))
        width = 11 * (1 - close)
        f.lines(points, width + 6, 0.8 * (1 - close), blur=1.5)
        f.lines(points, width, 0.95 * (1 - close), shade=True)
        f.lines(points, max(1, width * 0.2), 0.25 * (1 - close))


def tempo(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A foe beats the Program to it: a clock face draws itself and its hand sweeps round once, fast, ticking."""
    cx, cy = w / 2, h / 2
    alive = fade(t, 0.75, 1.0)
    grow = out(span(t, 0.0, 0.2))
    r = w * 0.34 * overshoot(span(t, 0.0, 0.25), 1.2)
    f.disc((cx, cy), r * 1.05, 0.4 * alive, shade=True, blur=4)
    f.arc((cx, cy), r, -90, -90 + 360 * grow, 3, 0.9 * alive)
    for i in range(12):
        angle = math.radians(i * 30 - 90)
        inner = r * (0.78 if i % 3 == 0 else 0.86)
        f.lines([(cx + inner * math.cos(angle), cy + inner * math.sin(angle)), (cx + r * 0.94 * math.cos(angle), cy + r * 0.94 * math.sin(angle))], 2.4 if i % 3 == 0 else 1.4, 0.8 * alive * grow)
    sweep = math.radians(-90 + 360 * out(span(t, 0.15, 0.7), 2))
    f.lines([(cx, cy), (cx + r * 0.8 * math.cos(sweep), cy + r * 0.8 * math.sin(sweep))], 4, 1.0 * alive)
    for k in range(1, 6):
        trail = sweep - k * 0.12
        f.lines([(cx, cy), (cx + r * 0.8 * math.cos(trail), cy + r * 0.8 * math.sin(trail))], 4, 0.18 * alive * (1 - k / 6))
    f.disc((cx, cy), w * 0.03, 0.9 * alive)


def _ring_of_runes(f: Frame, centre: tuple[float, float], radius: float, count: int, turn: float, size: float, shown: float, value: float, first: int = 0) -> None:
    """`count` runes around a circle, each turned to face out, appearing in order as `shown` goes 0 to 1."""
    for i in range(count):
        appear = span(shown, i / count * 0.8, i / count * 0.8 + 0.2)
        angle = i * 360 / count + turn
        at = (centre[0] + radius * math.cos(math.radians(angle)), centre[1] + radius * math.sin(math.radians(angle)))
        f.rune(first + i, at, size, angle + 90, max(1.4, size * 0.09), value * appear)


def _star(f: Frame, centre: tuple[float, float], radius: float, points: int, step: int, turn: float, drawn: float, width: float, value: float) -> None:
    """A star polygon ({points/step}) drawing itself along its edges: {8/3} is an octagram; {6/2} is one triangle, and a
    hexagram is two of them a sixth of a turn apart."""
    corners = [(centre[0] + radius * math.cos(math.radians(turn + i * 360 / points - 90)), centre[1] + radius * math.sin(math.radians(turn + i * 360 / points - 90))) for i in range(points)]
    path = [corners[(i * step) % points] for i in range(points + 1)]
    edges = len(path) - 1
    reach = drawn * edges
    for i in range(edges):
        part = clamp(reach - i)
        if part <= 0:
            break
        a, b = path[i], path[i + 1]
        f.lines([a, (a[0] + (b[0] - a[0]) * part, a[1] + (b[1] - a[1]) * part)], width, value)


def cast_sigil_simple(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A small spell: one ring drawn quickly, four runes, a spark in the middle, and it lets go."""
    cx, cy = w / 2, h / 2
    gather = into(span(t, 0.6, 0.85), 2.0)
    radius = w * 0.34 * (1.0 - 0.8 * gather)
    alive = fade(t, 0.85, 0.97)
    f.arc((cx, cy), radius, -90 + t * 120, -90 + t * 120 + 360 * out(span(t, 0.0, 0.35)), 3.4, 0.9 * alive)
    _ring_of_runes(f, (cx, cy), radius * 0.72, 4, t * 90, w * 0.07, span(t, 0.1, 0.4), 0.9 * alive, first=2)
    f.disc((cx, cy), w * 0.03, 0.7 * alive, blur=2)
    release = span(t, 0.84, 1.0)
    if release > 0:
        f.ellipse((cx, cy), w * (0.06 + 0.3 * out(release)), w * (0.06 + 0.3 * out(release)), 2.5 * (1 - release) + 0.5, 0.8 * (1 - release))


def cast_sigil_complex(f: Frame, t: float, w: int, h: int, rng: random.Random, grand: bool = False) -> None:
    """A strong spell: a double ring with ticks, a hexagram drawing itself inside, runes turning against it, nodes
    orbiting the rim, brackets snapping shut; a grand one adds an outer ring of runes, an octagram and spokes of light.
    It gathers and lets go in a double wave."""
    cx, cy = w / 2, h / 2
    gather = into(span(t, 0.66, 0.86), 2.0)
    alive = fade(t, 0.86, 0.97)
    shrink = 1.0 - 0.8 * gather
    r = w * (0.3 if grand else 0.4) * shrink
    turn = t * 110
    f.ellipse((cx, cy), r * 1.05, r * 1.05, 12, 0.4 * alive, shade=True, blur=6)
    draw_on = out(span(t, 0.0, 0.3))
    f.arc((cx, cy), r, -90 + turn, -90 + turn + 360 * draw_on, 4.5, 0.95 * alive)
    f.arc((cx, cy), r * 0.93, 90 - turn, 90 - turn + 360 * draw_on, 1.8, 0.7 * alive)
    for i in range(36):
        # Ticks round the rim, like a dial.
        if i / 36 > draw_on:
            break
        angle = math.radians(i * 10 + turn)
        inner = r * (0.86 if i % 3 == 0 else 0.9)
        f.lines([(cx + inner * math.cos(angle), cy + inner * math.sin(angle)), (cx + r * 0.93 * math.cos(angle), cy + r * 0.93 * math.sin(angle))], 1.6, 0.6 * alive)
    _star(f, (cx, cy), r * 0.8, 6, 2, -turn * 0.5, out(span(t, 0.15, 0.45)), 2.2, 0.85 * alive)
    _star(f, (cx, cy), r * 0.8, 6, 2, -turn * 0.5 + 60, out(span(t, 0.2, 0.5)), 2.2, 0.85 * alive)
    _ring_of_runes(f, (cx, cy), r * 0.62, 12, -turn * 1.4, w * 0.055, span(t, 0.15, 0.5), 1.0 * alive)
    for i in range(6):
        # Nodes riding the rim.
        angle = math.radians(i * 60 + turn * 2.2)
        at = (cx + r * math.cos(angle), cy + r * math.sin(angle))
        f.polygon([(at[0], at[1] - 6), (at[0] + 6, at[1]), (at[0], at[1] + 6), (at[0] - 6, at[1])], 0.95 * alive * span(t, 0.25, 0.35))
    if grand:
        outer = w * 0.44 * shrink
        f.arc((cx, cy), outer, 0, 360 * out(span(t, 0.05, 0.4)), 2.2, 0.75 * alive)
        _ring_of_runes(f, (cx, cy), outer * 0.9, 20, turn * 0.8, w * 0.045, span(t, 0.25, 0.6), 0.9 * alive, first=5)
        _star(f, (cx, cy), r * 0.45, 8, 3, turn * 0.9, out(span(t, 0.3, 0.6)), 1.8, 0.8 * alive)
        for i in range(8):
            # Spokes of light pulsing outward from the rim.
            angle = math.radians(i * 45 + turn * 0.3)
            pulse = 0.5 + 0.5 * math.sin(t * 30 + i)
            f.lines([(cx + r * 1.02 * math.cos(angle), cy + r * 1.02 * math.sin(angle)), (cx + outer * 0.86 * math.cos(angle), cy + outer * 0.86 * math.sin(angle))], 2.0, 0.5 * pulse * alive * span(t, 0.35, 0.5))
    snap = overshoot(span(t, 0.3, 0.44), 2.2)
    for side in (-1, 1):
        x = cx + side * (w * 0.6 - (w * 0.6 - r * 1.12) * snap)
        arm = h * 0.22 * shrink
        f.lines([(x + side * -w * 0.06, cy - arm), (x, cy - arm), (x, cy + arm), (x + side * -w * 0.06, cy + arm)], 6, 0.9 * span(t, 0.28, 0.32) * alive)
    f.disc((cx, cy), w * 0.04 * (1 + 0.3 * math.sin(t * 40)), 0.75 * alive, blur=2)
    release = span(t, 0.84, 1.0)
    if release > 0:
        for wave, lag in ((1.0, 0.0), (0.7, 0.25)):
            k = span(release, lag, 1.0)
            if k > 0:
                reach = w * (0.08 + 0.42 * out(k)) * wave
                f.ellipse((cx, cy), reach, reach, 4 * (1 - k) + 0.5, 0.9 * (1 - k))


def cast_sigil_grand(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    cast_sigil_complex(f, t, w, h, rng, grand=True)


def cast_ground(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """Under a strong caster: a circle on the ground (seen at a slant), runes round it, and motes and runes rising in a
    slow spiral around the caster, as the old games' high spells did. Its ground is at 88% of the height."""
    cx, gy = w / 2, h * 0.88
    alive = fade(t, 0.82, 1.0)
    grow = out(span(t, 0.0, 0.3))
    rx, ry = w * 0.46 * grow, w * 0.46 * 0.28 * grow
    f.ellipse((cx, gy), rx, ry, 10, 0.35 * alive, shade=True, blur=5)
    f.ellipse((cx, gy), rx, ry, 3.4, 0.9 * alive)
    f.ellipse((cx, gy), rx * 0.82, ry * 0.82, 1.6, 0.6 * alive)
    for i in range(14):
        angle = math.radians(i * 360 / 14 + t * 80)
        at = (cx + rx * 0.91 * math.cos(angle), gy + ry * 0.91 * math.sin(angle))
        f.rune(i, at, h * 0.028, 0, 1.5, 0.85 * alive * span(t, 0.1 + i * 0.01, 0.2 + i * 0.01))
    for i in range(22):
        # A mote leaves the ring, rising and circling the caster, fading as it climbs.
        start = (i * 0.037) % 0.6
        life = span(t, start, start + 0.45)
        if life <= 0 or life >= 1:
            continue
        angle = math.radians(i * 137 + life * 260)
        radius = rx * (0.95 - 0.35 * life)
        x = cx + radius * math.cos(angle)
        y = gy + ry * math.sin(angle) - h * 0.75 * out(life, 1.6)
        behind = math.sin(angle) < 0
        size = 3.2 if i % 3 else 0.0
        value = (0.5 if behind else 0.95) * (1 - life) * alive
        if size:
            f.disc((x, y), size, value, blur=1)
            f.lines([(x, y), (x, y + h * 0.05)], 2, value * 0.4, blur=1)
        else:
            f.rune(i, (x, y), h * 0.035, 0, 1.6, value)


def bolt_lance(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A fast bolt, heading right: a sharp lance of light with a bright core, flickering streaks along it and runes
    shed behind. It loops."""
    cy = h / 2
    tip = w * 0.9
    phase = t * 2 * math.pi
    f.polygon([(tip, cy), (tip - w * 0.2, cy - h * 0.13), (w * 0.2, cy - h * 0.035), (w * 0.2, cy + h * 0.035), (tip - w * 0.2, cy + h * 0.13)], 0.45, blur=3)
    f.polygon([(tip, cy), (tip - w * 0.16, cy - h * 0.07), (w * 0.34, cy), (tip - w * 0.16, cy + h * 0.07)], 1.0, blur=1)
    for i in range(3):
        offset = (i - 1) * h * 0.18 * (1 + 0.3 * math.sin(phase * 2 + i))
        start = w * (0.05 + 0.15 * ((t + i * 0.33) % 1.0))
        f.lines([(start, cy + offset), (tip - w * 0.3, cy + offset * 0.4)], 2.2, 0.55, blur=1)
    for i in range(3):
        drift = (t + i / 3) % 1.0
        f.rune(i * 4 + 2, (w * (0.45 - 0.4 * drift), cy + math.sin(phase + i * 2) * h * 0.25), h * 0.2 * (1 - drift * 0.5), drift * 180, 1.6, 0.7 * (1 - drift))


def bolt_orb(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A heavy bolt, heading right: an orb with a corona that pulses, runes orbiting it, and a short fierce tail."""
    cx, cy = w * 0.62, h / 2
    phase = t * 2 * math.pi
    pulse = 1.0 + 0.12 * math.sin(phase * 2)
    for i in range(5):
        length = w * (0.3 + 0.08 * math.sin(phase * 3 + i))
        offset = (i - 2) * h * 0.07
        f.lines([(cx - length, cy + offset * 1.3), (cx, cy + offset * 0.3)], 5 - abs(i - 2), 0.4 - abs(i - 2) * 0.08, blur=2)
    f.disc((cx, cy), h * 0.3 * pulse, 0.35, blur=6)
    f.disc((cx, cy), h * 0.2 * pulse, 0.85, blur=2)
    f.disc((cx, cy), h * 0.1, 1.0, blur=1)
    f.ellipse((cx, cy), h * 0.36 * pulse, h * 0.36 * pulse, 2, 0.6)
    for i in range(4):
        angle = phase + i * math.pi / 2
        at = (cx + math.cos(angle) * h * 0.4, cy + math.sin(angle) * h * 0.4 * 0.6)
        f.rune(i * 3, at, h * 0.16, math.degrees(angle), 1.8, 0.85 if math.sin(angle) > -0.2 else 0.45)


def hit_critical(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A blow that matters: the light is drawn in first (lines racing into the target, a ring closing), then it breaks
    open: long spikes, a dark heart, two shockwaves one after the other, splinters thrown far, runes sprayed."""
    cx, cy = w / 2, h / 2
    contact = 0.16
    if t < contact:
        pull = into(span(t, 0.0, contact), 2)
        ring = w * 0.45 * (1 - pull) + w * 0.05
        f.ellipse((cx, cy), ring, ring, 3, 0.7 * span(t, 0.0, 0.05))
        for i in range(12):
            angle = math.radians(i * 30 + 15)
            outer, inner = w * 0.48 * (1 - pull * 0.6), w * 0.48 * (1 - pull) + w * 0.03
            f.lines([(cx + outer * math.cos(angle), cy + outer * math.sin(angle)), (cx + inner * math.cos(angle), cy + inner * math.sin(angle))], 2.4, 0.6 * pull)
        return
    after = span(t, contact, 1.0)
    f.disc((cx, cy), w * 0.2 * (1 - out(after, 2)), 0.95 * fade(t, contact, 0.4), shade=True, blur=5)
    burst = fade(t, contact, contact + 0.18)
    for i in range(16):
        angle = math.radians(i * 22.5 + (11 if i % 2 else 0))
        reach = w * (0.47 if i % 2 == 0 else 0.3) * (0.3 + 0.7 * out(span(t, contact, contact + 0.07)))
        f.lines([(cx + w * 0.04 * math.cos(angle), cy + w * 0.04 * math.sin(angle)), (cx + reach * math.cos(angle), cy + reach * math.sin(angle))], 6 * burst + 0.5, 0.95 * burst)
    for lag, strength in ((0.0, 1.0), (0.14, 0.7)):
        k = span(after, lag, 1.0)
        if k > 0:
            ring = w * (0.06 + 0.44 * out(k, 3))
            f.ellipse((cx, cy), ring, ring, 12 * (1 - k) + 1, 0.95 * strength * (1 - k))
            f.ellipse((cx, cy), ring * 0.92, ring * 0.92, 14 * (1 - k), 0.5 * strength * (1 - k), shade=True, blur=3)
    for i in range(22):
        angle = rng.uniform(0, 360)
        reach = w * rng.uniform(0.25, 0.5) * out(after, 3)
        at = (cx + reach * math.cos(math.radians(angle)), cy + reach * math.sin(math.radians(angle)) + h * 0.12 * after * after)
        f.polygon(shard(at, w * rng.uniform(0.025, 0.05), angle, 1.0 + 2.5 * (1 - after)), 0.9 * fade(t, 0.45, 0.95))
    for i in range(10):
        angle = i * 36 + 10
        reach = w * 0.3 * out(after, 2) + w * 0.05
        at = (cx + reach * math.cos(math.radians(angle)), cy + reach * math.sin(math.radians(angle)) - h * 0.12 * after)
        f.rune(i + 2, at, h * 0.055, angle * 2 * after, 1.6, 0.75 * fade(t, 0.5, 1.0))


def bolt_thorn(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A rootglass thorn in flight, heading right: a long faceted spike of glass light, a ring of sap-light round its
    waist, two leaves trailing off it and a stream of droplets behind. It loops (ADR-0037)."""
    cy = h / 2
    tip = w * 0.92
    phase = t * 2 * math.pi
    # The thorn: a halo, the body, then a bright spine down its middle.
    body = [(tip, cy), (w * 0.62, cy - h * 0.17), (w * 0.3, cy - h * 0.07), (w * 0.24, cy), (w * 0.3, cy + h * 0.07), (w * 0.62, cy + h * 0.17)]
    f.polygon(body, 0.35, blur=4)
    f.polygon(body, 0.75, blur=1)
    f.lines([(w * 0.3, cy), (tip, cy)], 2.4, 1.0)
    for side in (-1, 1):
        f.lines([(w * 0.62, cy + side * h * 0.17), (tip, cy)], 1.4, 0.8)
        f.lines([(w * 0.62, cy + side * h * 0.17), (w * 0.44, cy)], 1.2, 0.6)
    f.polygon(body, 0.35, shade=True, blur=2)
    # A ring of light turning round its waist.
    waist = 0.5 + 0.5 * math.sin(phase * 2)
    f.ellipse((w * 0.5, cy), w * 0.025, h * (0.22 + 0.05 * waist), 2, 0.8)
    # Two leaves peeling off behind, fluttering.
    for side in (-1, 1):
        flutter = math.sin(phase * 2 + side) * h * 0.05
        base = (w * 0.3, cy + side * h * 0.04)
        leaf_tip = (w * 0.08, cy + side * (h * 0.3 + flutter))
        mid = ((base[0] + leaf_tip[0]) / 2, (base[1] + leaf_tip[1]) / 2)
        bulge = (0, side * h * 0.07)
        f.polygon([base, (mid[0] + bulge[1] * 0.4, mid[1] + bulge[1]), leaf_tip, (mid[0] - bulge[1] * 0.4, mid[1] - bulge[1] * 0.2)], 0.55, blur=1)
        f.lines([base, leaf_tip], 1.0, 0.85)
    # Droplets of sap-light streaming back.
    for i in range(6):
        drift = (t * 2 + i / 6) % 1.0
        x = w * (0.26 - 0.24 * drift)
        y = cy + math.sin(phase * 3 + i * 1.7) * h * 0.12
        f.disc((x, y), h * 0.03 * (1 - drift * 0.6), 0.8 * (1 - drift), blur=1)


def hit_starfall(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A star falls on the foe (ADR-0037): it is lit high to the upper left, hangs a beat as its points open, then
    streaks down at a slant and bursts at the foe's feet: a flash, a star-shaped spray of light, a ring along the
    ground, and sparkles drifting down. Its ground is at 88% of the height."""
    ground = h * 0.88
    cx = w / 2
    start = (w * 0.22, h * 0.13)
    land = 0.54
    if t < land:
        shown = span(t, 0.0, 0.12)
        fall = span(t, 0.26, land)
        x = start[0] + (cx - start[0]) * into(fall, 2.2)
        y = start[1] + (ground - h * 0.04 - start[1]) * into(fall, 2.2)
        size = w * (0.07 + 0.03 * math.sin(t * 50)) * shown
        if fall > 0:
            # The streak behind it, longer as it speeds up.
            back = (x - (x - start[0]) * min(1.0, 0.35 + fall * 0.6), y - (y - start[1]) * min(1.0, 0.35 + fall * 0.6))
            f.lines([back, (x, y)], size * 0.9, 0.35, blur=5)
            f.lines([back, (x, y)], 3, 0.9)
        f.disc((x, y), size * 1.4, 0.4 * shown, blur=4)
        for k in range(4):
            angle = 45 * k + t * 240
            arm = rotate((size * 1.8, 0), angle)
            f.polygon([(x + arm[0], y + arm[1]), (x + arm[1] * 0.18, y - arm[0] * 0.18), (x - arm[0] * 0.2, y - arm[1] * 0.2), (x - arm[1] * 0.18, y + arm[0] * 0.18)], 0.95 * shown)
        f.disc((x, y), size * 0.5, 1.0 * shown)
        return
    after = span(t, land, 1.0)
    f.disc((cx, ground - h * 0.05), w * 0.2 * (1 - after), 0.9 * (1 - span(after, 0, 0.2)), blur=6)
    spread = w * 0.46 * out(after, 3)
    f.ellipse((cx, ground), spread, spread * 0.2, 6 * (1 - after) + 1, 0.9 * (1 - after))
    f.ellipse((cx, ground), spread * 0.8, spread * 0.16, 14, 0.5 * (1 - after), shade=True, blur=4)
    # A star of light burst from the point of impact, its arms shrinking back.
    for k in range(8):
        angle = -90 + k * 45
        reach = h * (0.42 if k % 2 == 0 else 0.24) * out(span(after, 0, 0.35), 2) * (1 - span(after, 0.35, 1.0))
        tip = (cx + reach * math.cos(math.radians(angle)), ground - h * 0.05 + reach * math.sin(math.radians(angle)) * 0.9)
        f.lines([(cx, ground - h * 0.05), tip], 5 if k % 2 == 0 else 3, 0.9)
    # Sparkles flung up, then drifting down.
    for k in range(10):
        angle = -90 + rng.uniform(-70, 70)
        reach = h * rng.uniform(0.15, 0.4) * out(after, 2)
        at = (cx + reach * math.cos(math.radians(angle)), ground - h * 0.05 + reach * math.sin(math.radians(angle)) + h * 0.25 * after * after)
        size = w * 0.018 * (1 - after)
        f.lines([(at[0] - size * 2, at[1]), (at[0] + size * 2, at[1])], 2, 0.9 * (1 - after))
        f.lines([(at[0], at[1] - size * 2), (at[0], at[1] + size * 2)], 2, 0.9 * (1 - after))


def hit_roots(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """Roots erupt under the foe (ADR-0037): a ring of runes cracks open on the ground, the floor splits, and roots
    of light spear up through the foe from the cracks (the blow), splinter, and sink back as runes rise. Its ground
    is at 88% of the height."""
    ground = h * 0.88
    cx = w / 2
    land = 0.5
    ring = span(t, 0.0, 0.3)
    fade_all = 1 - span(t, 0.82, 1.0)
    # The ring on the ground, seen at a slant, its runes set one by one.
    f.ellipse((cx, ground), w * 0.36 * out(ring, 2), w * 0.36 * 0.22 * out(ring, 2), 3, 0.85 * fade_all)
    f.ellipse((cx, ground), w * 0.36, w * 0.36 * 0.22, 16, 0.4 * ring * fade_all, shade=True, blur=4)
    for k in range(10):
        shown = span(ring * 10 - k, 0, 1)
        angle = math.radians(k * 36)
        f.rune(k, (cx + math.cos(angle) * w * 0.3, ground + math.sin(angle) * w * 0.3 * 0.22), h * 0.045, 0, 1.6, 0.9 * shown * fade_all)
    # Cracks racing out from the middle.
    crack = span(t, 0.22, land)
    for k in range(6):
        angle = math.radians(k * 60 + 15)
        points = [(cx, ground)]
        for step in range(1, 5):
            r = w * 0.34 * crack * step / 4
            wobble = math.radians(rng.uniform(-14, 14))
            points.append((cx + math.cos(angle + wobble) * r, ground + math.sin(angle + wobble) * r * 0.22))
        f.lines(points, 2.4, 0.9 * fade_all)
        f.lines(points, 5, 0.6 * fade_all, shade=True)
    if t < land - 0.04:
        return
    # The roots: thorns of light spearing up from the cracks, tallest in the middle, then sinking back.
    rise = out(span(t, land - 0.04, land + 0.08), 3)
    sink = into(span(t, 0.66, 0.92), 2)
    for k in range(7):
        x = cx + (k - 3) * w * 0.1 + rng.uniform(-6, 6)
        tall = h * (0.66 - abs(k - 3) * 0.12) * rise * (1 - sink)
        lean = (k - 3) * w * 0.035
        base = w * (0.05 - abs(k - 3) * 0.006)
        if tall <= 1:
            continue
        spike = [(x - base, ground), (x + lean, ground - tall), (x + base, ground)]
        f.polygon(spike, 0.4, blur=3)
        f.polygon(spike, 0.75, blur=1)
        f.polygon(spike, 0.3, shade=True)
        f.lines([(x, ground), (x + lean, ground - tall)], 1.6, 1.0)
        # A thorn on its side.
        side = (x + lean * 0.5 + (base if k % 2 else -base) * 1.6, ground - tall * 0.55)
        f.lines([(x + lean * 0.5, ground - tall * 0.5), side], 1.4, 0.8)
    f.disc((cx, ground - h * 0.25), w * 0.16 * (1 - span(t, land, land + 0.18)), 0.7 * (1 - span(t, land, land + 0.18)), blur=6)
    # Runes rising from the cracks as the roots sink.
    for k in range(6):
        drift = span(t, 0.62 + k * 0.03, 1.0)
        if drift <= 0:
            continue
        x = cx + (k - 2.5) * w * 0.12
        f.rune(k + 4, (x, ground - h * 0.1 - h * 0.35 * out(drift, 2)), h * 0.05, drift * 90, 1.5, 0.8 * (1 - drift))


def hit_pillar(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A pillar of judgment (ADR-0037): a circle is written on the ground under the foe and another high above it,
    a thin line of light joins them, and the column slams down full width (the blow), burns, then narrows to a thread
    and is gone, runes racing round its foot. Its ground is at 88% of the height."""
    ground = h * 0.88
    cx = w / 2
    top = h * 0.06
    land = 0.52
    writing = span(t, 0.0, 0.32)
    fade_all = 1 - span(t, 0.8, 1.0)
    for y, size in ((ground, 0.34), (top + h * 0.03, 0.22)):
        rx = w * size
        f.ellipse((cx, y), rx * out(writing, 2), rx * 0.2 * out(writing, 2), 3, 0.85 * fade_all)
        f.ellipse((cx, y), rx * 0.75 * out(writing, 2), rx * 0.15 * out(writing, 2), 1.6, 0.6 * fade_all)
    # A thread of light from the upper circle to the lower before the column comes.
    thread = span(t, 0.3, land - 0.04)
    if 0 < thread and t < land:
        f.lines([(cx, top + h * 0.03), (cx, top + h * 0.03 + (ground - top) * into(thread, 2))], 2, 0.9)
    # The column.
    if t >= land - 0.04:
        slam = out(span(t, land - 0.04, land + 0.02), 3)
        narrow = into(span(t, 0.68, 0.92), 2)
        half = w * 0.16 * slam * (1 - narrow) + 1.5
        reach = top + h * 0.03 + (ground - top) * slam
        f.polygon([(cx - half, top + h * 0.03), (cx + half, top + h * 0.03), (cx + half, reach), (cx - half, reach)], 0.45 * fade_all, blur=6)
        f.polygon([(cx - half * 0.55, top + h * 0.03), (cx + half * 0.55, top + h * 0.03), (cx + half * 0.55, reach), (cx - half * 0.55, reach)], 1.0 * fade_all, blur=1)
        f.polygon([(cx - half * 1.2, ground - h * 0.4), (cx + half * 1.2, ground - h * 0.4), (cx + half * 1.2, ground), (cx - half * 1.2, ground)], 0.25 * fade_all, shade=True, blur=5)
        after = span(t, land, land + 0.3)
        spread = w * 0.44 * out(after, 3)
        f.ellipse((cx, ground), spread, spread * 0.2, 6 * (1 - after) + 1, 0.9 * (1 - after))
        # Runes racing round its foot.
        for k in range(8):
            angle = math.radians(k * 45 + t * 520)
            f.rune(k + 1, (cx + math.cos(angle) * w * 0.27, ground + math.sin(angle) * w * 0.27 * 0.2), h * 0.04, 0, 1.5, 0.85 * fade_all * span(t, land, land + 0.06))


MOTIONS = {
    "cast-sigil": cast_sigil,
    "cast-sigil-simple": cast_sigil_simple,
    "cast-sigil-complex": cast_sigil_complex,
    "cast-sigil-grand": cast_sigil_grand,
    "cast-ground": cast_ground,
    "bolt-lance": bolt_lance,
    "bolt-orb": bolt_orb,
    "hit-critical": hit_critical,
    "glyph-bolt": glyph_bolt,
    "hit-compile": hit_compile,
    "hit-heavy": hit_heavy,
    "ward-hex": ward_hex,
    "shatter": shatter,
    "claw": claw,
    "tempo": tempo,
    "bolt-thorn": bolt_thorn,
    "hit-starfall": hit_starfall,
    "hit-roots": hit_roots,
    "hit-pillar": hit_pillar,
}


# ---------------------------------------------------------------------------------------------------------------------
# Sheets


def draw(spec: dict) -> tuple[list[np.ndarray], dict]:
    w, h = spec["size"]
    frames = int(spec["frames"])
    motion = MOTIONS[spec["motion"]]
    out_frames = []
    for index in range(frames):
        # A looping animation's last frame leads back into its first; a one-shot's last frame is its end.
        t = index / frames if spec.get("loop") else index / max(1, frames - 1)
        frame = Frame(w, h)
        motion(frame, t, w, h, random.Random(spec.get("seed", 7)))
        out_frames.append(frame.finish(w, h, float(spec.get("bloom", 0.6))))
    columns = int(spec.get("columns", 8))
    facts = {
        "frames": frames,
        "columns": columns,
        "size": [w, h],
        "fps": float(spec.get("fps", 30)),
        "loop": bool(spec.get("loop", False)),
        "anchor": spec.get("anchor", [0.5, 0.5]),
        "impact": float(spec.get("impact", 0.0)),
    }
    # The sound that belongs to it (docs/SOUND_DESIGN.md), started with its first frame by the game.
    if spec.get("sound"):
        facts["sound"] = spec["sound"]
        facts["element_layer"] = bool(spec.get("element_layer", False))
    return out_frames, facts


def sheet_of(frames: list[np.ndarray], columns: int) -> Image.Image:
    h, w = frames[0].shape[:2]
    rows = -(-len(frames) // columns)
    grid = np.zeros((rows * h, columns * w, 3), np.uint8)
    for index, frame in enumerate(frames):
        row, column = divmod(index, columns)
        grid[row * h : (row + 1) * h, column * w : (column + 1) * w] = frame
    return Image.fromarray(grid, "RGB")


def preview(frames: list[np.ndarray], colour: tuple[int, int, int], picks: int = 8) -> Image.Image:
    """A strip of frames as the game would show them on a dark stage: light through a ramp, shade darkening."""
    h, w = frames[0].shape[:2]
    chosen = [frames[round(i * (len(frames) - 1) / max(1, picks - 1))] for i in range(picks)]
    strip = np.zeros((h, w * picks, 3), np.float32)
    ground = np.array([48, 38, 34], np.float32) / 255
    tint = np.array(colour, np.float32) / 255
    for i, frame in enumerate(chosen):
        light = frame[..., 0:1].astype(np.float32) / 255
        shade = frame[..., 1:2].astype(np.float32) / 255
        ramp = np.where(light < 0.5, tint * 0.25 + (tint - tint * 0.25) * light * 2, tint + (np.minimum(1, tint * 0.4 + 0.6) - tint) * (light - 0.5) * 2)
        strip[:, i * w : (i + 1) * w] = ground * (1 - shade * 0.7) + ramp * light
    return Image.fromarray((np.clip(strip, 0, 1) * 255).astype(np.uint8), "RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--only", help="comma-separated ids; a trailing * matches a prefix")
    parser.add_argument("--sheet", action="store_true", help="write a preview of every animation to the cache")
    args = parser.parse_args()
    manifest = json.loads((HERE / "spells.json").read_text())
    wanted = [w.strip() for w in args.only.split(",")] if args.only else None

    def chosen(spell_id: str) -> bool:
        return wanted is None or any(spell_id == w or (w.endswith("*") and spell_id.startswith(w[:-1])) for w in wanted)

    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    previews = []
    for spec in manifest["spells"]:
        if not chosen(spec["id"]):
            continue
        frames, facts = draw(spec)
        sheet_of(frames, facts["columns"]).save(OUT / f"{spec['id']}.png", optimize=True)
        (OUT / f"{spec['id']}.json").write_text(json.dumps(facts) + "\n")
        print(f"{spec['id']}: {facts['frames']} frames at {facts['size'][0]}x{facts['size'][1]}", flush=True)
        if args.sheet:
            previews.append(preview(frames, tuple(int(spec.get("preview", "#b48cff").lstrip("#")[i : i + 2], 16) for i in (0, 2, 4))))
    if previews:
        width = max(p.width for p in previews)
        board = Image.new("RGB", (width, sum(p.height for p in previews)), (12, 10, 14))
        y = 0
        for p in previews:
            board.paste(p, (0, y))
            y += p.height
        board.save(CACHE / "preview.png")
        print(f"preview {CACHE / 'preview.png'}")


if __name__ == "__main__":
    main()
