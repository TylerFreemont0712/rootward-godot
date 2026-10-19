#!/usr/bin/env python3
"""The listening page (pipeline/music/README.md): every take of every track (or of a package), measured and playable, to
pick from.

For each take it makes what is missing: the analysis (numbers and picture, analyze.py), a master as the game would play
it (master.py, with the loop's seam as a clip of its own, since an audio element that loops by itself leaves a gap the
game does not), and for a song, what it sings (lyrics.py). Then it writes index.html beside the takes, which plays from
disk: open it in a browser. A take is picked by naming it as `pick` in its track's brief.

    uv run --project pipeline python pipeline/music/listen.py [<track>...] [--package <name>] [--no-lyrics]
"""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import analyze  # noqa: E402
import library  # noqa: E402
import lyrics  # noqa: E402
import master  # noqa: E402
import notation  # noqa: E402


def engine_of(take: str) -> str:
    return "ComfyUI" if take.startswith("yue2-comfy-") else "YuE2 native"


def gather(track: str, with_lyrics: bool) -> dict:
    brief = library.brief(track)
    folder = library.track_takes_dir(track)
    takes = []
    for take in library.takes(track):
        audio = library.find_take(track, take)
        numbers = folder / "analysis" / f"{take}.json"
        entry: dict = {"take": take, "engine": engine_of(take), "picture": f"{track}/analysis/{take}.png"}
        try:
            if not numbers.exists():
                analyze.analyze(audio, brief.get("bpm"), brief.get("key"), folder / "analysis")
            entry["analysis"] = json.loads(numbers.read_text())
            mastered = folder / f"{take}.master.json"
            if not mastered.exists() or not (folder / f"{take}.master.ogg").exists():
                master.master(track, take)
            entry["master"] = json.loads(mastered.read_text())
        except SystemExit as error:  # a take that cannot be mastered is shown as such, and the others still are
            entry["error"] = str(error.code)
        result = folder / f"{take}.result.json"
        if result.exists():
            entry["result"] = json.loads(result.read_text())
        if "master" in entry and brief.get("lyrics") and with_lyrics:
            entry["lyrics"] = lyrics.check(track, take)
        takes.append(entry)
    score = notation.parse(library.score_text(track))
    return {"id": track, "brief": brief, "takes": takes,
            "sections": " · ".join(f"{part['name']} {part['bars']}" for part in notation.timeline(score))}


def figure(track: dict, entry: dict) -> str:
    brief, take = track["brief"], entry["take"]
    picked = brief.get("pick") == take
    caption = f'<b>{html.escape(take)}</b> · {html.escape(entry["engine"])}'
    if picked:
        caption += " · picked"
    if "error" in entry:
        return (f'<figure class="{"pick" if picked else ""}"><figcaption>{caption}<br>'
                f'<span class="warn">{html.escape(entry["error"])}</span></figcaption>'
                f'<label>raw take <audio controls preload="none" src="{html.escape(track["id"] + "/" + take + ".wav")}">'
                f'</audio></label></figure>')
    numbers, mastered = entry["analysis"], entry["master"]
    fit = mastered["adherence"]
    facts = [f"{mastered['bpm']} bpm (asked {brief.get('bpm')})", numbers["key"]["key"],
             f"follows its score {fit['mean']:.2f}", f"{mastered['seconds']:.0f} s",
             f"brightness {numbers['colour']['above_5k'] * 100:.2f}% over 5 kHz, "
             f"{numbers['colour']['below_150'] * 100:.0f}% under 150 Hz (raw)"]
    if "loop" in mastered:
        facts.append(f"loop {mastered['loop']['seconds']:.0f} s, seam {mastered['seam']}")
    if "result" in entry:
        result = entry["result"]
        facts.append(f"made in {result['took_seconds']:.0f} s ({result['realtime']}x real time"
                     + (f", peak {result['peak_vram_mib']} MiB" if result.get("peak_vram_mib", -1) > 0 else "") + ")")
    if "lyrics" in entry:
        words = entry["lyrics"]
        facts.append(f"sings {words['ok']} of {words['lyric_words']} words (error rate {words['wer']})")
    players = [f'<label>master <audio controls preload="none" '
               f'src="{html.escape(track["id"] + "/" + take + ".master.ogg")}"></audio></label>']
    seam_clip = library.track_takes_dir(track["id"]) / f"{take}.seam.ogg"
    if seam_clip.exists():
        players.append(f'<label>the seam (8 s before, 8 s after) <audio controls preload="none" '
                       f'src="{html.escape(track["id"] + "/" + seam_clip.name)}"></audio></label>')
    players.append(f'<label>raw take <audio controls preload="none" '
                   f'src="{html.escape(track["id"] + "/" + take + ".wav")}"></audio></label>')
    heard = ""
    if "lyrics" in entry and entry["lyrics"]["misheard"] + entry["lyrics"]["missed"]:
        heard = ("<p class=note>misheard: " + html.escape(", ".join(entry["lyrics"]["misheard"][:12]))
                 + (" · missed: " + html.escape(", ".join(entry["lyrics"]["missed"][:12]))
                    if entry["lyrics"]["missed"] else "") + "</p>")
    return (f'<figure class="{"pick" if picked else ""}"><figcaption>{caption}<br>'
            f'{html.escape(" · ".join(facts))}</figcaption>'
            f'{"".join(players)}{heard}<img loading="lazy" src="{html.escape(entry["picture"])}" '
            f'alt="analysis of {html.escape(take)}"></figure>')


def page(tracks: list[dict], title: str) -> str:
    body = []
    for track in tracks:
        brief = track["brief"]
        body.append(f'<section id="{html.escape(track["id"])}"><h2>{html.escape(brief.get("title", track["id"]))} '
                    f'<small>{html.escape(track["id"])} → {html.escape(brief.get("out", ""))} · '
                    f'{html.escape(brief.get("key", ""))} · {brief.get("bpm")} bpm · '
                    f'{html.escape(brief.get("kind", "loop"))}</small></h2>'
                    f'<p>{html.escape(brief.get("role", ""))}</p><p class=note>{html.escape(track["sections"])}</p>'
                    + ("".join(figure(track, entry) for entry in track["takes"]) or "<p>No takes yet.</p>")
                    + "</section>")
    index = " · ".join(f'<a href="#{html.escape(t["id"])}">{html.escape(t["brief"].get("title", t["id"]))}</a>'
                       for t in tracks)
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rootward music takes</title>
<style>
:root {{ --bg: #16110e; --panel: #221a15; --text: #eadfce; --muted: #a8998a; --accent: #f2a541; --pick: #6ddf9a; }}
body {{ background: var(--bg); color: var(--text); font: 15px/1.5 system-ui, sans-serif; margin: 0 auto; max-width: 1500px;
       padding: 16px; }}
h1 {{ color: var(--accent); }} h2 {{ margin-top: 40px; }} small {{ color: var(--muted); font-weight: normal; }}
a {{ color: var(--accent); }} .note {{ color: var(--muted); }} .warn {{ color: #f08a6a; }}
figure {{ background: var(--panel); border-radius: 8px; margin: 12px 0; padding: 12px; }}
figure.pick {{ outline: 2px solid var(--pick); }}
figcaption {{ margin-bottom: 8px; }} label {{ display: inline-flex; align-items: center; gap: 6px; margin: 4px 16px 4px 0;
       color: var(--muted); }}
img {{ display: block; margin-top: 8px; max-width: 100%; border-radius: 4px; }}
</style></head><body>
<h1>{html.escape(title)}</h1>
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
    parser.add_argument("--package", help="the tracks of packages/<name>.json (the ones that exist)")
    parser.add_argument("--no-lyrics", action="store_true")
    args = parser.parse_args()
    title = "Rootward music: every take"
    if args.package:
        try:
            package = library.load_package(args.package)
        except library.PackageError as error:
            sys.exit(str(error))
        title = f"Rootward music: {package.title}"
        for track in package.missing:
            print(f"missing track {track}: no tracks/{track}/brief.json yet; not on the page")
        names = package.present
    else:
        names = args.tracks or library.track_ids()
    tracks = [gather(name, not args.no_lyrics) for name in names]
    page_path = library.takes_dir() / ("index.html" if not args.package else f"index-{args.package}.html")
    page_path.parent.mkdir(parents=True, exist_ok=True)
    page_path.write_text(page(tracks, title))
    print(f"{page_path}: {sum(len(t['takes']) for t in tracks)} takes of {len(tracks)} tracks")


if __name__ == "__main__":
    main()
