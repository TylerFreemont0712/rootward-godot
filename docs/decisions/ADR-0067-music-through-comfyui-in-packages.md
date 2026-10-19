# ADR-0067: Composed scores performed through ComfyUI, in packages, to a solid soundtrack concept

Accepted 2026-10-13. Builds on ADR-0019 (the soundtrack is composed, not prompted). The concept is
`Concept/v0.3/13-soundtrack-solid.md`; the pipeline is `pipeline/music/README.md`.

## Context

The player found the main menu "a little too lullaby like" and asked for "a more solid soundtrack concept", a new
package for the main menu and the new Lanternroot mode, made with "our ComfyUI music pipeline", edited and improved.
Lanternroot played `music-rest`, the soundtrack's lullaby, everywhere: the character screen, the town and indoors.

An audit of `pipeline/music/` found that the ComfyUI route never performed a composed score: the saved
`yue2_MusicGen` workflow fed its music node the ABC its own planner wrote, so a ComfyUI take was a prompted piece
(ADR-0038's way), not our score. `perform.py` only used the native `yue2.cpp`. `master.py` and `listen.py` could not
run (they loaded a `soundtrack.json` an earlier commit had removed), a crashed render left a truncated file under its
final name for the cache to serve, and two runs could load two models on the 8 GB card.

## Decision

- **Two engines, one score.** `perform.py --engine comfy|native|auto` performs the same brief and score through the
  ComfyUI workflow (the composed score is the music node's ABC input; the planner nodes are dropped) or through
  `yue2.cpp`. `auto` uses ComfyUI while it is up. A ComfyUI take is named `yue2-comfy-...`, since its weights and
  sampler differ and its takes are not comparable with native ones. The smoke take followed its score at a mean
  adherence of 0.946 per bar, about 2.4 times faster than real time.
- **Packages.** `pipeline/music/packages/<name>.json` lists the tracks made together and the concept they follow;
  `perform.py --package` performs them one after another (one GPU job at a time, a lock in the takes folder) and goes on
  past a failure; `listen.py --package` lays out only those takes to pick from.
- **The solid concept.** Every loop has a groove (drums and a bass line), a melody to hum and sections that contrast,
  in "lantern folk with a backbeat" (guitar, fiddle, whistle, accordion, upright bass, live drums, horns for the big
  statements), no tempo under about 80 BPM, and the leitmotif (1 5 1 3 2 1) in each piece's guise. The package is a
  new `title` and four Lanternroot places: the front door (character select), the town, indoors and coding.
- **The game asks for a place's track and falls back.** The character screen plays `music-lanternroot-front`; the
  overworld plays `music-lanternroot-lesson` while a code editor is open (the boots, a lesson, a thing), else
  `music-lanternroot-town` outdoors and `music-lanternroot-home` indoors. Each falls back to the place's track and then
  to `music-rest` (`Sound.music_first`), so the mode sounds as before until the player picks and masters a take.
- The tools that read `soundtrack.json` are kept in `pipeline/music/retired/` until someone ports what is worth it.

## Alternatives

- **Prompted music in ComfyUI (ACE-Step, Stable Audio).** Faster to get something, but nothing to hold a tune across
  the soundtrack; ADR-0019 replaced it for that reason.
- **Native `yue2.cpp` only.** It works, but the player's pipeline and the one they asked to improve is ComfyUI's, and
  ComfyUI is usually up for the art pipelines anyway.
- **Replacing `music-rest` in place.** The rest stop in the Shardrun still wants its lullaby; Lanternroot gets its own.

## Consequences

- The takes are judged by numbers (tempo, key, adherence, loudness, colour, seam) and by the player's ear on the
  listening page; the game changes only when the player sets a `pick` and runs `master.py`.
- YuE2's licence (CC BY-NC 4.0) covers the ComfyUI checkpoint as it does the GGUF weights: fine while Rootward is not
  sold, to be performed again with another model for any commercial release (`docs/ASSET_LICENCES.md`).
- The new title score replaces the old one in the repository; the old take stays the game's `music-title` until a new
  pick is mastered.
