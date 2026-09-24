#!/usr/bin/env python3
"""Optional CLAP similarity screen for generated takes; never a substitute for listening.

Downloads laion/clap-htsat-unfused on first use (transformers + torch required).
Reports agreement with the requested sound and distractors; does not change picks or assets.
Use --only with the same comma-separated IDs as generate.py.
"""

import argparse
import json
from pathlib import Path

import torch
from huggingface_hub import hf_hub_download
from transformers import ClapConfig, ClapModel, ClapProcessor

from generate import CACHE_DIR, DEFAULT_MANIFEST, SAMPLE_RATE, decode, resolve, selected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only")
    parser.add_argument("--prepare", action="store_true", help="download the scorer without evaluating audio")
    args = parser.parse_args()
    torch.set_num_threads(4)
    model_id = "laion/clap-htsat-unfused"
    cache = str(CACHE_DIR / "models")
    processor = ClapProcessor.from_pretrained(model_id, cache_dir=cache)
    config = ClapConfig.from_pretrained(model_id, cache_dir=cache)
    # The upstream safetensors conversion is on this revision, not main. Pin it for offline reruns.
    weights = hf_hub_download(model_id, "model.safetensors", revision="79b58ed25fc00386262a2bea4b19fd21dc4310a0", cache_dir=cache)
    model = ClapModel.from_pretrained(Path(weights).parent, config=config, use_safetensors=True).eval()
    if args.prepare:
        print("CLAP scorer ready")
        return
    manifest = json.loads(DEFAULT_MANIFEST.read_text())
    distractors = [
        "A person speaking words.", "A person singing.", "A rhythmic musical tune with instruments.",
        "An electronic computer beep or alarm.", "A harsh distorted buzzing noise.",
    ]
    report = {}
    for asset in selected(manifest["assets"], args.only):
        if asset["style"] != "designed":
            continue
        job = resolve(asset, manifest)
        # Victory/defeat are musical stingers: instruments are a match, not a failure mode.
        unwanted = [d for d in distractors if not (job["id"].startswith("cue-") and "musical tune" in d)]
        texts = [job["tags"], *unwanted, "A continuous robotic humming or droning synthesizer."]
        takes = []
        for index in range(job["candidates"]):
            path = CACHE_DIR / job["id"] / f"candidate_{index}.ogg"
            if not path.exists():
                continue
            audio = decode(path).mean(axis=1)
            inputs = processor(text=texts, audio=audio, sampling_rate=SAMPLE_RATE, return_tensors="pt", padding=True)
            with torch.inference_mode():
                result = model(**inputs)
            similarities = (result.audio_embeds @ result.text_embeds.T)[0].cpu().numpy()
            scores = [round(float(value), 4) for value in similarities]
            takes.append({"index": index, "match": scores[0], "distractors": dict(zip(texts[1:], scores[1:])),
                          "margin": round(scores[0] - max(scores[1:]), 4)})
        report[job["id"]] = takes
        print(job["id"], json.dumps(takes), flush=True)
    path = CACHE_DIR / "sfx-semantic-report.json"
    path.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Report: {path}")


if __name__ == "__main__":
    main()
