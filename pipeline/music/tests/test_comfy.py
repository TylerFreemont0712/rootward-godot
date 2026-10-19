"""The ComfyUI engine: the saved workflow converted to the graph that performs a score, checked offline; and the errors
a missing node or a stopped ComfyUI give."""

import json
import os
import tempfile
import unittest
from pathlib import Path

import helpers  # noqa: F401
import comfy
import library

SAVED = library.MUSIC / "workflows" / "yue2_MusicGen.json"
SCORE = "X:1\nT:\nM:4/4\nL:1/16\nQ:1/4=120\nK:Dm\n% verse\nV: Vocal\n\"Dm\"z16|\nV: Ins\nB4 d4 f4 a4|\n"
SAMPLING = {"temperature": 1.0, "top_p": 0.95, "top_k": 100, "repetition_penalty": 1.2}


def prompt(workflow=None, **overrides):
    workflow = workflow or comfy.Workflow()
    args = dict(style="a style", lyrics="", abc=SCORE, lm_seed=1000, seed=1100, steps=32, max_duration=30.0,
                cfg_scale=1.0, sampling=SAMPLING)
    args.update(overrides)
    return workflow.prompt(**args)


class Conversion(unittest.TestCase):
    def test_the_saved_workflow_has_each_node_once(self):
        workflow = comfy.Workflow(SAVED)
        self.assertEqual(workflow.ids, {"CheckpointLoaderSimple": "15", "YuE2GenerateMusic": "22",
                                        "EmptyYuE2LatentAudio": "5", "KSampler": "8", "VAEDecodeAudioTiled": "17",
                                        "SaveAudioAdvanced": "10"})
        self.assertEqual(workflow.output_id, "10")

    def test_the_graph_has_no_planner_and_plays_the_given_score(self):
        graph = prompt()
        types = {node["class_type"] for node in graph.values()}
        self.assertNotIn("YuE2GenerateABC", types)
        self.assertNotIn("PreviewAny", types)
        self.assertEqual(graph["22"]["inputs"]["abc"], SCORE)

    def test_the_seeds_are_the_native_engines(self):
        graph = prompt()
        self.assertEqual(graph["22"]["inputs"]["seed"], 1000, "the semantic tokens draw from lm_seed")
        self.assertEqual(graph["8"]["inputs"]["seed"], 1100, "the acoustic noise draws from seed")
        self.assertEqual(graph["8"]["inputs"]["steps"], 32)

    def test_the_duration_and_guidance_reach_the_music_node(self):
        graph = prompt(max_duration=76.7, cfg_scale=1.05)
        self.assertEqual(graph["22"]["inputs"]["max_duration"], 76.7)
        self.assertEqual(graph["22"]["inputs"]["cfg_scale"], 1.05)
        self.assertEqual(graph["5"]["inputs"]["seconds"], ["22", 1], "the latent takes the music node's seconds")

    def test_every_link_points_at_a_node_of_the_graph(self):
        graph = prompt()
        for node_id, node in graph.items():
            for name, value in node["inputs"].items():
                if isinstance(value, list):
                    self.assertIn(value[0], graph, f"node {node_id} input {name} links to a missing node")

    def test_the_output_is_saved_audio(self):
        graph = prompt()
        self.assertEqual(graph["10"]["class_type"], "SaveAudioAdvanced")
        self.assertEqual(graph["17"]["class_type"], "VAEDecodeAudioTiled")
        self.assertEqual(graph["17"]["inputs"]["vae"], ["15", 2])


class SavedWorkflowProblems(unittest.TestCase):
    def workflow_without(self, kind=None, duplicate=None):
        graph = json.loads(SAVED.read_text())
        if kind:
            graph["nodes"] = [node for node in graph["nodes"] if node["type"] != kind]
        if duplicate:
            twin = next(node for node in graph["nodes"] if node["type"] == duplicate).copy()
            twin["id"] = 999
            graph["nodes"].append(twin)
        handle, path = tempfile.mkstemp(suffix=".json")
        with os.fdopen(handle, "w") as out:
            json.dump(graph, out)
        self.addCleanup(os.unlink, path)
        return Path(path)

    def test_a_missing_node_is_refused_by_name(self):
        with self.assertRaisesRegex(comfy.WorkflowError, "expected one active KSampler node, found 0"):
            comfy.Workflow(self.workflow_without(kind="KSampler"))

    def test_a_doubled_node_is_refused_by_name(self):
        with self.assertRaisesRegex(comfy.WorkflowError, "expected one active KSampler node, found 2"):
            comfy.Workflow(self.workflow_without(duplicate="KSampler"))

    def test_a_missing_file_is_refused(self):
        with self.assertRaisesRegex(comfy.WorkflowError, "no ComfyUI workflow"):
            comfy.Workflow(Path("/nonexistent/workflow.json"))


class NodesOnTheServer(unittest.TestCase):
    """check_nodes against a ComfyUI description given here, so it runs without ComfyUI."""

    def describe(self, graph, drop=None):
        info = {}
        for node in graph.values():
            spec = {"required": {name: ["STRING"] for name in node["inputs"]}, "optional": {}}
            info[node["class_type"]] = {"input": spec}
        if drop:
            info[drop[0]]["input"]["required"].pop(drop[1], None)
        return info

    def test_a_graph_the_server_describes_passes(self):
        graph = prompt()
        original = comfy.object_info
        comfy.object_info = lambda: self.describe(graph)
        try:
            self.assertEqual(comfy.check_nodes(graph), [])
        finally:
            comfy.object_info = original

    def test_an_input_the_server_does_not_take_is_reported(self):
        graph = prompt()
        info = self.describe(graph)
        info["KSampler"]["input"]["required"].pop("denoise")
        original = comfy.object_info
        comfy.object_info = lambda: info
        try:
            problems = comfy.check_nodes(graph)
        finally:
            comfy.object_info = original
        self.assertTrue(any("KSampler" in p and "'denoise'" in p for p in problems), problems)

    def test_a_node_the_server_lacks_is_reported(self):
        graph = prompt()
        info = self.describe(graph)
        del info["SaveAudioAdvanced"]
        original = comfy.object_info
        comfy.object_info = lambda: info
        try:
            problems = comfy.check_nodes(graph)
        finally:
            comfy.object_info = original
        self.assertTrue(any("ComfyUI has no SaveAudioAdvanced" in p for p in problems), problems)


class ComfyDown(unittest.TestCase):
    def setUp(self):
        self.old = os.environ.get("ROOTWARD_COMFY_URL")
        os.environ["ROOTWARD_COMFY_URL"] = "http://127.0.0.1:9"  # the discard port: nothing listens there

    def tearDown(self):
        if self.old is None:
            os.environ.pop("ROOTWARD_COMFY_URL", None)
        else:
            os.environ["ROOTWARD_COMFY_URL"] = self.old

    def test_a_stopped_comfyui_is_not_up(self):
        self.assertFalse(comfy.is_up())

    def test_a_stopped_comfyui_says_where_it_should_be(self):
        with self.assertRaisesRegex(comfy.ComfyError, "ComfyUI is not reachable at http://127.0.0.1:9"):
            comfy.get_json("/system_stats", timeout=2)


if __name__ == "__main__":
    unittest.main()
