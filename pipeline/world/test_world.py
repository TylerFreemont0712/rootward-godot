"""The world pipeline's pure parts (pipeline/world/world.py): checking specs, solving a building to its footprint, the
frame and render sizes, the prompt, and the cut.

  uv run --project pipeline python -m unittest discover -s pipeline/world -p 'test_*.py'
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import world  # noqa: E402

STYLE = world.load_style()
PALETTE = world.pixelkit.Palette.load()


def building(**overrides: object) -> dict:
    spec = {
        "id": "cottage",
        "kind": "building",
        "what": "a cosy cottage with a thatched roof",
        "footprint": [5, 5],
        "ramps": dict(STYLE["kinds"]["building"]["roles"]),
        "walls": 2.4,
        "roof": "gable",
        "door": 2,
        "windows": [1, 3],
    }
    spec.update(overrides)
    return spec


def barrel() -> dict:
    return {
        "id": "barrel",
        "kind": "prop",
        "what": "an oak barrel with iron hoops",
        "footprint": [1, 1],
        "ramps": {"wood": "wood", "hoops": "steel"},
        "parts": [{"shape": "cylinder", "at": [0.1, 0.1, 0], "size": [0.8, 0.8, 1.0], "ramp": "wood"}],
    }


class SpecTest(unittest.TestCase):
    def test_swing_metadata_rejects_invalid_axis_and_material(self) -> None:
        for swing in (True, {"axis": "diagonal"}, {"axis": "horizontal", "material": "glass"}):
            spec = {**barrel(), "swing": swing}
            self.assertTrue(any('"swing.' in p for p in world.check_spec(spec, "barrel", PALETTE, STYLE)))
        spec = {**barrel(), "swing": {"axis": "vertical", "material": "wood"}}
        self.assertEqual(world.check_spec(spec, "barrel", PALETTE, STYLE), [])

    def test_restyle_is_a_boolean(self) -> None:
        spec = {**barrel(), "restyle": False}
        self.assertEqual(world.check_spec(spec, "barrel", PALETTE, STYLE), [])
        spec["restyle"] = "false"
        self.assertTrue(any('"restyle"' in p for p in world.check_spec(spec, "barrel", PALETTE, STYLE)))

    def test_a_good_spec_has_no_problems(self) -> None:
        self.assertEqual(world.check_spec(building(), "cottage", PALETTE, STYLE), [])
        self.assertEqual(world.check_spec(barrel(), "barrel", PALETTE, STYLE), [])

    def test_a_typo_names_the_field_it_meant(self) -> None:
        problems = world.check_spec(building(windws=[1]), "cottage", PALETTE, STYLE)
        self.assertTrue(any("windws" in p and "windows" in p for p in problems), problems)

    def test_an_unknown_ramp_suggests_a_real_one(self) -> None:
        problems = world.check_spec(building(ramps={**building()["ramps"], "roof": "thach"}), "cottage", PALETTE, STYLE)
        self.assertTrue(any("thach" in p and "thatch" in p for p in problems), problems)

    def test_a_door_off_the_footprint_is_refused(self) -> None:
        problems = world.check_spec(building(door=5), "cottage", PALETTE, STYLE)
        self.assertTrue(any('"door"' in p for p in problems), problems)

    def test_the_id_must_match_the_file(self) -> None:
        problems = world.check_spec(building(), "house", PALETTE, STYLE)
        self.assertTrue(any("cottage.jsonc" in p or "house.jsonc" in p for p in problems), problems)

    def test_a_part_in_front_of_the_footprint_is_refused(self) -> None:
        spec = barrel()
        spec["parts"][0]["at"] = [0.1, -0.5, 0]
        problems = world.check_spec(spec, "barrel", PALETTE, STYLE)
        self.assertTrue(any("in front of the footprint" in p for p in problems), problems)

    def test_a_shade_must_be_one_of_its_ramps(self) -> None:
        spec = barrel()
        spec["parts"][0]["shade"] = 2
        self.assertEqual(world.check_spec(spec, "barrel", PALETTE, STYLE), [])
        spec["parts"][0]["shade"] = 7
        problems = world.check_spec(spec, "barrel", PALETTE, STYLE)
        self.assertTrue(any('"shade"' in p for p in problems), problems)
        darker = {**barrel(), "parts": [{**barrel()["parts"][0], "shade": 3}]}
        self.assertEqual(world.part_shapes(darker)[0]["shade"], 3)

    def test_the_maps_footprint_and_door_must_match(self) -> None:
        placed = {"cottage": [{"art": "cottage", "at": [3, 4], "size": [5, 4], "door": [1, 3], "_map": "town"}]}
        problems = world.check_maps(building(), placed)
        self.assertTrue(any("[5, 4]" in p for p in problems), problems)
        self.assertTrue(any('"door": 1' in p for p in problems), problems)

    def test_a_studio_resize_keeps_the_native_art_footprint_and_door(self) -> None:
        spec = building()
        placed = {"cottage": [{"art": "cottage", "at": [3, 4], "size": [2, 2], "door": [1, 1],
                               "art_size": spec["footprint"], "art_shape": {"door": [spec["door"], 4]},
                               "_map": "town"}]}
        self.assertEqual(world.check_maps(spec, placed), [])
        placed["cottage"][0]["art_size"] = [1, 1]
        self.assertTrue(world.check_maps(spec, placed))
        placed["cottage"][0]["art_size"] = spec["footprint"]
        placed["cottage"][0]["art_shape"] = {"door": [8, 9], "door_size": [10, 10]}
        self.assertEqual(world.check_maps(spec, placed), [])


    def test_an_id_may_have_an_underscore(self) -> None:
        spec = {**barrel(), "id": "fence_v"}
        self.assertEqual(world.check_spec(spec, "fence_v", PALETTE, STYLE), [])
        self.assertTrue(world.check_spec({**barrel(), "id": "Fence"}, "Fence", PALETTE, STYLE))

    def test_a_thing_that_takes_code_is_drawn_per_tile_so_its_picture_is_one_tile(self) -> None:
        gate = {**barrel(), "id": "gate"}
        coded = {"art": "gate", "at": [4, 44], "size": [2, 1], "program": {"hook": "on_use"}, "_map": "town"}
        self.assertEqual(world.check_maps(gate, {"gate": [coded]}), [])
        plain = {"art": "gate", "at": [4, 44], "size": [2, 1], "_map": "town"}
        self.assertTrue(world.check_maps(gate, {"gate": [plain]}))

    def test_unlit_names_a_role_and_a_ramp_with_as_many_shades(self) -> None:
        lamp = {**barrel(), "ramps": {"wood": "wood", "light": "glow"}, "unlit": {"light": "steel"}}
        self.assertEqual(world.check_spec(lamp, "barrel", PALETTE, STYLE), [])
        for bad in ({"glass": "steel"}, {"light": "no-such"}, {"light": "skin"}, {}):
            problems = world.check_spec({**lamp, "unlit": bad}, "barrel", PALETTE, STYLE)
            self.assertTrue(any('"unlit"' in p for p in problems), (bad, problems))


class FrameTest(unittest.TestCase):
    def test_a_building_fills_its_footprint_exactly(self) -> None:
        for rows in (4, 5, 6, 8):
            spec = building(footprint=[6, rows], door=3, windows=[1])
            frame = world.frame_of(spec, STYLE)
            top = max(world.top_of(item, STYLE["projection"]["depth_scale"]) for item in world.shapes_of(spec, STYLE))
            self.assertAlmostEqual(top, rows, places=3)  # shapes are stored to 4 places: well under a pixel
            self.assertEqual((frame["width"], frame["height"]), (6, rows))

    def test_a_prop_rises_above_its_footprint_in_half_tiles(self) -> None:
        frame = world.frame_of(barrel(), STYLE)
        self.assertEqual(frame["width"], 1)
        self.assertGreater(frame["height"], 1)
        self.assertEqual(frame["height"] * 2, int(frame["height"] * 2))

    def test_a_wide_canopy_pads_both_sides_alike(self) -> None:
        tree = {
            "id": "oak",
            "kind": "tree",
            "what": "a round leafy oak tree",
            "footprint": [1, 1],
            "ramps": {"trunk": "wood", "leaves": "leaf"},
            "canopy": [3.0, 2.5],
        }
        frame = world.frame_of(tree, STYLE)
        self.assertEqual(frame["pad"], 1.0)
        self.assertEqual(frame["width"], 3.0)

    def test_render_sizes_land_on_whole_pixels(self) -> None:
        for frame in ({"width": 5, "height": 5}, {"width": 1, "height": 2.5}, {"width": 9, "height": 8}):
            per_tile, width, height = world.render_size(frame, STYLE)
            self.assertEqual(per_tile % 16, 0)
            self.assertEqual((width % 8, height % 8), (0, 0))
            self.assertLessEqual(max(width, height), STYLE["projection"]["long_side"])

    def test_a_small_render_is_centred_on_a_canvas_comfyui_draws_well(self) -> None:
        self.assertEqual(world.canvas_of(256, 640, 512), (512, 640, 128, 0))
        self.assertEqual(world.canvas_of(960, 960, 512), (960, 960, 0, 0))


class PromptTest(unittest.TestCase):
    def test_the_prompt_names_what_it_is_and_its_colours(self) -> None:
        text, negative = world.prompt_for(building(), STYLE)
        self.assertIn("a cosy cottage with a thatched roof", text)
        self.assertIn("roof", text)
        self.assertIn("people", negative)

    def test_the_lock_keeps_the_ink(self) -> None:
        ramps = world.lock_ramps(barrel(), STYLE)
        self.assertIn("wood", ramps)
        self.assertIn("ink", ramps)


class CutTest(unittest.TestCase):
    def test_modular_blockouts_preserve_gate_gaps_without_comfy(self) -> None:
        spec = {**barrel(), "restyle": False}
        raw = np.zeros((8, 8, 4), np.uint8)
        raw[1:7, 1:3] = (120, 80, 40, 255)
        raw[1:7, 5:7] = (120, 80, 40, 255)
        raw[2:4, 1:7] = (120, 80, 40, 255)
        with tempfile.TemporaryDirectory() as folder:
            blockout = Path(folder) / "gate.png"
            Image.fromarray(raw, "RGBA").save(blockout)
            with patch.object(world, "blockout_path", return_value=blockout), patch.object(world.gen, "ensure_raws") as comfy:
                world.stage_restyle({"barrel": spec}, STYLE, False)
                held, _ = world.restyled_frame("barrel", spec, STYLE)
                comfy.assert_not_called()
        np.testing.assert_array_equal(np.round(held * 255).astype(np.uint8), raw)
        self.assertEqual(held[5, 4, 3], 0)

    def test_a_fitted_picture_stands_on_the_bottom_edge_centred(self) -> None:
        raw = np.zeros((100, 60, 4), np.float32)
        raw[10:60, 20:40] = [0.5, 0.3, 0.2, 1.0]
        out = world.fitted(raw, (40, 80))
        solid = out[..., 3] > 0.5
        rows, columns = np.nonzero(solid.any(axis=1))[0], np.nonzero(solid.any(axis=0))[0]
        self.assertEqual(rows[-1], out.shape[0] - 1)
        self.assertAlmostEqual((columns[0] + columns[-1]) / 2, out.shape[1] / 2 - 0.5, delta=1.0)

    def test_the_cut_is_the_frame_size_hard_edged_and_in_the_palette(self) -> None:
        raw = np.zeros((200, 100, 4), np.float32)
        raw[40:200, 10:90] = [0.55, 0.36, 0.22, 1.0]
        picture = world.finish(raw, (40, 80), 12, ["wood", "ink"])
        self.assertEqual(picture.size, (40, 80))
        self.assertEqual(world.pixelkit.problems(np.asarray(picture), PALETTE, "cut"), [])


    def test_an_unlit_sheet_has_the_dark_frame_first_and_swaps_only_that_ramp(self) -> None:
        glow, steel, wood = PALETTE.ramps["glow"], PALETTE.ramps["steel"], PALETTE.ramps["wood"]
        lit = np.zeros((4, 2, 4), np.uint8)
        lit[0, 0] = (*glow[1], 255)
        lit[1, 0] = (*wood[2], 255)
        lit[2, 1] = (*glow[3], 255)
        spec = {**barrel(), "ramps": {"wood": "wood", "light": "glow"}, "unlit": {"light": "steel"}}
        sheet = np.asarray(world.unlit_picture(Image.fromarray(lit, "RGBA"), spec, PALETTE))
        self.assertEqual(sheet.shape, (4, 4, 4))
        self.assertEqual(tuple(sheet[0, 0, :3]), steel[1])  # frame 0: the glass is dark iron
        self.assertEqual(tuple(sheet[1, 0, :3]), wood[2])  # the wood is the same in both
        self.assertEqual(tuple(sheet[2, 1, :3]), steel[3])
        self.assertEqual(tuple(sheet[0, 2, :3]), glow[1])  # frame 1: as cut, lit
        self.assertEqual(sheet[3, 0, 3], 0)  # transparent stays transparent
        self.assertEqual(world.pixelkit.problems(sheet, PALETTE, "lamp"), [])


if __name__ == "__main__":
    unittest.main()
