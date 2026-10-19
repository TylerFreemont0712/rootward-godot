"""Tests for the cast pipeline's own logic (ADR-0063): reading the content, a look's colours and prompt, choosing and
holding a restyle, the registered cut, and the sheet. Nothing here needs Blender or ComfyUI. Run from the repository root:

    uv run --project pipeline python -m unittest discover -s pipeline/animation -p 'test_*.py'
"""

from __future__ import annotations

import json
import unittest

import numpy as np
from PIL import Image

import cast
import pixelkit

CONFIG = json.loads(cast.CONFIG.read_text())
PALETTE = pixelkit.Palette.load()


def frame(
    box: tuple[int, int, int, int], size: tuple[int, int] = (80, 120), colour: tuple = (0.2, 0.6, 0.6)
) -> np.ndarray:
    """A float RGBA camera frame with one solid box (x0, y0, x1, y1) in it."""
    out = np.zeros((size[1], size[0], 4), np.float32)
    x0, y0, x1, y1 = box
    out[y0:y1, x0:x1, :3] = colour
    out[y0:y1, x0:x1, 3] = 1.0
    return out


class ContentTest(unittest.TestCase):
    def test_jsonc_drops_comments_and_trailing_commas_but_not_slashes_in_strings(self) -> None:
        text = '// a file\n{\n  "a": "http://x", // why\n  "b": [1, 2,],\n}\n'
        self.assertEqual(cast.read_jsonc(text), {"a": "http://x", "b": [1, 2]})

    def test_the_cast_is_the_named_characters_then_every_other_townsperson(self) -> None:
        config = {"cast": {"player": {"look": "start", "who": "a child"}, "smith": {"who": "a smith"}}}
        townsfolk = {"smith": {"look": {"outfit": "outfit/vest"}}, "baker": {"look": {"outfit": "outfit/dress"}}}
        made = cast.characters(config, townsfolk, {"start": {"outfit": "outfit/tunic"}})
        self.assertEqual(list(made), ["player", "smith", "baker"])
        self.assertEqual(made["player"]["look"], {"outfit": "outfit/tunic"})
        self.assertEqual(made["baker"]["who"], "a villager")
        with self.assertRaises(KeyError):
            cast.characters({"cast": {"ghost": {}}}, townsfolk, {"start": {}})

    def test_a_look_without_a_colour_takes_the_slot_default(self) -> None:
        ramps = cast.slot_ramps({"colours": {"hair": "hair_red"}}, PALETTE)
        self.assertEqual(ramps["hair"], "hair_red")
        self.assertEqual(ramps["main"], PALETTE.slots["main"])
        colours = cast.spec_colours({"colours": {"main": "cloth_teal"}}, PALETTE, CONFIG)
        self.assertEqual(colours["main"], cast.hex_of(PALETTE.shade("cloth_teal", CONFIG["colours"]["shade"])))
        self.assertIn("boot", colours)

    def test_the_prompt_names_each_part_in_its_colours_and_the_view(self) -> None:
        character = {
            "look": {"outfit": "outfit/armor", "hair": "hair/short", "colours": {"main": "cloth_navy"}},
            "who": "a guard",
        }
        text, negative = cast.prompt_for(character, "back", PALETTE, CONFIG)
        self.assertIn("a guard", text)
        self.assertIn("navy blue armor", text)
        self.assertIn("armored boots", text)
        self.assertIn("seen from behind", text)
        self.assertIn("face", negative)
        with self.assertRaises(KeyError):
            cast.prompt_for({"look": {"hat": "hat/crown"}, "who": "x"}, "front", PALETTE, CONFIG)


class FramesTest(unittest.TestCase):
    def test_the_candidate_that_matches_the_turns_outline_is_picked(self) -> None:
        turn = frame((20, 20, 60, 110))[..., 3]
        close, far = frame((22, 20, 60, 110)), frame((0, 0, 30, 50))
        chosen, scores = cast.pick([far, close], turn)
        self.assertEqual(chosen, 1)
        self.assertGreater(scores[1], 0.9)
        self.assertEqual(cast.pick([far, close], turn, override=0)[0], 0)

    def test_a_restyle_is_held_inside_the_turns_outline(self) -> None:
        turn = frame((20, 20, 60, 110), (240, 360))[..., 3]
        spilled = frame((20, 20, 200, 110), (240, 360))
        held = cast.guarded(spilled, turn, 8)
        self.assertEqual(held[60, 40, 3], 1.0)
        self.assertEqual(held[60, 190, 3], 0.0)

    def test_the_cut_keeps_every_frame_on_one_scale_and_one_place(self) -> None:
        # Two figures in the same camera frame: one tall, one shorter. Fitting each to its own box would make both fill
        # the cell; the registered cut keeps the shorter one shorter and both feet on the same row.
        tall, short = frame((30, 20, 50, 110)), frame((30, 50, 50, 110))
        ramps = cast.lock_ramps({}, PALETTE, CONFIG)
        cut = cast.registered_cut([tall, short], [16, 24], 8, 0.5, ramps)
        rows = [np.nonzero(np.asarray(image)[..., 3].any(axis=1))[0] for image in cut]
        self.assertEqual([image.size for image in cut], [(16, 24), (16, 24)])
        self.assertEqual(rows[0].max(), rows[1].max())
        self.assertLess(rows[0].min(), rows[1].min())

    def test_the_cut_draws_only_the_characters_colours_and_the_ink_outline(self) -> None:
        ramps = cast.lock_ramps({"colours": {"main": "cloth_teal"}}, PALETTE, CONFIG)
        allowed = {c for name in ramps for c in PALETTE.ramps[name]} | {PALETTE.resolve("ink")}
        image = np.asarray(cast.registered_cut([frame((30, 20, 50, 110))], [16, 24], 8, 0.5, ramps)[0])
        solid = image[image[..., 3] > 0][:, :3]
        self.assertTrue(all(tuple(int(v) for v in c) in allowed for c in solid))
        self.assertIn(PALETTE.resolve("ink"), {tuple(int(v) for v in c) for c in solid})
        self.assertTrue(set(np.unique(image[..., 3])) <= {0, 255})

    def test_the_sheet_has_a_row_per_facing_and_idle_settles(self) -> None:
        left = Image.new("RGBA", (8, 12), (0, 0, 0, 0))
        left.paste((200, 0, 0, 255), (0, 2, 3, 11))
        right = Image.new("RGBA", (8, 12), (0, 0, 0, 0))
        right.paste((0, 0, 200, 255), (4, 2, 8, 11))
        stops = {"front": left, "back": left, "left": left, "right": right}
        sheet = cast.assemble(stops, CONFIG["sheet"])
        self.assertEqual(sheet.size, (16, 48))
        # Right is its own turn (a held item stays in its hand), not left mirrored.
        self.assertTrue((np.asarray(sheet.crop((0, 36, 8, 48))) == np.asarray(right)).all())
        stop_top = np.nonzero(np.asarray(sheet.crop((0, 0, 8, 12)))[..., 3].any(axis=1))[0].min()
        idle_top = np.nonzero(np.asarray(sheet.crop((8, 0, 16, 12)))[..., 3].any(axis=1))[0].min()
        self.assertEqual(idle_top, stop_top + CONFIG["sheet"]["idle"]["drop"])

    def test_a_row_can_still_mirror_another_view(self) -> None:
        left = Image.new("RGBA", (8, 12), (0, 0, 0, 0))
        left.paste((200, 0, 0, 255), (0, 2, 3, 11))
        mirrored = {**CONFIG["sheet"], "rows": [{"facing": "right", "view": "left", "mirror": True}]}
        sheet = cast.assemble({"left": left}, mirrored)
        flipped = np.asarray(left.transpose(Image.Transpose.FLIP_LEFT_RIGHT))
        self.assertTrue((np.asarray(sheet.crop((0, 0, 8, 12))) == flipped).all())

    def test_the_ground_row_comes_from_the_camera(self) -> None:
        self.assertEqual(cast.ground_row({"height": 3.0, "center_z": 1.4}, 48), 46)

    def test_a_sheet_made_for_another_look_is_stale(self) -> None:
        index = {"sheets": {"pip": {"file": "pip.png", "look": {"outfit": "outfit/coat"}}}}
        cast_now = {"pip": {"look": {"outfit": "outfit/coat"}}, "pell": {"look": {}}}
        self.assertEqual(cast.stale(index, cast_now), ["pell"])
        cast_now["pip"]["look"] = {"outfit": "outfit/robe"}
        self.assertEqual(cast.stale(index, cast_now), ["pip", "pell"])


if __name__ == "__main__":
    unittest.main()
