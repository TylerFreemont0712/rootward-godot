#!/usr/bin/env python3
"""Sound ingredients made from nothing but numbers (docs/SOUND_DESIGN.md, "The palette"): the parts of the fight's
sounds whose pitch and shape must be exact, which no recording has. Each is a function of its arguments and a seed,
returning float stereo at 48 kHz, so a sound's recipe in the manifest makes the same sound every time.

A manifest layer names one: `{"synth": "rune_tick", "note": "A6", "delay_ms": 128, "gain_db": -14}`; every key but
the layer's own (delay_ms, gain_db, rate, reverse, pan, lp, hp, ...) is passed to the function, and `seed` comes from
the sound and the layer's place in it, so the takes of a sound (sfx-hit-1 to -4) differ.

Pitched ingredients sit in D, the soundtrack's home (D major's notes: D E F# G A B C#).

Second pass (test/sfx/SFX.md): the first palette was built on a Chamberlin state-variable filter that is inaccurate
above a few kHz, so its "band-limited" noise was a wall of hiss up to 20 kHz, its sub booms sat at 32-45 Hz where
no laptop speaker or pair of headphones reaches, and its glass was bare sine pings. The ingredients below keep their
names and arguments, so every manifest recipe still works, but they are built on an accurate filter (TPT), real filters
(Butterworth) for band limits, modal synthesis (decaying inharmonic partials, as glass and metal ring) for glass and
plates, thumps with an audible fundamental (90-200 Hz) and saturated harmonics, soft starts and ends on every sound
(no clicks), and a reverb tail that builds in rather than starting at full level.
"""

from __future__ import annotations

import math

import numpy as np

# LEARN: scipy is already in the pipeline's environment (librosa depends on it), so it is imported here without
# being listed in pipeline/pyproject.toml.
from scipy import signal as sg

RATE = 48000
NOTES = {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5, "F": -4, "F#": -3, "Gb": -3, "G": -2,
         "G#": -1, "Ab": -1, "A": 0, "A#": 1, "Bb": 1, "B": 2}

# Partial ratios (ratio, amplitude, relative decay) of the things that ring.
GLASS = ((1.0, 1.0, 1.0), (2.32, 0.55, 0.6), (4.25, 0.32, 0.4), (6.63, 0.16, 0.28), (9.38, 0.08, 0.2))
PLATE = ((1.0, 1.0, 1.0), (1.593, 0.7, 0.8), (2.136, 0.5, 0.6), (2.653, 0.38, 0.45), (3.5, 0.22, 0.3))
BAR = ((1.0, 1.0, 1.0), (2.76, 0.5, 0.5), (5.4, 0.25, 0.3), (8.93, 0.1, 0.15))
BELL = ((1.0, 1.0, 1.0), (2.0, 0.5, 0.7), (2.76, 0.45, 0.5), (5.4, 0.25, 0.25), (8.93, 0.12, 0.12))


def hz(note: str | float) -> float:
    """A frequency from a note name (`D6`, `F#5`) or a number of hertz."""
    if isinstance(note, (int, float)):
        return float(note)
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTES[name] + 12 * (octave - 4)) / 12)


def seconds(n: float) -> np.ndarray:
    return np.arange(int(n * RATE)) / RATE


def stereo(mono: np.ndarray, pan: float = 0.0) -> np.ndarray:
    """Equal-power pan, -1 left to 1 right."""
    angle = (pan + 1) * math.pi / 4
    return np.column_stack([mono * math.cos(angle), mono * math.sin(angle)]).astype(np.float32)


def envelope(n: int, attack: float, decay: float, hold: float = 0.0) -> np.ndarray:
    """A raised-cosine attack (no click at its start), an optional hold, then an exponential decay to -60 dB over
    `decay` seconds."""
    t = np.arange(n) / RATE
    rise = 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(attack, 1e-4), 0, 1))
    fall = np.where(t < attack + hold, 1.0, np.exp(-6.9 * (t - attack - hold) / max(decay, 1e-4)))
    return rise * fall


def edge(signal: np.ndarray, fade_in: float = 0.0005, fade_out: float = 0.006) -> np.ndarray:
    """Cosine fades at both ends: a sound that starts and ends on zero cannot click."""
    n = len(signal)
    out = signal.copy()
    a = min(n // 2, int(fade_in * RATE))
    b = min(n // 2, int(fade_out * RATE))
    shape = (slice(None),) + (None,) * (signal.ndim - 1)
    if a > 1:
        out[:a] *= (0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a))[shape]
    if b > 1:
        out[n - b:] *= (0.5 + 0.5 * np.cos(np.pi * np.arange(b) / b))[shape]
    return out


def _sos(kind: str, cutoff: float | tuple[float, float], order: int) -> np.ndarray:
    return sg.butter(order, cutoff, btype=kind, fs=RATE, output="sos")


def lp(signal: np.ndarray, cutoff: float, order: int = 4) -> np.ndarray:
    """A Butterworth low pass: what actually removes the hiss above `cutoff`."""
    return sg.sosfilt(_sos("low", min(cutoff, RATE * 0.45), order), signal, axis=0)


def hp(signal: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return sg.sosfilt(_sos("high", cutoff, order), signal, axis=0)


def bp(signal: np.ndarray, low: float, high: float, order: int = 2) -> np.ndarray:
    """A Butterworth band pass: noise that really stays between `low` and `high`."""
    return sg.sosfilt(_sos("band", (low, min(high, RATE * 0.45)), order), signal, axis=0)


def svf(signal: np.ndarray, cutoff: np.ndarray | float, q: float = 0.7, mode: str = "band") -> np.ndarray:
    """A state-variable filter whose cutoff may move per sample (low, band or high pass): what makes noise sweep,
    whistle and rush. The band output has unit gain at the cutoff.

    LEARN: this is the topology-preserving (Zavalishin) form. The Chamberlin form this replaced is two integrators in
    a loop with `f = 2 sin(pi fc / fs)`, which is only accurate well below the sample rate: above a few kHz its
    cutoff, its Q and so its skirts are wrong, and "band-limited" noise leaks broadband hiss. This form is exact at
    every cutoff (`g = tan(pi fc / fs)`), at the same cost."""
    n = len(signal)
    cut = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), (n,))
    g = np.tan(np.pi * np.clip(cut, 20, RATE * 0.45) / RATE)
    k = 1.0 / max(q, 0.3)
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    pick = {"low": 0, "band": 1, "high": 2}[mode]
    x = np.asarray(signal, dtype=np.float64).tolist()
    a1l, a2l, a3l = a1.tolist(), a2.tolist(), a3.tolist()
    ic1 = ic2 = 0.0
    out = [0.0] * n
    for i in range(n):
        v3 = x[i] - ic2
        v1 = a1l[i] * ic1 + a2l[i] * v3
        v2 = ic2 + a2l[i] * ic1 + a3l[i] * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        out[i] = v2 if pick == 0 else (k * v1 if pick == 1 else x[i] - k * v1 - v2)
    return np.asarray(out)


def glide(start: float, end: float, n: int, curve: float = 1.0) -> np.ndarray:
    """A pitch or cutoff moving from start to end, exponentially (as the ear hears pitch), `curve` > 1 lingering."""
    x = np.linspace(0, 1, n) ** curve
    return start * (end / start) ** x


def glide_then(start: float, end: float, n: int, over: float) -> np.ndarray:
    """A glide over the first `over` seconds, then held at its end for the rest of `n` samples."""
    moving = min(n, int(over * RATE))
    return np.concatenate([glide(start, end, moving), np.full(n - moving, end)])


def tone(frequency: np.ndarray | float, n: int, phase: float = 0.0) -> np.ndarray:
    """A sine whose frequency may glide."""
    freq = np.broadcast_to(np.asarray(frequency, dtype=np.float64), (n,))
    return np.sin(phase + 2 * np.pi * np.cumsum(freq) / RATE)


def modal(base: float, partials: tuple, n: int, rng: np.random.Generator, decay: float = 0.1, attack: float = 0.0004,
          spread: float = 0.002, top: float = 14000.0) -> np.ndarray:
    """A struck thing ringing: decaying sines at inharmonic ratios of `base` (GLASS, PLATE, BAR, BELL above), the high
    ones dying first. This is why a recording of glass or metal sounds like itself and a bare sine does not."""
    t = np.arange(n) / RATE
    out = np.zeros(n)
    for ratio, amp, rel in partials:
        freq = base * ratio * (1 + rng.uniform(-spread, spread))
        if freq > top:
            continue
        out += amp * np.sin(2 * np.pi * freq * t + rng.uniform(0, 6.28)) * np.exp(-6.9 * t / max(decay * rel, 1e-3))
    rise = 0.5 - 0.5 * np.cos(np.pi * np.clip(t / max(attack, 1e-4), 0, 1))
    return out * rise


def soft(signal: np.ndarray, drive: float = 2.0) -> np.ndarray:
    """A gentle saturation: adds the harmonics that make a low thump audible on small speakers."""
    return np.tanh(signal * drive) / np.tanh(drive)


def room(dry: np.ndarray, size: float = 0.8, mix: float = 0.3, seed: int = 0, bright: float = 6000) -> np.ndarray:
    """A small, soft reverb: the sound convolved with a decaying noise tail of `size` seconds, a different tail per
    ear so the room is wide. The tail builds in over a few milliseconds (a tail that starts at full level buzzes).
    Stereo in, stereo out, longer by the tail."""
    rng = np.random.default_rng(seed + 991)
    n = int(size * RATE)
    t = np.arange(n) / RATE
    decay = np.exp(-6.9 * np.arange(n) / n) * (1 - np.exp(-t / 0.008))
    tails = []
    for _ in range(2):
        tail = rng.standard_normal(n) * decay
        spectrum = np.fft.rfft(tail)
        freqs = np.fft.rfftfreq(n, 1 / RATE)
        spectrum *= 1 / (1 + (freqs / bright) ** 2)
        spectrum *= 1 / (1 + (120 / np.maximum(freqs, 1)) ** 2)  # no rumble in the room
        tail = np.fft.irfft(spectrum, n)
        tails.append(tail / (np.sqrt(np.sum(tail ** 2)) + 1e-9))
    length = len(dry) + n
    wet = np.zeros((length, 2))
    for channel in range(2):
        size_fft = 1 << (length - 1).bit_length()
        wet[:, channel] = np.fft.irfft(np.fft.rfft(dry[:, channel], size_fft) * np.fft.rfft(tails[channel], size_fft),
                                       size_fft)[:length]
    out = np.zeros((length, 2))
    out[: len(dry)] = dry * (1 - mix)
    return (out + wet * mix * 0.6).astype(np.float32)


def normal(signal: np.ndarray, peak: float = 0.9) -> np.ndarray:
    top = np.abs(signal).max()
    return signal * (peak / top) if top > 0 else signal


def finish(signal: np.ndarray, peak: float = 0.9, fade_out: float = 0.008, low: float = 0.0, high: float = 0.0) -> np.ndarray:
    """The last step of every ingredient: optional band limits, soft start and end, a level."""
    if high:
        signal = lp(signal, high)
    if low:
        signal = hp(signal, low)
    return normal(edge(signal, 0.0004, fade_out), peak)


# --------------------------------------------------------------------------------------------------------------------
# The ingredients


def shimmer(seed: int = 0, length: float = 0.36, note: str = "D6", rise: bool = True, width: float = 0.6) -> np.ndarray:
    """Light drawing itself: a glassy cluster of D major's notes swelling in with the drawing, a little upward glide,
    a soft breath of air, in a small room. Each note is a detuned pair (a chorus), the upper ones quieter."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    tail = int(0.14 * RATE)
    total = n + tail
    base = hz(note)
    t = np.arange(total) / RATE
    swell = np.clip(t / length, 0, 1) ** (1.6 if rise else 0.6)
    swell = np.where(t < length, swell, np.exp(-6.9 * (t - length) / 0.14))
    out = np.zeros((total, 2))
    for ratio, level in ((1.0, 1.0), (1.5, 0.65), (2.0, 0.42), (2.5198, 0.26), (3.0, 0.14), (4.0, 0.07)):
        if base * ratio > 8500:
            continue
        start = rng.uniform(0, 0.35) * length
        onset = np.clip((t - start) / (0.3 * length), 0, 1)
        drift = glide(1.0, 1.0 + (0.012 if rise else 0.0), total)
        wobble = 1 + 0.002 * np.sin(2 * np.pi * rng.uniform(4, 7) * t + rng.uniform(0, 6))
        for detune in (-0.0015, 0.0015):
            mono = tone(base * ratio * drift * wobble * (1 + detune), total, rng.uniform(0, 6)) * level * 0.5 * onset
            out += stereo(mono, rng.uniform(-width, width))
    air = bp(rng.standard_normal(total), 2200, 6000) * 0.07
    out += stereo(air, 0.0)
    out *= swell[:, None]
    return finish(room(out.astype(np.float32), 0.6, 0.35, seed, 5000), 0.8, 0.02, low=150, high=9000)


def rune_tick(seed: int = 0, note: str = "D7", length: float = 0.09) -> np.ndarray:
    """A rune taking its place: a small bright glass pluck on a note, a softer click at its front and a warm octave
    below it so the tick has a body rather than being a bare beep."""
    rng = np.random.default_rng(seed)
    n = int((length + 0.06) * RATE)
    base = hz(note) * (1 + rng.uniform(-0.004, 0.004))
    ping = (tone(base, n) + 0.28 * tone(base * 2.76, n) * np.exp(-6.9 * np.arange(n) / RATE / (0.5 * length))) \
        * envelope(n, 0.0008, length)
    body = tone(base / 2, n) * envelope(n, 0.001, 0.035) * 0.3
    click = bp(rng.standard_normal(n), 3000, 7000) * envelope(n, 0.0004, 0.004) * 0.2
    mono = lp(ping * 0.7 + body + click, 9000, 2)
    return finish(stereo(mono, rng.uniform(-0.4, 0.4)), 0.8, 0.012)


def bracket_clack(seed: int = 0, weight: float = 1.0) -> np.ndarray:
    """Two hard plates snapping shut, a hair apart: the code's brackets closing. Each is a metal plate ringing
    briefly, a bright crack at its front and a short thunk under it."""
    rng = np.random.default_rng(seed)
    n = int(0.3 * RATE)
    out = np.zeros((n, 2))
    for index, (at, pan) in enumerate(((0.0, -0.3), (rng.uniform(0.009, 0.014), 0.3))):
        start = int(at * RATE)
        m = n - start
        plate = modal(1750 * rng.uniform(0.94, 1.06) * (1.1 if index else 1.0), PLATE, m, rng, 0.07, 0.0003)
        crack = bp(rng.standard_normal(m), 2200, 6500) * envelope(m, 0.0003, 0.007)
        thunk = tone(glide(250, 125, m), m) * envelope(m, 0.0008, 0.04) * weight
        out[start:] += stereo(plate * 0.42 + crack * 0.75 + thunk * 0.8, pan)
    return finish(lp(out.astype(np.float32), 11000, 2), 0.9, 0.02)


def gather(seed: int = 0, length: float = 0.24, bright: float = 7000) -> np.ndarray:
    """Power drawn in: a reversed rush of air that swells, rising in pitch, and is cut off just as it peaks."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.linspace(0, 1, n)
    top = min(bright, 6500)
    whistle = tone(glide(hz("A5"), hz("D7"), n, 1.8), n) * 0.12
    swell = t ** 2.4
    channels = []
    for _ in range(2):
        noise = svf(rng.standard_normal(n), glide(600, top, n, 1.4), 1.4, "band")
        channels.append((noise + whistle) * swell)
    out = np.column_stack(channels)
    end = np.ones(n)
    ramp = int(0.006 * RATE)
    end[-ramp:] = 0.5 + 0.5 * np.cos(np.pi * np.arange(ramp) / ramp)
    out = lp(out * end[:, None], 6500, 4)
    return finish(out.astype(np.float32), 0.8, 0.002, low=120)


def release(seed: int = 0, size: float = 1.0, note: str = "D6") -> np.ndarray:
    """A seal letting go: a bright burst over a low punch, and a chord of glass ringing out after it. `size` from
    0.5 (a small spell) to 1.5 (a grand one) sets its weight and its tail."""
    rng = np.random.default_rng(seed)
    n = int((0.5 + 0.6 * size) * RATE)
    punch = soft(tone(glide_then(190, 66, n, 0.09), n) * envelope(n, 0.0015, 0.09 + 0.09 * size), 1.8) * size ** 0.7
    crack = bp(rng.standard_normal(n), 1800, 7000) * envelope(n, 0.0006, 0.03 + 0.025 * size)
    flash = svf(rng.standard_normal(n), glide(6000, 2200, n, 0.4), 0.9, "band") * envelope(n, 0.001, 0.05) * 0.4
    base = hz(note)
    ring = np.zeros(n)
    for ratio, amp, decay in ((1, 0.5, 0.5), (1.5, 0.34, 0.42), (2, 0.26, 0.34), (3, 0.1, 0.22)):
        for detune in (-0.002, 0.002):
            ring += tone(base * ratio * (1 + detune), n, rng.uniform(0, 6)) * amp * 0.5 \
                * envelope(n, 0.002, (0.2 + 0.35 * size) * decay / 0.5)
    dry = stereo(punch * 0.9 + crack * 0.6 + flash * 0.5, 0) + stereo(ring * 0.55, rng.uniform(-0.2, 0.2))
    return finish(room(dry, 0.5 + 0.3 * size, 0.25, seed, 5000), 0.95, 0.04, low=60, high=11000)


def sub_boom(seed: int = 0, start: float = 110.0, end: float = 52.0, length: float = 0.45) -> np.ndarray:
    """A low boom under an impact. The fundamental falls from `start` to `end`; the saturation adds the harmonics at
    two and three times that, which is what small speakers and headphones actually reproduce of a boom."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    pitch = glide(start, end, n, 0.5)
    body = soft(tone(pitch, n) * envelope(n, 0.003, length), 2.4)
    thump = lp(rng.standard_normal(n), 400, 2) * envelope(n, 0.001, 0.012) * 0.25
    return finish(stereo(body + thump), 0.9, 0.02, low=35)


def thud(seed: int = 0, pitch: float = 110.0, length: float = 0.3, crunch: float = 0.5, knock: float = 0.5) -> np.ndarray:
    """A dense block landing: a body that falls from `pitch` to half of it, a wooden-stony knock, and a crunch of
    mid noise as it settles (what a heavy thing sounds like on a small speaker is the knock and the crunch)."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    body = soft(tone(glide(pitch * 1.3, pitch * 0.6, n, 0.5), n) * envelope(n, 0.0015, min(length * 0.4, 0.2)), 2.0)
    thock = modal(pitch * 3.1, ((1, 1, 1), (2.1, 0.6, 0.6), (3.6, 0.35, 0.4)), n, rng, 0.07, 0.0008, 0.01) * knock
    grit = bp(rng.standard_normal(n), 300, 2400) * envelope(n, 0.0008, 0.05 + 0.03 * crunch) * crunch
    return finish(stereo(body * 0.85 + thock * 0.45 + grit * 0.6, rng.uniform(-0.1, 0.1)), 0.9, 0.03, low=45, high=7000)


def ring_sweep(seed: int = 0, length: float = 0.35, low: float = 1200, high: float = 9000) -> np.ndarray:
    """A thin ring racing outward: a narrow band of noise sweeping up, thinning as it goes, each ear its own."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    fade = envelope(n, 0.01, length * 0.8)
    top = min(high, 7500)
    sweep = glide(low, top, n, 0.7)
    left = svf(rng.standard_normal(n), sweep, 5.0, "band") * fade
    right = svf(rng.standard_normal(n), sweep * 1.03, 5.0, "band") * fade
    return finish(np.column_stack([left, right]).astype(np.float32), 0.7, 0.03, high=9500)


def crystal_burst(seed: int = 0, length: float = 0.35, count: int = 26, low: float = 2600, high: float = 9500,
                  decay: float = 1.0) -> np.ndarray:
    """Splinters of glass flung out: many tiny glass pings of unrelated pitches, thick at first and thinning. Each
    ping is a small glass (modal) rather than a bare sine, the pitches thin out upward (there are more low splinters
    than high), and a third of them sit in D major so the shower has a key."""
    rng = np.random.default_rng(seed)
    n = int((length + 0.14) * RATE)
    out = np.zeros((n, 2))
    scale = [hz(x) for x in ("D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7")]
    top = min(high, 7500)
    bottom = max(1500.0, min(low, top / 2))
    for _ in range(count):
        at = int(length * rng.random() ** (1.8 * decay) * RATE)
        m = min(n - at, int(0.12 * RATE))
        if m < 200:
            continue
        freq = rng.choice(scale) if rng.random() < 0.33 else math.exp(rng.uniform(math.log(bottom), math.log(top)))
        life = rng.uniform(0.012, 0.06)
        ping = modal(freq, GLASS, m, rng, life * 2.0, 0.0004, 0.01, top=11000)
        out[at: at + m] += stereo(ping * rng.uniform(0.3, 1.0) * (1 - at / n) ** 0.8 * 0.5, rng.uniform(-0.8, 0.8))
    return finish(room(out.astype(np.float32), 0.35, 0.2, seed, 6000), 0.8, 0.05, low=500, high=10000)


def ward_hum(seed: int = 0, length: float = 0.3, note: str = "D3") -> np.ndarray:
    """The ward's pulse: a warm chord on D, gently beating, swelling in and out."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.arange(n) / RATE
    shape = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.5
    base = hz(note)
    out = np.zeros((n, 2))
    for ratio, level in ((1, 1.0), (1.5, 0.7), (2, 0.6), (2.5198, 0.3), (3, 0.22), (4, 0.1)):
        for detune, pan in ((-0.003, -0.5), (0.003, 0.5)):
            out += stereo(tone(base * ratio * (1 + detune), n, rng.uniform(0, 6)) * level, pan)
    tremolo = 1 + 0.15 * np.sin(2 * np.pi * 6.0 * t)
    return finish(room((out * (shape * tremolo)[:, None]).astype(np.float32), 0.7, 0.3, seed, 3500), 0.8, 0.03,
                  low=70, high=6000)


def tile_lock(seed: int = 0, note: str = "A6") -> np.ndarray:
    """A hex tile clicking into the shield: a small glassy click with a short ring and a tiny tick under it."""
    rng = np.random.default_rng(seed)
    n = int(0.11 * RATE)
    base = hz(note) * rng.uniform(0.98, 1.02)
    click = bp(rng.standard_normal(n), 3000, 6500) * envelope(n, 0.0003, 0.004) * 0.7
    body = modal(base * 0.75, BAR, n, rng, 0.05, 0.0006, 0.005)
    tick = tone(glide(900, 520, n), n) * envelope(n, 0.0008, 0.014) * 0.4
    return finish(stereo(lp(click + body * 0.55 + tick, 9500, 2), rng.uniform(-0.6, 0.6)), 0.8, 0.02)


def dissolve(seed: int = 0, length: float = 0.55, count: int = 16) -> np.ndarray:
    """Something made of light breaking up gently: sparse sparkles in D, drifting up and thinning, over a soft hiss."""
    rng = np.random.default_rng(seed)
    n = int((length + 0.3) * RATE)
    out = np.zeros((n, 2))
    scale = ["D6", "E6", "F#6", "A6", "B6", "D7", "E7"]
    for _ in range(count):
        at = int(length * rng.random() ** 0.8 * RATE)
        m = min(n - at, int(0.25 * RATE))
        freq = hz(scale[rng.integers(len(scale))])
        ping = tone(glide(freq, freq * 1.008, m), m) * envelope(m, 0.003, rng.uniform(0.06, 0.16))
        out[at: at + m] += stereo(ping * rng.uniform(0.3, 0.8), rng.uniform(-0.7, 0.7))
    hiss = bp(rng.standard_normal(n), 3500, 7000) * envelope(n, 0.06, length) * 0.05
    out += stereo(hiss)
    return finish(room(out.astype(np.float32), 0.6, 0.35, seed, 5000), 0.7, 0.06, low=200, high=9000)


def slash(seed: int = 0, length: float = 0.12, high: float = 7000, low: float = 1300) -> np.ndarray:
    """A claw tearing through the air: a ragged hiss sweeping down, a bright metal edge at its front, and the short
    cloth-rip of what it cuts."""
    rng = np.random.default_rng(seed)
    n = int((length + 0.06) * RATE)
    sweep = glide(min(high, 6500) * rng.uniform(0.9, 1.1), low * rng.uniform(0.9, 1.1), n, 0.6)
    tear = svf(rng.standard_normal(n), sweep, 1.1, "band")
    grain = 0.55 + 0.45 * np.clip(np.abs(svf(rng.standard_normal(n), 45, 0.7, "low")) * 8, 0, 1.4)
    body = tear * grain * envelope(n, 0.004, length)
    edge_ping = modal(rng.uniform(2800, 3600), PLATE, n, rng, 0.035, 0.0004, 0.01) * 0.35
    rip = bp(rng.standard_normal(n), 350, 1800) * envelope(n, 0.002, 0.03) * 0.55
    mono = lp(body + edge_ping + rip, 8500, 4)
    pan = rng.uniform(-0.6, 0.6)
    return finish(np.column_stack([mono * math.cos((pan + 1) * math.pi / 4),
                                   np.roll(mono, 40) * math.sin((pan + 1) * math.pi / 4)]).astype(np.float32),
                  0.9, 0.03, low=150)


def clock_tick(seed: int = 0, note: str = "A5") -> np.ndarray:
    """A clock's tick: a dry click on a small wooden-and-metal body."""
    rng = np.random.default_rng(seed)
    n = int(0.06 * RATE)
    click = bp(rng.standard_normal(n), 1800, 4200) * envelope(n, 0.0003, 0.006)
    body = tone(hz(note) * rng.uniform(0.99, 1.01), n) * envelope(n, 0.0006, 0.02) * 0.5
    return finish(stereo(lp(click + body, 6500, 2), 0.2), 0.8, 0.015, low=300)


def bell(seed: int = 0, note: str = "D6", length: float = 1.2) -> np.ndarray:
    """A small hand bell: inharmonic partials, the high ones dying first."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    base = hz(note)
    ring = modal(base, BELL, n, rng, length * 0.5, 0.001, 0.003)
    strike = bp(rng.standard_normal(n), 2500, 6000) * envelope(n, 0.0004, 0.006) * 0.2
    return finish(room(stereo(ring + strike, 0.1), 0.8, 0.25, seed, 5000), 0.8, 0.08, low=200, high=11000)


def buzzer(seed: int = 0, length: float = 0.35, note: str = "A2") -> np.ndarray:
    """A flat, final buzzer: a band-limited square wave (odd harmonics only, so it cannot alias), rough, with short
    soft edges."""
    n = int(length * RATE)
    t = np.arange(n) / RATE
    wave = np.zeros(n)
    for detune, level in ((1.0, 0.6), (1.005, 0.4)):
        f = hz(note) * detune
        for k in range(1, int(2200 / f) + 1, 2):
            wave += level * np.sin(2 * np.pi * f * k * t) / k
    body = wave * (1 + 0.2 * np.sin(2 * np.pi * 31 * t))
    edge_shape = np.ones(n)
    ramp = int(0.012 * RATE)
    edge_shape[:ramp] = 0.5 - 0.5 * np.cos(np.pi * np.arange(ramp) / ramp)
    edge_shape[-ramp:] = 0.5 + 0.5 * np.cos(np.pi * np.arange(ramp) / ramp)
    return finish(stereo(lp(body * edge_shape, 2200, 2)), 0.7, 0.012, low=70)


def glitch(seed: int = 0, length: float = 0.5) -> np.ndarray:
    """A program crashing: an electrical sputter of crushed noise and stuck tones, catching and dying out."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    out = np.zeros(n)
    at = 0
    while at < n:
        burst = int(rng.uniform(0.01, 0.045) * RATE)
        end = min(n, at + burst)
        m = end - at
        level = (1 - at / n) ** 1.5
        window = 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(m) / max(m - 1, 1))
        if rng.random() < 0.5:
            steps = rng.integers(4, 12)
            noise = np.round(rng.standard_normal(m) * steps) / steps
            out[at:end] = noise * level * 0.6 * window
        else:
            freq = rng.choice([180, 360, 720, 1440, 2200]) * rng.uniform(0.98, 1.02)
            tone_burst = np.zeros(m)
            for k in range(1, int(4000 / freq) + 1, 2):
                tone_burst += np.sin(2 * np.pi * freq * k * np.arange(m) / RATE) / k
            out[at:end] = tone_burst * level * 0.55 * window
        at = end + int(rng.uniform(0.005, 0.03 + 0.08 * at / n) * RATE)
    held = np.repeat(out[:: 3], 3)[:n]  # a sample rate crushed to a third
    return finish(stereo(lp(held, 4500, 2), rng.uniform(-0.2, 0.2)), 0.8, 0.03, low=120)


def whiff(seed: int = 0, length: float = 0.18) -> np.ndarray:
    """A faint whiff of air past nothing."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.linspace(0, 1, n)
    body = svf(rng.standard_normal(n), glide(2800, 600, n), 1.0, "band") * np.sin(np.pi * t) ** 1.5
    return finish(stereo(body, rng.uniform(-0.3, 0.3)), 0.6, 0.02, low=200, high=6000)


def gulp(seed: int = 0, length: float = 0.3) -> np.ndarray:
    """A bolt swallowed by the void: a hollow tone falling into the dark, a sucking hiss, and silence."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.linspace(0, 1, n)
    fall = glide(340, 70, n, 0.7)
    sub = tone(fall * 0.5, n)
    hollow = svf(tone(fall, n) + 0.3 * soft(sub, 4.0), glide(1600, 260, n), 3.0, "band")
    suck = svf(rng.standard_normal(n), glide(2200, 300, n, 0.8), 2.0, "band") * 0.3
    shape = np.clip(t / 0.08, 0, 1) * (1 - t) ** 1.2
    return finish(room(stereo((hollow + suck) * shape), 0.3, 0.2, seed, 3000), 0.85, 0.04, low=80)


def zap(seed: int = 0, length: float = 0.14) -> np.ndarray:
    """An electric spark: a buzzing tone dropping fast, crackling."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    pitch = glide(2000, 240, n, 0.5)
    phase = 2 * np.pi * np.cumsum(pitch) / RATE
    # A band-limited saw: harmonics added only while they stay under 6 kHz, so it buzzes without aliasing.
    saw = np.zeros(n)
    for k in range(1, 26):
        saw += np.where(pitch * k < 6000, np.sin(k * phase) / k, 0.0)
    crackle = (rng.random(n) < 0.012) * rng.standard_normal(n) * 1.2
    body = lp(saw + lp(crackle, 5000, 2), 5000, 2) * envelope(n, 0.0015, length)
    return finish(stereo(body, rng.uniform(-0.3, 0.3)), 0.8, 0.02, low=100)


def flare(seed: int = 0, length: float = 0.45) -> np.ndarray:
    """Fire catching: a whoomph of dark air, a flare opening up in brightness, a few pops."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    whoomph = svf(rng.standard_normal(n), glide(250, 2000, n, 0.5), 0.8, "low") * envelope(n, 0.04, length * 0.9)
    boom = soft(tone(glide(120, 60, n), n) * envelope(n, 0.012, 0.2), 2.0) * 0.3
    pops = np.zeros(n)
    for _ in range(9):
        at = rng.integers(int(0.05 * RATE), n - 300)
        pops[at: at + 200] += bp(rng.standard_normal(200), 1500, 4500) * envelope(200, 0.0004, 0.002)
    return finish(room(stereo(whoomph + boom + pops * 0.5), 0.4, 0.2, seed, 4500), 0.85, 0.06, low=60, high=8000)


def crackle(seed: int = 0, length: float = 0.4) -> np.ndarray:
    """Frost forming: a dense crackling of tiny ice clicks and a thin glassy whistle rising."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    ticks = np.zeros(n)
    for _ in range(90):
        at = int(n * rng.random() ** 0.7)
        m = min(n - at, 160)
        low = rng.uniform(2200, 6000)
        ticks[at: at + m] += bp(rng.standard_normal(m), low, low * 1.4) * envelope(m, 0.0002, 0.0014) * rng.uniform(0.4, 1)
    whistle = tone(glide(hz("A5"), hz("D6"), n), n) * envelope(n, 0.06, length) * 0.15
    return finish(room(stereo(ticks * 1.5 + whistle, 0.1), 0.4, 0.25, seed, 6000), 0.8, 0.05, low=300, high=9500)


def bellows(seed: int = 0, length: float = 0.5) -> np.ndarray:
    """A forge's bellows: one long breath of air pushed through a nozzle."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.linspace(0, 1, n)
    breath = svf(rng.standard_normal(n), glide(400, 1100, n), 1.0, "band") * np.sin(np.pi * t) ** 0.8
    return finish(stereo(breath), 0.7, 0.04, low=100)


def paper(seed: int = 0, length: float = 0.12, low: float = 1800, high: float = 6500, attack: float = 0.02) -> np.ndarray:
    """Card on card: a short, dry rush of paper (a slide when long and soft, a snap when short and sharp). It is
    noise bounded to the paper's own band (about 700 Hz - 5 kHz), because above that a card is only hiss."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    top = min(high, 5200)
    body = svf(rng.standard_normal(n), glide(top, max(low, 700), n), 0.9, "band")
    body = hp(lp(body, 5600, 2), 500, 2)
    return finish(stereo(body * envelope(n, attack, length * 0.7), rng.uniform(-0.3, 0.3)), 0.7, 0.02)


def tap(seed: int = 0, pitch: float = 190.0, length: float = 0.09) -> np.ndarray:
    """Something light set down on a table: a short dull thump, a soft paper-and-wood tick on top."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    body = tone(glide(pitch * rng.uniform(0.95, 1.05), pitch * 0.55, n, 0.5), n) * envelope(n, 0.001, 0.035)
    tick = bp(rng.standard_normal(n), 1200, 4200) * envelope(n, 0.0005, 0.008) * 0.55
    return finish(stereo(body * 0.8 + tick, rng.uniform(-0.2, 0.2)), 0.8, 0.02, low=70)


def scrape(seed: int = 0, length: float = 0.4, low: float = 160.0, high: float = 700.0) -> np.ndarray:
    """A heavy slab dragged: low band noise rising in pitch with a slow stutter, as stone grinds."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.arange(n) / RATE
    grind = svf(rng.standard_normal(n), glide(low, high, n, 0.8), 1.6, "band")
    stutter = 0.65 + 0.35 * np.sin(2 * np.pi * rng.uniform(11, 16) * t + rng.uniform(0, 6))
    shape = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 0.7
    return finish(stereo(lp(grind * stutter * shape, 2500, 2), rng.uniform(-0.2, 0.2)), 0.8, 0.04, low=90)


INGREDIENTS = {
    "shimmer": shimmer, "rune_tick": rune_tick, "bracket_clack": bracket_clack, "gather": gather, "release": release,
    "sub_boom": sub_boom, "ring_sweep": ring_sweep, "crystal_burst": crystal_burst, "ward_hum": ward_hum,
    "tile_lock": tile_lock, "dissolve": dissolve, "slash": slash, "clock_tick": clock_tick, "bell": bell,
    "buzzer": buzzer, "glitch": glitch, "whiff": whiff, "gulp": gulp, "zap": zap, "flare": flare, "crackle": crackle,
    "bellows": bellows, "paper": paper, "thud": thud, "tap": tap, "scrape": scrape,
}


def make(name: str, seed: int, **args: object) -> np.ndarray:
    """One ingredient by name, as float stereo at 48 kHz."""
    if name not in INGREDIENTS:
        raise KeyError(f"no ingredient {name!r} (one of {', '.join(sorted(INGREDIENTS))})")
    return INGREDIENTS[name](seed=seed, **args).astype(np.float32)
