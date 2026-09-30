"""Tests for the motion core: `python3 -m unittest discover pipeline/moves` (stdlib only)."""

from __future__ import annotations

import unittest

import motion

LIBRARY = {
    "stand": {"UpperArm": {"raise": -70, "forward": 5}, "LowerArm": {"bend": 15}},
    "reach": {"base": "stand", "LeftUpperArm": {"raise": 20}},
}


def clip(**data: object) -> motion.Clip:
    return motion.Clip("test", {"length": 1.0, **data}, LIBRARY)


class PoseTest(unittest.TestCase):
    def test_unsided_bone_sets_both_sides(self) -> None:
        pose = motion.resolve("stand", LIBRARY)
        self.assertEqual(pose["LeftUpperArm"], {"raise": -70, "forward": 5})
        self.assertEqual(pose["RightUpperArm"], {"raise": -70, "forward": 5})

    def test_base_is_merged_per_parameter(self) -> None:
        pose = motion.resolve("reach", LIBRARY)
        self.assertEqual(pose["LeftUpperArm"], {"raise": 20, "forward": 5})
        self.assertEqual(pose["RightUpperArm"]["raise"], -70)

    def test_inline_pose_with_base(self) -> None:
        pose = motion.resolve({"base": "stand", "Hips": {"lift": 0.1}}, LIBRARY)
        self.assertEqual(pose["Hips"], {"lift": 0.1})
        self.assertEqual(pose["LeftLowerArm"], {"bend": 15})

    def test_missing_parameter_lerps_from_rest(self) -> None:
        mid = motion.lerp_pose({"Head": {"bend": 10}}, {"Head": {"turn": 20}}, 0.5)
        self.assertEqual(mid["Head"], {"bend": 5.0, "turn": 10.0})


class EaseTest(unittest.TestCase):
    def test_every_ease_starts_at_zero_and_ends_at_one(self) -> None:
        for name in motion.EASES:
            self.assertAlmostEqual(motion.ease(name, 0.0), 0.0, places=3, msg=name)
            self.assertAlmostEqual(motion.ease(name, 1.0), 1.0, places=3, msg=name)

    def test_back_out_overshoots(self) -> None:
        self.assertGreater(max(motion.ease("back_out", i / 20) for i in range(21)), 1.05)

    def test_back_in_pulls_back_first(self) -> None:
        self.assertLess(min(motion.ease("back_in", i / 20) for i in range(21)), -0.05)

    def test_unknown_ease_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            motion.ease("wobbly", 0.5)


class ClipTest(unittest.TestCase):
    def test_keys_interpolate_with_the_arriving_ease(self) -> None:
        c = clip(keys=[{"t": 0, "pose": {"Hips": {"lift": 0}}}, {"t": 1, "pose": {"Hips": {"lift": 1}}, "ease": "linear"}])
        self.assertAlmostEqual(c.sample(15)["Hips"]["lift"], 0.5)
        self.assertEqual(c.frames, 31)

    def test_hold_jumps_at_its_key(self) -> None:
        c = clip(keys=[{"t": 0, "pose": {"Hips": {"lift": 0}}}, {"t": 1, "pose": {"Hips": {"lift": 1}}, "ease": "hold"}])
        self.assertEqual(c.sample(29)["Hips"]["lift"], 0.0)
        self.assertEqual(c.sample(30)["Hips"]["lift"], 1.0)

    def test_first_key_must_be_at_zero(self) -> None:
        with self.assertRaises(ValueError):
            clip(keys=[{"t": 0.2, "pose": "stand"}])

    def test_a_loop_closes_on_its_first_pose(self) -> None:
        c = clip(loop=True, keys=[{"t": 0, "pose": {"Hips": {"lift": 0}}}, {"t": 0.5, "pose": {"Hips": {"lift": 1}}}])
        self.assertEqual(c.frames, 30)
        self.assertAlmostEqual(c.sample(29)["Hips"]["lift"], c.sample(1)["Hips"]["lift"], places=6)

    def test_lag_samples_a_bone_late(self) -> None:
        keys = [{"t": 0, "pose": {"Head": {"bend": 0}}}, {"t": 1, "pose": {"Head": {"bend": 30}}, "ease": "linear"}]
        c = clip(keys=keys, lag={"Head": 0.1})
        self.assertAlmostEqual(c.sample(15)["Head"]["bend"], 12.0)

    def test_sided_lag_applies_to_both_hands(self) -> None:
        c = clip(keys=[{"t": 0, "pose": "stand"}], lag={"Hand": 0.05})
        self.assertEqual(set(c.lag), {"LeftHand", "RightHand"})

    def test_steps_hold_drawings_on_twos(self) -> None:
        keys = [{"t": 0, "pose": {"Hips": {"lift": 0}}}, {"t": 1, "pose": {"Hips": {"lift": 1}}, "ease": "linear"}]
        c = clip(keys=keys, step=[{"from": 0.0, "to": 1.0, "frames": 2}])
        self.assertEqual(c.sample(4)["Hips"]["lift"], c.sample(5)["Hips"]["lift"])
        self.assertNotEqual(c.sample(5)["Hips"]["lift"], c.sample(6)["Hips"]["lift"])

    def test_layers_add_motion_only_inside_their_window(self) -> None:
        layer = {"kind": "tremble", "from": 0.4, "to": 0.6, "amp": 3.0, "bones": ["Chest"]}
        c = clip(keys=[{"t": 0, "pose": {"Chest": {"bend": 0}}}], layers=[layer])
        self.assertEqual(c.sample(3)["Chest"]["bend"], 0.0)
        self.assertNotEqual(c.sample(15)["Chest"]["bend"], 0.0)

    def test_a_looping_wave_closes(self) -> None:
        c = clip(loop=True, keys=[{"t": 0, "pose": {"Hips": {"lift": 0}}}], layers=[{"kind": "bob", "period": 0.7}])
        self.assertAlmostEqual(c.sample(0)["Hips"]["lift"], c.sample(30)["Hips"]["lift"], places=6)


class PlantTest(unittest.TestCase):
    def test_feet_are_planted_by_default(self) -> None:
        c = clip(keys=[{"t": 0, "pose": "stand"}])
        self.assertEqual(c.sample(10)[motion.PLANT], {"LeftFoot": 1.0, "RightFoot": 1.0})

    def test_a_foot_leaves_the_ground_outside_its_windows(self) -> None:
        c = clip(keys=[{"t": 0, "pose": "stand"}], plant={"LeftFoot": [[0, 0.3], [0.7, 1.0]], "RightFoot": [[0, 1.0]]})
        self.assertEqual(c.sample(15)[motion.PLANT]["LeftFoot"], 0.0)
        self.assertEqual(c.sample(15)[motion.PLANT]["RightFoot"], 1.0)
        self.assertEqual(c.sample(3)[motion.PLANT]["LeftFoot"], 1.0)

    def test_planting_fades_at_a_window_edge(self) -> None:
        c = clip(keys=[{"t": 0, "pose": "stand"}], plant={"LeftFoot": [[0.5, 1.0]]}, plant_fade=0.2)
        self.assertAlmostEqual(c.sample(18)[motion.PLANT]["LeftFoot"], 0.5, places=5)

    def test_a_foot_the_clip_does_not_name_stays_planted(self) -> None:
        c = clip(keys=[{"t": 0, "pose": "stand"}], plant={"LeftFoot": [[0, 0.1]]})
        self.assertEqual(c.sample(15)[motion.PLANT]["RightFoot"], 1.0)


class ContentTest(unittest.TestCase):
    def test_every_clip_resolves_and_samples(self) -> None:
        library = motion.load_library()
        for clip_id in motion.clip_ids():
            c = motion.load_clip(clip_id, library)
            for frame in range(c.frames):
                c.sample(frame)
            release = c.data.get("events", {}).get("release")
            if release is not None:
                self.assertLessEqual(float(release), c.length, clip_id)


if __name__ == "__main__":
    unittest.main()
