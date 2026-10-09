"""Tests for the pixel kit (ADR-0061): the palette, the .sprite text format, the checks every picture passes, and the
sheet layout the game reads. Run from the repository root:

    uv run --project pipeline python -m unittest discover -s pipeline/pixel -p 'test_*.py'
"""

from __future__ import annotations

import unittest

import characters
import pixelkit
from pixelkit import Palette, SpriteError

DOT = """sprite dot 4 2
legend Z cloth_red.1
frame idle
Z...
....
"""


class PaletteTest(unittest.TestCase):
    def setUp(self) -> None:
        self.palette = Palette.load()

    def test_every_ramp_is_a_list_of_valid_colours(self) -> None:
        self.assertTrue(self.palette.ramps, "the palette has no ramps")
        for name, shades in self.palette.ramps.items():
            self.assertTrue(shades, f"{name} has no shades")
            for colour in shades:
                self.assertIsInstance(colour, tuple, name)
                self.assertEqual(len(colour), 3, name)
                for channel in colour:
                    self.assertIsInstance(channel, int, name)
                    self.assertTrue(0 <= channel <= 255, f"{name}: {colour}")

    def test_hex_colours_read_with_or_without_the_hash(self) -> None:
        self.assertEqual(pixelkit.hex_rgb("#ff8000"), (255, 128, 0))
        self.assertEqual(pixelkit.hex_rgb("1a2b3c"), (26, 43, 60))

    def test_every_slot_and_legend_entry_names_a_real_colour(self) -> None:
        for slot, ramp in self.palette.slots.items():
            self.assertIn(ramp, self.palette.ramps, f"slot {slot}")
        for char, ref in self.palette.legend.items():
            with self.subTest(char=char):
                self.assertIn(self.palette.resolve(ref), self.palette.colours())

    def test_resolve_reads_a_shade_a_slot_or_refuses(self) -> None:
        self.assertEqual(self.palette.resolve("cloth_red"), self.palette.ramps["cloth_red"][0])
        self.assertEqual(self.palette.resolve("cloth_red.2"), self.palette.ramps["cloth_red"][2])
        hair = self.palette.slots["hair"]
        self.assertEqual(self.palette.resolve("@hair.1"), self.palette.ramps[hair][1])
        with self.assertRaises(ValueError):
            self.palette.resolve("cloth_red.9")
        self.assertEqual(self.palette.shade("cloth_red", 99), self.palette.ramps["cloth_red"][-1])


class ParseTest(unittest.TestCase):
    def setUp(self) -> None:
        self.palette = Palette.load()
        self.red = self.palette.resolve("cloth_red.1")

    def parse(self, text: str) -> dict:
        return pixelkit.parse(text, self.palette)

    def test_legend_and_pixels_draw_from_the_palette(self) -> None:
        idle = self.parse(DOT)["dot"].frames["idle"]
        self.assertEqual(tuple(idle[0, 0]), (*self.red, 255))
        self.assertEqual(idle[0, 1, 3], 0, "a . leaves the pixel empty")
        self.assertEqual(idle[1, :, 3].max(), 0, "a row the frame does not draw stays empty")

    def test_from_copies_the_frame_and_underscore_clears_one_pixel(self) -> None:
        text = DOT + "frame up from idle\n_...\n....\n"
        frames = self.parse(text)["dot"].frames
        self.assertEqual(frames["up"][0, 0, 3], 0)
        self.assertEqual(frames["idle"][0, 0, 3], 255, "copying must not change the frame it copied")

    def test_at_pastes_rows_from_a_corner(self) -> None:
        text = "sprite dot 4 2\nlegend Z cloth_red.1\nframe idle at 2 1\nZZ\n"
        frame = self.parse(text)["dot"].frames["idle"]
        self.assertEqual(frame[1, 2, 3], 255)
        self.assertEqual(frame[1, 3, 3], 255)
        self.assertEqual(frame[1, 1, 3], 0)
        self.assertEqual(frame[0, :, 3].max(), 0)

    def test_replace_clears_each_row_the_frame_draws(self) -> None:
        text = (
            "sprite dot 4 2\nlegend Z cloth_red.1\nframe idle\nZZZZ\nZZZZ\n"
            "frame step from idle replace\nZ...\n"
        )
        step = self.parse(text)["dot"].frames["step"]
        self.assertEqual(step[0, 0, 3], 255)
        self.assertEqual(step[0, 1, 3], 0, "the row it draws is cleared first")
        self.assertEqual(step[1, :, 3].min(), 255, "a row it does not draw keeps the copied pixels")

    def test_shift_moves_the_frame(self) -> None:
        text = DOT + "shift 1 0\n"
        frame = self.parse(text)["dot"].frames["idle"]
        self.assertEqual(frame[0, 0, 3], 0)
        self.assertEqual(frame[0, 1, 3], 255)

    def test_a_missing_colour_raises(self) -> None:
        with self.assertRaisesRegex(SpriteError, "no colour for 'W'"):
            self.parse("sprite dot 2 1\nframe idle\nW.\n")

    def test_an_unknown_colour_in_the_legend_raises(self) -> None:
        with self.assertRaisesRegex(SpriteError, "unknown colour nosuchramp.1"):
            self.parse("sprite dot 2 1\nlegend Z nosuchramp.1\nframe idle\nZ.\n")

    def test_a_row_too_wide_for_its_frame_raises(self) -> None:
        with self.assertRaisesRegex(SpriteError, "row is 4 wide, the frame is 2"):
            self.parse("sprite dot 2 1\nframe idle\n....\n")

    def test_a_placed_row_past_the_frame_raises(self) -> None:
        with self.assertRaisesRegex(SpriteError, "column 2 is past the 2-pixel frame"):
            self.parse("sprite dot 2 1\nlegend Z cloth_red.1\nframe idle at 1 0\nZZ\n")

    def test_a_row_below_the_frame_raises(self) -> None:
        with self.assertRaisesRegex(SpriteError, "row 1 is below the 1-pixel frame"):
            self.parse("sprite dot 2 1\nlegend Z cloth_red.1\nframe idle\nZZ\nZZ\n")


class ProblemsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.palette = Palette.load()
        self.red = self.palette.ramps["cloth_red"][1]

    def test_a_crisp_picture_has_no_problems(self) -> None:
        image = pixelkit.blank(3, 2)
        image[0, 0] = (*self.red, 255)
        image[1, 2] = (*self.palette.ramps["grass"][0], 255)
        self.assertEqual(pixelkit.problems(image, self.palette, "crisp"), [])

    def test_half_transparent_pixels_are_reported(self) -> None:
        image = pixelkit.blank(3, 2)
        image[0, 0] = (*self.red, 128)
        image[0, 1] = (*self.red, 1)
        self.assertEqual(pixelkit.problems(image, self.palette, "soft"), ["soft: 2 half-transparent pixels"])

    def test_colours_outside_the_palette_are_reported(self) -> None:
        stray = (1, 2, 3)
        self.assertNotIn(stray, self.palette.colours(), "the test colour must really be off the palette")
        image = pixelkit.blank(3, 2)
        image[0, 0] = (*stray, 255)
        problems = pixelkit.problems(image, self.palette, "stray")
        self.assertEqual(len(problems), 1)
        self.assertIn("1 colours outside the palette", problems[0])
        self.assertIn("#010203", problems[0])


class SheetTest(unittest.TestCase):
    def test_a_sheet_is_48_by_72_and_places_each_frame(self) -> None:
        palette = Palette.load()
        text = "sprite part 16 24\nlegend Z cloth_red.1\nframe left.step_b at 0 0\nZ\n"
        part = pixelkit.parse(text, palette)["part"]
        sheet = characters.sheet_of(part)
        # Three facings down the rows (24 pixels each), three poses across the columns (16 pixels each).
        self.assertEqual(sheet.shape, (72, 48, 4))
        self.assertEqual(sheet[48, 32, 3], 255, "left facing, step b: the frame's first pixel")
        self.assertEqual(sheet[0, 0, 3], 0)

    def test_every_character_part_makes_a_crisp_48_by_72_sheet(self) -> None:
        palette = Palette.load()
        parts = characters.load_parts(pixelkit.HERE / "sprites", palette)
        # Character parts are named <layer>/<part> (body/base, hair/short); props and the firefly are not sheets.
        worn = {name: part for name, part in parts.items() if "/" in name and name.split("/")[0] in characters.LAYERS}
        self.assertTrue(worn, "no character parts found in pipeline/pixel/sprites")
        for name, part in sorted(worn.items()):
            with self.subTest(part=name):
                self.assertEqual((part.width, part.height), (characters.FRAME_W, characters.FRAME_H))
                sheet = characters.sheet_of(part)
                self.assertEqual(sheet.shape, (72, 48, 4))
                self.assertEqual(pixelkit.problems(sheet, palette, name), [])

    def test_a_look_made_of_parts_makes_a_48_by_72_sheet(self) -> None:
        palette = Palette.load()
        parts = characters.load_parts(pixelkit.HERE / "sprites", palette)
        for look in characters.SAMPLE_LOOKS:
            with self.subTest(look=look):
                self.assertEqual(characters.look_sheet(parts, palette, look).shape, (72, 48, 4))


if __name__ == "__main__":
    unittest.main()
