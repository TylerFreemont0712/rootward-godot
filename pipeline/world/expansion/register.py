"""Register completed expansion pictures in Lanternroot Studio, preserving the catalog's compact format.

Run after world.sh cut: pipeline/.venv/bin/python pipeline/world/expansion/register.py
Use --ready-only while a batch is still rendering. Never register a missing picture.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
GROUPS = ("boundaries", "furniture", "nature-work", "imagegen")
CATALOG = ROOT / "game/content/packs/core/overworld/catalog.jsonc"
PICTURES = ROOT / "game/assets/overworld/world"


def parsed(path: Path) -> dict:
    return json.loads("\n".join(line for line in path.read_text().splitlines() if not line.lstrip().startswith("//")))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ready-only", action="store_true")
    args = parser.parse_args()
    catalog = parsed(CATALOG)
    index = parsed(PICTURES / "world.json")
    entries: dict = {}
    for group in GROUPS:
        for oid, entry in parsed(HERE / f"{group}.json").items():
            if oid in entries:
                raise ValueError(f"duplicate expansion id: {oid}")
            entries[oid] = entry
    missing = [oid for oid in entries if not (PICTURES / f"{oid}.png").exists() or oid not in index]
    if missing and not args.ready_only:
        raise ValueError(f"render these objects before registration: {', '.join(missing)}")
    farm = next(category for category in catalog["categories"] if category["id"] == "farm_and_work")
    for oid, name in (("animal_care", "Animal care"), ("farm_tools", "Farm tools"), ("workstations", "Workstations")):
        if not any(sub["id"] == oid for sub in farm["subcategories"]):
            farm["subcategories"].append({"id": oid, "name": name})
    categories = {category["id"]: {sub["id"] for sub in category["subcategories"]} for category in catalog["categories"]}
    ready = {oid: entry for oid, entry in entries.items() if oid not in missing}
    for oid, entry in ready.items():
        if entry["subcategory"] not in categories.get(entry["category"], set()):
            raise ValueError(f"{oid}: unknown category/subcategory")
        if entry["size"] != index[oid]["footprint"]:
            raise ValueError(f"{oid}: catalog and art footprint differ")
        if oid in catalog["assets"] and catalog["assets"][oid] != entry:
            raise ValueError(f"{oid}: existing catalog entry differs; review it before overwriting")
    catalog["assets"].update(ready)
    lines = CATALOG.read_text().splitlines()
    header = lines[:next(i for i, line in enumerate(lines) if line.strip() == "{")]
    out = header + ["{", '  "categories": [']
    for i, category in enumerate(catalog["categories"]):
        out.append("    " + json.dumps(category, ensure_ascii=False) + ("," if i + 1 < len(catalog["categories"]) else ""))
    out += ["  ],", '  "assets": {']
    for i, (oid, entry) in enumerate(catalog["assets"].items()):
        out.append("    " + json.dumps(oid) + ": " + json.dumps(entry, ensure_ascii=False) + ("," if i + 1 < len(catalog["assets"]) else ""))
    out += ["  }", "}", ""]
    CATALOG.write_text("\n".join(out))
    print(f"Registered {len(ready)} expansion objects; catalog now has {len(catalog['assets'])} entries.")
    if missing:
        print(f"Waiting for {len(missing)} pictures.")


if __name__ == "__main__":
    main()
