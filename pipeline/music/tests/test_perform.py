"""The requests the engines are given, and the take each makes: the native request keeps the digest its takes already
carry; the ComfyUI request is named apart from it."""

import json
import unittest
from pathlib import Path

import helpers  # noqa: F401
import library
import notation
import perform

FIXTURES = Path(__file__).resolve().parent / "fixtures"
BRIEF = json.loads((FIXTURES / "rest_brief.json").read_text())
SCORE = (FIXTURES / "rest_score.abc").read_text()


class NativeRequest(unittest.TestCase):
    def test_the_native_take_keeps_its_name(self):
        """The take the cache already holds for rest (seeds 1001 and 1101) is still the take this request makes."""
        request = perform.yue2_request(BRIEF, SCORE, 1001, 1101, 32)
        self.assertEqual(library.take_name("native", 1001, 1101, 32, request), "yue2-1001-1101-s32-44ef18")

    def test_the_duration_is_the_score_and_a_tail(self):
        self.assertEqual(perform.duration_of(SCORE, None), 76.7)

    def test_a_cap_shortens_the_take_and_changes_its_name(self):
        capped = perform.yue2_request(BRIEF, SCORE, 1001, 1101, 32, cap=30)
        self.assertEqual(capped["duration"], 30)
        self.assertNotEqual(library.take_name("native", 1001, 1101, 32, capped),
                            "yue2-1001-1101-s32-44ef18")

    def test_the_brief_can_change_the_semantic_sampling(self):
        brief = {**BRIEF, "yue2": {"semantic_sampling": {"temperature": 0.8}}}
        request = perform.yue2_request(brief, SCORE, 1, 2, 32)
        self.assertEqual(request["semantic_sampling"]["temperature"], 0.8)
        self.assertEqual(request["semantic_sampling"]["top_k"], 100)


class ComfyRequest(unittest.TestCase):
    def setUp(self):
        import comfy
        self.workflow = comfy.Workflow()

    def test_the_comfy_take_is_named_apart_and_carries_its_prompt(self):
        request = perform.comfy_request(self.workflow, BRIEF, SCORE, 1001, 1101, 32)
        name = library.take_name("comfy", 1001, 1101, 32, request)
        self.assertTrue(name.startswith("yue2-comfy-1001-1101-s32-"), name)
        self.assertEqual(request["prompt"]["22"]["inputs"]["abc"], notation.canonical(SCORE))
        self.assertNotEqual(library.digest(request), library.digest(perform.yue2_request(BRIEF, SCORE, 1001, 1101, 32)))

    def test_guidance_maps_the_native_default_to_the_workflow_value(self):
        native_default = perform.comfy_request(self.workflow, {**BRIEF, "yue2": {"cfg_scale": -1.0}}, SCORE, 1, 2, 32)
        explicit = perform.comfy_request(self.workflow, {**BRIEF, "yue2": {"cfg_scale": 1.05}}, SCORE, 1, 2, 32)
        self.assertEqual(native_default["cfg_scale"], 1.0)
        self.assertEqual(explicit["cfg_scale"], 1.05)

    def test_the_comfy_request_is_the_same_for_the_same_inputs(self):
        first = perform.comfy_request(self.workflow, BRIEF, SCORE, 5, 105, 32)
        second = perform.comfy_request(self.workflow, BRIEF, SCORE, 5, 105, 32)
        self.assertEqual(library.digest(first), library.digest(second))


if __name__ == "__main__":
    unittest.main()
