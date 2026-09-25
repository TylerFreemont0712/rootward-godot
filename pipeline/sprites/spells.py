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
    contact = 0.16
    slam = into(span(t, 0.0, contact), 2.4)
    if t < contact + 0.1:
        for side in (-1, 1):
            x = cx + side * (w * 0.46 - w * 0.34 * slam)
            arm = h * 0.16
            f.lines([(x + side * w * 0.05, cy - arm), (x, cy - arm), (x, cy + arm), (x + side * w * 0.05, cy + arm)], 6, 0.9 * fade(t, contact, contact + 0.1))
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
        for i in range(14):
            angle = rng.uniform(0, 360)
            speed = rng.uniform(0.25, 0.48)
            reach = w * speed * out(after, 3)
            at = (cx + reach * math.cos(math.radians(angle)), cy + reach * math.sin(math.radians(angle)))
            size = w * rng.uniform(0.03, 0.06)
            f.polygon(shard(at, size, angle, 1.0 + 2.0 * (1 - after)), 0.9 * fade(t, 0.35, 0.9))
        for i in range(8):
            angle = i * 45 + 20
            reach = w * 0.2 * out(after, 2) + w * 0.06
            at = (cx + reach * math.cos(math.radians(angle)), cy + reach * math.sin(math.radians(angle)) - h * 0.1 * after)
            f.rune(i + 4, at, h * 0.06, angle * 2 * after, 1.6, 0.7 * fade(t, 0.4, 0.95))


def hit_heavy(f: Frame, t: float, w: int, h: int, rng: random.Random) -> None:
    """A heavy blow: blocks of code fall one after another onto the target and crash, each splashing on the ground, the
    last and largest shaking loose a ring of dust. Its ground is at 85% of the height."""
    ground = h * 0.85
    cx = w / 2
    drops = [(0.0, -0.12), (0.08, 0.14), (0.16, -0.02), (0.24, 0.1), (0.34, 0.0)]
    for index, (start, dx) in enumerate(drops):
        fall = span(t, start, start + 0.1)
        last = index == len(drops) - 1
        bw, bh = w * (0.3 if last else 0.2), h * (0.2 if last else 0.13)
        x = cx + dx * w
        if fall < 1:
            y = -bh + (ground - bh * 0.5 + bh) * into(fall, 2.2)
            f.lines([(x, y - h * 0.45 * fall), (x, y)], bw * 0.5, 0.3 * fall, blur=5)
            f.lines([(x - bw * 0.3, y - h * 0.3 * fall), (x - bw * 0.3, y)], 2, 0.5 * fall)
            f.lines([(x + bw * 0.3, y - h * 0.3 * fall), (x + bw * 0.3, y)], 2, 0.5 * fall)
            f.polygon([(x - bw / 2, y - bh / 2), (x + bw / 2, y - bh / 2), (x + bw / 2, y + bh / 2), (x - bw / 2, y + bh / 2)], 0.35, shade=True)
            f.lines([(x - bw / 2, y - bh / 2), (x + bw / 2, y - bh / 2), (x + bw / 2, y + bh / 2), (x - bw / 2, y + bh / 2), (x - bw / 2, y - bh / 2)], 3, 0.9)
            f.rune(index * 2 + 3, (x, y), bh * 0.7, 0, 2.2, 0.9)
            continue
        after = span(t, start + 0.1, start + 0.1 + (0.5 if last else 0.3))
        if after >= 1:
            continue
        spread = w * (0.5 if last else 0.22) * out(after, 3)
        f.ellipse((x, ground), spread, spread * 0.22, 6 * (1 - after) + 1, 0.9 * (1 - after))
        f.ellipse((x, ground), spread * 0.8, spread * 0.18, 12, 0.5 * (1 - after), shade=True, blur=4)
        for k in range(6 if last else 4):
            angle = -90 + rng.uniform(-60, 60)
            reach = h * rng.uniform(0.12, 0.3 if last else 0.18) * out(after, 2)
            fall_back = h * 0.25 * after * after
            at = (x + reach * math.cos(math.radians(angle)), ground + reach * math.sin(math.radians(angle)) + fall_back)
            f.polygon(shard(at, w * 0.035, angle, 1.6), 0.85 * (1 - after))
        f.disc((x, ground - bh * 0.3), w * (0.1 if last else 0.07) * (1 - after), 0.65 * (1 - span(after, 0, 0.3)), blur=3)
        for k in range(5 if last else 3):
            # Sparks thrown straight up from the crash.
            rise = out(after, 2)
            sx = x + (k - 2) * w * 0.05
            f.lines([(sx, ground - h * 0.05 - h * 0.35 * rise), (sx, ground - h * 0.05 - h * 0.25 * rise)], 2.2, 0.8 * (1 - after))


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


MOTIONS = {
    "cast-sigil": cast_sigil,
    "glyph-bolt": glyph_bolt,
    "hit-compile": hit_compile,
    "hit-heavy": hit_heavy,
    "ward-hex": ward_hex,
    "shatter": shatter,
    "claw": claw,
    "tempo": tempo,
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
