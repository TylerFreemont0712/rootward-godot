#!/usr/bin/env python3
"""The listening page (pipeline/music/README.md): every take of every track, measured and playable, to pick from.

For each take it makes what is missing: the analysis (numbers and picture, analyze.py), a master as the game would
play it (master.py, with the loop's seam as a clip of its own, since an audio element that loops by itself leaves a
gap the game does not), and for a song, what it sings (lyrics.py). Then it writes pipeline/cache/music/index.html,
which plays from disk: open it in a browser. A take is picked by naming it as `pick` in its track's brief.

    uv run --project pipeline python pipeline/music/listen.py [<track>...] [--no-lyrics]
"""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402
import lyrics  # noqa: E402
import master  # noqa: E402
import notation  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TRACKS = Path(__file__).with_name("tracks")
CACHE = ROOT / "pipeline" / "cache" / "music"
PAGE = CACHE / "index.html"


def gather(track: str, with_lyrics: bool) -> dict:
    brief = json.loads((TRACKS / track / "brief.json").read_text())
    folder = CACHE / track
    takes = []
    for audio in sorted(folder.glob("yue2-*.wav")) if folder.exists() else []:
        take = audio.stem
        numbers = folder / "analysis" / f"{take}.json"
        if not numbers.exists():
            analyze.analyze(audio, brief.get("bpm"), brief.get("key"), folder / "analysis")
        mastered = folder / f"{take}.master.json"
        if not mastered.exists():
            master.master(track, take)
        entry = {"take": take, "analysis": json.loads(numbers.read_text()),
                 "master": json.loads(mastered.read_text()), "picture": f"{track}/analysis/{take}.png"}
        if brief.get("lyrics") and with_lyrics:
            entry["lyrics"] = lyrics.check(track, take)
        takes.append(entry)
    score = notation.parse((TRACKS / track / "score.abc").read_text())
    return {"id": track, "brief": brief, "takes": takes,
            "sections": " · ".join(f"{part['name']} {part['bars']}" for part in notation.timeline(score))}


def figure(track: dict, entry: dict) -> str:
    brief, take = track["brief"], entry["take"]
    numbers, mastered = entry["analysis"], entry["master"]
    fit = mastered["adherence"]
    facts = [f"{mastered['bpm']} bpm (asked {brief.get('bpm')})", numbers["key"]["key"],
             f"follows its score {fit['mean']:.2f}", f"{mastered['seconds']:.0f} s",
             f"brightness {numbers['colour']['above_5k'] * 100:.2f}% over 5 kHz, "
             f"{numbers['colour']['below_150'] * 100:.0f}% under 150 Hz (raw)"]
    if "loop" in mastered:
        facts.append(f"loop {mastered['loop']['seconds']:.0f} s, seam {mastered['seam']}")
    if "lyrics" in entry:
        words = entry["lyrics"]
        facts.append(f"sings {words['ok']} of {words['lyric_words']} words (error rate {words['wer']})")
    picked = brief.get("pick") == take
    # The page sits in pipeline/cache/music/; a picked game track's master is in game/assets/audio/.
    master_src = f"{track['id']}/{take}.master.ogg"
    if picked and brief.get("kind", "loop") != "bonus":
        master_src = "../../../" + mastered["file"]
    players = [f'<label>master <audio controls preload="none" src="{html.escape(master_src)}"></audio></label>']
    seam_clip = CACHE / track["id"] / f"{take}.seam.ogg"
    if seam_clip.exists():
        players.append(f'<label>the seam (8 s before, 8 s after) <audio controls preload="none" '
                       f'src="{html.escape(track["id"] + "/" + seam_clip.name)}"></audio></label>')
    players.append(f'<label>raw take <audio controls preload="none" '
                   f'src="{html.escape(track["id"] + "/" + take + ".wav")}"></audio></label>')
    heard = ""
    if "lyrics" in entry and entry["lyrics"]["misheard"] + entry["lyrics"]["missed"]:
        heard = ("<p class=note>misheard: " + html.escape(", ".join(entry["lyrics"]["misheard"][:12]))
                 + (" · missed: " + html.escape(", ".join(entry["lyrics"]["missed"][:12])) if entry["lyrics"]["missed"] else "")
                 + "</p>")
    return (f'<figure class="{"pick" if picked else ""}"><figcaption><b>{html.escape(take)}</b>'
            f'{" · picked" if picked else ""}<br>{html.escape(" · ".join(facts))}</figcaption>'
            f'{"".join(players)}{heard}<img loading="lazy" src="{html.escape(entry["picture"])}" alt="analysis of {html.escape(take)}"></figure>')


def page(tracks: list[dict]) -> str:
    body = []
    for track in tracks:
        brief = track["brief"]
        body.append(f'<section id="{html.escape(track["id"])}"><h2>{html.escape(brief["title"])} '
                    f'<small>{html.escape(track["id"])} → {html.escape(brief["out"])} · {html.escape(brief.get("key", ""))} · '
                    f'{brief.get("bpm")} bpm · {html.escape(brief.get("kind", "loop"))}</small></h2>'
                    f'<p>{html.escape(brief.get("role", ""))}</p><p class=note>{html.escape(track["sections"])}</p>'
                    + ("".join(figure(track, entry) for entry in track["takes"]) or "<p>No takes yet.</p>")
                    + "</section>")
    index = " · ".join(f'<a href="#{html.escape(t["id"])}">{html.escape(t["brief"]["title"])}</a>' for t in tracks)
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rootward music takes</title>
<style>
:root {{ --bg: #16110e; --panel: #221a15; --text: #eadfce; --muted: #a8998a; --accent: #f2a541; --pick: #6ddf9a; }}
body {{ background: var(--bg); color: var(--text); font: 15px/1.5 system-ui, sans-serif; margin: 0 auto; max-width: 1500px;
       padding: 16px; }}
h1 {{ color: var(--accent); }} h2 {{ margin-top: 40px; }} small {{ color: var(--muted); font-weight: normal; }}
a {{ color: var(--accent); }} .note {{ color: var(--muted); }}
figure {{ background: var(--panel); border-radius: 8px; margin: 12px 0; padding: 12px; }}
figure.pick {{ outline: 2px solid var(--pick); }}
figcaption {{ margin-bottom: 8px; }} label {{ display: inline-flex; align-items: center; gap: 6px; margin: 4px 16px 4px 0;
       color: var(--muted); }}
img {{ display: block; margin-top: 8px; max-width: 100%; border-radius: 4px; }}
</style></head><body>
<h1>Rootward music: every take</h1>
<p>Masters are levelled and toned as the game would play them. A loop's seam clip is the join the game plays, the
loop's end running into its start. Pick a take by setting <code>"pick"</code> in the track's brief, then run
<code>master.py &lt;track&gt;</code>.</p>
<p>{index}</p>
{"".join(body)}
</body></html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("tracks", nargs="*")
    parser.add_argument("--no-lyrics", action="store_true")
    args = parser.parse_args()
    names = args.tracks or sorted(path.name for path in TRACKS.iterdir() if (path / "brief.json").exists())
    tracks = [gather(name, not args.no_lyrics) for name in names]
    PAGE.parent.mkdir(parents=True, exist_ok=True)
    PAGE.write_text(page(tracks))
    print(f"{PAGE.relative_to(ROOT)}: {sum(len(t['takes']) for t in tracks)} takes of {len(tracks)} tracks")


if __name__ == "__main__":
    main()
