"""ComfyUI as an engine for the performances (pipeline/music/README.md): the yue2_MusicGen workflow, as saved in the
ComfyUI editor (workflows/yue2_MusicGen.json), run through ComfyUI's HTTP API with a track's score in place of the
planner.

The saved graph has a planner (YuE2GenerateABC writes a score from a style and lyrics) feeding the music node. This does
not use it: the composed score is the music node's `abc` input, so a take plays the score it was given, as the native
engine does. Everything else is the workflow's own: its checkpoint, sampler, decoder and output node.

The nodes are found by type, so a re-saved workflow whose ids moved still converts; one that lost a node, or has two,
is refused with a message that names it. The seeds mean what they mean in yue2.cpp: the music node's seed draws the
semantic tokens (lm_seed, `YuE2GenerateMusic.seed` in ComfyUI's source, comfy_extras/nodes_yue2.py), and the sampler's
seed draws the acoustic noise (seed). Its steps are the sampler's steps, and its duration the native engine's.
"""

from __future__ import annotations

import json
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import library


class ComfyError(RuntimeError):
    """ComfyUI cannot do the job: it is down, refused the graph, lost it, or failed while making it."""


class WorkflowError(ValueError):
    """The saved workflow does not have the nodes the pipeline needs."""


# The widget values of each node type the pipeline uses, in the order the editor stores them (its widgets_values).
LAYOUT = {
    "CheckpointLoaderSimple": ["ckpt_name"],
    "YuE2GenerateMusic": ["style", "lyrics", "abc", "seed", "control", "mode", "max_duration", "temperature", "top_p",
                          "top_k", "repetition_penalty", "cfg_scale"],
    "EmptyYuE2LatentAudio": ["seconds", "batch_size"],
    "KSampler": ["seed", "control", "steps", "cfg", "sampler_name", "scheduler", "denoise"],
    "VAEDecodeAudioTiled": ["tile_size", "overlap"],
    "SaveAudioAdvanced": ["filename_prefix", "format"],
}
NEEDED = list(LAYOUT)


class Workflow:
    """The saved workflow, its nodes found by type and their widget values read."""

    def __init__(self, path: Path | None = None):
        self.path = path or library.resolve(library.config()["workflow"])
        if not self.path.exists():
            raise WorkflowError(f"no ComfyUI workflow at {self.path}")
        graph = json.loads(self.path.read_text())
        # mode 0 is active; 2 (muted) and 4 (bypassed) nodes are not part of a run.
        live = [node for node in graph.get("nodes", []) if node.get("mode", 0) == 0]
        self.ids: dict[str, str] = {}
        self.widgets: dict[str, dict] = {}
        for kind in NEEDED:
            found = [node for node in live if node.get("type") == kind]
            if len(found) != 1:
                raise WorkflowError(f"{self.path.name}: expected one active {kind} node, found {len(found)}")
            node = found[0]
            self.ids[kind] = str(node["id"])
            values = node.get("widgets_values") or []
            names = LAYOUT[kind]
            if len(values) < len(names):
                raise WorkflowError(f"{self.path.name}: {kind} has {len(values)} widget values, expected {len(names)}")
            self.widgets[kind] = dict(zip(names, values))
        self.output_id = self.ids["SaveAudioAdvanced"]

    def prompt(self, style: str, lyrics: str, abc: str, lm_seed: int, seed: int, steps: int, max_duration: float,
               cfg_scale: float, sampling: dict) -> dict:
        """The API graph that performs `abc` (a canonical score) in `style`. `sampling` holds the music node's
        temperature, top_p, top_k and repetition_penalty; `cfg_scale` is the music node's guidance (1.0 is none)."""
        i = self.ids
        ckpt, music = i["CheckpointLoaderSimple"], i["YuE2GenerateMusic"]
        latent, sampler = i["EmptyYuE2LatentAudio"], i["KSampler"]
        decode, save = i["VAEDecodeAudioTiled"], self.output_id
        sample, tiles = self.widgets["KSampler"], self.widgets["VAEDecodeAudioTiled"]
        return {
            ckpt: {"class_type": "CheckpointLoaderSimple",
                   "inputs": {"ckpt_name": self.widgets["CheckpointLoaderSimple"]["ckpt_name"]}},
            music: {"class_type": "YuE2GenerateMusic", "inputs": {
                "clip": [ckpt, 1], "style": style, "lyrics": lyrics, "abc": abc, "seed": lm_seed,
                "mode": self.widgets["YuE2GenerateMusic"]["mode"], "max_duration": max_duration,
                "temperature": sampling["temperature"], "top_p": sampling["top_p"], "top_k": sampling["top_k"],
                "repetition_penalty": sampling["repetition_penalty"], "cfg_scale": cfg_scale}},
            latent: {"class_type": "EmptyYuE2LatentAudio", "inputs": {
                "seconds": [music, 1], "batch_size": self.widgets["EmptyYuE2LatentAudio"]["batch_size"]}},
            sampler: {"class_type": "KSampler", "inputs": {
                "model": [ckpt, 0], "seed": seed, "steps": steps, "cfg": sample["cfg"],
                "sampler_name": sample["sampler_name"], "scheduler": sample["scheduler"],
                "positive": [music, 0], "negative": [music, 0], "latent_image": [latent, 0],
                "denoise": sample["denoise"]}},
            decode: {"class_type": "VAEDecodeAudioTiled", "inputs": {
                "samples": [sampler, 0], "vae": [ckpt, 2], "tile_size": tiles["tile_size"],
                "overlap": tiles["overlap"]}},
            save: {"class_type": "SaveAudioAdvanced", "inputs": {
                "audio": [decode, 0], "filename_prefix": self.widgets["SaveAudioAdvanced"]["filename_prefix"],
                "format": self.widgets["SaveAudioAdvanced"]["format"]}},
        }


# --- the HTTP side -------------------------------------------------------------------------------------------------

def url(path: str) -> str:
    return library.config()["comfy_url"].rstrip("/") + path


def get_json(path: str, timeout: float = 30) -> dict:
    try:
        with urllib.request.urlopen(url(path), timeout=timeout) as response:
            return json.load(response)
    except urllib.error.URLError as error:
        raise ComfyError(f"ComfyUI is not reachable at {library.config()['comfy_url']} ({error.reason})") from error


def post_json(path: str, data: dict) -> dict:
    request = urllib.request.Request(url(path), json.dumps(data).encode(), {"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise ComfyError(f"ComfyUI refused the graph: {error.read().decode(errors='replace')[:1200]}") from error
    except urllib.error.URLError as error:
        raise ComfyError(f"ComfyUI is not reachable at {library.config()['comfy_url']} ({error.reason})") from error


def is_up() -> bool:
    try:
        urllib.request.urlopen(url("/system_stats"), timeout=2).read()
        return True
    except OSError:
        return False


def vram_mib() -> int:
    """The NVIDIA card's memory in use, in MiB, or -1 when nvidia-smi cannot say."""
    try:
        out = subprocess.check_output(["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"])
        return int(out.split()[0])
    except (OSError, subprocess.CalledProcessError, ValueError, IndexError):
        return -1


def object_info() -> dict:
    return get_json("/object_info", timeout=60)


def check_nodes(prompt: dict) -> list[str]:
    """Problems between a graph and the ComfyUI running now: a node it does not have, an input it does not take, or a
    required input it leaves out. Empty when the graph would run."""
    info = object_info()
    problems = []
    for node_id, node in prompt.items():
        spec = info.get(node["class_type"])
        if spec is None:
            problems.append(f"node {node_id}: ComfyUI has no {node['class_type']} (is its custom node installed?)")
            continue
        required = spec["input"].get("required", {})
        accepted = {**required, **spec["input"].get("optional", {})}
        for name in node["inputs"]:
            if name not in accepted:
                problems.append(f"node {node_id} ({node['class_type']}): ComfyUI has no input {name!r}")
        for name in required:
            if name not in node["inputs"]:
                problems.append(f"node {node_id} ({node['class_type']}): required input {name!r} is not set")
    return problems


def submit(prompt: dict) -> str:
    return post_json("/prompt", {"prompt": prompt})["prompt_id"]


def queued(prompt_id: str) -> bool:
    queue = get_json("/queue")
    return any(item[1] == prompt_id for item in queue.get("queue_running", []) + queue.get("queue_pending", []))


def wait(prompt_id: str, timeout: float = 900.0, poll: float = 2.0) -> dict:
    """Block until the job finishes; returns its history entry. A failed job, a job ComfyUI no longer has (it was
    restarted), and a job that takes longer than `timeout` seconds are ComfyErrors that say which."""
    started = time.monotonic()
    lost = 0
    while True:
        history = get_json("/history/" + prompt_id)
        if prompt_id in history:
            entry = history[prompt_id]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                raise ComfyError(f"the job failed: {json.dumps(status)[:1500]}")
            if status.get("completed"):
                return entry
            lost = 0
        else:
            lost = 0 if queued(prompt_id) else lost + 1
            if lost >= 5:
                raise ComfyError("ComfyUI no longer has the job (it may have been restarted); run the take again")
        if time.monotonic() - started > timeout:
            raise ComfyError(f"no result after {timeout:.0f} s; see the job in ComfyUI's queue")
        time.sleep(poll)


def fetch_audio(entry: dict, output_id: str, destination: Path) -> None:
    """Download the saved audio of a finished job (over HTTP, so ComfyUI's output folder can be anywhere) and write it
    to `destination` as 32-bit float WAV, the same format the native engine writes."""
    outputs = entry.get("outputs", {}).get(output_id, {}).get("audio")
    if not outputs:
        raise ComfyError(f"the job made no audio at node {output_id}")
    audio = outputs[0]
    query = urllib.parse.urlencode({"filename": audio["filename"], "subfolder": audio.get("subfolder", ""),
                                    "type": audio.get("type", "output")})
    destination.parent.mkdir(parents=True, exist_ok=True)
    download = destination.parent / (destination.stem + ".download" + Path(audio["filename"]).suffix)
    try:
        with urllib.request.urlopen(url("/view?" + query), timeout=300) as response, download.open("wb") as out:
            while chunk := response.read(1 << 20):
                out.write(chunk)
        subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-v", "error", "-y", "-i", str(download), "-c:a",
                        "pcm_f32le", str(destination)], check=True)
    finally:
        download.unlink(missing_ok=True)
