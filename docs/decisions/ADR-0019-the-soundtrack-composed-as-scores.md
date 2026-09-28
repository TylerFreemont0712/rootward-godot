# ADR-0019: the soundtrack composed as scores, performed by YuE2

- Status: accepted
- Date: 2026-09-28
- Related: ADR-0005 (one asset pipeline), ADR-0020 (sounds made on their animations)

## Context

The player: "THe current music is... very rudementary and needs a lot of work. First, can you make sure that the
current pipeline is the best that we can do? I saw YuE2 has a fairly compact gguf model that we could probably use, and
the general workflow should be pretty guided, instead of just a prompt, I'd like you to be much more involved in the
music creation process. Of the current music the semi-violin high tempo feels like the best track, but it still needs
work."

Measured, the old tracks (ACE-Step 1.5 turbo, one prompt each) were dark (0 to 2.4% of their energy over 5 kHz),
boomy (12 to 66% under 150 Hz), wandering (little self-similarity) and drifting (up to 4.7 beats); Salvage Skirmish
dropped out at 13 s. Nothing in them was composed: the model chose every note.

## Options

1. ACE-Step with better prompts or its 4B XL model: still a prompt; the model writes the music.
2. Stable Audio 3 Medium: better instrumental sound, inpainting and continuation, still a prompt.
3. MiniMax Music 3: open weights, but an 8B planner the 8 GB GPU cannot hold.
4. YuE2 (m-a-p) through yue2.cpp: its planner writes an ABC score (melody and chords), then the audio from it; given
   a score, it plays that score. 3.8 GB in Q8_0.

## Decision

- **Every track is composed**: a brief (role, key, tempo, form, loop) and an ABC score (melody and chords, bar by bar)
  in `pipeline/music/tracks/<id>/`, with one leitmotif (1 5 1 3 2 1) through the soundtrack. YuE2 performs the score.
- **Every take is measured and heard in place**: tempo and grid, key, loudness, colour, shape, how closely each bar
  holds the score (chroma against the score's pitch classes), what a song sings (Whisper); a master as the game will
  play it (bar-line loop, crossfaded seam, colour faults corrected, one gain) and the seam as a clip; all on one local
  page (`listen.py`). The brief's `pick` goes into the game (`master.py`).
- **The score goes to YuE2 as SheetSage2 writes the scores it trained on**: its note lengths only, no spaces in a bar.

## Consequences

- The picks follow their scores at 0.68 to 0.94 (per-bar chroma correlation); the old tracks had no score to follow.
  The same seeds followed a canonical score 0.70 against 0.67 for a spaced one.
- YuE2's weights are CC BY-NC 4.0: right for Rootward, which is not sold; a commercial release would perform the
  scores again with another model. The scores are ours either way.
- Nobody in the loop can hear, so the picks are by measurement; the player listens on the page and changes `pick`.
- The old manifest's music entries are retired (`pipeline/audio` makes sound effects and the treasure cue only).
- A bonus song (`bonus-keep-me-a-light`, sung, not in the game) proved the sung path: 175 of 178 words heard.
