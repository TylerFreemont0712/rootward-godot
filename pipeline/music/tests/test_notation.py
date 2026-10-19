"""The score notation: the check, the canonical form YuE2 is given, key signatures, the loop's bars."""

import unittest
from pathlib import Path

import helpers  # noqa: F401  (puts the pipeline folder on the path)
import library
import notation

VALID = """X:1
T:Test
M:4/4
L:1/16
Q:1/4=120
V: Vocal clef=treble name="Vocal Melody" snm="Vocal"
V: Ins clef=treble name="Ins Melody" snm="Inst."
K:Dm
% silence
V: Vocal
Z|
V: Ins
Z|
% verse
V: Vocal
"Dm"z16|"Bb"z16|
V: Ins
B4 d4 f4 a4|c'8 b8|
"""

ROSTER = (Path(__file__).parent / "fixtures" / "rest_score.abc").read_text()


class KeySignatures(unittest.TestCase):
    def test_keys_as_the_scores_write_them(self):
        self.assertEqual(notation.key_signature("C"), {})
        self.assertEqual(notation.key_signature("F"), {"B": -1})
        self.assertEqual(notation.key_signature("Dm"), {"B": -1})
        self.assertEqual(notation.key_signature("D minor"), {"B": -1})
        self.assertEqual(notation.key_signature("Bb"), {"B": -1, "E": -1})
        self.assertEqual(notation.key_signature("F#m"), {"F": 1, "C": 1, "G": 1})
        self.assertEqual(notation.key_signature("D"), {"F": 1, "C": 1})

    def test_keys_a_table_would_have_missed(self):
        self.assertEqual(notation.key_signature("Ebm"), {"B": -1, "E": -1, "A": -1, "D": -1, "G": -1, "C": -1})
        self.assertEqual(notation.key_signature("C#m"), {"F": 1, "C": 1, "G": 1, "D": 1})
        self.assertEqual(notation.key_signature("Db"), {"B": -1, "E": -1, "A": -1, "D": -1, "G": -1})
        self.assertEqual(len(notation.key_signature("Cb")), 7)

    def test_an_unknown_key_is_an_error_not_c_major(self):
        for bad in ("Hm", "Dorian", "D# dorian", ""):
            with self.assertRaises(ValueError, msg=bad):
                notation.key_signature(bad)


class Check(unittest.TestCase):
    def test_a_valid_score_passes(self):
        self.assertEqual(notation.check(notation.parse(VALID)), [])

    def test_a_bar_of_the_wrong_length_is_flagged(self):
        broken = VALID.replace('"Dm"z16|"Bb"z16|', '"Dm"z16|"Bb"z12|')
        problems = notation.check(notation.parse(broken))
        self.assertTrue(any("is 12 units, not 16" in p for p in problems), problems)

    def test_a_length_yuE2_never_saw_is_flagged(self):
        broken = VALID.replace("B4 d4 f4 a4", "B4 d4 f4 a4").replace("c'8 b8", "c'10 b6")
        problems = notation.check(notation.parse(broken))
        self.assertTrue(any("never saw" in p for p in problems), problems)

    def test_a_section_yuE2_does_not_know_is_flagged(self):
        problems = notation.check(notation.parse(VALID.replace("% verse", "% drop")))
        self.assertTrue(any("'drop'" in p for p in problems), problems)

    def test_a_key_it_cannot_read_is_flagged(self):
        problems = notation.check(notation.parse(VALID.replace("K:Dm", "K:Hm")))
        self.assertTrue(any("not a key" in p for p in problems), problems)

    def test_every_committed_track_score_passes(self):
        for track in library.track_ids():
            with self.subTest(track=track):
                self.assertEqual(notation.check(notation.parse(library.score_text(track))), [])


class Canonical(unittest.TestCase):
    def test_no_title_and_no_spaces_inside_a_bar(self):
        out = notation.canonical(VALID)
        self.assertIn("\nT:\n", "\n" + out)
        self.assertNotIn("T:Test", out)
        self.assertIn("B4d4f4a4", out)
        self.assertIn("%verse" if "%verse" in out else "% verse", out)
        for line in out.splitlines():
            if line.startswith(("V:", "%", "K:", "M:", "L:", "Q:", "X:", "T:")):
                continue
            self.assertNotIn(" ", line)

    def test_canonical_keeps_the_notes_and_chords(self):
        parsed_before = notation.parse(VALID)
        parsed_after = notation.parse(notation.canonical(VALID))
        self.assertEqual([len(s.bars) for s in parsed_before.sections],
                         [len(s.bars) for s in parsed_after.sections])
        self.assertEqual(notation.bars(parsed_before)[-1]["chords"], notation.bars(parsed_after)[-1]["chords"])


class Pitches(unittest.TestCase):
    def test_a_key_signature_flattens_the_melody(self):
        bars = notation.bars(notation.parse(VALID))
        first_verse_bar = bars[1]  # bar 0 is the silence
        self.assertEqual(sorted(pc for pc, _ in first_verse_bar["notes"]), [2, 5, 9, 10])  # B4 is B flat in Dm

    def test_the_timeline_counts_bars_from_the_silence(self):
        parts = notation.timeline(notation.parse(ROSTER))
        self.assertEqual([(p["name"], p["bar"], p["bars"]) for p in parts],
                         [("silence", 0, 1), ("intro", 1, 2), ("verse", 3, 8), ("bridge", 11, 8), ("verse", 19, 8),
                          ("outro", 27, 2)])


class LoopBars(unittest.TestCase):
    """The brief's loop becomes score bars: from the first bar of `from` to the end of the `occurrence`-th `to`."""

    def setUp(self):
        self.score = notation.parse(ROSTER)

    def test_a_verse_to_the_second_verse(self):
        self.assertEqual(notation.loop_bars(self.score, {"from": "verse", "to": "verse", "occurrence": 2}), (3, 27))

    def test_the_first_verse_alone(self):
        self.assertEqual(notation.loop_bars(self.score, {"from": "verse", "to": "verse", "occurrence": 1}), (3, 11))

    def test_occurrence_defaults_to_the_first(self):
        self.assertEqual(notation.loop_bars(self.score, {"from": "intro", "to": "bridge"}), (1, 19))

    def test_a_loop_the_score_cannot_hold_is_an_error(self):
        with self.assertRaises(ValueError):
            notation.loop_bars(self.score, {"from": "chorus", "to": "verse"})
        with self.assertRaises(ValueError):
            notation.loop_bars(self.score, {"from": "verse", "to": "verse", "occurrence": 3})
        with self.assertRaises(ValueError):
            notation.loop_bars(self.score, {"from": "bridge", "to": "intro"})


if __name__ == "__main__":
    unittest.main()
