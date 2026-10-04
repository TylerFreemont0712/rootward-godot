# Everything beyond the cards, for paradigm_update_art.py: relics, laws, focus emblems, scripts, issue pictures and the
# Registry's pieces. Subjects live in paradigm-update-subjects.json (one bold object each, house style).
import json
from pathlib import Path

subjects = json.loads((Path(HERE) / "paradigm-update-subjects.json").read_text())
ASSETS = []
for relic_id, subject in {**subjects["emblems"], **subjects["laws"], **subjects["relics"]}.items():
    # ComfyUI repeatedly returned a multi-emblem sheet for this one; it is implemented as a source SVG instead.
    if relic_id != "focus-table":
        ASSETS.append(asset(f"shardrun-relic-{relic_id}", f"shardrun/relic-{relic_id}", subject))
for icon_id, subject in subjects["map_rooms"].items():
    ASSETS.append(asset(f"shardrun-{icon_id}", f"shardrun/{icon_id}", subject, style="program-map-icon"))
for script_id, subject in subjects["scripts"].items():
    ASSETS.append(asset(f"shardrun-script-{script_id}", f"shardrun/script-{script_id}", subject))
for issue_id, subject in subjects["issues"].items():
    ASSETS.append(asset(f"shardrun-issue-{issue_id}", f"shardrun/issue-{issue_id}", subject, post={"size": [384, 384]}))
for name, subject in subjects["misc"].items():
    if name == "registry":
        ASSETS.append(asset("shardrun-registry", "shardrun/registry", subject, style="program-backdrop"))
    else:
        ASSETS.append(asset(f"shardrun-{name}", f"shardrun/{name}", subject))
