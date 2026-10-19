"""Terrain variation is authored, palette-safe and shares the same edges in every variant."""

from __future__ import annotations

import json
import re
import unittest

import numpy as np

import pixelkit
import terrain


class TerrainTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.palette = pixelkit.Palette.load()
        cls.sheet, cls.layout = terrain.atlas(cls.palette)

    def tile(self, row: int, column: int) -> np.ndarray:
        side = terrain.TILE
        return self.sheet[row * side : (row + 1) * side, column * side : (column + 1) * side]

    def test_every_paintable_surface_has_real_art_and_valid_movement(self) -> None:
        path = terrain.SCALE.with_name("terrain.jsonc")
        catalog = json.loads(re.sub(r"//[^\n]*", "", path.read_text()))
        outdoors = {kind for kind, entry in catalog.items() if entry.get("paint") == "outdoor"}
        self.assertEqual(outdoors, {"grass", *self.layout["overlay"]})
        self.assertEqual(len(outdoors), 19)
        for kind in outdoors:
            self.assertIn(kind, self.layout["base"])
            self.assertEqual(catalog[kind]["walk"], kind != "water", kind)
        self.assertEqual({k for k, v in catalog.items() if v.get("paint") == "indoor"}, {"floor", "wall", "void"})

    def test_the_whole_atlas_has_only_palette_colours_and_hard_alpha(self) -> None:
        self.assertEqual(pixelkit.problems(self.sheet, self.palette, "terrain"), [])

    def test_every_outdoor_surface_has_eight_visibly_different_variants(self) -> None:
        for kind, entry in self.layout["overlay"].items():
            with self.subTest(kind=kind):
                count = entry["variants"]
                self.assertGreaterEqual(count, 8)
                frames = entry["frames"]
                tiles = [self.tile(entry["row"] + v * frames, 15) for v in range(count)]
                self.assertEqual(len({tile.tobytes() for tile in tiles}), count)
        grass = self.layout["base"]["grass"]
        self.assertGreaterEqual(grass["count"], 8)
        self.assertEqual(len({self.tile(grass["row"], v).tobytes() for v in range(grass["count"])}), grass["count"])

    def test_variants_preserve_every_mask_and_its_border_in_each_ripple_frame(self) -> None:
        # Variants may change the interior texture, never the shared shore/edge or pixel occupancy. That also makes
        # a repaint independent of the order the cells were visited in.
        rim = terrain.UNIT
        for kind, entry in self.layout["overlay"].items():
            for frame in range(entry["frames"]):
                for mask in range(16):
                    original = self.tile(entry["row"] + frame, mask)
                    for variant in range(1, entry["variants"]):
                        other = self.tile(entry["row"] + variant * entry["frames"] + frame, mask)
                        with self.subTest(kind=kind, frame=frame, mask=mask, variant=variant):
                            np.testing.assert_array_equal(other[..., 3], original[..., 3])
                            np.testing.assert_array_equal(other[:rim], original[:rim])
                            np.testing.assert_array_equal(other[-rim:], original[-rim:])
                            np.testing.assert_array_equal(other[:, :rim], original[:, :rim])
                            np.testing.assert_array_equal(other[:, -rim:], original[:, -rim:])

    def test_grass_plants_are_sparse_and_the_grass_variants_share_their_edges(self) -> None:
        entry = self.layout["base"]["grass"]
        grass_colours = set(self.palette.ramps["grass"])
        original = self.tile(entry["row"], 0)
        has_small_plants = False
        for variant in range(entry["count"]):
            tile = self.tile(entry["row"], variant)
            other_plants = sum(tuple(pixel) not in grass_colours for pixel in tile[..., :3].reshape(-1, 3))
            has_small_plants |= other_plants > 0
            self.assertLess(other_plants / (terrain.TILE**2), 0.035)
            np.testing.assert_array_equal(tile[:terrain.UNIT], original[:terrain.UNIT])
            np.testing.assert_array_equal(tile[-terrain.UNIT:], original[-terrain.UNIT:])
        self.assertTrue(has_small_plants)

    def test_layer_order_and_all_atlas_regions_fit_the_renderer(self) -> None:
        order = self.layout["order"]
        self.assertEqual(set(order), set(self.layout["overlay"]))
        self.assertEqual(len(order), len(set(order)))
        self.assertLessEqual(len(order), 30, "two signed 64-bit planes hold fifteen four-bit layers each")
        self.assertEqual(order[-1], "water")
        for entry in self.layout["overlay"].values():
            self.assertLessEqual((entry["row"] + entry["variants"] * entry["frames"]) * terrain.TILE, self.sheet.shape[0])

    def test_flowerless_meadow_keeps_the_flowered_turfs_colour_and_texture(self) -> None:
        entry = self.layout["overlay"]["meadow"]
        flower_colours = {
            self.palette.shade(ramp, shade)
            for ramp in ("cloth_white", "cloth_yellow", "cloth_pink", "cloth_blue")
            for shade in range(4)
        }
        green_means = []
        empty = []
        for variant in range(8):
            rgb = self.tile(entry["row"] + variant, 15)[..., :3]
            green = (rgb[..., 1].astype(float) > rgb[..., 0] * 1.05) & (rgb[..., 1] > rgb[..., 2] * 1.1)
            greens = rgb[green]
            green_means.append(greens.mean(axis=0))
            if not any(tuple(pixel) in flower_colours for pixel in rgb.reshape(-1, 3)):
                empty.append(variant)
                self.assertGreaterEqual(len(np.unique(greens, axis=0)), 5, "bare meadow must retain painted turf detail")
        self.assertEqual(len(empty), 3, "three quiet meadow layouts must contain no petals")
        flowered_mean = np.mean([green_means[v] for v in range(8) if v not in empty], axis=0)
        for variant in empty:
            self.assertLess(np.abs(green_means[variant] - flowered_mean).max(), 8, "no differently coloured grass squares")

    def test_every_path_material_keeps_joined_edges_across_variants(self) -> None:
        for kind in terrain.PATHS:
            entry = self.layout["overlay"][kind]
            for variant in range(8):
                left = [self.tile(entry["row"] + variant, mask) for mask in range(16)]
                right = [self.tile(entry["row"] + (variant + 3) % 8, mask) for mask in range(16)]
                for a in range(16):
                    for b in range(16):
                        with self.subTest(kind=kind, variant=variant, first=a, second=b):
                            if (a & 2) >> 1 == b & 1 and (a & 8) >> 1 == b & 4:
                                np.testing.assert_array_equal(left[a][:, -1], right[b][:, 0])
                            if a >> 2 == b & 3:
                                np.testing.assert_array_equal(left[a][-1], right[b][0])

    def test_path_rims_appear_on_exposed_edges_and_not_filled_interiors(self) -> None:
        for kind in terrain.PATHS:
            entry = self.layout["overlay"][kind]
            _make, rim, _shade, wobble = terrain.GROUNDS[kind]
            noise = terrain.edge_noise(wobble, 0.12)
            noise[0, :] = noise[-1, :] = (noise[0, :] + noise[-1, :]) / 2
            noise[:, 0] = noise[:, -1] = (noise[:, 0] + noise[:, -1]) / 2
            rim_colour = self.palette.shade(*rim)
            for variant in range(entry["variants"]):
                texture = terrain.varied_land(self.palette, kind, variant, _make)
                full = self.tile(entry["row"] + variant, 15)
                exposed = self.tile(entry["row"] + variant, 5)
                expected = np.roll(texture, (-terrain.HALF, -terrain.HALF), axis=(0, 1))
                with self.subTest(kind=kind, variant=variant):
                    np.testing.assert_array_equal(
                        full[terrain.UNIT:-terrain.UNIT, terrain.UNIT:-terrain.UNIT, :3],
                        expected[terrain.UNIT:-terrain.UNIT, terrain.UNIT:-terrain.UNIT, :3],
                    )
                    rim_pixels = np.all(exposed[..., :3] == rim_colour, axis=-1)
                    self.assertGreater(rim_pixels.sum(), 0, "an exposed straight edge gets a clear rim")

    def test_an_atlas_rebuild_is_byte_identical(self) -> None:
        repeat, layout = terrain.atlas(self.palette)
        self.assertEqual(layout, self.layout)
        np.testing.assert_array_equal(repeat, self.sheet)


if __name__ == "__main__":
    unittest.main()
