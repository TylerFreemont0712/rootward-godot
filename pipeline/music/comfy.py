"""The yue2_MusicGen workflow, run through ComfyUI's HTTP API.

The workflow file (workflows/yue2_MusicGen.json, exactly as saved from the ComfyUI editor) is converted to API format
here, with its own widget values for everything but five inputs: the style (nodes 12 and 13 feed it to both YuE2
nodes), the lyrics, the music node's seed and `max_duration`, and the planner node's seed. Nothing else about the graph
is changed, so a take is the workflow's result, not ours.

    planner:  15 checkpoint -> 23 YuE2GenerateABC -> 14 PreviewAny   (style + lyrics + planner seed -> an ABC score)
    music:    15 -> 22 YuE2GenerateMusic (style, lyrics, the ABC, seed, max_duration) -> 8 KSampler -> 17 tiled VAE -> 10 save

The ids below are found by node type, so a re-saved workflow whose ids shifted still converts; one that lost a node,
or has two of one, is refused with a message.
"""

from __future__ import annotations

import json
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import manifest

# widgets_values layouts of the node types we convert (the order the editor stores them in).
LAYOUT = {
    "YuE2GenerateABC": ["style", "lyrics", "seed", "control", "mode", "max_abc_tokens", "temperature", "top_p", "top_k",
                        "repetition_penalty", "penalty_window"],
    "YuE2GenerateMusic": ["style", "lyrics", "abc", "seed", "control", "mode", "max_duration", "temperature", "top_p",
                          "top_k", "repetition_penalty", "cfg_scale"],
    "KSampler": ["seed", "control", "steps", "cfg", "sampler_name", "scheduler", "denoise"],
    "EmptyYuE2LatentAudio": ["seconds", "batch_size"],
    "VAEDecodeAudioTiled": ["tile_size", "overlap"],
    "SaveAudioAdvanced": ["filename_prefix", "format"],
    "CheckpointLoaderSimple": ["ckpt_name"],
}
NEEDED = ["CheckpointLoaderSimple", "YuE2GenerateABC", "PreviewAny", "YuE2GenerateMusic", "EmptyYuE2LatentAudio", "KSampler",
          "VAEDecodeAudioTiled", "SaveAudioAdvanced"]


class Workflow:
    def __init__(self, path: Path | None = None):
        path = path or manifest._resolve(manifest.config()["workflow"])
        self.path = path
        graph = json.loads(path.read_text())
        # mode 0 is active; 2 (muted) and 4 (bypassed) nodes are not part of the run (the SheetSage cover branch).
        live = [n for n in graph["nodes"] if n.get("mode", 0) == 0]
        self.ids: dict[str, str] = {}
        self.widgets: dict[str, dict] = {}
        for kind in NEEDED:
            found = [n for n in live if n["type"] == kind]
            if len(found) != 1:
                raise SystemExit(f"{path.name}: expected one active {kind} node, found {len(found)}")
            node = found[0]
            self.ids[kind] = str(node["id"])
            names = LAYOUT.get(kind)
            if names:
                values = node.get("widgets_values") or []
                if len(values) < len(names):
                    raise SystemExit(f"{path.name}: {kind} has {len(values)} widget values, expected {len(names)}")
                self.widgets[kind] = dict(zip(names, values))
        self.output_id = self.ids["SaveAudioAdvanced"]
        self.abc_id = self.ids["PreviewAny"]

    def _planner(self, style: str, lyrics: str, abc_seed: int) -> dict:
        i, w = self.ids, self.widgets["YuE2GenerateABC"]
        ckpt = i["CheckpointLoaderSimple"]
        return {
            ckpt: {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": self.widgets["CheckpointLoaderSimple"]["ckpt_name"]}},
            i["YuE2GenerateABC"]: {"class_type": "YuE2GenerateABC", "inputs": {
                "clip": [ckpt, 1], "style": style, "lyrics": lyrics, "seed": abc_seed, "mode": w["mode"],
                "max_abc_tokens": w["max_abc_tokens"], "temperature": w["temperature"], "top_p": w["top_p"],
                "top_k": w["top_k"], "repetition_penalty": w["repetition_penalty"], "penalty_window": w["penalty_window"]}},
            self.abc_id: {"class_type": "PreviewAny", "inputs": {"source": [i["YuE2GenerateABC"], 0]}},
        }

    def planner_api(self, style: str, lyrics: str, abc_seed: int) -> dict:
        """Only the planner (no audio): what `plan` rolls to look at a score before spending a GPU run on it."""
        return self._planner(style, lyrics, abc_seed)

    def api(self, style: str, lyrics: str, seed: int, max_duration: float, abc_seed: int) -> dict:
        i = self.ids
        ckpt, music = i["CheckpointLoaderSimple"], self.widgets["YuE2GenerateMusic"]
        sampler, decode = self.widgets["KSampler"], self.widgets["VAEDecodeAudioTiled"]
        save, latent = self.widgets["SaveAudioAdvanced"], self.widgets["EmptyYuE2LatentAudio"]
        prompt = self._planner(style, lyrics, abc_seed)
        prompt[i["YuE2GenerateMusic"]] = {"class_type": "YuE2GenerateMusic", "inputs": {
            "clip": [ckpt, 1], "style": style, "lyrics": lyrics, "abc": [self.abc_id, 0], "seed": seed, "mode": music["mode"],
            "max_duration": max_duration, "temperature": music["temperature"], "top_p": music["top_p"],
            "top_k": music["top_k"], "repetition_penalty": music["repetition_penalty"], "cfg_scale": music["cfg_scale"]}}
        prompt[i["EmptyYuE2LatentAudio"]] = {"class_type": "EmptyYuE2LatentAudio", "inputs": {
            "seconds": [i["YuE2GenerateMusic"], 1], "batch_size": latent["batch_size"]}}
        prompt[i["KSampler"]] = {"class_type": "KSampler", "inputs": {
            "model": [ckpt, 0], "seed": sampler["seed"], "steps": sampler["steps"], "cfg": sampler["cfg"],
            "sampler_name": sampler["sampler_name"], "scheduler": sampler["scheduler"],
            "positive": [i["YuE2GenerateMusic"], 0], "negative": [i["YuE2GenerateMusic"], 0],
            "latent_image": [i["EmptyYuE2LatentAudio"], 0], "denoise": sampler["denoise"]}}
        prompt[i["VAEDecodeAudioTiled"]] = {"class_type": "VAEDecodeAudioTiled", "inputs": {
            "samples": [i["KSampler"], 0], "vae": [ckpt, 2], "tile_size": decode["tile_size"], "overlap": decode["overlap"]}}
        prompt[self.output_id] = {"class_type": "SaveAudioAdvanced", "inputs": {
            "audio": [i["VAEDecodeAudioTiled"], 0], "filename_prefix": save["filename_prefix"], "format": save["format"]}}
        return prompt


# --- the HTTP side -------------------------------------------------------------------------------------------------

def url(path: str) -> str:
    return manifest.config()["comfy_url"].rstrip("/") + path


def get_json(path: str) -> dict:
    with urllib.request.urlopen(url(path), timeout=30) as response:
        return json.load(response)


def post_json(path: str, data: dict) -> dict:
    request = urllib.request.Request(url(path), json.dumps(data).encode(), {"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"ComfyUI refused the job: {error.read().decode(errors='replace')[:1200]}") from error


def is_up() -> bool:
    try:
        urllib.request.urlopen(url("/system_stats"), timeout=2).read()
        return True
    except OSError:
        return False


def vram_mib() -> int:
    try:
        out = subprocess.check_output(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"])
        return int(out.split()[0])
    except (OSError, subprocess.CalledProcessError, ValueError):
        return -1


def submit(prompt: dict) -> str:
    return post_json("/prompt", {"prompt": prompt})["prompt_id"]


def wait(prompt_id: str, poll: float = 3.0, track_vram: bool = True) -> tuple[dict, int]:
    """Block until the job ends. Returns (its history entry, peak VRAM in MiB seen). Raises on a failed job."""
    peak = 0
    while True:
        if track_vram:
            peak = max(peak, vram_mib())
        history = get_json("/history/" + prompt_id)
        if prompt_id in history:
            entry = history[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise RuntimeError(f"the job failed: {json.dumps(status)[:1500]}")
            if status.get("completed"):
                return entry, peak
        time.sleep(poll)


def known(prompt_id: str) -> bool:
    """Whether ComfyUI still has the job (running, queued or finished); false after a server restart."""
    if prompt_id in get_json("/history/" + prompt_id):
        return True
    queue = get_json("/queue")
    return any(item[1] == prompt_id for item in queue.get("queue_running", []) + queue.get("queue_pending", []))


def download(entry: dict, node_id: str, destination: Path) -> None:
    """Fetch the saved audio of a finished job over HTTP (so ComfyUI's output folder can be anywhere) as flac."""
    audio = entry["outputs"][node_id]["audio"][0]
    query = urllib.parse.urlencode({"filename": audio["filename"], "subfolder": audio.get("subfolder", ""),
                                    "type": audio.get("type", "output")})
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(".part")
    with urllib.request.urlopen(url("/view?" + query), timeout=120) as response, partial.open("wb") as out:
        while chunk := response.read(1 << 20):
            out.write(chunk)
    if audio["filename"].lower().endswith(".flac"):
        partial.replace(destination)
    else:  # the workflow's save format was changed: keep the pipeline's takes flac
        subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-y", "-i", str(partial), "-f", "flac",
                        str(destination)], check=True)
        partial.unlink()


def abc_of(entry: dict, abc_id: str) -> str | None:
    text = entry.get("outputs", {}).get(abc_id, {}).get("text")
    return text[0] if isinstance(text, list) and text else text


def plan_abc(workflow: Workflow, style: str, lyrics: str, abc_seed: int) -> str:
    """Run only the planner (nodes checkpoint -> ABC -> preview) and return its score."""
    entry, _ = wait(submit(workflow.planner_api(style, lyrics, abc_seed)), poll=1.0, track_vram=False)
    text = abc_of(entry, workflow.abc_id)
    if not text:
        raise RuntimeError("the planner returned no score")
    return text


def check_nodes(workflow: Workflow) -> list[str]:
    """Problems between the converted graph and what this ComfyUI actually offers (a node renamed, an input gone)."""
    info = get_json("/object_info")
    problems = []
    for node_id, node in workflow.api("s", "l", 1, 10, 1).items():
        spec = info.get(node["class_type"])
        if spec is None:
            problems.append(f"node {node_id}: ComfyUI has no {node['class_type']}")
            continue
        accepted = {**spec["input"].get("required", {}), **spec["input"].get("optional", {})}
        for name in node["inputs"]:
            if name not in accepted:
                problems.append(f"node {node_id} ({node['class_type']}): ComfyUI has no input {name!r}")
        for name in spec["input"].get("required", {}):
            if name not in node["inputs"]:
                problems.append(f"node {node_id} ({node['class_type']}): required input {name!r} is not set")
    return problems
