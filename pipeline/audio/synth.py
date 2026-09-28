#!/usr/bin/env python3
"""Sound ingredients made from nothing but numbers (docs/SOUND_DESIGN.md, "The palette"): the parts of the fight's
sounds whose pitch and shape must be exact, which no recording has. Each is a function of its arguments and a seed,
returning float stereo at 48 kHz, so a sound's recipe in the manifest makes the same sound every time.

A manifest layer names one: `{"synth": "rune_tick", "note": "A6", "delay_ms": 128, "gain_db": -14}`; every key but
the layer's own (delay_ms, gain_db, rate, reverse, pan) is passed to the function, and `seed` comes from the sound and
the layer's place in it, so the takes of a sound (sfx-hit-1 to -4) differ.

Pitched ingredients sit in D, the soundtrack's home (D major's notes: D E F# G A B C#).
"""

from __future__ import annotations

import math

import numpy as np

RATE = 48000
NOTES = {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5, "F": -4, "F#": -3, "Gb": -3, "G": -2,
         "G#": -1, "Ab": -1, "A": 0, "A#": 1, "Bb": 1, "B": 2}


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
    """A fast linear attack, an optional hold, then an exponential decay to -60 dB over `decay` seconds."""
    t = np.arange(n) / RATE
    rise = np.clip(t / max(attack, 1e-4), 0, 1)
    fall = np.where(t < attack + hold, 1.0, np.exp(-6.9 * (t - attack - hold) / max(decay, 1e-4)))
    return rise * fall


def svf(signal: np.ndarray, cutoff: np.ndarray | float, q: float = 0.7, mode: str = "band") -> np.ndarray:
    """A state-variable filter whose cutoff may move per sample (low, band or high pass): what makes noise sweep,
    whistle and rush. LEARN: the Chamberlin form is two integrators in a loop; `f = 2 sin(pi fc / fs)` is stable below
    about a sixth of the sample rate, so the cutoff is clamped there."""
    n = len(signal)
    cut = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), (n,))
    f = 2 * np.sin(np.pi * np.clip(cut, 20, RATE / 6.5) / RATE)
    damp = 1.0 / max(q, 0.5)
    low = band = 0.0
    out = np.empty(n)
    pick = {"low": 0, "band": 1, "high": 2}[mode]
    for i in range(n):
        high = signal[i] - low - damp * band
        band += f[i] * high
        low += f[i] * band
        out[i] = (low, band, high)[pick]
    return out


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


def room(dry: np.ndarray, size: float = 0.8, mix: float = 0.3, seed: int = 0, bright: float = 6000) -> np.ndarray:
    """A small, soft reverb: the sound convolved with a decaying noise tail of `size` seconds, a different tail per
    ear so the room is wide. Stereo in, stereo out, longer by the tail."""
    rng = np.random.default_rng(seed + 991)
    n = int(size * RATE)
    decay = np.exp(-6.9 * np.arange(n) / n)
    tails = []
    for _ in range(2):
        tail = rng.standard_normal(n) * decay
        spectrum = np.fft.rfft(tail)
        freqs = np.fft.rfftfreq(n, 1 / RATE)
        spectrum *= 1 / (1 + (freqs / bright) ** 2)
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


# --------------------------------------------------------------------------------------------------------------------
# The ingredients


def shimmer(seed: int = 0, length: float = 0.36, note: str = "D6", rise: bool = True, width: float = 0.6) -> np.ndarray:
    """Light drawing itself: a glassy cluster of D major's bright notes swelling in with the drawing, a little
    upward glide, a breath of high air, in a small room."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    tail = int(0.12 * RATE)
    total = n + tail
    base = hz(note)
    t = np.arange(total) / RATE
    swell = np.clip(t / length, 0, 1) ** (1.6 if rise else 0.6)
    swell = np.where(t < length, swell, np.exp(-6.9 * (t - length) / 0.12))
    out = np.zeros((total, 2))
    for ratio, level in ((1.0, 1.0), (1.5, 0.7), (2.0, 0.6), (2.5198, 0.45), (3.0, 0.3), (4.0, 0.2)):
        start = rng.uniform(0, 0.35) * length
        onset = np.clip((t - start) / (0.3 * length), 0, 1)
        drift = glide(1.0, 1.0 + (0.012 if rise else 0.0), total)
        wobble = 1 + 0.003 * np.sin(2 * np.pi * rng.uniform(4, 7) * t + rng.uniform(0, 6))
        mono = tone(base * ratio * drift * wobble, total, rng.uniform(0, 6)) * level * onset
        out += stereo(mono, rng.uniform(-width, width))
    air = svf(rng.standard_normal(total), glide(3000, 9000 if rise else 5000, total), 1.5, "band") * 0.25
    out += stereo(air, 0.0)
    out *= swell[:, None]
    return normal(room(out.astype(np.float32), 0.6, 0.35, seed), 0.8)


def rune_tick(seed: int = 0, note: str = "D7", length: float = 0.09) -> np.ndarray:
    """A rune taking its place: a tiny bright glass tick on a note, with a click at its front."""
    rng = np.random.default_rng(seed)
    n = int((length + 0.05) * RATE)
    base = hz(note) * (1 + rng.uniform(-0.004, 0.004))
    ping = (tone(base, n) + 0.35 * tone(base * 2.76, n)) * envelope(n, 0.001, length)
    click = svf(rng.standard_normal(n), 6500, 2.0, "band") * envelope(n, 0.0003, 0.006)
    return normal(stereo(ping * 0.8 + click * 0.5, rng.uniform(-0.4, 0.4)), 0.8)


def bracket_clack(seed: int = 0, weight: float = 1.0) -> np.ndarray:
    """Two hard, bright plates snapping shut, a hair apart: the code's brackets closing."""
    rng = np.random.default_rng(seed)
    n = int(0.25 * RATE)
    out = np.zeros((n, 2))
    for index, (at, pan) in enumerate(((0.0, -0.35), (rng.uniform(0.008, 0.014), 0.35))):
        start = int(at * RATE)
        m = n - start
        burst = svf(rng.standard_normal(m), 4200, 1.2, "band") * envelope(m, 0.0003, 0.012)
        modes = sum(tone(f * rng.uniform(0.97, 1.03), m) * envelope(m, 0.0005, d) * a
                    for f, d, a in ((2350, 0.05, 0.6), (3480, 0.035, 0.45), (5150, 0.02, 0.3)))
        thump = tone(glide(210, 120, m), m) * envelope(m, 0.001, 0.03) * 0.7 * weight
        out[start:] += stereo(burst * 0.9 + modes + thump, pan)
    return normal(out.astype(np.float32), 0.9)


def gather(seed: int = 0, length: float = 0.24, bright: float = 7000) -> np.ndarray:
    """Power drawn in: a reversed rush of air that swells, rising in pitch, and stops dead at its end."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.linspace(0, 1, n)
    noise = svf(rng.standard_normal(n), glide(700, bright, n, 1.4), 1.2, "band")
    whistle = tone(glide(hz("A5"), hz("D7"), n, 1.8), n) * 0.25
    swell = t ** 2.4
    left = noise * swell + whistle * swell
    right = svf(rng.standard_normal(n), glide(700, bright, n, 1.4), 1.2, "band") * swell + whistle * swell
    end = np.ones(n)
    end[-int(0.004 * RATE):] = np.linspace(1, 0, int(0.004 * RATE))
    return normal(np.column_stack([left * end, right * end]).astype(np.float32), 0.8)


def release(seed: int = 0, size: float = 1.0, note: str = "D6") -> np.ndarray:
    """A seal letting go: a bright burst over a low punch, and a chord of glass ringing out after it. `size` from
    0.5 (a small spell) to 1.5 (a grand one) sets its weight and its tail."""
    rng = np.random.default_rng(seed)
    n = int((0.5 + 0.6 * size) * RATE)
    punch = tone(glide_then(150, 48, n, 0.12), n) * envelope(n, 0.001, 0.12 + 0.12 * size) * size
    burst = svf(rng.standard_normal(n), glide(9000, 2500, n, 0.5), 0.8, "band") * envelope(n, 0.0008, 0.09 + 0.1 * size)
    base = hz(note)
    ring = sum(tone(base * r, n, rng.uniform(0, 6)) * a for r, a in ((1, 0.5), (1.5, 0.35), (2, 0.3), (3, 0.15)))
    ring = ring * envelope(n, 0.002, 0.25 + 0.35 * size) * 0.5
    dry = stereo(punch * 0.9 + burst * 0.8, 0) + stereo(ring, rng.uniform(-0.2, 0.2))
    return normal(room(dry, 0.5 + 0.3 * size, 0.25, seed), 0.95)


def sub_boom(seed: int = 0, start: float = 72.0, end: float = 34.0, length: float = 0.55) -> np.ndarray:
    """A low boom under an impact, a little driven so it is heard on small speakers too."""
    n = int(length * RATE)
    body = tone(glide(start, end, n, 0.6), n) * envelope(n, 0.002, length)
    return normal(stereo(np.tanh(body * 2.2) / np.tanh(2.2)), 0.9)


def ring_sweep(seed: int = 0, length: float = 0.35, low: float = 1200, high: float = 9000) -> np.ndarray:
    """A thin ring racing outward: a narrow band of noise sweeping up, thinning as it goes, each ear its own."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    fade = envelope(n, 0.004, length * 0.9)
    sweep = glide(low, high, n, 0.7)
    left = svf(rng.standard_normal(n), sweep, 6.0, "band") * fade
    right = svf(rng.standard_normal(n), sweep * 1.03, 6.0, "band") * fade
    return normal(np.column_stack([left, right]).astype(np.float32), 0.7)


def crystal_burst(seed: int = 0, length: float = 0.35, count: int = 26, low: float = 2600, high: float = 9500,
                  decay: float = 1.0) -> np.ndarray:
    """Splinters of glass flung out: many tiny pings of bright, unrelated pitches, thick at first and thinning."""
    rng = np.random.default_rng(seed)
    n = int((length + 0.12) * RATE)
    out = np.zeros((n, 2))
    for _ in range(count):
        at = int(length * rng.random() ** (1.8 * decay) * RATE)
        m = min(n - at, int(0.08 * RATE))
        freq = rng.uniform(low, high)
        life = rng.uniform(0.008, 0.05)
        ping = (tone(freq, m) + 0.4 * tone(freq * rng.uniform(1.4, 2.3), m)) * envelope(m, 0.0004, life)
        out[at: at + m] += stereo(ping * rng.uniform(0.3, 1.0) * (1 - at / n) ** 0.8, rng.uniform(-0.8, 0.8))
    return normal(room(out.astype(np.float32), 0.35, 0.2, seed, 9000), 0.8)


def ward_hum(seed: int = 0, length: float = 0.3, note: str = "D3") -> np.ndarray:
    """The ward's pulse: a warm chord on D, gently beating, swelling in and out."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.arange(n) / RATE
    shape = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.5
    base = hz(note)
    out = np.zeros((n, 2))
    for ratio, level in ((1, 1.0), (1.5, 0.7), (2, 0.6), (2.5198, 0.35), (3, 0.3), (4, 0.15)):
        for detune, pan in ((-0.003, -0.5), (0.003, 0.5)):
            out += stereo(tone(base * ratio * (1 + detune), n, rng.uniform(0, 6)) * level, pan)
    tremolo = 1 + 0.18 * np.sin(2 * np.pi * 6.0 * t)
    return normal(room((out * (shape * tremolo)[:, None]).astype(np.float32), 0.7, 0.3, seed), 0.8)


def tile_lock(seed: int = 0, note: str = "A6") -> np.ndarray:
    """A hex tile clicking into the shield: a small glassy click with a short ring."""
    rng = np.random.default_rng(seed)
    n = int(0.09 * RATE)
    base = hz(note) * rng.uniform(0.98, 1.02)
    click = svf(rng.standard_normal(n), 5200, 2.5, "band") * envelope(n, 0.0002, 0.004)
    body = (tone(base, n) * 0.6 + tone(base * 2.4, n) * 0.3) * envelope(n, 0.0006, 0.035)
    tick = tone(glide(900, 600, n), n) * envelope(n, 0.0005, 0.012) * 0.4
    return normal(stereo(click + body + tick, rng.uniform(-0.6, 0.6)), 0.8)


def dissolve(seed: int = 0, length: float = 0.55, count: int = 16) -> np.ndarray:
    """Something made of light breaking up gently: sparse sparkles in D, drifting up and thinning, over a soft hiss."""
    rng = np.random.default_rng(seed)
    n = int((length + 0.3) * RATE)
    out = np.zeros((n, 2))
    scale = ["D6", "E6", "F#6", "A6", "B6", "D7", "E7", "F#7", "A7"]
    for _ in range(count):
        at = int(length * rng.random() ** 0.8 * RATE)
        m = min(n - at, int(0.25 * RATE))
        freq = hz(scale[rng.integers(len(scale))])
        ping = tone(glide(freq, freq * 1.01, m), m) * envelope(m, 0.002, rng.uniform(0.06, 0.18))
        out[at: at + m] += stereo(ping * rng.uniform(0.3, 0.8), rng.uniform(-0.7, 0.7))
    hiss = svf(rng.standard_normal(n), 7000, 1.0, "band") * envelope(n, 0.05, length) * 0.2
    out += stereo(hiss)
    return normal(room(out.astype(np.float32), 0.6, 0.35, seed), 0.7)


def slash(seed: int = 0, length: float = 0.12, high: float = 7000, low: float = 1300) -> np.ndarray:
    """A claw tearing through the air: a hiss sweeping down, ragged, with a sharp front."""
    rng = np.random.default_rng(seed)
    n = int((length + 0.06) * RATE)
    sweep = glide(high * rng.uniform(0.9, 1.1), low * rng.uniform(0.9, 1.1), n, 0.6)
    tear = svf(rng.standard_normal(n), sweep, 1.6, "band")
    grain = 0.55 + 0.45 * np.abs(svf(rng.standard_normal(n), 45, 0.7, "low")) * 8
    body = tear * np.clip(grain, 0, 1.4) * envelope(n, 0.002, length)
    pan = rng.uniform(-0.6, 0.6)
    return normal(np.column_stack([body * math.cos((pan + 1) * math.pi / 4),
                                   np.roll(body, 40) * math.sin((pan + 1) * math.pi / 4)]).astype(np.float32), 0.9)


def clock_tick(seed: int = 0, note: str = "A5") -> np.ndarray:
    """A clock's tick: a dry click on a small wooden-and-metal body."""
    rng = np.random.default_rng(seed)
    n = int(0.05 * RATE)
    click = svf(rng.standard_normal(n), 2600, 2.0, "band") * envelope(n, 0.0002, 0.006)
    body = tone(hz(note) * rng.uniform(0.99, 1.01), n) * envelope(n, 0.0005, 0.018) * 0.5
    return normal(stereo(click + body, 0.2), 0.8)


def bell(seed: int = 0, note: str = "D6", length: float = 1.2) -> np.ndarray:
    """A small hand bell: inharmonic partials, the high ones dying first."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    base = hz(note)
    ring = sum(tone(base * r, n, rng.uniform(0, 6)) * a * envelope(n, 0.001, length * d)
               for r, a, d in ((1.0, 1.0, 1.0), (2.0, 0.5, 0.7), (2.76, 0.45, 0.5), (5.4, 0.25, 0.25), (8.93, 0.12, 0.12)))
    strike = svf(rng.standard_normal(n), 5000, 1.5, "band") * envelope(n, 0.0002, 0.006) * 0.3
    return normal(room(stereo(ring + strike, 0.1), 0.8, 0.25, seed), 0.8)


def buzzer(seed: int = 0, length: float = 0.35, note: str = "A2") -> np.ndarray:
    """A flat, final buzzer: a filtered square wave, rough, cut off square at both ends."""
    n = int(length * RATE)
    t = np.arange(n) / RATE
    wave = np.sign(np.sin(2 * np.pi * hz(note) * t)) * 0.6 + np.sign(np.sin(2 * np.pi * hz(note) * 1.005 * t)) * 0.4
    body = svf(wave, 1800, 0.7, "low") * (1 + 0.25 * np.sin(2 * np.pi * 31 * t))
    edge = np.ones(n)
    ramp = int(0.004 * RATE)
    edge[:ramp] = np.linspace(0, 1, ramp)
    edge[-ramp:] = np.linspace(1, 0, ramp)
    return normal(stereo(body * edge), 0.7)


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
        if rng.random() < 0.5:
            steps = rng.integers(4, 12)
            noise = np.round(rng.standard_normal(m) * steps) / steps
            out[at:end] = noise * level * 0.8
        else:
            freq = rng.choice([180, 360, 720, 1440, 2880]) * rng.uniform(0.98, 1.02)
            out[at:end] = np.sign(np.sin(2 * np.pi * freq * np.arange(m) / RATE)) * level * 0.5
        at = end + int(rng.uniform(0.005, 0.03 + 0.08 * at / n) * RATE)
    held = np.repeat(out[:: 3], 3)[:n]  # a sample rate crushed to a third
    return normal(stereo(svf(held, 6000, 0.7, "low"), rng.uniform(-0.2, 0.2)), 0.8)


def whiff(seed: int = 0, length: float = 0.18) -> np.ndarray:
    """A faint whiff of air past nothing."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.linspace(0, 1, n)
    body = svf(rng.standard_normal(n), glide(3200, 700, n), 1.2, "band") * np.sin(np.pi * t) ** 1.5
    return normal(stereo(body, rng.uniform(-0.3, 0.3)), 0.6)


def gulp(seed: int = 0, length: float = 0.3) -> np.ndarray:
    """A bolt swallowed by the void: a hollow tone falling into the dark, a sucking hiss, and silence."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.linspace(0, 1, n)
    fall = glide(340, 58, n, 0.7)
    hollow = svf(tone(fall, n) + 0.3 * np.sign(tone(fall * 0.5, n)), glide(1600, 200, n), 3.0, "band")
    suck = svf(rng.standard_normal(n), glide(2600, 300, n, 0.8), 2.0, "band") * 0.35
    shape = np.clip(t / 0.08, 0, 1) * (1 - t) ** 1.2
    return normal(room(stereo((hollow + suck) * shape), 0.3, 0.2, seed, 3000), 0.85)


def zap(seed: int = 0, length: float = 0.14) -> np.ndarray:
    """An electric spark: a buzzing tone dropping fast, crackling."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    pitch = glide(2400, 260, n, 0.5)
    saw = 2 * ((np.cumsum(pitch) / RATE) % 1.0) - 1
    crackle = (rng.random(n) < 0.012) * rng.standard_normal(n) * 3
    body = svf(saw + crackle, 5000, 0.7, "low") * envelope(n, 0.001, length)
    return normal(stereo(body, rng.uniform(-0.3, 0.3)), 0.8)


def flare(seed: int = 0, length: float = 0.45) -> np.ndarray:
    """Fire catching: a whoomph of dark air, a flare opening up in brightness, a few pops."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    whoomph = svf(rng.standard_normal(n), glide(250, 2200, n, 0.5), 0.8, "low") * envelope(n, 0.035, length * 0.9)
    boom = tone(glide(90, 45, n), n) * envelope(n, 0.01, 0.2) * 0.5
    pops = np.zeros(n)
    for _ in range(9):
        at = rng.integers(int(0.05 * RATE), n - 300)
        pops[at: at + 200] += svf(rng.standard_normal(200), 3000, 1.0, "band") * envelope(200, 0.0002, 0.002)
    return normal(room(stereo(whoomph + boom + pops * 0.6), 0.4, 0.2, seed, 5000), 0.85)


def crackle(seed: int = 0, length: float = 0.4) -> np.ndarray:
    """Frost forming: a dense crackling of tiny ice clicks and a thin glassy whistle rising."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    ticks = np.zeros(n)
    for _ in range(90):
        at = int(n * rng.random() ** 0.7)
        m = min(n - at, 120)
        ticks[at: at + m] += svf(rng.standard_normal(m), rng.uniform(4000, 10000), 3.0, "band") * envelope(m, 0.0001, 0.001)
    whistle = tone(glide(hz("A6"), hz("D7"), n), n) * envelope(n, 0.05, length) * 0.2
    return normal(room(stereo(ticks + whistle, 0.1), 0.4, 0.25, seed, 10000), 0.8)


def bellows(seed: int = 0, length: float = 0.5) -> np.ndarray:
    """A forge's bellows: one long breath of air pushed through a nozzle."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    t = np.linspace(0, 1, n)
    breath = svf(rng.standard_normal(n), glide(400, 1100, n), 1.0, "band") * np.sin(np.pi * t) ** 0.8
    return normal(stereo(breath), 0.7)


def paper(seed: int = 0, length: float = 0.12, low: float = 1800, high: float = 6500, attack: float = 0.02) -> np.ndarray:
    """Card on card: a short, dry rush of paper (a slide when long and soft, a snap when short and sharp)."""
    rng = np.random.default_rng(seed)
    n = int(length * RATE)
    body = svf(rng.standard_normal(n), glide(high, low, n), 0.9, "band")
    return normal(stereo(body * envelope(n, attack, length * 0.8), rng.uniform(-0.3, 0.3)), 0.7)


INGREDIENTS = {
    "shimmer": shimmer, "rune_tick": rune_tick, "bracket_clack": bracket_clack, "gather": gather, "release": release,
    "sub_boom": sub_boom, "ring_sweep": ring_sweep, "crystal_burst": crystal_burst, "ward_hum": ward_hum,
    "tile_lock": tile_lock, "dissolve": dissolve, "slash": slash, "clock_tick": clock_tick, "bell": bell,
    "buzzer": buzzer, "glitch": glitch, "whiff": whiff, "gulp": gulp, "zap": zap, "flare": flare, "crackle": crackle,
    "bellows": bellows, "paper": paper,
}


def make(name: str, seed: int, **args: object) -> np.ndarray:
    """One ingredient by name, as float stereo at 48 kHz."""
    if name not in INGREDIENTS:
        raise KeyError(f"no ingredient {name!r} (one of {', '.join(sorted(INGREDIENTS))})")
    return INGREDIENTS[name](seed=seed, **args).astype(np.float32)
