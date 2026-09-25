"""A small ComfyUI client: load a graph from `workflows/`, set its inputs by node title, run it, fetch the outputs.

Graphs are addressed by `_meta.title` ("rw:sampler"), never by node id, so a graph can be re-saved from the ComfyUI
editor with its nodes renumbered and the driver still finds them. Plain `urllib`, so it runs in the pipeline's own
environment (numpy and Pillow only).
"""

from __future__ import annotations

import io
import json
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent


class Graph:
    def __init__(self, name: str) -> None:
        self.nodes: dict[str, dict] = json.loads((HERE / "workflows" / f"{name}.json").read_text())

    def id_of(self, title: str) -> str:
        for node_id, node in self.nodes.items():
            if node.get("_meta", {}).get("title") == title:
                return node_id
        raise KeyError(f"no node titled {title!r}")

    def set(self, title: str, **inputs: object) -> None:
        self.nodes[self.id_of(title)]["inputs"].update(inputs)

    def link(self, title: str, name: str, source_title: str, output: int = 0) -> None:
        self.set(title, **{name: [self.id_of(source_title), output]})

    def unset(self, title: str, name: str) -> None:
        self.nodes[self.id_of(title)]["inputs"].pop(name, None)

    def remove(self, *titles: str) -> None:
        for title in titles:
            del self.nodes[self.id_of(title)]

    def api(self) -> dict:
        return {node_id: {k: v for k, v in node.items() if k != "_meta"} for node_id, node in self.nodes.items()}


def _get(url: str, timeout: float = 30) -> bytes:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read()


def _post_json(url: str, payload: dict, timeout: float = 60) -> dict:
    request = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"ComfyUI refused the graph: {error.read().decode()[:2000]}") from error


class Comfy:
    def __init__(self, url: str) -> None:
        self.url = url.rstrip("/")
        self.client = str(uuid.uuid4())

    def alive(self) -> bool:
        try:
            _get(f"{self.url}/system_stats", 3)
            return True
        except (urllib.error.URLError, OSError):
            return False

    def models(self, folder: str) -> list[str]:
        try:
            return json.loads(_get(f"{self.url}/models/{folder}", 10))
        except urllib.error.URLError:
            return []

    def has_node(self, name: str) -> bool:
        return json.loads(_get(f"{self.url}/object_info/{name}", 10)) != {}

    def upload(self, image: Image.Image, name: str) -> str:
        """Upload into ComfyUI's input folder under `rootward/`; returns the name LoadImage takes."""
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        boundary = uuid.uuid4().hex
        parts = []
        for key, value in (("subfolder", "rootward"), ("overwrite", "true")):
            parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode())
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{name}"\r\n'
            f"Content-Type: image/png\r\n\r\n".encode()
            + buffer.getvalue()
            + b"\r\n"
        )
        parts.append(f"--{boundary}--\r\n".encode())
        request = urllib.request.Request(
            f"{self.url}/upload/image",
            data=b"".join(parts),
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            body = json.loads(response.read())
        return f"{body['subfolder']}/{body['name']}" if body.get("subfolder") else body["name"]

    def run(self, graph: Graph, timeout: float = 3600) -> dict[str, list[Image.Image]]:
        """Queue a graph and wait for it; returns every saved image keyed by its SaveImage node's title."""
        prompt_id = _post_json(f"{self.url}/prompt", {"prompt": graph.api(), "client_id": self.client})["prompt_id"]
        started = time.monotonic()
        while True:
            history = json.loads(_get(f"{self.url}/history/{prompt_id}")).get(prompt_id)
            if history is not None:
                status = history.get("status", {})
                if status.get("status_str") == "error":
                    messages = [m for m in status.get("messages", []) if m[0] == "execution_error"]
                    raise RuntimeError(f"ComfyUI failed: {json.dumps(messages)[:2000]}")
                if status.get("completed"):
                    break
            if time.monotonic() - started > timeout:
                raise TimeoutError(f"ComfyUI took longer than {timeout:.0f}s on {prompt_id}")
            time.sleep(2)
        titles = {node_id: node.get("_meta", {}).get("title", node_id) for node_id, node in graph.nodes.items()}
        out: dict[str, list[Image.Image]] = {}
        for node_id, output in history.get("outputs", {}).items():
            for item in output.get("images", []):
                query = urllib.parse.urlencode(
                    {"filename": item["filename"], "subfolder": item["subfolder"], "type": item["type"]}
                )
                data = _get(f"{self.url}/view?{query}", 120)
                out.setdefault(titles.get(node_id, node_id), []).append(Image.open(io.BytesIO(data)).copy())
        return out
