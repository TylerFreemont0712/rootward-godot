# ADR-0038: A prompted soundtrack, "Glass Circuit", replaces the composed one slot by slot

Accepted 2026-10-03.

## Context

The player found the soundtrack of ADR-0019 (scores of our own, performed by YuE2) too generic for the game's current
art and direction. They had tested the ComfyUI workflow `yue2_MusicGen` (YuE2 plans an ABC score from a style and
lyrics, then plays it) and liked its results, and asked a sound designer to propose a soundtrack for it.

## Decision

- The new soundtrack is **prompted, not composed**: each track is a style string and lyrics (section tags for an
  instrumental), a seed on the YuE2 Generate Music node and a duration cap, run through the unchanged workflow. The
  designer's identity, "Glass Circuit" (glassy kalimba, glockenspiel and celesta arpeggios, warm analog synth, airy
  choir, taiko), and every track's exact prompt and seeds are in `test/music/SOUNDTRACK.md` and `queue.json`.
- Tracks were replaced once the player had heard and approved them, and all thirteen slots now are: the title (the
  rough take "b"), the Salvage, Heap and Kernel maps, rest, the three battle themes (Salvage take 1), the two
  guardians, and the treasure, victory and defeat cues (the victory and defeat cues are the 12 s and 13 s trimmed
  cuts, not the 40 s takes).
- `test/music/install_music.py` installs a slot from its mastered take: the steps of `pipeline/music/master.py`
  (tone, one level gain, a bar-aligned loop cut at `loopEnd` with a 0.15 s crossfade) into `game/assets/audio/` and
  `music.json`. The planner picks its own key and tempo, so several tracks are not in D (the sound effects' key).

## Consequences

- A prompted track cannot be given a melody: the recurring motif lives only in the wording of the prompts.
- The planner writes at least about 30 s however short the cap, so stingers are trimmed and faded cuts, not composed.
- The takes (`test/music/`, about 450 MB) are local and uncommitted; the installed `.ogg` files are the record.
- YuE2's licence (CC BY-NC 4.0) is unchanged by this decision.
