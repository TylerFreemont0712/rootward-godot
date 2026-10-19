"""Mastering's arithmetic: the loop's seconds from the score's bars, the shelves that correct a fault, and the start and
end of the sound."""

import unittest
from pathlib import Path

import numpy as np

import helpers  # noqa: F401
import analyze
import master
import notation

FIXTURES = Path(__file__).resolve().parent / "fixtures"
SCORE = notation.parse((FIXTURES / "rest_score.abc").read_text())


class LoopArithmetic(unittest.TestCase):
    def test_the_loop_is_the_score_bars_placed_on_the_take(self):
        placed = {"bar0": 1.0, "bar_seconds": 2.0}
        start, end = master.loop_points(SCORE, {"from": "verse", "to": "verse", "occurrence": 2}, placed)
        self.assertEqual((start, end), (1.0 + 3 * 2.0, 1.0 + 27 * 2.0))

    def test_the_first_verse_alone_is_eight_bars_shorter_than_the_pair(self):
        placed = {"bar0": 0.0, "bar_seconds": 1.0}
        one = master.loop_points(SCORE, {"from": "verse", "to": "verse", "occurrence": 1}, placed)
        two = master.loop_points(SCORE, {"from": "verse", "to": "verse", "occurrence": 2}, placed)
        self.assertEqual(one, (3.0, 11.0))
        self.assertEqual(two[1] - one[1], 16.0)


class Shelves(unittest.TestCase):
    def test_a_fault_is_corrected_by_at_most_six_decibels(self):
        self.assertEqual(master.shelf_gain(0.5, 0.2), -6.0)
        self.assertEqual(master.shelf_gain(0.001, 0.2), 6.0)

    def test_a_colour_already_on_target_is_left_alone(self):
        self.assertAlmostEqual(master.shelf_gain(0.2, 0.2), 0.0, places=6)


class Edges(unittest.TestCase):
    def test_the_music_starts_where_the_sound_does(self):
        rate = analyze.SR
        mono = np.zeros(rate * 3, dtype=np.float32)
        t = np.arange(rate * 2) / rate
        mono[rate:] = 0.4 * np.sin(2 * np.pi * 440 * t)
        self.assertAlmostEqual(master.first_sound(mono), 1.0, delta=0.06)

    def test_the_music_ends_where_the_sound_dies(self):
        rate = master.RATE
        stereo = np.zeros((rate * 3, 2), dtype=np.float32)
        t = np.arange(rate) / rate
        stereo[: rate] = (0.4 * np.sin(2 * np.pi * 440 * t))[:, None]
        self.assertAlmostEqual(master.last_sound(stereo) / rate, 1.0, delta=0.06)

    def test_a_seam_is_a_finite_ratio(self):
        rng = np.random.default_rng(1)
        audio = rng.standard_normal((master.RATE * 6, 2)).astype(np.float32) * 0.1
        value = master.seam(audio, master.RATE * 2)
        self.assertTrue(np.isfinite(value) and value >= 0)


if __name__ == "__main__":
    unittest.main()
