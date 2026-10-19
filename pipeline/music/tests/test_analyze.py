"""The measurements: how closely a take follows its score (bar by bar), and the colour of a whole piece."""

import unittest

import numpy as np

import helpers  # noqa: F401
import analyze
import notation


def bar_of(chords, notes, section="verse"):
    return {"section": section, "chords": chords, "notes": notes}


class Adherence(unittest.TestCase):
    def setUp(self):
        # Four bars of two seconds each, sampled every tenth of a second.
        self.times = np.arange(0, 8, 0.1)
        self.bars = [bar_of(["C"], [(0, 1.0), (4, 1.0)]), bar_of(["G"], [(7, 2.0)]),
                     bar_of(["Am"], [(9, 1.0), (0, 1.0)]), bar_of([], [])]

    def chroma_for(self, bars):
        frames = np.zeros((12, len(self.times)))
        for index, bar in enumerate(bars):
            window = (self.times >= index * 2) & (self.times < index * 2 + 2)
            frames[:, window] = analyze.expected_chroma(bar)[:, None]
        return frames

    def test_expected_chroma_weighs_notes_and_chord_tones(self):
        expected = analyze.expected_chroma(bar_of(["C"], [(0, 1.0), (4, 1.0)]))
        self.assertEqual({pc for pc in range(12) if expected[pc] > 0}, {0, 4, 7})
        self.assertGreater(expected[0], expected[7], "the notes weigh more than the chord under them")

    def test_a_take_that_plays_the_score_scores_near_one(self):
        fit = analyze.adherence(self.chroma_for(self.bars), self.times, self.bars, 0.0, 2.0)
        self.assertGreater(fit["mean"], 0.95, fit)
        self.assertEqual(fit["bars"], 3, "the silent bar holds nothing to compare")
        self.assertEqual(fit["below_0.3"], 0)

    def test_a_take_that_plays_other_bars_scores_low(self):
        swapped = [self.bars[2], self.bars[0], self.bars[1], self.bars[3]]
        fit = analyze.adherence(self.chroma_for(swapped), self.times, self.bars, 0.0, 2.0)
        self.assertLess(fit["mean"], 0.3, fit)
        self.assertGreater(fit["below_0.3"], 0)

    def test_a_score_bar_pitch_class_comes_from_the_key(self):
        score = notation.parse("X:1\nM:4/4\nL:1/16\nQ:1/4=120\nK:Dm\n% verse\nV: Vocal\n\"Dm\"z16|\nV: Ins\nB4 d4 f4 a4|\n")
        bars = notation.bars(score)
        self.assertIn(10, [pc for pc, _ in bars[0]["notes"]], "B in Dm is B flat")


class Colour(unittest.TestCase):
    def test_the_spectrum_covers_the_whole_piece_not_its_first_minute(self):
        rate = analyze.FULL_SR
        seconds = 70
        mid = np.zeros(seconds * rate, dtype=np.float32)
        t = np.arange(10 * rate) / rate
        mid[-10 * rate:] = 0.5 * np.sin(2 * np.pi * 10000 * t)  # a bright tone, only in the last ten seconds
        spectrum, freqs = analyze.mean_power_spectrum(mid.astype(np.float64))
        share = spectrum[freqs > 5000].sum() / spectrum.sum()
        self.assertGreater(share, 0.9, "the tone sits in the last ten seconds, past the first minute")

    def test_a_spectrum_peak_is_where_the_tone_is(self):
        rate = analyze.FULL_SR
        t = np.arange(rate * 2) / rate
        spectrum, freqs = analyze.mean_power_spectrum(np.sin(2 * np.pi * 1000 * t))
        self.assertAlmostEqual(float(freqs[int(np.argmax(spectrum))]), 1000, delta=2 * rate / (1 << 20))


if __name__ == "__main__":
    unittest.main()
